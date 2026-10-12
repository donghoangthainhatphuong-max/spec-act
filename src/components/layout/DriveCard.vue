<script setup>
import { computed, onMounted, ref } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import { useSessionStore } from '../../stores/session';
import { formatBytes } from '../../i18n';

const { t } = useI18n();
const session = useSessionStore();
const quota = ref(null);
onMounted(async () => { try { quota.value = await session.repo?.quota(); } catch { quota.value = null; } });
const pct = computed(() => (quota.value?.limit ? Math.min(100, (quota.value.used / quota.value.limit) * 100) : 0));
</script>

<template>
  <section class="drive">
    <b><AppIcon name="drive" :size="20" />{{ session.mode === 'demo' ? t('rail.demo') : t('rail.drive') }}</b>
    <template v-if="quota">
      <div class="bar" role="progressbar" :aria-valuenow="Math.round(pct)" aria-valuemin="0" aria-valuemax="100"><span :style="{ width: Math.max(pct, 1.5) + '%' }" /></div>
      <span class="hint">{{ quota.limit ? t('settings.storageUsed', { used: formatBytes(quota.used), total: formatBytes(quota.limit) }) : t('settings.storageUsedOnly', { used: formatBytes(quota.used) }) }}</span>
    </template>
  </section>
</template>
