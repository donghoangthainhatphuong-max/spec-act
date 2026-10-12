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

// view transform: zoom, rotation (quarter turns) and pan
const MIN = 1;
const MAX = 6;
const scale = ref(1);
const rot = ref(0);
const tx = ref(0);
const ty = ref(0);
const dragging = ref(false);
let touchX = null;
let drag = null;
let pinch = null;

const imgStyle = computed(() => ({ transform: `translate(${tx.value}px, ${ty.value}px) rotate(${rot.value}deg) scale(${scale.value})`, transition: dragging.value || pinch ? 'none' : 'transform .2s ease' }));
const zoomed = computed(() => scale.value > 1.001);

function resetView() { scale.value = 1; rot.value = 0; tx.value = 0; ty.value = 0; }
function zoomTo(s) {
  scale.value = Math.min(MAX, Math.max(MIN, s));
  if (scale.value === 1) { tx.value = 0; ty.value = 0; }
}
const zoomBy = (f) => zoomTo(scale.value * f);
const rotate = (d) => { rot.value += d; };

async function show() {
  if (!v.value) return;
  loading.value = true;
  src.value = '';
  resetView();
  const item = v.value.items[index.value];
  try {
    const thumb = await session.repo.mediaUrl(v.value.post, item, { thumb: true }).catch(() => '');
    if (thumb) src.value = thumb; // instant preview while the full size loads
    src.value = await session.repo.mediaUrl(v.value.post, item);
  } catch { /* keep preview */ }
  loading.value = false;
  // warm the neighbours so next/previous feels instant
  const n = v.value?.items.length || 0;
  if (n > 1 && v.value) for (const d of [1, -1]) session.repo.mediaUrl(v.value.post, v.value.items[(index.value + d + n) % n]).catch(() => {});
}
watch(v, (val) => { if (val) { index.value = val.index; show(); } }, { immediate: true });
watch(index, show);

const step = (d) => { if (count.value > 1) index.value = (index.value + d + count.value) % count.value; };
function onKey(e) {
  if (!v.value) return;
  if (e.key === 'Escape') ui.closeViewer();
  else if (e.key === 'ArrowRight') step(1);
  else if (e.key === 'ArrowLeft') step(-1);
  else if (e.key === '+' || e.key === '=') zoomBy(1.25);
  else if (e.key === '-') zoomBy(0.8);
  else if (e.key === '0') resetView();
  else if (e.key === 'r' || e.key === 'R') rotate(e.shiftKey ? -90 : 90);
}
onMounted(() => document.addEventListener('keydown', onKey));
onBeforeUnmount(() => document.removeEventListener('keydown', onKey));

function onWheel(e) { e.preventDefault(); zoomBy(e.deltaY < 0 ? 1.15 : 1 / 1.15); }
function onDbl() { if (zoomed.value) { scale.value = 1; tx.value = 0; ty.value = 0; } else zoomTo(2.5); }

// one finger / mouse: swipe to change photo when not zoomed, pan when zoomed; two fingers: pinch
const dist = (a, b) => Math.hypot(a.clientX - b.clientX, a.clientY - b.clientY);
function onPointerDown(e) {
  if (e.target.closest('.icon-btn, .toolbar')) return;
  if (e.pointerType === 'touch') return; // touch handled below
  if (!zoomed.value) return;
  dragging.value = true;
  drag = { x: e.clientX - tx.value, y: e.clientY - ty.value };
  e.currentTarget.setPointerCapture?.(e.pointerId);
}
function onPointerMove(e) { if (drag && dragging.value) { tx.value = e.clientX - drag.x; ty.value = e.clientY - drag.y; } }
function onPointerUp() { dragging.value = false; drag = null; }

function onTouchStart(e) {
  if (e.touches.length === 2) { pinch = { d: dist(e.touches[0], e.touches[1]), s: scale.value }; touchX = null; return; }
  if (zoomed.value) { drag = { x: e.touches[0].clientX - tx.value, y: e.touches[0].clientY - ty.value }; dragging.value = true; touchX = null; } else touchX = e.touches[0].clientX;
}
function onTouchMove(e) {
  if (pinch && e.touches.length === 2) { zoomTo(pinch.s * (dist(e.touches[0], e.touches[1]) / pinch.d)); return; }
  if (drag && dragging.value && e.touches.length === 1) { tx.value = e.touches[0].clientX - drag.x; ty.value = e.touches[0].clientY - drag.y; }
}
function onTouchEnd(e) {
  if (pinch) { if (e.touches.length < 2) pinch = null; return; }
  if (dragging.value) { dragging.value = false; drag = null; return; }
  if (touchX == null || zoomed.value) return;
  const dx = e.changedTouches[0].clientX - touchX;
  if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
  touchX = null;
}
</script>

