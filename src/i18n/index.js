import { ref, shallowRef } from 'vue';
import en from '../locales/en.json';
import { LANGS, config } from '../config';

/**
 * A deliberately tiny i18n layer: flat `key -> string` JSON per language, `{name}` placeholders,
 * English as the fallback. (No message-format syntax, so translators can use any character.)
 */
const loaders = import.meta.glob('../locales/*.json');
const RTL = new Set(['ar', 'he', 'fa', 'ur']);

export const locale = ref('en');
const catalogs = shallowRef({ en });

export function t(key, params) {
  const loc = locale.value; // read inside the call so templates re-render when the language changes
  let s = catalogs.value[loc]?.[key] ?? en[key] ?? key;
  if (params) s = s.replace(/\{(\w+)\}/g, (m, k) => (params[k] != null ? String(params[k]) : m));
  return s;
}

/** English text regardless of the selected language (pages that only exist in English must not mix two languages). */
export function tEnglish(key, params) {
  let s = en[key] ?? key;
  if (params) s = s.replace(/\{(\w+)\}/g, (m, k) => (params[k] != null ? String(params[k]) : m));
  return s;
}

/** Same shape components expect from a composable. */
export function useI18n() { return { t, locale }; }
export const currentLocale = () => locale.value;

export function detectLanguage() {
  try {
    const saved = JSON.parse(localStorage.getItem('specact.prefs') || '{}').lang;
    if (saved && LANGS.some(([c]) => c === saved)) return saved;
  } catch { /* ignore */ }
  if (!config.detectLang) return config.defaultLang;
  const nav = (navigator.languages || [navigator.language || '']).map((l) => l.slice(0, 2).toLowerCase());
  const hit = nav.find((l) => LANGS.some(([c]) => c === l));
  return hit || config.defaultLang;
}

export async function setLocale(code) {
  if (!LANGS.some(([c]) => c === code)) code = config.defaultLang;
  if (!catalogs.value[code]) {
    const load = loaders[`../locales/${code}.json`];
    if (load) catalogs.value = { ...catalogs.value, [code]: (await load()).default };
  }
  locale.value = code;
  document.documentElement.lang = code;
  document.documentElement.dir = RTL.has(code) ? 'rtl' : 'ltr';
  return code;
}

/* ---------- locale-aware formatting ---------- */
export function ago(ts) {
  const loc = currentLocale();
  const d = (ts - Date.now()) / 1000;
  const a = Math.abs(d);
  const rtf = new Intl.RelativeTimeFormat(loc, { numeric: 'auto', style: 'short' });
  if (a < 60) return rtf.format(0, 'second');
  if (a < 3600) return rtf.format(Math.round(d / 60), 'minute');
  if (a < 86400) return rtf.format(Math.round(d / 3600), 'hour');
  if (a < 86400 * 30) return rtf.format(Math.round(d / 86400), 'day');
  return new Intl.DateTimeFormat(loc, { day: 'numeric', month: 'short', year: new Date(ts).getFullYear() === new Date().getFullYear() ? undefined : 'numeric' }).format(ts);
}

export function listOf(names) {
  try { return new Intl.ListFormat(currentLocale(), { style: 'long', type: 'conjunction' }).format(names); } catch { return names.join(', '); }
}

export function formatBytes(n) {
  if (n == null) return '';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  let i = 0;
  let v = n;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return `${new Intl.NumberFormat(currentLocale(), { maximumFractionDigits: v >= 10 || i === 0 ? 0 : 1 }).format(v)} ${units[i]}`;
}
