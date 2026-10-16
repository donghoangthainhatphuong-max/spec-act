<script setup>
import { useId } from 'vue';

/** The SPECACT mark: a moment with a keyhole (yours) inside the circle of the few people you chose. Colours follow the theme. */
defineProps({ size: { type: Number, default: 28 } });
const id = `kh${useId()}`;
</script>

<template>
  <svg :width="size" :height="size" viewBox="0 0 64 64" aria-hidden="true" class="logo">
    <defs>
      <mask :id="id" maskUnits="userSpaceOnUse" x="0" y="0" width="64" height="64">
        <rect width="64" height="64" fill="#fff" />
        <circle cx="32" cy="29.5" r="4.3" fill="#000" />
        <rect x="29.8" y="30.5" width="4.4" height="11" rx="2.2" fill="#000" />
      </mask>
    </defs>
    <circle cx="32" cy="32" r="27" fill="none" stroke="currentColor" stroke-width="2.4" opacity=".4" />
    <circle cx="32" cy="32" r="15.5" fill="currentColor" :mask="`url(#${id})`" />
    <circle cx="51.1" cy="12.9" r="4.2" fill="var(--spark)" />
    <circle cx="27.3" cy="58.6" r="3.4" fill="var(--spark)" />
    <circle cx="6.6" cy="22.8" r="3.4" fill="var(--spark)" />
  </svg>
</template>
