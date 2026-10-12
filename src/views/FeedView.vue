<script setup>
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { useI18n } from '@/i18n';
import AppAvatar from '../components/ui/AppAvatar.vue';
import AppIcon from '../components/ui/AppIcon.vue';
import PostCard from '../components/post/PostCard.vue';
import { usePostsStore } from '../stores/posts';
import { usePeopleStore } from '../stores/people';
import { useSessionStore } from '../stores/session';
import { useUiStore } from '../stores/ui';
import { currentLocale, ago } from '../i18n';
import { plainMentions } from '../composables/format';

const props = defineProps({ kind: { type: String, default: 'home' } });
const { t } = useI18n();
const posts = usePostsStore();
const people = usePeopleStore();
const session = useSessionStore();
const ui = useUiStore();

const who = ref(null);
const menu = ref(null);
const visible = ref(12);
const sentinel = ref(null);
let observer;

const H = 3600e3;
const base = computed(() => (props.kind === 'shared' ? posts.shared : props.kind === 'mine' ? posts.mine : posts.feed));
const list = computed(() => {
  let l = base.value;
  if (props.kind === 'home' && who.value) l = l.filter((p) => p.owner.email === who.value);
  const q = ui.search.trim().toLowerCase();
  if (q) l = l.filter((p) => `${people.nameFor(p.owner.email)} ${p.protected ? '' : plainMentions(p.text, people.nameFor)}`.toLowerCase().includes(q));
  return l;
});
const shown = computed(() => list.value.slice(0, visible.value));

const strip = computed(() => {
  const seen = new Set();
  const out = [];
  const push = (email) => { if (email && !seen.has(email) && !people.isMe(email)) { seen.add(email); out.push(email); } };
  posts.shared.forEach((p) => push(p.owner.email));
  people.sorted.forEach((c) => push(c.email));
  return out.map((email) => ({ email, fresh: posts.shared.some((p) => p.owner.email === email && Date.now() - p.createdAt < 24 * H) }));
});

const greeting = computed(() => {
  const h = new Date().getHours();
  return t(h < 11 ? 'home.morning' : h < 18 ? 'home.afternoon' : 'home.evening', { name: session.me.name });
});
const dateText = computed(() => {
  try { return new Intl.DateTimeFormat(currentLocale(), { weekday: 'long', day: 'numeric', month: 'long' }).format(new Date()); } catch { return ''; }
});
const title = computed(() => ({ shared: t('nav.shared'), mine: t('nav.mine') })[props.kind]);
const emptyMsg = computed(() => (ui.search ? t('feed.noResults') : props.kind === 'mine' ? t('feed.emptyMine') : props.kind === 'shared' ? t('feed.emptyShared') : t('feed.empty')));
const syncText = computed(() => {
  if (posts.syncing) return t('feed.syncing');
  return posts.syncedAt && session.mode === 'drive' ? t('feed.updated', { when: ago(posts.syncedAt) }) : '';
});

function closeMenu() { menu.value = null; }
onMounted(() => {
  document.addEventListener('click', closeMenu);
  if (!('IntersectionObserver' in window)) { visible.value = 9999; return; }
  observer = new IntersectionObserver((e) => { if (e.some((x) => x.isIntersecting)) visible.value += 12; }, { rootMargin: '600px' });
  watch(sentinel, (el, old) => { if (old) observer.unobserve(old); if (el) observer.observe(el); }, { immediate: true });
});
onBeforeUnmount(() => { document.removeEventListener('click', closeMenu); observer?.disconnect(); });
watch(() => [props.kind, ui.search, who.value], () => { visible.value = 12; });
</script>

