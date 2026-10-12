<script setup>
import { computed, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../components/ui/AppIcon.vue';
import AppLogo from '../components/ui/AppLogo.vue';
import LegalLinks from '../components/layout/LegalLinks.vue';
import { LANGS, config } from '../config';
import { usePrefsStore } from '../stores/prefs';

const props = defineProps({ page: { type: String, required: true } }); // about | terms | privacy
const { t, locale } = useI18n();
const prefs = usePrefsStore();

const loaders = import.meta.glob('../locales/pages/*.json');
const docs = ref({});
const native = computed(() => !!loaders[`../locales/pages/${locale.value}.json`]);
const doc = computed(() => (docs.value[native.value ? locale.value : 'en'] || {})[props.page]);
const meta = computed(() => docs.value[native.value ? locale.value : 'en'] || {});

watch([locale], async () => {
  for (const code of new Set(['en', locale.value])) {
    const load = loaders[`../locales/pages/${code}.json`];
    if (load && !docs.value[code]) docs.value = { ...docs.value, [code]: (await load()).default };
  }
}, { immediate: true });

const updated = computed(() => {
  try { return new Intl.DateTimeFormat(locale.value, { dateStyle: 'long' }).format(new Date(meta.value.updated)); } catch { return meta.value.updated || ''; }
});
const contact = config.legalContact;
</script>

<template>
  <div class="legal-page">
    <header class="legal-top">
      <RouterLink class="brand" to="/"><AppLogo :size="26" /><span>SPECACT</span></RouterLink>
      <span class="grow" />
      <label class="sr" for="legal-lang">{{ t('settings.language') }}</label>
      <select id="legal-lang" v-model="prefs.lang" class="select sm"><option v-for="[c, n] in LANGS" :key="c" :value="c">{{ n }}</option></select>
    </header>

    <main v-if="doc" class="legal-body">
      <RouterLink class="btn ghost back" to="/"><AppIcon name="back" :size="18" />{{ t('legal.back') }}</RouterLink>
      <h1 class="page-title">{{ doc.title }}</h1>
      <p class="lead">{{ doc.lead }}</p>
      <p class="hint meta">{{ t('legal.updated', { date: updated }) }}<template v-if="!native"> · {{ t('legal.fallback') }}</template></p>
      <section v-for="(s, i) in doc.sections" :key="i" class="legal-sec">
        <h2>{{ s.h }}</h2>
        <p v-for="(p, j) in s.body || []" :key="'p' + j">{{ p }}</p>
        <ul v-if="s.list"><li v-for="(li, j) in s.list" :key="j">{{ li }}</li></ul>
      </section>
      <p v-if="contact" class="hint">{{ t('legal.contact') }}: <a :href="'mailto:' + contact">{{ contact }}</a></p>
    </main>

    <footer class="legal-foot"><LegalLinks /></footer>
  </div>
</template>

<style scoped>
.legal-page { min-height: 100dvh; display: flex; flex-direction: column; }
.legal-top { display: flex; align-items: center; gap: 12px; padding: 16px clamp(16px, 4vw, 40px); }
.legal-top .brand { margin: 0; padding: 0; }
.legal-body { flex: 1; width: 100%; max-width: 720px; margin: 0 auto; padding: 8px 20px 48px; display: flex; flex-direction: column; gap: 14px; }
.lead { font-family: var(--read); font-size: 21px; line-height: 1.5; }
.meta { margin-top: -4px; }
.legal-sec { display: flex; flex-direction: column; gap: 10px; padding-top: 14px; border-top: 1px solid var(--line); }
.legal-sec h2 { font-size: 19px; font-weight: 650; }
.legal-sec p, .legal-sec li { font-size: 16px; line-height: 1.6; color: color-mix(in srgb, var(--text) 88%, var(--muted)); }
.legal-sec ul { margin: 0; padding-inline-start: 20px; display: flex; flex-direction: column; gap: 8px; }
.legal-body a { color: var(--accent); }
.legal-foot { padding: 20px; border-top: 1px solid var(--line); }
</style>
