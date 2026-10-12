<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRouter } from 'vue-router';
import { useI18n } from '@/i18n';
import AppAvatar from '../components/ui/AppAvatar.vue';
import AppIcon from '../components/ui/AppIcon.vue';
import CredentialsForm from '../components/auth/CredentialsForm.vue';
import ChangePinDialog from '../components/auth/ChangePinDialog.vue';
import { usePrefsStore } from '../stores/prefs';
import { useSessionStore } from '../stores/session';
import { usePostsStore } from '../stores/posts';
import { useUiStore } from '../stores/ui';
import { LANGS, config } from '../config';
import { formatBytes } from '../i18n';

const { t } = useI18n();
const router = useRouter();
const prefs = usePrefsStore();
const session = useSessionStore();
const posts = usePostsStore();
const ui = useUiStore();

const quota = ref(null);
const editKeys = ref(false);
const pinOpen = ref(false);
const installEvent = ref(null);
const demo = computed(() => session.mode === 'demo');
const pct = computed(() => (quota.value?.limit ? Math.min(100, (quota.value.used / quota.value.limit) * 100) : 0));
const lockOptions = [0, 1, 5, 15, 30, 60];
const rootUrl = ref('');

function onInstall(e) { e.preventDefault(); installEvent.value = e; }
onMounted(async () => {
  window.addEventListener('beforeinstallprompt', onInstall);
  try { quota.value = await session.repo.quota(); } catch { quota.value = null; }
  try { const L = await session.repo.ensureLayout?.(); if (L?.rootId) rootUrl.value = `https://drive.google.com/drive/folders/${L.rootId}`; } catch { /* offline */ }
});
onBeforeUnmount(() => window.removeEventListener('beforeinstallprompt', onInstall));

async function install() {
  const ev = installEvent.value;
  if (!ev) return;
  ev.prompt();
  await ev.userChoice;
  installEvent.value = null;
}
async function signOut() {
  if (!(await ui.confirm({ text: t('settings.signOutConfirm'), yes: t('settings.signOut'), danger: false }))) return;
  await session.signOut();
  router.replace('/welcome');
}
async function saveKeys(c) {
  const before = session.credsPreview().clientId;
  await session.saveCreds(c);
  editKeys.value = false;
  if (before !== c.clientId) { ui.toast(t('toast.keysChangedSignIn')); await session.signOut(); router.replace('/welcome'); } else ui.toast(t('toast.saved'));
}
async function reset() {
  if (!(await ui.confirm({ text: t('settings.resetConfirm'), yes: t('settings.reset') }))) return;
  await session.resetDevice();
  router.replace('/welcome');
}
async function lockNow() { await session.lock(); router.replace('/welcome'); }
async function resync() { await posts.sync(); ui.toast(t('toast.synced')); }
</script>

