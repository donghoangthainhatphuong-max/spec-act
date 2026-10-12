import { createApp } from 'vue';
import { createPinia } from 'pinia';
import { registerSW } from 'virtual:pwa-register';
import App from './App.vue';
import { router } from './router';
import { usePrefsStore } from './stores/prefs';
import { useSessionStore } from './stores/session';
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
await useSessionStore().init();
app.mount('#app');

// The service worker only makes the app installable/offline-capable; the app works without it.
registerSW({ immediate: true, onRegisterError: () => {} });
