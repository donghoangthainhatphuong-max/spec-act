<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import { config } from '../../config';

const props = defineProps({
  title: { type: String, default: '' },
  hint: { type: String, default: '' },
  error: { type: String, default: '' },
  busy: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  length: { type: Number, default: config.pinLength },
});
const emit = defineEmits(['complete']);
const { t } = useI18n();
const pin = ref('');
const shaking = ref(false);
const root = ref(null);

const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
const inactive = computed(() => props.busy || props.disabled);

function push(d) {
  if (inactive.value || pin.value.length >= props.length) return;
  pin.value += d;
  if (pin.value.length === props.length) {
    const value = pin.value;
    emit('complete', value);
  }
}
const back = () => { if (!inactive.value) pin.value = pin.value.slice(0, -1); };
function onKey(e) {
  if (e.ctrlKey || e.metaKey || e.altKey) return;
  const target = e.target;
  if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;
  if (/^\d$/.test(e.key)) { e.preventDefault(); push(e.key); }
  else if (e.key === 'Backspace') { e.preventDefault(); back(); }
}
function reset({ shake = false } = {}) {
  pin.value = '';
  if (shake) { shaking.value = true; setTimeout(() => { shaking.value = false; }, 450); }
}
watch(() => props.error, (e) => { if (e) reset({ shake: true }); });

onMounted(() => window.addEventListener('keydown', onKey));
onBeforeUnmount(() => window.removeEventListener('keydown', onKey));
defineExpose({ reset });
</script>

<template>
  <div ref="root" class="pinpad">
    <h2 v-if="title" class="pin-title">{{ title }}</h2>
    <p v-if="hint" class="hint pin-hint">{{ hint }}</p>
    <div class="dots" :class="{ shake: shaking }" role="img" :aria-label="t('pin.entered', { n: pin.length, total: length })">
      <i v-for="i in length" :key="i" :class="{ on: i <= pin.length }" />
    </div>
    <p class="pin-error" role="alert" aria-live="assertive">{{ error }}</p>
    <div class="keys" role="group" :aria-label="t('pin.keypad')">
      <template v-for="(k, i) in keys" :key="i">
        <span v-if="k === ''" />
        <button v-else-if="k === 'del'" type="button" class="key del" :aria-label="t('pin.delete')" :disabled="inactive || !pin.length" @click="back"><AppIcon name="backspace" :size="22" /></button>
        <button v-else type="button" class="key" :disabled="inactive" @click="push(k)">{{ k }}</button>
      </template>
    </div>
  </div>
</template>

<style scoped>
.pinpad { display: flex; flex-direction: column; align-items: center; gap: 10px; width: 100%; }
.pin-title { font-size: 20px; font-weight: 650; text-align: center; }
.pin-hint { text-align: center; max-width: 34ch; }
.dots { display: flex; gap: 14px; padding: 14px 0 4px; }
.dots i { width: 14px; height: 14px; border-radius: 50%; border: 1.5px solid color-mix(in srgb, var(--muted) 70%, transparent); transition: background-color .12s, transform .12s, border-color .12s; }
.dots i.on { background: var(--accent); border-color: var(--accent); transform: scale(1.12); }
.dots.shake { animation: shake .4s; }
.pin-error { min-height: 20px; font-size: 13.5px; font-weight: 550; color: var(--danger); text-align: center; }
.keys { display: grid; grid-template-columns: repeat(3, 72px); gap: 12px; justify-content: center; direction: ltr; }
.key { width: 72px; height: 72px; border-radius: 50%; border: 1px solid var(--line); background: var(--surface); font-size: 25px; font-weight: 500; font-variant-numeric: tabular-nums; display: inline-flex; align-items: center; justify-content: center; transition: background-color .12s, transform .08s; }
.key:hover:not(:disabled) { background: var(--sunken); }
.key:active:not(:disabled) { transform: scale(.94); background: var(--accent-soft); }
.key:disabled { opacity: .45; cursor: default; }
.key.del { border-color: transparent; background: transparent; color: var(--muted); }
@media (max-width: 380px), (max-height: 700px) { .keys { grid-template-columns: repeat(3, 62px); gap: 9px; } .key { width: 62px; height: 62px; font-size: 22px; } }
</style>
