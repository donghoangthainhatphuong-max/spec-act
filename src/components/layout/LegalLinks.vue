<script setup>
import { useI18n } from '@/i18n';

defineProps({ inverse: { type: Boolean, default: false } });
const { t } = useI18n();
</script>

<template>
  <nav class="legal-links" :class="{ inverse }" :aria-label="t('legal.about')">
    <RouterLink :to="{ name: 'about' }">{{ t('legal.about') }}</RouterLink>
    <RouterLink :to="{ name: 'terms' }">{{ t('legal.terms') }}</RouterLink>
    <RouterLink :to="{ name: 'privacy' }">{{ t('legal.privacy') }}</RouterLink>
  </nav>
</template>

<style scoped>
.legal-links { display: flex; flex-wrap: wrap; gap: 6px 18px; justify-content: center; font-size: 13px; }
.legal-links a { color: var(--muted); text-decoration: underline; text-underline-offset: 3px; text-decoration-color: color-mix(in srgb, var(--muted) 40%, transparent); }
.legal-links a:hover { color: var(--text); }
</style>
