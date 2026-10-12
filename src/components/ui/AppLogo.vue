<script setup>
defineProps({ size: { type: Number, default: 28 } });
</script>

<template>
  <svg :width="size" :height="size" viewBox="0 0 40 40" aria-hidden="true">
    <circle cx="20" cy="20" r="17" fill="none" stroke="currentColor" stroke-width="3" />
    <path d="M20 3a17 17 0 0 1 0 34z" fill="currentColor" />
    <circle cx="20" cy="17" r="3.4" fill="var(--logo-hole, var(--bg))" />
    <rect x="18.3" y="18" width="3.4" height="9" rx="1.2" fill="var(--logo-hole, var(--bg))" />
  </svg>
</template>