<template>
  <div
    v-if="v" class="viewer" :class="{ zoomed }" role="dialog" aria-modal="true"
    @click.self="ui.closeViewer()" @wheel="onWheel" @pointerdown="onPointerDown" @pointermove="onPointerMove" @pointerup="onPointerUp" @pointercancel="onPointerUp"
    @touchstart.passive="onTouchStart" @touchmove.passive="onTouchMove" @touchend.passive="onTouchEnd"
  >
    <img v-if="src" :src="src" alt="" draggable="false" :class="{ dim: loading }" :style="imgStyle" @dblclick="onDbl" />
    <button class="icon-btn vclose" :aria-label="t('close')" @click="ui.closeViewer()"><AppIcon name="x" :size="22" /></button>
    <template v-if="count > 1">
      <button class="icon-btn nav prev" :aria-label="t('viewer.prev')" @click="step(-1)"><AppIcon name="back" :size="22" /></button>
      <button class="icon-btn nav next" :aria-label="t('viewer.next')" @click="step(1)"><AppIcon name="chevron" :size="22" /></button>
    </template>
    <div class="toolbar" role="toolbar" :aria-label="t('viewer.tools')">
      <button class="icon-btn" :aria-label="t('viewer.rotateLeft')" :title="t('viewer.rotateLeft')" @click="rotate(-90)"><AppIcon name="rotate" :size="20" class="flip" /></button>
      <button class="icon-btn" :aria-label="t('viewer.rotateRight')" :title="t('viewer.rotateRight')" @click="rotate(90)"><AppIcon name="rotate" :size="20" /></button>
      <button class="icon-btn" :aria-label="t('viewer.zoomOut')" :title="t('viewer.zoomOut')" :disabled="scale <= MIN" @click="zoomBy(0.8)"><AppIcon name="zoomout" :size="20" /></button>
      <span class="pct">{{ Math.round(scale * 100) }}%</span>
      <button class="icon-btn" :aria-label="t('viewer.zoomIn')" :title="t('viewer.zoomIn')" :disabled="scale >= MAX" @click="zoomBy(1.25)"><AppIcon name="zoomin" :size="20" /></button>
      <button class="icon-btn" :aria-label="t('viewer.reset')" :title="t('viewer.reset')" @click="resetView"><AppIcon name="refresh" :size="20" /></button>
      <span v-if="count > 1" class="counter">{{ index + 1 }} / {{ count }}</span>
    </div>
  </div>
</template>

<style>
/* global on purpose: must out-rank the design's `.viewer .icon-btn` (top-right corner) rule */
.viewer { touch-action: none; overflow: hidden; }
.viewer.zoomed { cursor: grab; }
.viewer img { max-width: 100%; max-height: 100%; object-fit: contain; user-select: none; -webkit-user-drag: none; will-change: transform; }
.viewer img.dim { opacity: .8; }
.viewer .icon-btn.vclose { position: absolute; top: 16px; color: #fff; background: rgba(255,255,255,.12); inset-inline-end: 16px; }
.viewer .icon-btn.nav { position: absolute; top: 50%; bottom: auto; transform: translateY(-50%); color: #fff; background: rgba(255,255,255,.12); width: 48px; height: 48px; inset-inline-end: auto; }
.viewer .icon-btn.nav:hover { background: rgba(255,255,255,.22); }
.viewer .icon-btn.prev { inset-inline-start: 16px; }
.viewer .icon-btn.next { inset-inline-end: 16px; inset-inline-start: auto; }
[dir="rtl"] .viewer .nav svg { transform: scaleX(-1); }
.viewer .toolbar { position: absolute; bottom: calc(18px + env(safe-area-inset-bottom)); left: 50%; transform: translateX(-50%); display: flex; align-items: center; gap: 2px; padding: 4px 8px; border-radius: 999px; background: rgba(20,22,21,.72); backdrop-filter: blur(10px); color: #fff; max-width: calc(100vw - 24px); }
.viewer .toolbar .icon-btn { position: static; width: 38px; height: 38px; color: #fff; background: transparent; }
.viewer .toolbar .icon-btn:hover:not(:disabled) { background: rgba(255,255,255,.14); }
.viewer .toolbar .icon-btn:disabled { opacity: .35; }
.viewer .toolbar .flip { transform: scaleX(-1); }
.viewer .pct { min-width: 46px; text-align: center; font-size: 12.5px; font-variant-numeric: tabular-nums; opacity: .85; }
.viewer .counter { margin-inline-start: 6px; padding-inline-start: 10px; border-inline-start: 1px solid rgba(255,255,255,.25); font-size: 13px; white-space: nowrap; }
</style>
