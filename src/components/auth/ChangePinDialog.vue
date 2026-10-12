<script setup>
import { computed, nextTick, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import PinPad from './PinPad.vue';
import { useSessionStore } from '../../stores/session';
import { useUiStore } from '../../stores/ui';

const props = defineProps({ open: { type: Boolean, default: false } });
const emit = defineEmits(['close']);
const { t } = useI18n();
const session = useSessionStore();
const ui = useUiStore();

const dlg = ref(null);
const pad = ref(null);
const step = ref('old'); // old | new | confirm
const oldPin = ref('');
const newPin = ref('');
const error = ref('');
const busy = ref(false);

const title = computed(() => t(`pin.change.${step.value}`));

watch(() => props.open, async (o) => {
  await nextTick();
  if (o && !dlg.value.open) { step.value = 'old'; oldPin.value = newPin.value = error.value = ''; dlg.value.showModal(); }
  if (!o && dlg.value.open) dlg.value.close();
});

async function onComplete(pin) {
  error.value = '';
  if (step.value === 'old') { oldPin.value = pin; step.value = 'new'; pad.value.reset(); return; }
  if (step.value === 'new') {
    if (pin === oldPin.value) { error.value = t('pin.change.same'); pad.value.reset({ shake: true }); return; }
    newPin.value = pin; step.value = 'confirm'; pad.value.reset(); return;
  }
  if (pin !== newPin.value) { error.value = t('pin.mismatch'); newPin.value = ''; step.value = 'new'; pad.value.reset({ shake: true }); return; }
  busy.value = true;
  try {
    await session.changePin(oldPin.value, newPin.value);
    ui.toast(t('toast.pinChanged'));
    emit('close');
  } catch (e) {
    error.value = e.code === 'bad-pin' ? t('pin.wrong') : t('error.generic');
    step.value = 'old'; oldPin.value = ''; pad.value.reset({ shake: true });
  } finally { busy.value = false; }
}
</script>

<template>
  <dialog ref="dlg" class="pin-dialog" :aria-label="t('settings.changePin')" @cancel.prevent="emit('close')" @click.self="emit('close')">
    <PinPad ref="pad" :title="title" :error="error" :busy="busy" @complete="onComplete" />
    <div class="footer-actions" style="margin-top:12px"><button class="btn" @click="emit('close')">{{ t('compose.cancel') }}</button></div>
  </dialog>
</template>

<style scoped>
.pin-dialog { max-width: 360px; }
</style>
