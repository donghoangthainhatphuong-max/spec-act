<script setup>
import { computed } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from '@/i18n';
import AppIcon from '../ui/AppIcon.vue';
import AppLogo from '../ui/AppLogo.vue';
import BrandName from '../ui/BrandName.vue';
import AppAvatar from '../ui/AppAvatar.vue';
import RightRail from './RightRail.vue';
import { useSessionStore } from '../../stores/session';
import { usePrefsStore } from '../../stores/prefs';
import { usePostsStore } from '../../stores/posts';
import { useUiStore } from '../../stores/ui';

const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const session = useSessionStore();
const prefs = usePrefsStore();
const posts = usePostsStore();
const ui = useUiStore();

const name = computed(() => String(route.name));
const sealedCount = computed(() => posts.shared.filter((p) => p.protected && !posts.hasKey(p.id)).length);
const nav = computed(() => [
  { to: '/', icon: 'home', label: 'nav.home', on: name.value === 'home' },
  { to: '/shared', icon: 'inbox', label: 'nav.shared', on: name.value === 'shared', badge: sealedCount.value },
  { to: '/mine', icon: 'user', label: 'nav.mine', on: name.value === 'mine' },
  { to: '/friends', icon: 'users', label: 'nav.friends', on: name.value === 'friends' },
  { to: '/settings', icon: 'gear', label: 'nav.settings', on: name.value === 'settings' },
]);
const dark = computed(() => prefs.resolvedTheme() === 'dark');

// On a phone the "+" goes straight to the camera; on a computer it opens the composer with the file picker as before.
function newPost() {
  const phone = matchMedia('(pointer: coarse)').matches && innerWidth <= 860;
  router.push(phone ? { name: 'new', query: { camera: '1' } } : { name: 'new' });
}

function onSearch(e) {
  ui.search = e.target.value;
  if (!['home', 'shared', 'mine'].includes(name.value)) router.push('/');
}
</script>

<template>
  <header class="top">
    <RouterLink class="brand" to="/"><AppLogo :size="26" /><BrandName /></RouterLink>
    <span class="grow" />
    <span v-if="session.mode === 'demo'" class="demo-chip">{{ t('demo.badge') }}</span>
    <button class="icon-btn" :aria-label="t('theme.toggle')" :title="t('theme.toggle')" @click="prefs.toggleTheme()"><AppIcon :name="dark ? 'sun' : 'moon'" :size="20" /></button>
    <RouterLink to="/settings" :aria-label="t('nav.settings')" style="margin-inline-start:4px"><AppAvatar :email="session.me.email" size="sm" /></RouterLink>
  </header>
  <div class="app">
    <aside class="side">
      <RouterLink class="brand" to="/"><AppLogo :size="28" /><BrandName /></RouterLink>
      <label class="search">
        <AppIcon name="search" :size="18" /><span class="sr">{{ t('search') }}</span>
        <input type="search" :value="ui.search" :placeholder="t('search')" autocomplete="off" @input="onSearch" />
      </label>
      <nav class="nav" aria-label="Menu">
        <RouterLink v-for="n in nav" :key="n.to" :to="n.to" :class="{ on: n.on }" :aria-current="n.on ? 'page' : undefined">
          <AppIcon :name="n.icon" :size="22" /><span>{{ t(n.label) }}</span><span v-if="n.badge" class="badge" :title="t('nav.sealedBadge')">{{ n.badge }}</span>
        </RouterLink>
      </nav>
      <RouterLink to="/new" class="btn primary lg new"><AppIcon name="plus" :size="20" />{{ t('nav.new') }}</RouterLink>
      <span class="grow" />
      <div class="me-row">
        <AppAvatar :email="session.me.email" />
        <div class="who"><b>{{ session.me.name }}</b><span>{{ session.me.email }}</span></div>
        <button v-if="session.mode === 'drive'" class="icon-btn" :aria-label="t('settings.lockNow')" :title="t('settings.lockNow')" @click="session.lock()"><AppIcon name="lock" :size="19" /></button>
        <button class="icon-btn" :aria-label="t('theme.toggle')" :title="t('theme.toggle')" @click="prefs.toggleTheme()"><AppIcon :name="dark ? 'sun' : 'moon'" :size="20" /></button>
      </div>
    </aside>
    <main id="main">
      <div v-if="session.mode === 'demo'" class="banner demo">
        <AppIcon name="info" :size="18" /><span>{{ t('demo.banner') }}</span>
        <button class="btn sm" @click="session.leaveDemo().then(() => router.replace('/welcome'))">{{ t('demo.exit') }}</button>
      </div>
      <div v-else-if="session.offline" class="banner warn"><AppIcon name="alert" :size="18" /><span>{{ t('banner.offline') }}</span></div>
      <RouterView v-slot="{ Component, route: r }">
        <component :is="Component" :key="r.name === 'post' || r.name === 'edit' ? r.fullPath.split('#')[0] : r.name" />
      </RouterView>
    </main>
    <RightRail />
  </div>
  <nav class="tabbar" aria-label="Menu">
    <RouterLink to="/" :class="{ on: name === 'home' }"><AppIcon name="home" :size="22" />{{ t('nav.home') }}</RouterLink>
    <RouterLink to="/shared" :class="{ on: name === 'shared' }"><AppIcon name="inbox" :size="22" />{{ t('nav.sharedShort') }}</RouterLink>
    <RouterLink to="/new" class="plus" :aria-label="t('nav.new')" @click.prevent="newPost"><AppIcon name="plus" :size="24" /></RouterLink>
    <RouterLink to="/friends" :class="{ on: name === 'friends' }"><AppIcon name="users" :size="22" />{{ t('nav.friends') }}</RouterLink>
    <RouterLink to="/settings" :class="{ on: name === 'settings' }"><AppIcon name="gear" :size="22" />{{ t('nav.settings') }}</RouterLink>
  </nav>
</template>

<style scoped>
.banner { display: flex; align-items: center; gap: 10px; padding: 10px 14px; border-radius: 16px; font-size: 14px; }
.banner span { flex: 1; }
.banner.demo { background: var(--accent-soft); color: var(--text); }
.banner.warn { background: color-mix(in srgb, var(--danger) 10%, var(--surface)); color: var(--text); }
.demo-chip { font-size: 11.5px; font-weight: 650; letter-spacing: .04em; text-transform: uppercase; padding: 3px 8px; border-radius: 999px; background: var(--accent-soft); color: var(--accent); }
</style>
