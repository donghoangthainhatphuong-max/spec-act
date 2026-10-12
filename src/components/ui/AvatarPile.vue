<script setup>
import { computed } from 'vue';
import { useI18n } from '@/i18n';
import AppAvatar from './AppAvatar.vue';
import { usePeopleStore } from '../../stores/people';
import { listOf } from '../../i18n';

const props = defineProps({ emails: { type: Array, default: () => [] }, total: { type: Number, default: 0 }, max: { type: Number, default: 3 } });
const { t } = useI18n();
const people = usePeopleStore();
const count = computed(() => Math.max(props.total, props.emails.length));
const label = computed(() => t('post.visibleTo', { names: listOf(props.emails.map((e) => people.nameFor(e))) }));
</script>

<template>
  <span v-if="emails.length" class="pile" :title="label" role="img" :aria-label="label">
    <AppAvatar v-for="e in emails.slice(0, max)" :key="e" :email="e" size="xs" />
    <span v-if="count > max" class="more">+{{ count - max }}</span>
  </span>
</template>
