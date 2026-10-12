<script setup>
import { computed, nextTick, ref } from 'vue';
import { useI18n } from '@/i18n';
import AppAvatar from '../ui/AppAvatar.vue';
import { usePeopleStore } from '../../stores/people';
import { activeMentionQuery, isEmail, normEmail } from '../../services/mentions';

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '' },
  rows: { type: Number, default: 5 },
  inputId: { type: String, default: undefined },
  inputClass: { type: String, default: 'textarea' },
});
const emit = defineEmits(['update:modelValue', 'submit']);
const { t } = useI18n();
const people = usePeopleStore();

const ta = ref(null);
const query = ref(null); // { query, start, end }
const active = ref(0);

const options = computed(() => {
  if (!query.value) return [];
  const q = query.value.query.toLowerCase();
  const list = people.sorted
    .filter((c) => !q || c.name.toLowerCase().includes(q) || c.email.includes(q))
    .slice(0, 6)
    .map((c) => ({ email: c.email, name: c.name }));
  if (isEmail(q) && !list.some((o) => o.email === normEmail(q))) list.push({ email: normEmail(q), name: normEmail(q), raw: true });
  return list;
});

function sync() {
  const el = ta.value;
  query.value = el ? activeMentionQuery(el.value, el.selectionStart) : null;
  active.value = 0;
}
function onInput(e) {
  emit('update:modelValue', e.target.value);
  sync();
}
async function choose(opt) {
  const q = query.value;
  if (!q) return;
  const text = props.modelValue;
  const insert = `@${opt.email} `;
  const next = text.slice(0, q.start) + insert + text.slice(q.end);
  emit('update:modelValue', next);
  query.value = null;
  await nextTick();
  const pos = q.start + insert.length;
  ta.value.focus();
  ta.value.setSelectionRange(pos, pos);
}
function onKey(e) {
  if (e.isComposing) return;
  if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') { e.preventDefault(); emit('submit'); return; }
  if (!options.value.length) return;
  if (e.key === 'ArrowDown') { e.preventDefault(); active.value = (active.value + 1) % options.value.length; }
  else if (e.key === 'ArrowUp') { e.preventDefault(); active.value = (active.value - 1 + options.value.length) % options.value.length; }
  else if (e.key === 'Enter' || e.key === 'Tab') { e.preventDefault(); choose(options.value[active.value]); }
  else if (e.key === 'Escape') { e.preventDefault(); query.value = null; }
}
defineExpose({ focus: () => ta.value?.focus() });
</script>

<template>
  <div class="mention-wrap">
    <textarea
      :id="inputId" ref="ta" :class="inputClass" :rows="rows" :value="modelValue" :placeholder="placeholder"
      role="combobox" aria-autocomplete="list" :aria-expanded="options.length > 0" aria-haspopup="listbox"
      @input="onInput" @keydown="onKey" @keyup="(e) => ['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(e.key) && sync()" @click="sync" @blur="query = null"
    />
    <ul v-if="options.length" class="mention-pop" role="listbox" @mousedown.prevent>
      <li v-for="(o, i) in options" :key="o.email" role="option" :aria-selected="i === active" :class="{ on: i === active }" @mouseenter="active = i" @click="choose(o)">
        <AppAvatar :email="o.email" :name="o.raw ? undefined : o.name" size="sm" />
        <span class="who"><b>{{ o.raw ? t('mention.use', { email: o.email }) : o.name }}</b><span v-if="!o.raw">{{ o.email }}</span></span>
      </li>
    </ul>
    <p v-else-if="query && !people.sorted.length" class="hint mention-tip">{{ t('mention.empty') }}</p>
  </div>
</template>

<style scoped>
.mention-wrap { position: relative; }
.mention-pop { position: absolute; z-index: 20; inset-inline-start: 0; top: 100%; margin: 6px 0 0; padding: 6px; list-style: none; min-width: min(320px, 100%); border-radius: 16px; background: var(--surface); border: 1px solid var(--line); box-shadow: 0 18px 40px -16px rgba(0,0,0,.35); animation: fade .12s; }
.mention-pop li { display: flex; align-items: center; gap: 10px; padding: 8px 10px; border-radius: 12px; cursor: pointer; }
.mention-pop li.on { background: var(--sunken); }
.who { display: flex; flex-direction: column; line-height: 1.3; min-width: 0; }
.who b { font-weight: 600; font-size: 14.5px; }
.who span { font-size: 12.5px; color: var(--muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.mention-tip { position: absolute; top: 100%; margin-top: 6px; }
</style>