<template>
  <h1 class="page-title">{{ t('settings.title') }}</h1>

  <section class="set"><h2>{{ t('settings.appearance') }}</h2>
    <div class="tiles" role="group" :aria-label="t('settings.appearance')">
      <button v-for="m in ['light', 'dark', 'system']" :key="m" class="tile" :aria-pressed="prefs.theme === m" @click="prefs.theme = m">
        <span class="mini" :class="'mini-' + m" aria-hidden="true"><i /><i /><i /></span><span>{{ t('settings.' + m) }}</span>
      </button>
    </div>
    <div class="set-row" style="border-top:1px solid var(--line)">
      <label for="lang"><b style="font-weight:600">{{ t('settings.language') }}</b></label>
      <select id="lang" v-model="prefs.lang" class="select"><option v-for="[c, n] in LANGS" :key="c" :value="c">{{ n }}</option></select>
    </div>
  </section>

  <section class="set"><h2>{{ t('settings.account') }}</h2>
    <div class="set-row"><div class="person" style="min-height:0"><AppAvatar :email="session.me.email" size="lg" /><div class="who"><b>{{ session.me.name }}</b><span>{{ session.me.email }}</span></div></div></div>
    <div v-if="quota" class="set-row storage">
      <b style="font-weight:600">{{ t('settings.storage') }}</b>
      <div class="bar"><span :style="{ width: Math.max(pct, 1.5) + '%' }" /></div>
      <span class="hint">{{ quota.limit ? t('settings.storageUsed', { used: formatBytes(quota.used), total: formatBytes(quota.limit) }) : t('settings.storageUsedOnly', { used: formatBytes(quota.used) }) }}</span>
    </div>
    <div v-if="rootUrl" class="set-row"><span>{{ t('settings.driveFolder') }}</span><a class="btn sm" :href="rootUrl" target="_blank" rel="noopener noreferrer"><AppIcon name="external" :size="16" />{{ t('settings.openDrive') }}</a></div>
    <div v-if="!demo" class="set-row"><span>{{ t('settings.resync') }}<small class="hint block">{{ t('settings.resyncHint') }}</small></span><button class="btn sm" :disabled="posts.syncing" @click="resync"><AppIcon name="refresh" :size="16" />{{ t('feed.refresh') }}</button></div>
    <div class="set-row"><button class="btn danger" @click="signOut"><AppIcon name="logout" :size="18" />{{ demo ? t('demo.exit') : t('settings.signOut') }}</button></div>
  </section>

  <section v-if="!demo" class="set"><h2>{{ t('settings.security') }}</h2>
    <div class="set-row"><span>{{ t('settings.autoLock') }}<small class="hint block">{{ t('settings.autoLockHint') }}</small></span>
      <select v-model.number="prefs.autoLock" class="select" :aria-label="t('settings.autoLock')"><option v-for="m in lockOptions" :key="m" :value="m">{{ m === 0 ? t('settings.never') : t('settings.minutes', { n: m }) }}</option></select>
    </div>
    <div class="set-row"><span>{{ t('settings.pin') }}<small class="hint block">{{ t('settings.pinHint', { n: config.pinLength }) }}</small></span><div class="btns"><button class="btn sm" @click="pinOpen = true"><AppIcon name="key" :size="16" />{{ t('settings.changePin') }}</button><button class="btn sm" @click="lockNow"><AppIcon name="lock" :size="16" />{{ t('settings.lockNow') }}</button></div></div>
    <div class="set-row"><span>{{ t('settings.keys') }}<small class="hint block">{{ t('settings.keysHint') }}</small></span><button class="btn sm" @click="editKeys = !editKeys">{{ editKeys ? t('compose.cancel') : t('settings.editKeys') }}</button></div>
    <div v-if="editKeys" class="set-row" style="display:block"><CredentialsForm :initial="session.credsPreview()" :submit-label="t('compose.save')" @submit="saveKeys" /></div>
    <div class="set-row"><span>{{ t('settings.notify') }}<small class="hint block">{{ t('settings.notifyHint') }}</small></span><button class="switch" role="switch" :aria-checked="prefs.notify" :aria-label="t('settings.notify')" @click="prefs.notify = !prefs.notify"><span /></button></div>
  </section>

  <section class="set"><h2>{{ t('settings.about') }}</h2>
    <div class="set-row about"><p>{{ t('about.notSocial') }}</p></div>
    <div class="set-row about"><p>{{ t('about.sovereignty') }}</p></div>
    <div v-if="installEvent" class="set-row"><span>{{ t('settings.install') }}</span><button class="btn sm primary" @click="install"><AppIcon name="download" :size="16" />{{ t('settings.installBtn') }}</button></div>
    <div class="set-row"><span class="hint">SPECACT · Secure Personal Ecosystem for Content, Access, and Control Trust</span></div>
  </section>

  <section v-if="!demo" class="set"><h2>{{ t('settings.danger') }}</h2>
    <div class="set-row"><span>{{ t('settings.resetHint') }}</span><button class="btn danger sm" @click="reset"><AppIcon name="trash" :size="16" />{{ t('settings.reset') }}</button></div>
  </section>

  <ChangePinDialog :open="pinOpen" @close="pinOpen = false" />
</template>

<style scoped>
.block { display: block; margin-top: 2px; }
.btns { display: flex; gap: 8px; flex-wrap: wrap; }
.about p { line-height: 1.55; color: var(--muted); font-family: var(--read); font-size: 17px; }
.set-row > span { flex: 1; min-width: 180px; }
.storage { flex-direction: column; align-items: stretch; }
</style>
