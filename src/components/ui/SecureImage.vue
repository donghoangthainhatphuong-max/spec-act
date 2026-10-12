<script setup>
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useSessionStore } from '../../stores/session';
import AppIcon from './AppIcon.vue';

const props = defineProps({
  post: { type: Object, required: true },
  item: { type: Object, required: true },
  thumb: { type: Boolean, default: false },
  alt: { type: String, default: '' },
  eager: { type: Boolean, default: false },
});
const emit = defineEmits(['loaded']);
const session = useSessionStore();
const src = ref('');
const failed = ref(false);
const root = ref(null);
let observer;
let started = false;

async function load() {
  if (started || !session.repo) return;
  started = true;
  failed.value = false;
  try {
    src.value = await session.repo.mediaUrl(props.post, props.item, { thumb: props.thumb });
    emit('loaded');
  } catch { failed.value = true; }
}

onMounted(() => {
  if (props.eager || !('IntersectionObserver' in window)) { load(); return; }
  observer = new IntersectionObserver((entries) => { if (entries.some((e) => e.isIntersecting)) { observer.disconnect(); load(); } }, { rootMargin: '400px' });
  observer.observe(root.value);
});
onBeforeUnmount(() => observer?.disconnect());
watch(() => [props.item.id, props.thumb], () => { started = false; src.value = ''; load(); });
</script>

<template>
  <span ref="root" class="secure-img" :class="{ ready: !!src, failed }">
    <img v-if="src" :src="src" :alt="alt" decoding="async" draggable="false" />
    <AppIcon v-else-if="failed" name="image" :size="22" class="ph" />
  </span>
</template>

<style scoped>
.secure-img { display: block; width: 100%; height: 100%; background: var(--sunken); position: relative; overflow: hidden; }
.secure-img:not(.ready):not(.failed)::after { content: ""; position: absolute; inset: 0; background: linear-gradient(100deg, transparent 20%, color-mix(in srgb, var(--surface) 55%, transparent) 50%, transparent 80%); background-size: 200% 100%; animation: shimmer 1.4s infinite linear; }
.secure-img img { width: 100%; height: 100%; object-fit: cover; animation: fade .25s; }
.ph { position: absolute; inset: 0; margin: auto; color: var(--muted); }
@keyframes shimmer { from { background-position: 150% 0; } to { background-position: -50% 0; } }
</style>
