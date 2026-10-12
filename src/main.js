import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { registerSW } from 'virtual:pwa-register';
import App from './App.vue';
import { router } from './router';
import { usePrefsStore } from './stores/prefs';
import { useSessionStore } from './stores/session';
import { useUiStore } from './stores/ui';
import { t } from './i18n';
import { captureRedirect } from './services/googleAuth';

import './assets/fonts.css';
import './styles/base.css';
import './styles/shell.css';
import './styles/feed.css';
import './styles/compose.css';
import './styles/pages.css';
import './styles/welcome.css';
import './styles/overlays.css';
import './styles/extra.css';

// Google may have just sent the user back with ?code=… — park it until the vault is unlocked.
captureRedirect();

const app = createApp(App);
const pinia = createPinia();
app.use(pinia).use(router);

await usePrefsStore().init();

if (!window.isSecureContext || !globalThis.crypto?.subtle || !globalThis.indexedDB) {
  // WebCrypto only exists on https:// and http://localhost — without it nothing can be encrypted, so stop early and say why.
  const box = document.getElementById('app');
  box.innerHTML = '<main class="insecure" role="alert"><h1></h1><p></p></main>';
  box.querySelector('h1').textContent = 'SPECACT';
  box.querySelector('p').textContent = t('error.insecure');
} else {
  await useSessionStore().init();
  app.mount('#app');
}

// The service worker only makes the app installable/offline-capable; the app works without it.
// A new version is announced, never forced: the user may have a draft open or the vault unlocked.
const ui = useUiStore();
const updateSW = registerSW({ immediate: true, onNeedRefresh: () => { ui.updateReady = true; }, onRegisterError: () => {} });
ui.setUpdater(() => updateSW(true));
