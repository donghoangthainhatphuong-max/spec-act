<script setup>
import { computed } from 'vue';
import { useI18n } from '@/i18n';
import SecureImage from '../ui/SecureImage.vue';

const props = defineProps({
  post: { type: Object, required: true },
  media: { type: Array, required: true },
  total: { type: Number, default: 0 },
  detail: { type: Boolean, default: false },
});
const emit = defineEmits(['open']);
const { t } = useI18n();

const head = computed(() => props.media.slice(0, 3));
const rest = computed(() => (props.detail ? props.media.slice(3) : []));
const hidden = computed(() => (props.detail ? 0 : Math.max(0, (props.total || props.media.length) - 3)));
</script>

<template>
  <div v-if="media.length">
    <div class="photos" :class="'n' + head.length">
      <button v-for="(m, i) in head" :key="m.id" :aria-label="t('post.viewPhoto')" @click="emit('open', i)">
        <SecureImage :post="post" :item="m" :thumb="i > 0 && !detail" :eager="detail && i === 0" />
        <span v-if="i === 2 && hidden" class="more-photos">+{{ hidden }}</span>
      </button>
    </div>
    <div v-if="rest.length" class="photos rest">
      <button v-for="(m, i) in rest" :key="m.id" :aria-label="t('post.viewPhoto')" @click="emit('open', i + 3)">
        <SecureImage :post="post" :item="m" thumb />
      </button>
    </div>
  </div>
</template>

<style scoped>
.rest { grid-template-columns: repeat(3, 1fr); margin-top: 3px; }
.rest button { aspect-ratio: 1; }
.more-photos { position: absolute; inset: 0; display: grid; place-items: center; background: rgba(0,0,0,.45); color: #fff; font-size: 26px; font-weight: 600; }
</style>
