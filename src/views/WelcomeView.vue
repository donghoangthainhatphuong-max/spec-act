<script>
const intro = { played: false };
</script>

<script setup>
import { computed, onBeforeUnmount, ref, watch } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from '@/i18n';
import AppIcon from '../components/ui/AppIcon.vue';
import AppLogo from '../components/ui/AppLogo.vue';
import OrbitGraphic from '../components/ui/OrbitGraphic.vue';
import LegalLinks from '../components/layout/LegalLinks.vue';
import PinPad from '../components/auth/PinPad.vue';
import CredentialsForm from '../components/auth/CredentialsForm.vue';
import lanterns from '../assets/samples/lanterns.jpg?url';
import { useSessionStore } from '../stores/session';
import { usePrefsStore } from '../stores/prefs';
import { useUiStore } from '../stores/ui';
import { LANGS, config } from '../config';

const { t } = useI18n();
const router = useRouter();
const session = useSessionStore();
const prefs = usePrefsStore();
const ui = useUiStore();

const pad = ref(null);
const animate = !intro.played; // the orbit draws itself once per visit to the app
intro.played = true;
const step = ref('intro'); // first run: intro -> pin -> pin2 -> (creds)
const firstPin = ref('');
const error = ref('');
const busy = ref(false);
const editKeys = ref(false);
const until = ref(0);
const now = ref(Date.now());
let tick = null;

const stage = computed(() => {
  if (session.phase === 'no-vault') return step.value;
  if (session.phase === 'locked') return 'unlock';
  if (session.phase === 'signed-out') return session.hasCreds && !editKeys.value ? 'signin' : 'creds';
  return 'signin';
});
const wait = computed(() => Math.max(0, Math.ceil((until.value - now.value) / 1000)));
const dark = computed(() => prefs.resolvedTheme() === 'dark');

// quietly decorative: the people around a photo, as in the product itself
const sats = [
  { email: 'diepchi.photo@gmail.com', name: 'Diệp Chi', lit: true }, { email: 'quocbao.dev@gmail.com', name: 'Quốc Bảo' },
  { email: 'minhthu.tran@gmail.com', name: 'Minh Thư', lit: true }, { email: 'tuankiet.le@gmail.com', name: 'Tuấn Kiệt' },
  { email: 'khaihoan.ng@gmail.com', name: 'Khải Hoàn', lit: true }, { email: null },
];

watch(() => session.phase, (p) => {
  if (p === 'locked' || p === 'no-vault') { step.value = 'intro'; error.value = ''; }
}, { immediate: true });

const noticeText = computed(() => {
  const n = session.notice;
  if (!n) return '';
  if (n.kind === 'expired') return t('notice.expired');
  if (n.kind === 'storage-unavailable') return t('notice.storage');
  if (n.kind === 'offline-first') return t('notice.offlineFirst');
  const map = { denied: 'notice.denied', 'state-mismatch': 'notice.state', 'no-refresh-token': 'notice.noRefresh', 'scope-missing': 'notice.scope', 'invalid-client': 'notice.invalidClient', expired: 'notice.state' };
  return t(map[n.detail] || 'notice.generic', { detail: n.detail || '' });
});

/* ---- first run ---- */
async function onPinChoose(pin) {
  if (/^(\d)\1+$/.test(pin) || '0123456789'.includes(pin) || '9876543210'.includes(pin)) { error.value = t('pin.weak'); pad.value.reset({ shake: true }); return; }
  error.value = '';
  firstPin.value = pin;
  step.value = 'pin2';
  pad.value.reset();
}
async function onPinConfirm(pin) {
  if (pin !== firstPin.value) { error.value = t('pin.mismatch'); firstPin.value = ''; step.value = 'pin'; pad.value.reset({ shake: true }); return; }
  busy.value = true;
  try { await session.setup(pin); error.value = ''; } catch { error.value = t('error.generic'); pad.value.reset({ shake: true }); } finally { busy.value = false; }
}

