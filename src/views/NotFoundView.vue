<script setup>
import { useI18n } from '@/i18n';
const { t } = useI18n();
</script>

<template>
  <div class="empty">
    <p>{{ t('notfound.text') }}</p>
    <RouterLink class="btn primary" to="/">{{ t('nav.home') }}</RouterLink>
  </div>
</template>
