import { defineStore } from 'pinia';
import { ref, watch } from 'vue';
import { config } from '../config';
import { detectLanguage, setLocale } from '../i18n';

const KEY = 'specact.prefs';
const read = () => { try { return JSON.parse(localStorage.getItem(KEY) || '{}'); } catch { return {}; } };

/** Non-sensitive, per-device preferences (kept in localStorage). */
export const usePrefsStore = defineStore('prefs', () => {
  const saved = read();
  const lang = ref(detectLanguage());
  const theme = ref(['light', 'dark', 'system'].includes(saved.theme) ? saved.theme : config.defaultTheme);
  const autoLock = ref(Number.isFinite(saved.autoLock) ? saved.autoLock : config.autoLockMinutes);
  const notify = ref(typeof saved.notify === 'boolean' ? saved.notify : config.notifyEmail);

  const mq = typeof matchMedia === 'function' ? matchMedia('(prefers-color-scheme: dark)') : null;
  const systemDark = ref(!!mq?.matches);
  mq?.addEventListener?.('change', (e) => { systemDark.value = e.matches; });

  const resolvedTheme = () => (theme.value === 'system' ? (systemDark.value ? 'dark' : 'light') : theme.value);
  const applyTheme = () => {
    document.documentElement.dataset.theme = resolvedTheme();
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', resolvedTheme() === 'dark' ? '#0F1211' : '#F3F4F2');
  };

  watch([lang, theme, autoLock, notify], () => {
    try { localStorage.setItem(KEY, JSON.stringify({ lang: lang.value, theme: theme.value, autoLock: autoLock.value, notify: notify.value })); } catch { /* private mode */ }
  });
  watch([theme, systemDark], applyTheme);
  watch(lang, (l) => setLocale(l));

  async function init() {
    applyTheme();
    await setLocale(lang.value);
  }
  const toggleTheme = () => { theme.value = resolvedTheme() === 'dark' ? 'light' : 'dark'; };

  return { lang, theme, autoLock, notify, resolvedTheme, systemDark, init, toggleTheme };
});
