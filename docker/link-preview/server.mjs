/**
 * SPECACT link-preview service (optional). A browser cannot read another site's HTML (CORS) and SPECACT has no
 * backend, so a page that should show a pasted link as a card (Open Graph) is fetched here — on YOUR server —
 * and handed back to the app, which parses the tags itself.
 *
 *   GET /link-preview?url=<page>                 -> the page's HTML (text/html, at most 1.5 MB)
 *   GET /link-preview?url=<picture>&kind=image   -> the picture (jpeg/png/webp/gif/avif only, at most 5 MB; never SVG)
 *
 * Safe to expose: only http(s), every address a name resolves to must be public (no localhost, LAN, link-local or
 * cloud-metadata addresses) and is re-checked on every redirect; responses are size- and time-limited; requests are
 * rate-limited per client; nothing is stored or logged.
 */
import dns from 'node:dns/promises';
import http from 'node:http';
import net from 'node:net';

const MAX_HTML = 1_500_000;
const MAX_IMAGE = 5 * 1024 * 1024;
const TIMEOUT_MS = 8000;
const MAX_REDIRECTS = 4;
const RATE = { windowMs: 60_000, max: 40 };
const UA = 'Mozilla/5.0 (compatible; SPECACTLinkPreview/1.0)';

/** True for any address that must never be fetched on behalf of a visitor. */
export function isBlockedAddress(ip) {
  if (net.isIPv4(ip)) {
    const [a, b] = ip.split('.').map(Number);
    return a === 0 || a === 10 || a === 127 || (a === 100 && b >= 64 && b <= 127) || (a === 169 && b === 254) || (a === 172 && b >= 16 && b <= 31)
      || (a === 192 && b === 0) || (a === 192 && b === 168) || (a === 198 && (b === 18 || b === 19)) || a >= 224;
  }
  if (net.isIPv6(ip)) {
    const v = ip.toLowerCase();
    const mapped = /^::ffff:(\d+\.\d+\.\d+\.\d+)$/.exec(v);
    if (mapped) return isBlockedAddress(mapped[1]);
    return v === '::' || v === '::1' || v.startsWith('fc') || v.startsWith('fd') || /^fe[89ab]/.test(v) || v.startsWith('ff') || v.startsWith('64:ff9b');
  }
  return true; // not an address at all
}

/** Throws unless the URL is plain http(s) to a public host; returns the parsed URL. */
export async function assertPublic(raw, lookup = dns.lookup) {
  let u;
  try { u = new URL(raw); } catch { throw new Error('bad-url'); }
  if (u.protocol !== 'http:' && u.protocol !== 'https:') throw new Error('bad-scheme');
  if (u.username || u.password) throw new Error('credentials-in-url');
  const host = u.hostname.replace(/^\[|\]$/g, '');
  const addrs = net.isIP(host) ? [{ address: host }] : await lookup(host, { all: true, verbatim: true });
  if (!addrs.length || addrs.some((a) => isBlockedAddress(a.address))) throw new Error('blocked-address');
  return u;
}

async function readLimited(res, max) {
  const chunks = [];
  let size = 0;
  for await (const c of res.body) {
    size += c.length;
    if (size > max) break; // an oversized page is cut, not refused: the tags live at the top
    chunks.push(c);
  }
  return Buffer.concat(chunks);
}

/** Fetch with the public-address check on every hop. */
export async function safeFetch(raw, { image = false, fetchImpl = fetch, lookup = dns.lookup } = {}) {
  let url = raw;
  for (let hop = 0; hop <= MAX_REDIRECTS; hop++) {
    const u = await assertPublic(url, lookup);
    const res = await fetchImpl(u, {
      redirect: 'manual', signal: AbortSignal.timeout(TIMEOUT_MS),
      headers: { 'User-Agent': UA, Accept: image ? 'image/*' : 'text/html,application/xhtml+xml', 'Accept-Language': 'en,vi;q=0.8' },
    });
    if (res.status >= 300 && res.status < 400 && res.headers.get('location')) { url = new URL(res.headers.get('location'), u).href; continue; }
    if (!res.ok) throw new Error(`upstream-${res.status}`);
    const type = (res.headers.get('content-type') || '').toLowerCase();
    if (image) {
      if (!/^image\/(jpeg|png|webp|gif|avif)/.test(type)) throw new Error('not-an-image');
      return { type: type.split(';')[0], body: await readLimited(res, MAX_IMAGE) };
    }
    if (!/(text\/html|application\/xhtml)/.test(type)) throw new Error('not-html');
    return { type: 'text/html; charset=utf-8', body: await readLimited(res, MAX_HTML) };
  }
  throw new Error('too-many-redirects');
}

const hits = new Map();
function limited(key) {
  const now = Date.now();
  const h = (hits.get(key) || []).filter((t) => now - t < RATE.windowMs);
  h.push(now);
  hits.set(key, h);
  if (hits.size > 5000) for (const [k, v] of hits) if (!v.some((t) => now - t < RATE.windowMs)) hits.delete(k);
  return h.length > RATE.max;
}

export async function handle(req, res, options = {}) {
  const send = (code, type, body) => { res.writeHead(code, { 'Content-Type': type, 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff', 'Content-Security-Policy': "default-src 'none'; sandbox" }); res.end(body); };
  const u = new URL(req.url, 'http://x');
  if (req.method !== 'GET' || u.pathname !== '/link-preview') return send(404, 'text/plain', 'not found');
  const client = String(req.headers['x-forwarded-for'] || req.socket?.remoteAddress || '').split(',')[0].trim();
  if (limited(client)) return send(429, 'text/plain', 'slow down');
  try {
    const target = u.searchParams.get('url') || '';
    if (target.length > 2000) return send(400, 'text/plain', 'bad url');
    const { type, body } = await safeFetch(target, { image: u.searchParams.get('kind') === 'image', ...options });
    return send(200, type, body);
  } catch (e) {
    return send(/^(bad-|blocked|credentials|not-)/.test(e.message) ? 400 : 502, 'text/plain', 'unavailable');
  }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  http.createServer((req, res) => { handle(req, res).catch(() => { res.writeHead(500); res.end(); }); }).listen(Number(process.env.PORT) || 8787, '0.0.0.0', () => console.log('link-preview listening'));
}
