<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from './AppIcon.vue';
import { useUiStore } from '../../stores/ui';
import { useSessionStore } from '../../stores/session';

const { t } = useI18n();
const ui = useUiStore();
const session = useSessionStore();
const src = ref('');
const loading = ref(false);
const index = ref(0);
const v = computed(() => ui.viewer);
const count = computed(() => v.value?.items.length || 0);
let touchX = null;

async function show() {
  if (!v.value) return;
  loading.value = true;
  src.value = '';
  const item = v.value.items[index.value];
  try {
    const thumb = await session.repo.mediaUrl(v.value.post, item, { thumb: true }).catch(() => '');
    if (thumb) src.value = thumb; // instant preview while the full size loads
    src.value = await session.repo.mediaUrl(v.value.post, item);
  } catch { /* keep preview */ }
  loading.value = false;
}
watch(v, (val) => { if (val) { index.value = val.index; show(); } }, { immediate: true });
watch(index, show);

const step = (d) => { if (count.value > 1) index.value = (index.value + d + count.value) % count.value; };
function onKey(e) {
  if (!v.value) return;
  if (e.key === 'Escape') ui.closeViewer();
  if (e.key === 'ArrowRight') step(1);
  if (e.key === 'ArrowLeft') step(-1);
}
onMounted(() => document.addEventListener('keydown', onKey));
onBeforeUnmount(() => document.removeEventListener('keydown', onKey));
const onTouchStart = (e) => { touchX = e.touches[0].clientX; };
const onTouchEnd = (e) => {
  if (touchX == null) return;
  const dx = e.changedTouches[0].clientX - touchX;
  if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
  touchX = null;
};
</script>

<template>
  <div v-if="v" class="viewer" role="dialog" aria-modal="true" @click.self="ui.closeViewer()" @touchstart.passive="onTouchStart" @touchend.passive="onTouchEnd">
    <img v-if="src" :src="src" alt="" :class="{ dim: loading }" />
    <button class="icon-btn" :aria-label="t('close')" @click="ui.closeViewer()"><AppIcon name="x" :size="22" /></button>
    <template v-if="count > 1">
      <button class="icon-btn nav prev" :aria-label="t('viewer.prev')" @click="step(-1)"><AppIcon name="back" :size="22" /></button>
      <button class="icon-btn nav next" :aria-label="t('viewer.next')" @click="step(1)"><AppIcon name="chevron" :size="22" /></button>
      <span class="counter">{{ index + 1 }} / {{ count }}</span>
    </template>
  </div>
</template>

<style scoped>
.dim { opacity: .8; }
.viewer img { max-width: 100%; object-fit: contain; }
.nav { top: 50%; transform: translateY(-50%); inset-inline-end: auto; position: absolute; color: #fff; background: rgba(255,255,255,.1); }
.prev { inset-inline-start: 16px; }
.next { inset-inline-end: 16px; }
[dir="rtl"] .prev svg, [dir="rtl"] .next svg { transform: scaleX(-1); }
.counter { position: absolute; bottom: 20px; left: 50%; transform: translateX(-50%); color: #fff; font-size: 13px; background: rgba(0,0,0,.45); padding: 4px 12px; border-radius: 999px; }
</style>
