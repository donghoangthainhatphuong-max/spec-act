<script setup>
import { computed } from 'vue';
import { useI18n } from '@/i18n';
import AppIcon from './AppIcon.vue';
import { usePeopleStore } from '../../stores/people';
import { useSessionStore } from '../../stores/session';
import { openChat } from '../../composables/share';

const props = defineProps({ email: { type: String, required: true }, label: { type: Boolean, default: false } });
const { t } = useI18n();
const people = usePeopleStore();
const session = useSessionStore();

// no chat with yourself, and none in demo mode (the people are made up)
const show = computed(() => session.mode === 'drive' && !people.isMe(props.email));
const title = computed(() => t('chat.message', { name: people.nameFor(props.email) }));
</script>

<template>
  <button v-if="show" type="button" class="chat-btn" :class="label ? 'btn sm' : 'icon-btn'" :title="title" :aria-label="title" @click.stop.prevent="openChat(session.me.email, email)">
    <AppIcon name="chat" :size="label ? 16 : 18" /><span v-if="label">{{ t('chat.open') }}</span>
  </button>
</template>
