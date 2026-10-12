<script setup>
import { computed, ref } from 'vue';
import { useI18n } from '@/i18n';
import AppAvatar from '../components/ui/AppAvatar.vue';
import ChatButton from '../components/ui/ChatButton.vue';
import AppIcon from '../components/ui/AppIcon.vue';
import SecureImage from '../components/ui/SecureImage.vue';
import { usePeopleStore } from '../stores/people';
import { usePostsStore } from '../stores/posts';
import { useUiStore } from '../stores/ui';
import { isEmail, normEmail } from '../services/mentions';

const { t } = useI18n();
const people = usePeopleStore();
const posts = usePostsStore();
const ui = useUiStore();

const email = ref('');
const name = ref('');
const busy = ref(false);

const cards = computed(() => people.sorted.map((c) => {
  const ps = posts.mine.filter((p) => p.audience?.[c.email]);
  const withPhotos = ps.filter((p) => p.media?.length && !p.protected);
  return { ...c, n: ps.length, shots: withPhotos.slice(0, 3) };
}));
const suggestions = computed(() => {
  const seen = new Set();
  return posts.shared.map((p) => p.owner).filter((o) => !people.isContact(o.email) && !people.isMe(o.email) && !seen.has(o.email) && seen.add(o.email));
});

async function add(addr = email.value, nm = name.value) {
  const e = normEmail(addr);
  if (!isEmail(e)) { ui.toast(t('friends.invalid'), { kind: 'error' }); return; }
  if (people.isMe(e)) { ui.toast(t('friends.self'), { kind: 'error' }); return; }
  busy.value = true;
  try {
    const c = await people.add(e, nm);
    email.value = ''; name.value = '';
    ui.toast(t('toast.friendAdded', { name: c.name }));
  } catch { ui.toast(t('error.generic'), { kind: 'error' }); } finally { busy.value = false; }
}
async function remove(c) {
  if (!(await ui.confirm({ text: t('friends.removeConfirm', { name: c.name }), yes: t('friends.remove'), danger: false }))) return;
  try { await people.remove(c.email); } catch { ui.toast(t('error.generic'), { kind: 'error' }); }
}
</script>

<template>
  <h1 class="page-title">{{ t('friends.title') }}</h1>
  <p class="page-sub">{{ t('friends.sub') }}</p>

  <form class="add-friend" @submit.prevent="add()">
    <label class="sr" for="fe">{{ t('friends.email') }}</label>
    <input id="fe" v-model="email" class="input" type="email" inputmode="email" :placeholder="t('friends.email')" required autocomplete="off" />
    <label class="sr" for="fn">{{ t('friends.name') }}</label>
    <input id="fn" v-model="name" class="input name" :placeholder="t('friends.nameOptional')" autocomplete="off" />
    <button class="btn primary" style="min-height:46px" :disabled="busy"><AppIcon name="plus" :size="18" />{{ t('friends.add') }}</button>
  </form>

  <section v-if="suggestions.length" class="section">
    <h2>{{ t('friends.suggested') }}</h2>
    <div class="person" v-for="o in suggestions" :key="o.email">
      <AppAvatar :email="o.email" :name="o.name" size="sm" />
      <div class="who"><b>{{ o.name || people.nameFor(o.email) }}</b><span>{{ o.email }}</span></div>
      <button class="btn sm" @click="add(o.email, o.name)"><AppIcon name="plus" :size="16" />{{ t('friends.add') }}</button>
    </div>
  </section>

  <div v-if="cards.length" class="fgrid">
    <article v-for="c in cards" :key="c.email" class="fcard">
      <div class="top-row">
        <AppAvatar :email="c.email" :name="c.name" size="xl" />
        <div class="who"><b>{{ c.name }}</b><span>{{ c.email }}</span></div>
 <ChatButton :email="c.email" />
        <button class="icon-btn" :aria-label="`${t('friends.remove')} ${c.name}`" :title="t('friends.remove')" @click="remove(c)"><AppIcon name="x" :size="18" /></button>
      </div>
      <div class="sees">
        <span>{{ c.n === 0 ? t('friends.seesNone') : c.n === 1 ? t('friends.sees1') : t('friends.sees', { n: c.n }) }}</span>
        <span v-if="c.shots.length" class="mini-photos"><span v-for="p in c.shots" :key="p.id" class="mini"><SecureImage :post="p" :item="p.media[0]" thumb /></span></span>
      </div>
    </article>
  </div>
  <div v-else class="empty"><p>{{ t('friends.empty') }}</p></div>
</template>

<style scoped>
.add-friend { flex-wrap: wrap; }
.add-friend .input { flex: 1 1 200px; }
.add-friend .input.name { flex: 0 1 180px; }
.mini-photos { display: flex; }
.mini { width: 30px; height: 30px; border-radius: 8px; overflow: hidden; box-shadow: 0 0 0 2px var(--surface); display: block; }
.mini + .mini { margin-inline-start: -8px; }
</style>
