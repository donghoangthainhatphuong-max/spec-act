<script setup>
import AppIcon from './AppIcon.vue';
import { useUiStore } from '../../stores/ui';

const ui = useUiStore();
</script>

<template>
  <div id="toast" role="status" aria-live="polite">
    <span v-for="x in ui.toasts" :key="x.id" class="t" :class="x.kind"><i><AppIcon :name="x.kind === 'error' ? 'alert' : 'check'" :size="13" /></i>{{ x.message }}</span>
  </div>
</template>

<style scoped>
#toast { display: flex; flex-direction: column; gap: 8px; align-items: center; }
.t.error i { background: var(--danger); color: #fff; }
.t { white-space: normal; max-width: min(92vw, 460px); }
</style>
