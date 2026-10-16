<script setup>
import { computed, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from '@/i18n';
import AppIcon from '../components/ui/AppIcon.vue';
import AppLogo from '../components/ui/AppLogo.vue';
import BrandName from '../components/ui/BrandName.vue';
import { LANGS, TERMS_VERSION } from '../config';
import { usePrefsStore } from '../stores/prefs';

/** Shown before anything else until the current Terms of Use and Privacy Policy are accepted. */
const { t, locale } = useI18n();
const prefs = usePrefsStore();
const route = useRoute();
const router = useRouter();
const agreed = ref(false);

// "I have read and agree to the {terms} and the {privacy}." with the two names turned into links
const parts = computed(() => t('consent.check').split(/(\{terms\}|\{privacy\})/).map((s) => (s === '{terms}' ? { link: 'terms', text: t('consent.termsLink') } : s === '{privacy}' ? { link: 'privacy', text: t('consent.privacyLink') } : { text: s })));
const version = computed(() => { try { return new Intl.DateTimeFormat(locale.value, { dateStyle: 'long' }).format(new Date(TERMS_VERSION)); } catch { return TERMS_VERSION; } });

function accept() {
  if (!agreed.value) return;
  prefs.acceptTerms();
  const next = typeof route.query.next === 'string' && route.query.next.startsWith('/') ? route.query.next : '/';
  router.replace(next);
}
</script>

<template>
  <div class="consent-page">
    <div class="consent-card">
      <div class="consent-top">
        <span class="brand"><AppLogo :size="28" /><BrandName /></span>
        <span class="grow" />
        <label class="sr" for="consent-lang">{{ t('settings.language') }}</label>
        <select id="consent-lang" v-model="prefs.lang" class="select sm"><option v-for="[c, n] in LANGS" :key="c" :value="c">{{ n }}</option></select>
      </div>
      <h1 class="page-title">{{ t('consent.title') }}</h1>
      <p class="lead">{{ t('consent.lead') }}</p>
      <ul class="consent-points">
        <li v-for="k in ['k1', 'k2', 'k3', 'k4']" :key="k"><AppIcon name="shield" :size="18" /><span>{{ t('consent.' + k) }}</span></li>
      </ul>
      <label class="consent-check">
        <input v-model="agreed" type="checkbox" />
        <span><template v-for="(p, i) in parts" :key="i"><RouterLink v-if="p.link" :to="{ name: p.link }" target="_blank">{{ p.text }}</RouterLink><template v-else>{{ p.text }}</template></template></span>
      </label>
      <button class="btn primary lg block" :disabled="!agreed" @click="accept">{{ t('consent.accept') }}</button>
      <p class="hint meta">{{ t('consent.version', { date: version }) }}</p>
    </div>
  </div>
</template>
