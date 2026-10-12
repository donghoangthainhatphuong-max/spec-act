/**
 * Google OAuth 2.0 "authorization code + PKCE" straight from the browser.
 * The user's own client id / secret are used; the only servers contacted are Google's.
 */
import { config, redirectUri } from '../config';
import { b64urlEncode, pkcePair, randomBytes } from './crypto';

const AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const REVOKE_URL = 'https://oauth2.googleapis.com/revoke';
const PENDING_KEY = 'specact.oauth.pending'; // PKCE verifier + state, lives only for the redirect round-trip
const RESULT_KEY = 'specact.oauth.result'; // code / error coming back from Google

export class AuthError extends Error {
  constructor(code, detail) { super(detail || code); this.name = 'AuthError'; this.code = code; }
}

const ss = () => { try { return globalThis.sessionStorage; } catch { return null; } };

/** Build the Google consent URL and remember what we need to finish the flow after the redirect. */
export async function buildSignInUrl({ clientId, loginHint }) {
  const { verifier, challenge } = await pkcePair();
  const state = b64urlEncode(randomBytes(24));
  const uri = redirectUri();
  ss()?.setItem(PENDING_KEY, JSON.stringify({ verifier, state, redirectUri: uri, at: Date.now() }));
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: uri,
    response_type: 'code',
    scope: config.oauthScopes.join(' '),
    code_challenge: challenge,
    code_challenge_method: 'S256',
    state,
    access_type: 'offline',
    include_granted_scopes: 'true',
    prompt: 'consent select_account',
  });
  if (loginHint) params.set('login_hint', loginHint);
  return `${AUTH_URL}?${params}`;
}

export async function startSignIn(creds) {
  location.assign(await buildSignInUrl(creds));
}

/**
 * Called once at boot, before the app mounts. If Google just sent the user back with ?code=…,
 * park the result in sessionStorage (the vault is still locked) and clean the address bar.
 */
export function captureRedirect() {
  const q = new URLSearchParams(location.search);
  if (!q.has('code') && !q.has('error')) return false;
  const result = { code: q.get('code'), error: q.get('error'), state: q.get('state'), at: Date.now() };
  ss()?.setItem(RESULT_KEY, JSON.stringify(result));
  history.replaceState(null, '', location.pathname + location.hash);
  return true;
}

export function hasPendingResult() {
  return !!ss()?.getItem(RESULT_KEY);
}

export function takePendingResult() {
  const store = ss();
  if (!store) return null;
  const raw = store.getItem(RESULT_KEY);
  store.removeItem(RESULT_KEY);
  const pendingRaw = store.getItem(PENDING_KEY);
  store.removeItem(PENDING_KEY);
  if (!raw) return null;
  const result = JSON.parse(raw);
  if (result.error) throw new AuthError(result.error === 'access_denied' ? 'denied' : 'oauth-error', result.error);
  const pending = pendingRaw ? JSON.parse(pendingRaw) : null;
  if (!pending || pending.state !== result.state) throw new AuthError('state-mismatch');
  if (Date.now() - pending.at > 15 * 60_000) throw new AuthError('expired');
  return { code: result.code, verifier: pending.verifier, redirectUri: pending.redirectUri };
}

async function tokenRequest(body) {
  let res;
  try {
    res = await fetch(TOKEN_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(body),
    });
  } catch {
    throw new AuthError('network');
  }
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const code = json.error === 'invalid_grant' ? 'invalid-grant' : json.error === 'invalid_client' ? 'invalid-client' : 'token-error';
    throw new AuthError(code, json.error_description || json.error);
  }
  return {
    accessToken: json.access_token,
    refreshToken: json.refresh_token || null,
    expiresAt: Date.now() + (json.expires_in || 3600) * 1000,
    scope: json.scope || '',
  };
}

export function exchangeCode({ clientId, clientSecret, code, verifier, redirectUri: uri }) {
  return tokenRequest({
    grant_type: 'authorization_code',
    client_id: clientId,
    ...(clientSecret ? { client_secret: clientSecret } : {}),
    code,
    code_verifier: verifier,
    redirect_uri: uri,
  });
}

export function refreshAccessToken({ clientId, clientSecret, refreshToken }) {
  return tokenRequest({
    grant_type: 'refresh_token',
    client_id: clientId,
    ...(clientSecret ? { client_secret: clientSecret } : {}),
    refresh_token: refreshToken,
  });
}

export async function revokeToken(token) {
  try { await fetch(REVOKE_URL, { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ token }) }); } catch { /* best effort */ }
}

export const looksLikeClientId = (s) => /^[\w.-]+\.apps\.googleusercontent\.com$/i.test((s || '').trim());
