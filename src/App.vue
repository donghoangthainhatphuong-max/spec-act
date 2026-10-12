<script setup>
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import AppShell from './components/layout/AppShell.vue';
import ToastHost from './components/ui/ToastHost.vue';
import ConfirmDialog from './components/ui/ConfirmDialog.vue';
import Lightbox from './components/ui/Lightbox.vue';
import { useUiStore } from './stores/ui';
import { useI18n } from '@/i18n';
import { useSessionStore } from './stores/session';
import { usePeopleStore } from './stores/people';
import { usePostsStore } from './stores/posts';
import { useAutoLock } from './composables/useAutoLock';
import { config } from './config';

const { t } = useI18n();
const ui = useUiStore();
const route = useRoute();
const router = useRouter();
const session = useSessionStore();
const people = usePeopleStore();
const posts = usePostsStore();
useAutoLock();

const ready = computed(() => session.phase === 'ready');
const inShell = computed(() => ready.value && route.meta.shell);

// Signed in while the welcome page is showing -> continue to where the visitor was going.
watch([ready, () => route.name], ([isReady, name]) => {
  if (isReady && name === 'welcome') {
    const next = route.query.next;
    router.replace(typeof next === 'string' && next.startsWith('/') ? next : '/');
  }
}, { immediate: true });

watch(() => session.phase, async (p, prev) => {
  if (p === 'ready') {
    await people.load();
    await posts.init();
    posts.startAutoSync(config.syncIntervalSeconds);
  } else if (prev === 'ready') {
    posts.startAutoSync(0);
    if (route.name !== 'welcome') router.replace({ name: 'welcome', query: route.fullPath !== '/' ? { next: route.fullPath } : {} });
  }
}, { immediate: true });
</script>

<template>
  <AppShell v-if="inShell" />
  <RouterView v-else-if="!ready" />
  <div v-if="ui.updateReady" class="update-banner" role="status"><span>{{ t('update.ready') }}</span><button class="btn sm primary" @click="ui.applyUpdate()">{{ t('update.reload') }}</button></div>
  <ToastHost />
  <ConfirmDialog />
  <Lightbox />
</template>