/* ---- unlock ---- */
async function onUnlock(pin) {
  busy.value = true;
  error.value = '';
  try {
    await session.unlock(pin);
  } catch (e) {
    if (e.code === 'bad-pin') {
      error.value = t('pin.wrong', { n: e.remaining });
      if (e.retryInMs) startWait(e.retryInMs);
    } else if (e.code === 'throttled') {
      startWait(e.retryInMs);
      error.value = '';
    } else if (e.code === 'wiped') {
      error.value = '';
      ui.toast(t('pin.wiped'), { kind: 'error', ms: 6000 });
    } else {
      error.value = t('error.generic');
    }
    pad.value?.reset({ shake: true });
  } finally { busy.value = false; }
}
function startWait(ms) {
  until.value = Date.now() + ms;
  now.value = Date.now();
  clearInterval(tick);
  tick = setInterval(() => { now.value = Date.now(); if (now.value >= until.value) clearInterval(tick); }, 500);
}
onBeforeUnmount(() => clearInterval(tick));

/* ---- google ---- */
async function saveAndSignIn(c) {
  busy.value = true;
  try {
    await session.saveCreds(c);
    editKeys.value = false;
    await session.beginSignIn();
  } catch { ui.toast(t('error.generic'), { kind: 'error' }); busy.value = false; }
}
async function signIn() {
  busy.value = true;
  try { await session.beginSignIn(); } catch { ui.toast(t('error.generic'), { kind: 'error' }); busy.value = false; }
}
async function forgot() {
  if (!(await ui.confirm({ text: t('pin.forgotConfirm'), yes: t('settings.reset') }))) return;
  await session.resetDevice();
  step.value = 'intro';
}
async function demo() { await session.enterDemo(); router.replace('/'); }
</script>