<template>
  <div class="hello" v-if="kind === 'home'">
    <h1>{{ greeting }}</h1>
    <p>{{ dateText }}</p>
  </div>
  <h1 v-else class="page-title">{{ title }}</h1>

  <div v-if="kind === 'home' && strip.length" class="strip" role="group" :aria-label="t('feed.people')">
    <button v-for="s in strip" :key="s.email" class="story" :class="{ fresh: s.fresh, on: who === s.email }" :aria-pressed="who === s.email" @click="who = who === s.email ? null : s.email">
      <AppAvatar :email="s.email" size="xl" /><span>{{ people.nameFor(s.email) }}</span>
    </button>
    <RouterLink class="story add" to="/friends"><span class="avatar xl" aria-hidden="true"><AppIcon name="plus" :size="22" /></span><span>{{ t('friends.add') }}</span></RouterLink>
  </div>

  <RouterLink v-if="kind !== 'shared'" class="composer" to="/new">
    <AppAvatar :email="session.me.email" /><span class="prompt">{{ t('feed.prompt') }}</span><span class="ico"><AppIcon name="image" :size="20" /></span>
  </RouterLink>

  <nav class="tabs only-mobile" :aria-label="t('nav.home')">
    <RouterLink to="/" :class="{ on: kind === 'home' }">{{ t('feed.all') }}</RouterLink>
    <RouterLink to="/shared" :class="{ on: kind === 'shared' }">{{ t('nav.sharedShort') }}</RouterLink>
    <RouterLink to="/mine" :class="{ on: kind === 'mine' }">{{ t('nav.mine') }}</RouterLink>
  </nav>

  <label class="search only-mobile">
    <AppIcon name="search" :size="18" /><span class="sr">{{ t('search') }}</span>
    <input v-model="ui.search" type="search" :placeholder="t('search')" autocomplete="off" />
  </label>

  <div v-if="kind === 'home' && who" class="filter-chip">
    <AppAvatar :email="who" size="sm" /><span>{{ t('feed.from', { name: people.nameFor(who) }) }}</span>
    <button class="icon-btn" :aria-label="t('feed.clear')" @click="who = null"><AppIcon name="x" :size="16" /></button>
  </div>

  <div v-if="session.mode === 'drive'" class="syncbar">
    <span class="hint" aria-live="polite">{{ syncText }}</span>
    <button class="icon-btn" :class="{ spin: posts.syncing }" :aria-label="t('feed.refresh')" :title="t('feed.refresh')" :disabled="posts.syncing" @click="posts.sync()"><AppIcon name="refresh" :size="18" /></button>
  </div>
  <p v-if="posts.error && !posts.syncing" class="alert-line" role="alert"><AppIcon name="alert" :size="16" />{{ posts.error.status === 0 ? t('banner.offline') : t('error.sync') }}</p>

  <template v-if="posts.loading">
    <div v-for="i in 2" :key="i" class="post skeleton" aria-hidden="true"><div class="sk-head"><i class="sk av" /><i class="sk l1" /></div><i class="sk l2" /><i class="sk l3" /><i class="sk img" /></div>
  </template>
  <template v-else-if="shown.length">
    <PostCard v-for="p in shown" :key="p.id" :post="p" :menu-open="menu === p.id" @menu="(v) => (menu = v)" />
    <div v-if="visible < list.length" ref="sentinel" class="more-sentinel"><button class="btn" @click="visible += 12">{{ t('feed.more') }}</button></div>
  </template>
  <div v-else class="empty">
    <p>{{ emptyMsg }}</p>
    <RouterLink v-if="kind === 'mine' && !ui.search" class="btn primary" to="/new"><AppIcon name="plus" :size="18" />{{ t('nav.new') }}</RouterLink>
  </div>
</template>

<style scoped>
.syncbar { display: flex; align-items: center; justify-content: space-between; margin: -8px 0 -6px; min-height: 28px; }
.syncbar .icon-btn { width: 32px; height: 32px; }
.spin :deep(svg) { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.alert-line { display: flex; align-items: center; gap: 8px; color: var(--danger); font-size: 14px; }
.more-sentinel { display: flex; justify-content: center; padding: 8px; }
.skeleton { padding: 18px; display: flex; flex-direction: column; gap: 12px; }
.sk-head { display: flex; gap: 12px; align-items: center; }
.sk { display: block; border-radius: 10px; background: var(--sunken); animation: pulse 1.4s ease-in-out infinite; }
.sk.av { width: 40px; height: 40px; border-radius: 50%; }
.sk.l1 { width: 40%; height: 14px; } .sk.l2 { width: 90%; height: 14px; } .sk.l3 { width: 65%; height: 14px; }
.sk.img { width: 100%; height: 220px; border-radius: 14px; }
@keyframes pulse { 50% { opacity: .55; } }
</style>
