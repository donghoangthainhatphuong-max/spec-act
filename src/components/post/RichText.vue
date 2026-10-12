<script setup>
import { computed } from 'vue';
import { tokenize } from '../../services/mentions';
import { usePeopleStore } from '../../stores/people';

const props = defineProps({ text: { type: String, default: '' } });
const people = usePeopleStore();
const segments = computed(() => tokenize(props.text));
</script>

<template>
  <template v-for="(s, i) in segments" :key="i">
    <span v-if="s.t === 'mention'" class="mention" :title="s.email">@{{ people.nameFor(s.email) }}</span>
    <a v-else-if="s.t === 'link'" :href="s.v" class="autolink" target="_blank" rel="noopener noreferrer nofollow" @click.stop>{{ s.v }}</a>
    <template v-else>{{ s.v }}</template>
  </template>
</template>