<template>
  <div class="welcome" :class="{ compact: stage !== 'intro' && stage !== 'signin' }">
    <div class="art" :class="{ play: animate }" role="img" :aria-label="t('welcome.art')">
      <OrbitGraphic :center="{ src: lanterns }" :sats="sats" />
      <p class="quote">{{ t('welcome.quote') }}</p>
    </div>

    <div class="panel">
      <div class="tools">
        <label class="sr" for="lang-top">{{ t('settings.language') }}</label>
        <select id="lang-top" v-model="prefs.lang" class="select"><option v-for="[c, n] in LANGS" :key="c" :value="c">{{ n }}</option></select>
        <button class="icon-btn" :aria-label="t('theme.toggle')" :title="t('theme.toggle')" @click="prefs.toggleTheme()"><AppIcon :name="dark ? 'sun' : 'moon'" :size="20" /></button>
      </div>

      <div class="body">
        <div class="brand"><AppLogo :size="30" /><span>SPECACT</span></div>

        <p v-if="noticeText" class="notice" role="alert"><AppIcon name="alert" :size="18" />{{ noticeText }}</p>

        <!-- 1. first run -->
        <template v-if="stage === 'intro'">
          <h1>{{ t('welcome.title') }}</h1>
          <p class="sub">{{ t('welcome.sub') }}</p>
          <p class="mission"><AppIcon name="shield" :size="18" />{{ t('welcome.mission') }}</p>
          <button class="btn primary lg block g" @click="step = 'pin'"><svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z" opacity=".95" /><path d="M12 22c2.7 0 5-.9 6.6-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z" opacity=".8" /><path d="M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z" opacity=".65" /><path d="M12 6c1.5 0 2.8.5 3.8 1.5l2.9-2.9A10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.8 9.4 6 12 6z" opacity=".8" /></svg>{{ t('welcome.google') }}</button>
          <ul class="flow">
            <li><b>1</b>{{ t('welcome.flow1', { n: config.pinLength }) }}</li>
            <li><b>2</b>{{ t('welcome.flow2') }}</li>
            <li><b>3</b>{{ t('welcome.flow3') }}</li>
          </ul>
          <button v-if="config.enableDemo" class="btn ghost" @click="demo">{{ t('welcome.demo') }}</button>
        </template>

        <template v-else-if="stage === 'pin' || stage === 'pin2'">
          <PinPad ref="pad" :key="stage" :title="stage === 'pin' ? t('pin.create', { n: config.pinLength }) : t('pin.confirm')" :hint="stage === 'pin' ? t('pin.createHint') : ''" :error="error" :busy="busy" @complete="stage === 'pin' ? onPinChoose($event) : onPinConfirm($event)" />
          <button class="btn ghost sm" style="align-self:center" @click="step = 'intro'; error = ''"><AppIcon name="back" :size="16" />{{ t('post.back') }}</button>
        </template>

        <!-- 2. vault locked -->
        <template v-else-if="stage === 'unlock'">
          <PinPad ref="pad" :title="t('pin.unlock')" :hint="t('pin.unlockHint')" :error="wait ? t('pin.wait', { n: wait }) : error" :busy="busy" :disabled="wait > 0" @complete="onUnlock" />
          <button class="btn ghost sm" style="align-self:center" @click="forgot">{{ t('pin.forgot') }}</button>
        </template>

        <!-- 3. keys -->
        <template v-else-if="stage === 'creds'">
          <h1 class="h-sm">{{ t('creds.title') }}</h1>
          <CredentialsForm :initial="session.credsPreview()" :submit-label="t('creds.saveAndContinue')" :busy="busy" :show-cancel="session.hasCreds" @submit="saveAndSignIn" @cancel="editKeys = false" />
        </template>

        <!-- 4. sign in -->
        <template v-else>
          <h1>{{ t('welcome.title') }}</h1>
          <p class="sub">{{ t('welcome.sub') }}</p>
          <p class="mission"><AppIcon name="shield" :size="18" />{{ t('welcome.mission') }}</p>
          <button class="btn primary lg block g" :disabled="busy" @click="signIn"><svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M21.6 12.2c0-.7-.1-1.4-.2-2H12v3.8h5.4a4.6 4.6 0 0 1-2 3v2.5h3.2c1.9-1.7 3-4.3 3-7.3z" opacity=".95" /><path d="M12 22c2.7 0 5-.9 6.6-2.5l-3.2-2.5c-.9.6-2 1-3.4 1-2.6 0-4.8-1.8-5.6-4.1H3.1v2.6A10 10 0 0 0 12 22z" opacity=".8" /><path d="M6.4 13.9a6 6 0 0 1 0-3.8V7.5H3.1a10 10 0 0 0 0 9z" opacity=".65" /><path d="M12 6c1.5 0 2.8.5 3.8 1.5l2.9-2.9A10 10 0 0 0 3.1 7.5l3.3 2.6C7.2 7.8 9.4 6 12 6z" opacity=".8" /></svg>{{ t('welcome.google') }}</button>
          <details data-act="adv"><summary><AppIcon name="key" :size="16" />{{ t('welcome.advanced') }}</summary>
            <div class="adv"><p class="hint">{{ t('welcome.advancedHint') }}</p><button class="btn sm" @click="editKeys = true">{{ t('settings.editKeys') }}</button></div>
          </details>
          <button v-if="config.enableDemo" class="btn ghost" @click="demo">{{ t('welcome.demo') }}</button>
        </template>
      </div>

      <LegalLinks class="welcome-legal" />
      <ul class="trust"><li v-for="s in t('welcome.foot').split(/\s*·\s*/)" :key="s"><AppIcon name="check" :size="14" />{{ s }}</li></ul>
    </div>
  </div>
</template>

<style scoped>
.welcome { position: relative; }
.notice { display: flex; gap: 10px; align-items: flex-start; padding: 12px 14px; border-radius: 14px; background: color-mix(in srgb, var(--danger) 9%, var(--surface)); border: 1px solid color-mix(in srgb, var(--danger) 25%, var(--line)); font-size: 14px; line-height: 1.45; }
.notice svg { flex: none; color: var(--danger); margin-top: 1px; }
.flow { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 10px; font-size: 14.5px; color: var(--muted); }
.flow li { display: flex; gap: 12px; align-items: flex-start; line-height: 1.45; }
.flow b { flex: none; width: 24px; height: 24px; border-radius: 50%; background: var(--accent-soft); color: var(--accent); display: grid; place-items: center; font-size: 12.5px; font-weight: 700; }
.mission { display: flex; gap: 10px; align-items: flex-start; padding: 12px 14px; border-radius: 14px; background: var(--accent-soft); font-size: 14px; line-height: 1.5; }
.mission svg { flex: none; color: var(--accent); margin-top: 1px; }
.welcome-legal { margin-bottom: 10px; }
.h-sm { font-size: clamp(26px, 3.4vw, 34px); }
.btn:disabled { opacity: .6; }
</style>
