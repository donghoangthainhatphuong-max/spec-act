import { defineStore } from 'pinia';
import { markRaw, ref, shallowRef } from 'vue';
import { vault, VaultError } from '../services/secureStore';
import { DriveClient } from '../services/drive';
import { DriveRepo } from '../services/repo';
import { AuthError, exchangeCode, hasPendingResult, refreshAccessToken, revokeToken, startSignIn, takePendingResult } from '../services/googleAuth';
import { emit } from '../services/events';
import { normEmail, prettyName } from '../services/mentions';

/**
 * phase: booting -> no-vault | locked -> signed-out -> ready
 *   no-vault   first run, nothing stored on this device yet
 *   locked     a vault exists; waiting for the PIN
 *   signed-out vault open, but no valid Google session (needs "Continue with Google")
 *   ready      repo available
 */
export const useSessionStore = defineStore('session', () => {
  const phase = ref('booting');
  const mode = ref('drive'); // 'drive' | 'demo'
  const me = ref(null);
  const repo = shallowRef(null);
  const hasCreds = ref(false);
  const keepSignedIn = ref(true);
  const offline = ref(false);
  const notice = ref(null); // { kind, detail }
  const busy = ref(false);

  let secrets = null; // { clientId, clientSecret, refreshToken, keep }
  let token = { value: null, expiresAt: 0 };
  let refreshing = null;
  let readyResolve;
  const ready = new Promise((r) => { readyResolve = r; });

  async function init() {
    try {
      const st = await vault.status();
      phase.value = st.exists ? 'locked' : 'no-vault';
    } catch {
      phase.value = 'no-vault';
      notice.value = { kind: 'storage-unavailable' };
    }
    readyResolve();
  }

  /* ---------- vault ---------- */
  async function setup(pin) {
    await vault.create(pin);
    secrets = { clientId: '', clientSecret: '', refreshToken: null, keep: true };
    keepSignedIn.value = true;
    hasCreds.value = false;
    phase.value = 'signed-out';
  }

  async function unlock(pin) {
    try {
      await vault.unlock(pin); // throws VaultError(bad-pin | throttled | wiped)
    } catch (e) {
      if (e instanceof VaultError && e.code === 'wiped') phase.value = 'no-vault';
      throw e;
    }
    secrets = (await vault.get('creds')) || { clientId: '', clientSecret: '', refreshToken: null, keep: true };
    hasCreds.value = !!secrets.clientId;
    keepSignedIn.value = secrets.keep !== false;
    notice.value = null;
    if (hasPendingResult()) {
      try { await finishOAuth(); } catch (e) { notice.value = { kind: 'auth-error', detail: e.code || e.message }; }
    }
    await resume();
  }

  async function saveCreds({ clientId, clientSecret, keep }) {
    secrets = { ...secrets, clientId: clientId.trim(), clientSecret: clientSecret.trim(), keep: keep !== false };
    if (clientId.trim() !== (await vault.get('creds'))?.clientId) secrets.refreshToken = null;
    keepSignedIn.value = secrets.keep;
    hasCreds.value = !!secrets.clientId;
    await vault.set('creds', secrets);
  }

  function credsPreview() {
    return { clientId: secrets?.clientId || '', clientSecret: secrets?.clientSecret || '', keep: secrets?.keep !== false };
  }

  async function verifyPin(pin) {
    try { await vault.verify(pin); } catch (e) {
      if (e instanceof VaultError && e.code === 'wiped') await resetDevice();
      throw e;
    }
  }

  async function changePin(oldPin, newPin) {
    await vault.changePin(oldPin, newPin);
  }

  /* ---------- Google session ---------- */
  async function finishOAuth() {
    const pend = takePendingResult();
    if (!pend) return;
    const tok = await exchangeCode({ clientId: secrets.clientId, clientSecret: secrets.clientSecret, ...pend });
    if (!tok.refreshToken) throw new AuthError('no-refresh-token');
    if (tok.scope && !/googleapis\.com\/auth\/drive(\s|$)/.test(tok.scope)) throw new AuthError('scope-missing');
    token = { value: tok.accessToken, expiresAt: tok.expiresAt };
    secrets.refreshToken = tok.refreshToken;
    if (secrets.keep !== false) await vault.set('creds', secrets);
  }

  function refreshAccess() {
    if (!refreshing) {
      refreshing = refreshAccessToken({ clientId: secrets.clientId, clientSecret: secrets.clientSecret, refreshToken: secrets.refreshToken })
        .then((t) => { token = { value: t.accessToken, expiresAt: t.expiresAt }; return t.accessToken; })
        .catch(async (e) => {
          if (e.code === 'invalid-grant' || e.code === 'invalid-client') await expireSession(e.code);
          throw e;
        })
        .finally(() => { refreshing = null; });
    }
    return refreshing;
  }

  async function getToken() {
    if (token.value && token.expiresAt - Date.now() > 60_000) return token.value;
    if (!secrets?.refreshToken) throw new AuthError('signed-out');
    return refreshAccess();
  }

  async function expireSession(code) {
    token = { value: null, expiresAt: 0 };
    notice.value = { kind: 'expired', detail: code };
    teardownRepo();
    phase.value = 'signed-out';
    if (secrets) { secrets.refreshToken = null; try { await vault.set('creds', secrets); } catch { /* locked */ } }
  }

  async function resume() {
    if (!secrets?.refreshToken && !token.value) { phase.value = 'signed-out'; return; }
    try {
      if (!token.value || token.expiresAt - Date.now() < 60_000) await refreshAccess();
      offline.value = false;
    } catch (e) {
      if (e.code === 'invalid-grant' || e.code === 'invalid-client') return;
      if (e.code !== 'network') { notice.value = { kind: 'auth-error', detail: e.code }; phase.value = 'signed-out'; return; }
      offline.value = true; // keep going with cached data
    }
    await startRepo();
  }

  async function startRepo() {
    const drive = new DriveClient({ getToken, onUnauthorized: () => { token = { value: null, expiresAt: 0 }; return refreshAccess(); } });
    let profile = await vault.get('profile');
    if (!offline.value) {
      try {
        const about = await drive.about();
        profile = { email: normEmail(about.user.emailAddress), name: about.user.displayName || prettyName(about.user.emailAddress) };
        await vault.set('profile', profile);
      } catch (e) {
        if (!profile) { notice.value = { kind: 'auth-error', detail: e.reason || e.message }; phase.value = 'signed-out'; return; }
        offline.value = true;
      }
    }
    if (!profile) { notice.value = { kind: 'offline-first' }; phase.value = 'signed-out'; return; }
    me.value = profile;
    mode.value = 'drive';
    const r = markRaw(new DriveRepo({ drive, me: profile, vault }));
    await r.restoreKeys();
    repo.value = r;
    phase.value = 'ready';
  }

  async function beginSignIn() {
    if (!secrets?.clientId) throw new AuthError('no-creds');
    busy.value = true;
    try { await startSignIn({ clientId: secrets.clientId, loginHint: me.value?.email }); } finally { busy.value = false; }
  }

  /* ---------- leaving ---------- */
  function teardownRepo() {
    repo.value?.dispose?.();
    repo.value = null;
    emit('session-end');
  }

  async function lock() {
    if (mode.value === 'demo') return;
    try { await repo.value?.flush?.(); } catch { /* offline */ }
    teardownRepo();
    vault.lock();
    secrets = null;
    token = { value: null, expiresAt: 0 };
    me.value = null;
    hasCreds.value = false;
    phase.value = 'locked';
  }

  async function signOut() {
    if (mode.value === 'demo') { await leaveDemo(); return; }
    try { await repo.value?.flush?.(); } catch { /* ignore */ }
    if (secrets?.refreshToken) await revokeToken(secrets.refreshToken);
    teardownRepo();
    if (secrets) { secrets.refreshToken = null; await vault.set('creds', secrets); }
    await vault.remove('profile').catch(() => {});
    token = { value: null, expiresAt: 0 };
    me.value = null;
    phase.value = 'signed-out';
  }

  async function resetDevice() {
    teardownRepo();
    await vault.wipe();
    secrets = null;
    token = { value: null, expiresAt: 0 };
    me.value = null;
    hasCreds.value = false;
    mode.value = 'drive';
    notice.value = null;
    phase.value = 'no-vault';
  }

  /* ---------- demo ---------- */
  async function enterDemo() {
    const { DemoRepo, DEMO_ME } = await import('../services/demoRepo');
    mode.value = 'demo';
    me.value = DEMO_ME;
    repo.value = markRaw(new DemoRepo());
    phase.value = 'ready';
  }
  async function leaveDemo() {
    teardownRepo();
    mode.value = 'drive';
    me.value = null;
    const st = await vault.status().catch(() => ({ exists: false }));
    phase.value = st.exists ? 'locked' : 'no-vault';
  }

  return {
    phase, mode, me, repo, hasCreds, keepSignedIn, offline, notice, busy, ready,
    init, setup, unlock, saveCreds, credsPreview, verifyPin, changePin, beginSignIn, lock, signOut, resetDevice, enterDemo, leaveDemo,
  };
});

export { VaultError };
