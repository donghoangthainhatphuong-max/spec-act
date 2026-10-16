<script setup>
import { computed } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import SecureImage from '../ui/SecureImage.vue';

/** Link preview card (Open Graph). All text is untrusted and rendered as text; only http(s) addresses open. */
const props = defineProps({
  link: { type: Object, required: true },
  post: { type: Object, default: null }, // owner of the picture file
  imageUrl: { type: String, default: '' }, // local picture of a card still being written
  removable: { type: Boolean, default: false },
});
const emit = defineEmits(['remove']);
const { t } = useI18n();
const safe = computed(() => /^https?:\/\//i.test(props.link.url));
const item = computed(() => (props.link.image ? { id: props.link.image, thumb: null, mime: 'image/jpeg' } : null));
const host = computed(() => { try { return new URL(props.link.url).hostname.replace(/^www\./, ''); } catch { return ''; } });
</script>

<template>
  <div class="linkcard">
    <component :is="safe ? 'a' : 'div'" class="lc-body" :href="safe ? link.url : undefined" target="_blank" rel="noopener noreferrer nofollow" @click.stop>
      <div v-if="imageUrl || (item && post)" class="lc-img">
        <img v-if="imageUrl" :src="imageUrl" alt="" />
        <SecureImage v-else :post="post" :item="item" />
      </div>
      <div class="lc-text">
        <span class="lc-site"><AppIcon name="external" :size="13" />{{ link.site || host }}</span>
        <b v-if="link.title" class="lc-title">{{ link.title }}</b>
        <span v-if="link.description" class="lc-desc">{{ link.description }}</span>
      </div>
    </component>
    <button v-if="removable" type="button" class="lc-x" :aria-label="t('compose.linkRemove')" @click="emit('remove')"><AppIcon name="x" :size="14" /></button>
  </div>
</template>

<style scoped>
.linkcard { position: relative; margin: 8px 14px 12px; border: 1px solid var(--line); border-radius: var(--r); background: var(--sunken); overflow: hidden; }
.lc-body { display: block; color: inherit; text-decoration: none; }
.lc-img { aspect-ratio: 1.91 / 1; background: var(--line); }
.lc-img img { width: 100%; height: 100%; object-fit: cover; display: block; }
.lc-text { display: flex; flex-direction: column; gap: 3px; padding: 10px 14px 12px; min-width: 0; }
.lc-site { display: flex; align-items: center; gap: 5px; font-size: 12px; color: var(--muted); text-transform: uppercase; letter-spacing: .03em; }
.lc-title { font-size: 15px; line-height: 1.3; overflow-wrap: anywhere; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }
.lc-desc { font-size: 13.5px; color: var(--muted); line-height: 1.4; overflow-wrap: anywhere; display: -webkit-box; -webkit-line-clamp: 3; -webkit-box-orient: vertical; overflow: hidden; }
.lc-x { position: absolute; top: 8px; inset-inline-end: 8px; width: 28px; height: 28px; border-radius: 50%; border: 0; background: rgba(0,0,0,.6); color: #fff; display: grid; place-items: center; cursor: pointer; }
</style>
