<script setup>
import { ref } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import { useSessionStore } from '../../stores/session';
import { useUiStore } from '../../stores/ui';
import { humanSize, labelOf } from '../../services/mediaKinds';

const props = defineProps({ post: { type: Object, required: true }, items: { type: Array, default: () => [] }, more: { type: Number, default: 0 } });
const { t } = useI18n();
const session = useSessionStore();
const ui = useUiStore();

const playing = ref({}); // item id -> object URL of the audio being played
const busy = ref({});

const clock = (s) => `${Math.floor(s / 60)}:${String(Math.round(s % 60)).padStart(2, '0')}`;

async function load(item) {
  busy.value = { ...busy.value, [item.id]: true };
  try { return await session.repo.mediaUrl(props.post, item); } catch { ui.toast(t('error.generic'), { kind: 'error' }); return ''; } finally { busy.value = { ...busy.value, [item.id]: false }; }
}
async function play(item) {
  if (playing.value[item.id]) { const { [item.id]: _x, ...rest } = playing.value; playing.value = rest; return; }
  const url = await load(item);
  if (url) playing.value = { ...playing.value, [item.id]: url };
}
// Documents are only ever handed over as a download — never rendered by this page.
async function download(item) {
  const url = await load(item);
  if (!url) return;
  const a = document.createElement('a');
  a.href = url;
  a.download = item.name || 'file';
  a.rel = 'noopener';
  document.body.appendChild(a);
  a.click();
  a.remove();
}
</script>

<template>
  <ul v-if="items.length" class="attach">
    <li v-for="m in items" :key="m.id">
      <span class="ico" :class="m.kind"><AppIcon :name="m.kind === 'audio' ? 'mic' : 'file'" :size="20" /><b v-if="m.kind === 'file'">{{ labelOf(m.name) }}</b></span>
      <div class="info">
        <span class="name" :title="m.name">{{ m.name }}</span>
        <span class="meta">{{ m.kind === 'audio' && m.duration ? clock(m.duration) + ' · ' : '' }}{{ humanSize(m.size) }}</span>
        <audio v-if="m.kind === 'audio' && playing[m.id]" :src="playing[m.id]" controls autoplay preload="auto" />
      </div>
      <button v-if="m.kind === 'audio'" class="btn sm" :disabled="busy[m.id]" :aria-label="t('attach.play')" @click="play(m)"><AppIcon :name="playing[m.id] ? 'x' : 'play'" :size="16" :fill="!playing[m.id]" />{{ busy[m.id] ? t('attach.loading') : playing[m.id] ? t('close') : t('attach.play') }}</button>
      <button v-else class="btn sm" :disabled="busy[m.id]" :aria-label="`${t('attach.download')} ${m.name}`" @click="download(m)"><AppIcon name="download" :size="16" />{{ busy[m.id] ? t('attach.loading') : t('attach.download') }}</button>
    </li>
    <li v-if="more > 0" class="more"><RouterLink :to="{ name: 'post', params: { id: post.id } }">{{ t('attach.more', { n: more }) }}</RouterLink></li>
  </ul>
</template>

<style scoped>
.attach { list-style: none; margin: 0; padding: 4px 14px 10px; display: flex; flex-direction: column; gap: 8px; }
.attach li { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: 16px; background: var(--sunken); }
.attach li.more { justify-content: center; background: transparent; padding: 0; }
.attach li.more a { font-size: 13.5px; color: var(--accent); }
.ico { flex: none; width: 44px; height: 44px; border-radius: 12px; background: var(--surface); color: var(--muted); display: inline-flex; flex-direction: column; align-items: center; justify-content: center; gap: 1px; }
.ico.audio { color: var(--accent); }
.ico b { font-size: 9.5px; letter-spacing: .04em; color: var(--text); font-weight: 700; }
.info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; }
.name { font-weight: 600; font-size: 14.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.meta { font-size: 12.5px; color: var(--muted); }
audio { width: 100%; height: 36px; margin-top: 6px; }
.btn.sm { flex: none; }
</style>
