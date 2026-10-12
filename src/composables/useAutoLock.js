import { onBeforeUnmount, onMounted, watch } from 'vue';
import { useSessionStore } from '../stores/session';
import { usePrefsStore } from '../stores/prefs';

/** Lock the vault after N idle minutes, or when the tab stayed hidden for that long. */
export function useAutoLock() {
  const session = useSessionStore();
  const prefs = usePrefsStore();
  let timer = null;
  let hiddenAt = 0;
  let last = Date.now();

  const limit = () => (session.mode === 'drive' && session.phase === 'ready' ? prefs.autoLock * 60_000 : 0);
  function arm() {
    clearTimeout(timer);
    const ms = limit();
    if (ms > 0) timer = setTimeout(() => session.lock(), ms);
  }
  function activity() { last = Date.now(); arm(); }
  function onVisibility() {
    if (document.hidden) { hiddenAt = Date.now(); return; }
    const ms = limit();
    if (ms > 0 && hiddenAt && Date.now() - hiddenAt >= ms) session.lock(); else activity();
    hiddenAt = 0;
  }
  const events = ['pointerdown', 'keydown', 'scroll', 'touchstart'];
  onMounted(() => {
    events.forEach((e) => window.addEventListener(e, activity, { passive: true }));
    document.addEventListener('visibilitychange', onVisibility);
    arm();
  });
  onBeforeUnmount(() => {
    events.forEach((e) => window.removeEventListener(e, activity));
    document.removeEventListener('visibilitychange', onVisibility);
    clearTimeout(timer);
  });
  watch(() => [prefs.autoLock, session.phase, session.mode], arm);
  void last;
}
