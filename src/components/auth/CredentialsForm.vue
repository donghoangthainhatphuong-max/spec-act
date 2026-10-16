<script setup>
import { computed, ref } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import { redirectUri } from '../../config';
import { looksLikeClientId } from '../../services/googleAuth';
import { copyText } from '../../composables/share';
import { usePrefsStore } from '../../stores/prefs';
import { useUiStore } from '../../stores/ui';

const props = defineProps({
  initial: { type: Object, default: () => ({ clientId: '', clientSecret: '', keep: true }) },
  submitLabel: { type: String, default: '' },
  busy: { type: Boolean, default: false },
  showCancel: { type: Boolean, default: false },
});
const emit = defineEmits(['submit', 'cancel']);
const { t } = useI18n();
const ui = useUiStore();
const prefs = usePrefsStore();

// first time here: accepting the Terms of Use and Privacy Policy is part of this page (no separate screen)
const needConsent = computed(() => !prefs.consentOk);
const agreed = ref(false);
const parts = computed(() => t('consent.check').split(/(\{terms\}|\{privacy\})/).map((x) => (x === '{terms}' ? { link: 'terms', text: t('consent.termsLink') } : x === '{privacy}' ? { link: 'privacy', text: t('consent.privacyLink') } : { text: x })));

const clientId = ref(props.initial.clientId);
const clientSecret = ref(props.initial.clientSecret);
const keep = ref(props.initial.keep !== false);
const reveal = ref(false);
const touched = ref(false);

const uri = redirectUri();
const origin = location.origin;
const idOk = computed(() => looksLikeClientId(clientId.value));
const valid = computed(() => idOk.value && clientSecret.value.trim().length >= 8 && (!needConsent.value || agreed.value));

function submit() {
  touched.value = true;
  if (!valid.value) return;
  if (needConsent.value) prefs.acceptTerms();
  emit('submit', { clientId: clientId.value.trim(), clientSecret: clientSecret.value.trim(), keep: keep.value });
}
async function copy(text) { ui.toast((await copyText(text)) ? t('toast.copied') : t('error.generic')); }
</script>

<template>
  <form class="creds" novalidate @submit.prevent="submit">
    <p class="hint">{{ t('creds.hint') }}</p>

    <details class="guide">
      <summary><AppIcon name="info" :size="16" />{{ t('creds.howTo') }}</summary>
      <ol>
        <li>{{ t('creds.step1') }} <a href="https://console.cloud.google.com/projectcreate" target="_blank" rel="noopener noreferrer">console.cloud.google.com</a></li>
        <li>{{ t('creds.step2') }} <a href="https://console.cloud.google.com/apis/library/drive.googleapis.com" target="_blank" rel="noopener noreferrer">Google Drive API</a></li>
        <li>{{ t('creds.step3') }}</li>
        <li>{{ t('creds.step4') }}</li>
        <li>{{ t('creds.step5') }}</li>
      </ol>
    </details>

    <div class="field">
      <label for="cid">{{ t('welcome.clientId') }}</label>
      <input id="cid" v-model="clientId" class="input" placeholder="123456789-abc….apps.googleusercontent.com" autocomplete="off" autocapitalize="off" spellcheck="false" :aria-invalid="touched && !idOk" />
      <p v-if="touched && !idOk" class="err" role="alert">{{ t('creds.badId') }}</p>
    </div>
    <div class="field">
      <label for="csec">{{ t('welcome.secret') }}</label>
      <div class="pwrow">
        <input id="csec" v-model="clientSecret" class="input" :type="reveal ? 'text' : 'password'" placeholder="GOCSPX-…" autocomplete="off" autocapitalize="off" spellcheck="false" :aria-invalid="touched && clientSecret.trim().length < 8" />
        <button type="button" class="icon-btn" :aria-label="t('compose.showPassword')" :aria-pressed="reveal" @click="reveal = !reveal"><AppIcon name="eye" :size="20" /></button>
      </div>
      <p v-if="touched && clientSecret.trim().length < 8" class="err" role="alert">{{ t('creds.badSecret') }}</p>
    </div>

    <div class="uri">
      <span class="hint">{{ t('creds.redirect') }}</span>
      <div class="copyrow"><code>{{ uri }}</code><button type="button" class="icon-btn" :aria-label="t('creds.copy')" @click="copy(uri)"><AppIcon name="copy" :size="18" /></button></div>
      <span class="hint">{{ t('creds.origin') }}</span>
      <div class="copyrow"><code>{{ origin }}</code><button type="button" class="icon-btn" :aria-label="t('creds.copy')" @click="copy(origin)"><AppIcon name="copy" :size="18" /></button></div>
    </div>

    <div class="row-between">
      <span style="font-size:14px">{{ t('welcome.remember') }}</span>
      <button type="button" class="switch" role="switch" :aria-checked="keep" :aria-label="t('welcome.remember')" @click="keep = !keep"><span /></button>
    </div>
    <p class="hint"><AppIcon name="shield" :size="14" style="vertical-align:-2px" /> {{ t('creds.local') }}</p>

    <label v-if="needConsent" class="consent-check">
      <input v-model="agreed" type="checkbox" />
      <span><template v-for="(p, i) in parts" :key="i"><RouterLink v-if="p.link" :to="{ name: p.link }" target="_blank">{{ p.text }}</RouterLink><template v-else>{{ p.text }}</template></template></span>
    </label>

    <div class="actions-row">
      <button v-if="showCancel" type="button" class="btn" @click="emit('cancel')">{{ t('compose.cancel') }}</button>
      <button class="btn primary lg block" :disabled="busy || (needConsent && !agreed)">{{ submitLabel || t('creds.save') }}</button>
    </div>
  </form>
</template>

<style scoped>
.creds { display: flex; flex-direction: column; gap: 14px; }
.guide { border: 1px solid var(--line); border-radius: 14px; padding: 4px 14px; background: var(--sunken); }
.guide summary { cursor: pointer; padding: 10px 0; font-size: 14px; font-weight: 550; display: flex; gap: 8px; align-items: center; list-style: none; }
.guide summary::-webkit-details-marker { display: none; }
.guide ol { margin: 0 0 12px; padding-inline-start: 20px; display: flex; flex-direction: column; gap: 8px; font-size: 13.5px; line-height: 1.45; color: var(--muted); }
.guide a { color: var(--accent); text-decoration: underline; text-underline-offset: 2px; }
.err { color: var(--danger); font-size: 13px; }
.pwrow { display: flex; gap: 6px; align-items: center; }
.uri { display: flex; flex-direction: column; gap: 6px; }
.copyrow { display: flex; align-items: center; gap: 6px; background: var(--sunken); border-radius: 12px; padding: 4px 4px 4px 12px; }
.copyrow code { flex: 1; min-width: 0; font-size: 13px; overflow-wrap: anywhere; user-select: all; }
.actions-row { display: flex; gap: 8px; }
.btn:disabled { opacity: .6; }
</style>
