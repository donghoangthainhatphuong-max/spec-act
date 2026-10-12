<script setup>
import { computed } from 'vue';
import { usePeopleStore } from '../../stores/people';

const props = defineProps({
  email: { type: String, default: '' },
  name: { type: String, default: '' },
  size: { type: String, default: '' }, // xs | sm | lg | xl
});
const people = usePeopleStore();

const label = computed(() => props.name || (props.email ? people.nameFor(props.email) : '?'));
const initials = computed(() => {
  const words = label.value.trim().split(/\s+/).filter(Boolean);
  return (words.map((w) => Array.from(w)[0]).slice(-2).join('') || '?').toUpperCase();
});
const hue = computed(() => {
  let h = 0;
  for (const c of props.email || label.value) h = (h * 31 + c.charCodeAt(0)) % 360;
  return h;
});
const isMe = computed(() => !!props.email && people.isMe(props.email));
</script>

<template>
  <span class="avatar" :class="[size, { me: isMe }]" :style="{ '--h': hue }" aria-hidden="true">{{ initials }}</span>
</template>
