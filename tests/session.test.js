import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { FakeDrive } from './fakeDrive';

vi.mock('../src/config', async (orig) => {
  const mod = await orig();
  return { ...mod, config: { ...mod.config, pbkdf2Iterations: 1000, postKdfIterations: 1000, pinMaxAttempts: 5 } };
});

const { useSessionStore } = await import('../src/stores/session');
const { vault } = await import('../src/services/secureStore');
const { captureRedirect, buildSignInUrl } = await import('../src/services/googleAuth');

const PIN = '482916';
let fake;
let tokenCalls;
let refreshBehaviour;

function installFetch() {
  fake = new FakeDrive();
  fake.addUser('alice@gmail.com', 'Alice');
  tokenCalls = [];
  refreshBehaviour = 'ok';
  globalThis.fetch = async (url, init) => {
    if (String(url) === 'https://oauth2.googleapis.com/token') {
      const body = Object.fromEntries(new URLSearchParams(init.body));
      tokenCalls.push(body);
      const json = (status, b) => new Response(JSON.stringify(b), { status, headers: { 'Content-Type': 'application/json' } });
      if (body.client_id !== 'cid.apps.googleusercontent.com') return json(401, { error: 'invalid_client' });
      if (body.grant_type === 'authorization_code') {
        if (body.code !== 'good-code' || !body.code_verifier) return json(400, { error: 'invalid_grant' });
        return json(200, { access_token: 'tok-alice@gmail.com', refresh_token: 'refresh-1', expires_in: 3600, scope: 'https://www.googleapis.com/auth/drive' });
      }
      if (refreshBehaviour === 'revoked') return json(400, { error: 'invalid_grant' });
      if (refreshBehaviour === 'network') throw new TypeError('offline');
      return json(200, { access_token: 'tok-alice@gmail.com', expires_in: 3600, scope: 'https://www.googleapis.com/auth/drive' });
    }
    return fake.fetch(url, init);
  };
}

/** What Google does after consent: sends the browser back to the app with ?code&state. */
async function simulateGoogleRedirect(code = 'good-code', tamper = false) {
  const url = new URL(await buildSignInUrl({ clientId: 'cid.apps.googleusercontent.com' }));
  expect(url.searchParams.get('code_challenge_method')).toBe('S256');
  expect(url.searchParams.get('access_type')).toBe('offline');
  expect(url.searchParams.get('scope')).toContain('auth/drive');
  history.replaceState(null, '', `/?code=${code}&state=${tamper ? 'forged' : url.searchParams.get('state')}#/welcome`);
  expect(captureRedirect()).toBe(true);
  expect(location.search).toBe(''); // the code never stays in the address bar
}

beforeEach(async () => {
  await vault.wipe();
  sessionStorage.clear();
  history.replaceState(null, '', '/');
  installFetch();
  setActivePinia(createPinia());
});

describe('session', () => {
  it('first run: PIN → keys → Google → ready; then lock/unlock refreshes silently', async () => {
    const s = useSessionStore();
    await s.init();
    expect(s.phase).toBe('no-vault');

    await s.setup(PIN);
    expect(s.phase).toBe('signed-out');
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
    expect(s.hasCreds).toBe(true);

    // the browser leaves for Google and comes back: the app reloads, the vault is locked again
    await simulateGoogleRedirect();
    s.lock();
    await s.init();
    expect(s.phase).toBe('locked');
    await s.unlock(PIN);
    expect(s.phase).toBe('ready');
    expect(s.me).toEqual({ email: 'alice@gmail.com', name: 'Alice' });
    expect(tokenCalls[0]).toMatchObject({ grant_type: 'authorization_code', client_secret: 'GOCSPX-secret-value' });
    expect(sessionStorage.getItem('specact.oauth.result')).toBeNull();

    // the repo works with the token
    const { post } = await s.repo.createPost({ text: 'hello', files: [], audience: {} });
    expect(post.owner.email).toBe('alice@gmail.com');

    await s.lock();
    expect(s.phase).toBe('locked');
    expect(s.repo).toBeNull();
    await expect(vault.get('creds')).rejects.toMatchObject({ code: 'locked' });

    await s.unlock(PIN);
    expect(s.phase).toBe('ready');
    expect(tokenCalls.at(-1)).toMatchObject({ grant_type: 'refresh_token', refresh_token: 'refresh-1' });
    expect((await s.repo.loadIndex()).mine).toHaveLength(1); // cached index survived the lock
  });

  it('keeps the refresh token only in memory when "remember" is off', async () => {
    const s = useSessionStore();
    await s.setup(PIN);
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: false });
    await simulateGoogleRedirect();
    await s.unlock(PIN).catch(() => {});
    s.lock();
    await s.init();
    await s.unlock(PIN);
    expect(s.phase).toBe('signed-out'); // must sign in again
  });

  it('rejects a forged state (CSRF) and a missing refresh token', async () => {
    const s = useSessionStore();
    await s.setup(PIN);
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
    await simulateGoogleRedirect('good-code', true);
    s.lock();
    await s.init();
    await s.unlock(PIN);
    expect(s.phase).toBe('signed-out');
    expect(s.notice).toMatchObject({ kind: 'auth-error', detail: 'state-mismatch' });
    expect(tokenCalls).toHaveLength(0); // never even talked to Google with a forged state
  });

  it('a revoked refresh token sends the user back to sign-in without losing the keys', async () => {
    const s = useSessionStore();
    await s.setup(PIN);
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
    await simulateGoogleRedirect();
    s.lock();
    await s.init();
    await s.unlock(PIN);
    expect(s.phase).toBe('ready');
    await s.lock();

    refreshBehaviour = 'revoked';
    await s.unlock(PIN);
    expect(s.phase).toBe('signed-out');
    expect(s.notice.kind).toBe('expired');
    expect(s.hasCreds).toBe(true);
  });

  it('opens from cache when offline', async () => {
    const s = useSessionStore();
    await s.setup(PIN);
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
    await simulateGoogleRedirect();
    s.lock();
    await s.init();
    await s.unlock(PIN);
    await s.repo.createPost({ text: 'cached', files: [], audience: {} });
    await s.lock();

    refreshBehaviour = 'network';
    await s.unlock(PIN);
    expect(s.phase).toBe('ready');
    expect(s.offline).toBe(true);
    expect((await s.repo.loadIndex()).mine[0].text).toBe('cached');
  });

  it('signing out revokes access locally but keeps PIN and keys; reset wipes everything', async () => {
    const s = useSessionStore();
    await s.setup(PIN);
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
    await simulateGoogleRedirect();
    s.lock();
    await s.init();
    await s.unlock(PIN);
    await s.signOut();
    expect(s.phase).toBe('signed-out');
    expect(s.hasCreds).toBe(true);
    await s.resetDevice();
    expect(s.phase).toBe('no-vault');
    expect(await vault.exists()).toBe(false);
  });

  it('changing the client id forgets the old refresh token', async () => {
    const s = useSessionStore();
    await s.setup(PIN);
    await s.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
    await simulateGoogleRedirect();
    s.lock();
    await s.init();
    await s.unlock(PIN);
    await s.saveCreds({ clientId: 'other.apps.googleusercontent.com', clientSecret: 'GOCSPX-another-secret', keep: true });
    expect((await vault.get('creds')).refreshToken).toBeNull();
  });
});
