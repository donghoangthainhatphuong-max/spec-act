<script setup>
import { computed } from 'vue';
import { useRoute } from 'vue-router';
import { useI18n } from '@/i18n';
import OrbitGraphic from '../ui/OrbitGraphic.vue';
import SecureImage from '../ui/SecureImage.vue';
import AppIcon from '../ui/AppIcon.vue';
import DriveCard from './DriveCard.vue';
import { usePostsStore } from '../../stores/posts';
import { usePeopleStore } from '../../stores/people';
import { useDraftStore } from '../../stores/draft';
import { useSessionStore } from '../../stores/session';
import { useUiStore } from '../../stores/ui';
import { listOf } from '../../i18n';

const { t } = useI18n();
const route = useRoute();
const posts = usePostsStore();
const people = usePeopleStore();
const draft = useDraftStore();
const session = useSessionStore();
const ui = useUiStore();

const kind = computed(() => String(route.name));
const feedLike = computed(() => ['home', 'shared', 'mine'].includes(kind.value));

const shots = computed(() => {
  const list = posts.shared.filter((p) => p.media?.length || p.protected).slice(0, 4);
  return list.length % 2 ? list.slice(0, list.length - 1) : list;
});

const post = computed(() => (kind.value === 'post' ? (posts.full[route.params.id] || posts.entryById(route.params.id)) : null));
const orbit = computed(() => {
  const me = session.me?.email;
  if (kind.value === 'post' && post.value) {
    const aud = Object.keys(post.value.audience || {}).filter((e) => e !== post.value.owner.email);
    const mine = post.value.owner.email === me;
    const others = mine ? people.contacts.filter((c) => !post.value.audience?.[c.email]).map((c) => c.email) : [];
    return {
      center: { email: post.value.owner.email },
      sats: [...aud.map((email) => ({ email, lit: true })), ...others.slice(0, 8).map((email) => ({ email }))],
      caption: aud.length ? t('post.visibleTo', { names: listOf(aud.map((e) => people.nameFor(e))) }) : t('post.onlyYou'),
    };
  }
  if (kind.value === 'new' || kind.value === 'edit') {
    const aud = Object.keys(draft.audience);
    const first = draft.photos.find((p) => p.url && p.type === 'image');
    return {
      center: first ? { src: first.url } : { email: me },
      sats: people.contacts.map((c) => ({ email: c.email, lit: aud.includes(c.email) })),
      caption: aud.length ? t('post.visibleTo', { names: listOf(aud.map((e) => people.nameFor(e))) }) : t('compose.onlyMe'),
    };
  }
  if (kind.value === 'friends') return { center: { email: me }, sats: people.contacts.map((c) => ({ email: c.email, lit: true })), caption: t('friends.sub') };
  return null;
});
</script>

<template>
  <aside class="rail">
    <section v-if="feedLike && shots.length">
      <h2>{{ t('rail.recent') }}</h2>
      <div class="mosaic">
        <RouterLink v-for="p in shots" :key="p.id" :to="{ name: 'post', params: { id: p.id } }" :class="{ locked: p.protected }" :aria-label="people.nameFor(p.owner.email)">
          <SecureImage v-if="!p.protected" :post="p" :item="p.media[0]" thumb />
          <span v-else class="lk lk-solid"><AppIcon name="lock" :size="18" /></span>
        </RouterLink>
      </div>
    </section>
    <section v-if="orbit" class="orbit-card hero-ctx">
      <OrbitGraphic :center="orbit.center" :sats="orbit.sats" :big="false" :fresh="ui.fresh" />
      <p class="cap">{{ orbit.caption }}</p>
    </section>
    <DriveCard />
  </aside>
</template>

<style scoped>
.mosaic a { display: block; }
.lk-solid { background: var(--sunken); color: var(--muted); }
.mosaic a.locked { filter: none; }
</style>
