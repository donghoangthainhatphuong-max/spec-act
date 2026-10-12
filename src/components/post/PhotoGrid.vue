<script setup>
import { computed } from 'vue';
import { useI18n } from '@/i18n';
import SecureImage from '../ui/SecureImage.vue';
import AppIcon from '../ui/AppIcon.vue';

const props = defineProps({
  post: { type: Object, required: true },
  media: { type: Array, required: true },
  total: { type: Number, default: 0 },
  detail: { type: Boolean, default: false },
});
const emit = defineEmits(['open']);
const { t } = useI18n();

const clock = (s) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, '0')}`;
const head = computed(() => props.media.slice(0, 3));
const rest = computed(() => (props.detail ? props.media.slice(3) : []));
const hidden = computed(() => (props.detail ? 0 : Math.max(0, (props.total || props.media.length) - 3)));
</script>

<template>
  <div v-if="media.length">
    <div class="photos" :class="'n' + head.length">
      <button v-for="(m, i) in head" :key="m.id" :aria-label="t('post.viewPhoto')" @click="emit('open', i)">
        <SecureImage :post="post" :item="m" :thumb="(i > 0 && !detail) || m.kind === 'video'" :eager="detail && i === 0" />
        <span v-if="m.kind === 'video'" class="play"><AppIcon name="play" :size="26" fill /><small v-if="m.duration">{{ clock(m.duration) }}</small></span>
        <span v-if="i === 2 && hidden" class="more-photos">+{{ hidden }}</span>
      </button>
    </div>
    <div v-if="rest.length" class="photos rest">
      <button v-for="(m, i) in rest" :key="m.id" :aria-label="t('post.viewPhoto')" @click="emit('open', i + 3)">
        <SecureImage :post="post" :item="m" thumb />
        <span v-if="m.kind === 'video'" class="play"><AppIcon name="play" :size="22" fill /></span>
      </button>
    </div>
  </div>
</template>

<style scoped>
.play { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: #fff; background: rgba(0,0,0,.18); pointer-events: none; }
.play svg { filter: drop-shadow(0 2px 6px rgba(0,0,0,.5)); }
.play small { position: absolute; right: 8px; bottom: 8px; padding: 2px 8px; border-radius: 999px; background: rgba(0,0,0,.6); font-size: 12px; font-variant-numeric: tabular-nums; }
.rest { grid-template-columns: repeat(3, 1fr); margin-top: 3px; }
.rest button { aspect-ratio: 1; }
.more-photos { position: absolute; inset: 0; display: grid; place-items: center; background: rgba(0,0,0,.45); color: #fff; font-size: 26px; font-weight: 600; }
</style>
