import { createRouter, createWebHashHistory } from 'vue-router';
import { config } from '../config';
import { useSessionStore } from '../stores/session';
import { useUiStore } from '../stores/ui';


const routes = [
  {
    path: '/demo', name: 'demo', meta: { public: true }, component: () => import('../views/NotFoundView.vue'),
    async beforeEnter() {
      const session = useSessionStore();
      await session.ready;
      if (!config.enableDemo) return { name: 'welcome' };
      if (session.phase === 'ready' && session.mode === 'drive') return { name: 'home' };
      if (session.phase !== 'ready') await session.enterDemo();
      return { name: 'home' };
    },
  },
  { path: '/about', name: 'about', component: () => import('../views/LegalView.vue'), props: { page: 'about' }, meta: { public: true, legal: true } },
  { path: '/terms', name: 'terms', component: () => import('../views/LegalView.vue'), props: { page: 'terms' }, meta: { public: true, legal: true } },
  { path: '/privacy', name: 'privacy', component: () => import('../views/LegalView.vue'), props: { page: 'privacy' }, meta: { public: true, legal: true } },
  { path: '/welcome', name: 'welcome', component: () => import('../views/WelcomeView.vue'), meta: { public: true } },
  { path: '/', name: 'home', component: () => import('../views/FeedView.vue'), props: { kind: 'home' }, meta: { shell: true } },
  { path: '/shared', name: 'shared', component: () => import('../views/FeedView.vue'), props: { kind: 'shared' }, meta: { shell: true } },
  { path: '/mine', name: 'mine', component: () => import('../views/FeedView.vue'), props: { kind: 'mine' }, meta: { shell: true } },
  { path: '/post/:id', name: 'post', component: () => import('../views/PostView.vue'), props: true, meta: { shell: true } },
  { path: '/new', name: 'new', component: () => import('../views/ComposeView.vue'), meta: { shell: true } },
  { path: '/edit/:id', name: 'edit', component: () => import('../views/ComposeView.vue'), props: true, meta: { shell: true } },
  { path: '/friends', name: 'friends', component: () => import('../views/FriendsView.vue'), meta: { shell: true } },
  { path: '/settings', name: 'settings', component: () => import('../views/SettingsView.vue'), meta: { shell: true } },
  { path: '/:pathMatch(.*)*', name: 'notfound', component: () => import('../views/NotFoundView.vue'), meta: { shell: true } },
];

export const router = createRouter({
  history: createWebHashHistory(config.basePath),
  routes,
  scrollBehavior(to, from, saved) {
    if (saved) return saved;
    if (to.hash) return { el: to.hash, behavior: 'smooth', top: 80 };
    return { top: 0 };
  },
});

router.beforeEach(async (to) => {
  const session = useSessionStore();
  await session.ready;
  if (to.meta.public) return true;
  if (session.phase !== 'ready') return { name: 'welcome', query: to.fullPath !== '/' ? { next: to.fullPath } : {} };
  return true;
});

router.afterEach(() => { useUiStore().closeViewer(); });
