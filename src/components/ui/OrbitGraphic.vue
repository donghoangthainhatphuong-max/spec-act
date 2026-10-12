<script setup>
import { computed } from 'vue';
import AppAvatar from './AppAvatar.vue';
import AppIcon from './AppIcon.vue';
import { usePeopleStore } from '../../stores/people';

/** The signature element: one thing in the middle, the people who can see it around it. */
const props = defineProps({
  center: { type: Object, default: () => ({}) }, // { src } | { email }
  sats: { type: Array, default: () => [] }, // [{ email?, lit }]
  big: { type: Boolean, default: true },
  fresh: { type: String, default: null },
});
const people = usePeopleStore();

const pts = computed(() => {
  const n = props.sats.length;
  return props.sats.map((s, i) => {
    const a = ((-90 + (360 / Math.max(n, 1)) * i) * Math.PI) / 180;
    return { ...s, x: 50 + 40 * Math.cos(a), y: 50 + 40 * Math.sin(a) };
  });
});
const lines = computed(() => { let i = 0; return pts.value.filter((s) => s.lit).map((s) => ({ ...s, d: i++ })); });
const dots = computed(() => { let i = 0; return pts.value.map((s) => ({ ...s, d: s.lit ? i++ : 0 })); });
const satSize = (s) => (s.lit ? (props.big ? 'xl' : 'lg') : (props.big ? 'lg' : 'sm'));
</script>

<template>
  <div class="orbit" :class="{ sm: !big }">
    <svg viewBox="0 0 100 100" aria-hidden="true">
      <circle class="ring" cx="50" cy="50" r="40" />
      <line v-for="s in lines" :key="s.email" :class="{ fresh: s.email === fresh }" x1="50" y1="50" :x2="s.x.toFixed(2)" :y2="s.y.toFixed(2)" :style="{ '--d': s.d }" />
    </svg>
    <div v-if="center.src" class="core"><img :src="center.src" alt="" /></div>
    <div v-else class="core face"><AppAvatar :email="center.email" :name="center.name" size="xl" /></div>
    <span v-for="s in dots" :key="s.email || 'x' + s.x" class="sat" :class="[s.lit ? 'lit' : 'dim', { fresh: s.email === fresh }]" :style="{ left: s.x.toFixed(2) + '%', top: s.y.toFixed(2) + '%', '--d': s.d }" :title="s.email ? people.nameFor(s.email) : ''">
      <AppAvatar v-if="s.email" :email="s.email" :name="s.name" :size="satSize(s)" />
      <span v-else class="avatar" :class="big ? 'lg' : 'sm'"><AppIcon name="user" :size="big ? 20 : 16" /></span>
      <i v-if="s.lit" class="tick"><AppIcon name="check" :size="big ? 12 : 10" /></i>
    </span>
  </div>
</template>
