/**
 * Central configuration.
 * Precedence: runtime `window.__SPECACT_ENV__` (docker) > build-time `import.meta.env` > defaults.
 */
const runtime = (typeof globalThis !== 'undefined' && globalThis.__SPECACT_ENV__) || {};
const built = import.meta.env || {};

const raw = (key) => {
  const v = runtime[key] !== undefined && runtime[key] !== '' ? runtime[key] : built[key];
  return v === undefined || v === '' ? undefined : v;
};
const str = (key, def) => { const v = raw(key); return v === undefined ? def : String(v); };
const int = (key, def, min = -Infinity, max = Infinity) => {
  const n = parseInt(raw(key), 10);
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : def;
};
const num = (key, def, min = -Infinity, max = Infinity) => {
  const n = parseFloat(raw(key));
  return Number.isFinite(n) ? Math.min(max, Math.max(min, n)) : def;
};
const bool = (key, def) => {
  const v = raw(key);
  if (v === undefined) return def;
  return ['1', 'true', 'yes', 'on'].includes(String(v).toLowerCase());
};

export const LANGS = [
  ['vi', 'Tiếng Việt'], ['en', 'English'], ['zh', '中文'], ['ja', '日本語'], ['ko', '한국어'], ['ru', 'Русский'], ['fr', 'Français'],
  ['de', 'Deutsch'], ['es', 'Español'], ['th', 'ไทย'], ['id', 'Bahasa Indonesia'], ['hi', 'हिन्दी'], ['ar', 'العربية'], ['tr', 'Türkçe'],
];

const defaultLang = str('VITE_DEFAULT_LANG', 'vi');
const defaultTheme = str('VITE_DEFAULT_THEME', 'system');

export const config = Object.freeze({
  appName: str('VITE_APP_NAME', 'SPECACT'),
  basePath: str('BASE_URL', '/'),
  defaultLang: LANGS.some(([c]) => c === defaultLang) ? defaultLang : 'vi',
  defaultTheme: ['system', 'light', 'dark'].includes(defaultTheme) ? defaultTheme : 'system',
  enableDemo: bool('VITE_ENABLE_DEMO', true),

  rootFolder: str('VITE_DRIVE_ROOT_FOLDER', 'SPECACT'),
  postsFolder: str('VITE_DRIVE_POSTS_FOLDER', 'posts'),
  oauthScopes: str('VITE_OAUTH_SCOPES', 'https://www.googleapis.com/auth/drive').split(/[\s,]+/).filter(Boolean),
  oauthRedirectUri: str('VITE_OAUTH_REDIRECT_URI', ''),
  deleteMode: str('VITE_DELETE_MODE', 'trash') === 'permanent' ? 'permanent' : 'trash',
  notifyEmail: bool('VITE_NOTIFY_EMAIL', false),
  syncIntervalSeconds: int('VITE_SYNC_INTERVAL_SECONDS', 180, 0),

  pinLength: int('VITE_PIN_LENGTH', 6, 4, 12),
  pbkdf2Iterations: int('VITE_PBKDF2_ITERATIONS', 600000, 1000),
  pinMaxAttempts: int('VITE_PIN_MAX_ATTEMPTS', 10, 3),
  autoLockMinutes: int('VITE_AUTO_LOCK_MINUTES', 5, 0),
  postKdfIterations: int('VITE_POST_KDF_ITERATIONS', 310000, 1000),

  maxImagesPerPost: int('VITE_MAX_IMAGES_PER_POST', 10, 1, 50),
  maxImageMb: num('VITE_MAX_IMAGE_MB', 25, 1),
  imageMaxDimension: int('VITE_IMAGE_MAX_DIMENSION', 2048, 320),
  imageQuality: num('VITE_IMAGE_QUALITY', 0.86, 0.3, 1),
  thumbDimension: int('VITE_THUMB_DIMENSION', 480, 96),
});

/** Where Google sends the user back. Must be registered as an authorized redirect URI. */
export function redirectUri() {
  if (config.oauthRedirectUri) return config.oauthRedirectUri;
  return `${location.origin}${config.basePath}`;
}
