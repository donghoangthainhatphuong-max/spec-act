import { describe, expect, it, vi } from 'vitest';
import { assertPublic, handle, isBlockedAddress, safeFetch } from '../docker/link-preview/server.mjs';

const lookupTo = (address) => async () => [{ address }];
const res = (status, body, headers = {}) => new Response(body, { status, headers });

describe('link-preview service: only public addresses', () => {
  it('blocks loopback, LAN, link-local, metadata and mapped addresses', () => {
    for (const ip of ['127.0.0.1', '10.1.2.3', '172.16.0.9', '172.31.255.1', '192.168.1.5', '169.254.169.254', '100.64.0.1', '0.0.0.0', '::1', 'fe80::1', 'fc00::1', 'fd12::1', '::ffff:127.0.0.1', '::ffff:10.0.0.1', 'not-an-ip']) expect(isBlockedAddress(ip), ip).toBe(true);
    for (const ip of ['8.8.8.8', '1.1.1.1', '172.32.0.1', '2606:4700:4700::1111']) expect(isBlockedAddress(ip), ip).toBe(false);
  });

  it('refuses other schemes, credentials and names that resolve to private addresses', async () => {
    await expect(assertPublic('file:///etc/passwd')).rejects.toThrow('bad-scheme');
    await expect(assertPublic('javascript:alert(1)')).rejects.toThrow();
    await expect(assertPublic('http://user:pw@example.com/')).rejects.toThrow('credentials-in-url');
    await expect(assertPublic('http://127.0.0.1:8080/')).rejects.toThrow('blocked-address');
    await expect(assertPublic('http://[::1]/')).rejects.toThrow('blocked-address');
    await expect(assertPublic('http://evil.example/', lookupTo('10.0.0.5'))).rejects.toThrow('blocked-address');
    expect((await assertPublic('https://ok.example/a', lookupTo('93.184.216.34'))).hostname).toBe('ok.example');
  });

  it('re-checks every redirect hop (a public page cannot bounce the service into the LAN)', async () => {
    const lookup = async (host) => [{ address: host === 'inner.example' ? '192.168.0.10' : '93.184.216.34' }];
    const fetchImpl = vi.fn(async (u) => (String(u).includes('start') ? res(302, '', { location: 'http://inner.example/admin' }) : res(200, 'secret', { 'content-type': 'text/html' })));
    await expect(safeFetch('https://pub.example/start', { fetchImpl, lookup })).rejects.toThrow('blocked-address');
    expect(fetchImpl).toHaveBeenCalledTimes(1);
  });

  it('returns HTML, only HTML, and only real pictures for kind=image', async () => {
    const lookup = lookupTo('93.184.216.34');
    const ok = await safeFetch('https://pub.example/', { lookup, fetchImpl: async () => res(200, '<title>Hi</title>', { 'content-type': 'text/html; charset=utf-8' }) });
    expect(ok.body.toString()).toContain('Hi');
    await expect(safeFetch('https://pub.example/x.json', { lookup, fetchImpl: async () => res(200, '{}', { 'content-type': 'application/json' }) })).rejects.toThrow('not-html');
    await expect(safeFetch('https://pub.example/a.svg', { image: true, lookup, fetchImpl: async () => res(200, '<svg onload=alert(1)>', { 'content-type': 'image/svg+xml' }) })).rejects.toThrow('not-an-image');
    expect((await safeFetch('https://pub.example/a.png', { image: true, lookup, fetchImpl: async () => res(200, new Uint8Array([1, 2]), { 'content-type': 'image/png' }) })).type).toBe('image/png');
  });

  it('answers over HTTP without caching, sandboxed, and hides internals', async () => {
    const out = {};
    const r = { writeHead: (c, h) => { out.code = c; out.headers = h; }, end: (b) => { out.body = b; } };
    await handle({ method: 'GET', url: '/link-preview?url=http%3A%2F%2F127.0.0.1%2F', headers: { 'x-forwarded-for': '9.9.9.9' }, socket: {} }, r);
    expect(out.code).toBe(400);
    expect(String(out.body)).toBe('unavailable'); // no detail about why
    expect(out.headers['Cache-Control']).toBe('no-store');
    await handle({ method: 'GET', url: '/other', headers: {}, socket: {} }, r);
    expect(out.code).toBe(404);
  });
});
