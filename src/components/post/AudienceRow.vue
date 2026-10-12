<script setup>
import { useI18n } from '@/i18n';
import AppAvatar from '../ui/AppAvatar.vue';
import ChatButton from '../ui/ChatButton.vue';
import AppIcon from '../ui/AppIcon.vue';
import { usePeopleStore } from '../../stores/people';

defineProps({
  email: { type: String, required: true },
  role: { type: String, default: 'view' },
  removable: { type: Boolean, default: true },
  viaMention: { type: Boolean, default: false },
  disabled: { type: Boolean, default: false },
  uid: { type: String, default: '' },
});
const emit = defineEmits(['role', 'remove']);
const { t } = useI18n();
const people = usePeopleStore();
</script>

<template>
  <div class="person">
    <AppAvatar :email="email" size="sm" />
    <div class="who">
      <b>{{ people.nameFor(email) }}<small v-if="viaMention" class="via"><AppIcon name="at" :size="12" />{{ t('compose.viaMention') }}</small></b>
      <span>{{ email }}</span>
    </div>
    <ChatButton :email="email" />
    <label class="sr" :for="`role-${uid}-${email}`">{{ t('post.access') }}</label>
    <select :id="`role-${uid}-${email}`" class="select sm" :value="role" :disabled="disabled" @change="emit('role', $event.target.value)">
      <option value="view">{{ t('post.canView') }}</option>
      <option value="comment">{{ t('post.canComment') }}</option>
    </select>
    <button v-if="removable" class="icon-btn" type="button" :disabled="disabled" :aria-label="`${t('post.remove')} ${people.nameFor(email)}`" @click="emit('remove')"><AppIcon name="x" :size="18" /></button>
  </div>
</template>

<style scoped>
.via { display: inline-flex; align-items: center; gap: 3px; margin-inline-start: 8px; font-size: 11.5px; font-weight: 550; color: var(--accent); background: var(--accent-soft); padding: 1px 7px; border-radius: 999px; vertical-align: 1px; }
</style>
