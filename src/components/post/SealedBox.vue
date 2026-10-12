<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import { usePostsStore } from '../../stores/posts';
import { useUiStore } from '../../stores/ui';
import { usePeopleStore } from '../../stores/people';
import { useSessionStore } from '../../stores/session';

const props = defineProps({ post: { type: Object, required: true } });
const emit = defineEmits(['unlocked']);
const { t } = useI18n();
const posts = usePostsStore();
const ui = useUiStore();
const people = usePeopleStore();
const session = useSessionStore();

const pw = ref('');
const remember = ref(false);
const busy = ref(false);
const wrong = ref(false);
const root = ref(null);
const hue = computed(() => { let h = 0; for (const c of props.post.owner.email) h = (h * 31 + c.charCodeAt(0)) % 360; return h; });

async function submit() {
  if (!pw.value || busy.value) { shake(); return; }
  busy.value = true;
  wrong.value = false;
  try {
    await posts.unlock(props.post.id, pw.value, remember.value);
    pw.value = '';
    ui.toast(t('toast.unlocked'));
    emit('unlocked');
  } catch (e) {
    wrong.value = e.code === 'wrong-password';
    if (!wrong.value) ui.toast(t('error.generic'), { kind: 'error' });
    shake();
  } finally { busy.value = false; }
}
async function shake() {
  const el = root.value;
  if (!el) return;
  el.classList.remove('shake');
  await nextTick();
  void el.offsetWidth;
  el.classList.add('shake');
  el.querySelector('input')?.focus();
}
</script>

<template>
  <div ref="root" class="sealed" :style="{ '--h': hue }">
    <div class="veil" />
    <form class="box" @submit.prevent="submit">
      <span class="lockmark"><AppIcon name="lock" :size="22" /></span>
      <b>{{ t('post.protected') }}</b>
      <span class="hint">{{ t('post.protectedHint', { name: people.nameFor(post.owner.email) }) }}</span>
      <div class="row">
        <label class="sr" :for="'pw-' + post.id">{{ t('post.password') }}</label>
        <input :id="'pw-' + post.id" v-model="pw" class="input" type="password" :placeholder="t('post.password')" autocomplete="off" :aria-invalid="wrong" />
        <button class="btn primary" :disabled="busy">{{ t('post.unlock') }}</button>
      </div>
      <p v-if="wrong" class="wrong" role="alert">{{ t('post.wrongPassword') }}</p>
      <label v-if="session.mode === 'drive'" class="remember"><input v-model="remember" type="checkbox" /> {{ t('post.rememberKey') }}</label>
    </form>
  </div>
</template>

<style scoped>
.sealed { background:
  radial-gradient(120% 90% at 12% 8%, oklch(.78 .07 var(--h) / .55), transparent 62%),
  radial-gradient(110% 90% at 90% 95%, oklch(.7 .07 calc(var(--h) + 70) / .45), transparent 60%),
  var(--sunken); }
[data-theme="dark"] .sealed { background:
  radial-gradient(120% 90% at 12% 8%, oklch(.38 .06 var(--h) / .75), transparent 62%),
  radial-gradient(110% 90% at 90% 95%, oklch(.32 .06 calc(var(--h) + 70) / .7), transparent 60%),
  var(--sunken); }
.wrong { color: var(--danger); font-size: 13.5px; font-weight: 550; }
.remember { display: inline-flex; align-items: center; gap: 8px; font-size: 13px; color: var(--muted); cursor: pointer; }
.remember input { accent-color: var(--accent); width: 16px; height: 16px; }
.btn:disabled { opacity: .6; cursor: progress; }
</style>
