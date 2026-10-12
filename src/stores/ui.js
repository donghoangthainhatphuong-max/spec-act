import { defineStore } from 'pinia';
import { ref } from 'vue';

export const useUiStore = defineStore('ui', () => {
  const toasts = ref([]);
  const confirmState = ref(null);
  const viewer = ref(null); // { post, items, index }
  const search = ref('');
  const fresh = ref(null); // email just added to an audience (animates the orbit)
  let seq = 0;

  function toast(message, { kind = 'ok', ms = 2800 } = {}) {
    const id = ++seq;
    toasts.value = [...toasts.value.slice(-2), { id, message, kind }];
    setTimeout(() => { toasts.value = toasts.value.filter((x) => x.id !== id); }, ms);
  }

  /** Promise based confirm dialog. */
  function confirm({ text, yes, danger = true }) {
    return new Promise((resolve) => { confirmState.value = { text, yes, danger, resolve }; });
  }
  function answer(v) { confirmState.value?.resolve(v); confirmState.value = null; }

  function flash(email) { fresh.value = email; setTimeout(() => { if (fresh.value === email) fresh.value = null; }, 900); }

  function openViewer(items, index = 0) { viewer.value = { items, index }; }
  function closeViewer() { viewer.value = null; }

  return { toasts, toast, confirmState, confirm, answer, viewer, openViewer, closeViewer, search, fresh, flash };
});
