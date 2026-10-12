<script setup>
import { nextTick, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import { useUiStore } from '../../stores/ui';

const { t } = useI18n();
const ui = useUiStore();
const dlg = ref(null);

watch(() => ui.confirmState, async (s) => {
  await nextTick();
  if (s && dlg.value && !dlg.value.open) dlg.value.showModal();
  if (!s && dlg.value?.open) dlg.value.close();
});
function onCancel(e) { e.preventDefault(); ui.answer(false); }
</script>

<template>
  <dialog ref="dlg" aria-labelledby="confirm-text" @cancel="onCancel" @click.self="ui.answer(false)">
    <template v-if="ui.confirmState">
      <p id="confirm-text">{{ ui.confirmState.text }}</p>
      <div class="footer-actions" style="margin-top:20px">
        <button class="btn" @click="ui.answer(false)">{{ t('compose.cancel') }}</button>
        <button class="btn primary" :class="{ dangerous: ui.confirmState.danger }" @click="ui.answer(true)">{{ ui.confirmState.yes }}</button>
      </div>
    </template>
  </dialog>
</template>

<style scoped>
.dangerous { background: var(--danger); border-color: var(--danger); color: var(--surface); }
</style>
