<script setup>
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { useI18n } from '@/i18n';
import { useRouter } from 'vue-router';
import AppAvatar from '../ui/AppAvatar.vue';
import AppIcon from '../ui/AppIcon.vue';
import AvatarPile from '../ui/AvatarPile.vue';
import RichText from './RichText.vue';
import PhotoGrid from './PhotoGrid.vue';
import SealedBox from './SealedBox.vue';
import { usePostsStore } from '../../stores/posts';
import { usePeopleStore } from '../../stores/people';
import { useSessionStore } from '../../stores/session';
import { useUiStore } from '../../stores/ui';
import { ago, listOf } from '../../i18n';
import { plainMentions } from '../../composables/format';
import { copyText, postLink } from '../../composables/share';

const props = defineProps({
  post: { type: Object, required: true },
  detail: { type: Boolean, default: false },
  menuOpen: { type: Boolean, default: false },
});
const emit = defineEmits(['menu', 'unlocked']);
const { t } = useI18n();
const router = useRouter();
const posts = usePostsStore();
const people = usePeopleStore();
const session = useSessionStore();
const ui = useUiStore();

const el = ref(null);
const popped = ref(false);

// Protected posts show their content in the feed once the key is known on this device.
const view = computed(() => {
  if (props.detail) return props.post;
  const f = posts.full[props.post.id];
  return props.post.protected && f && !f.locked ? f : props.post;
});
// An index entry of a protected post carries no content, so it is sealed until the full post is open.
const locked = computed(() => {
  const v = view.value;
  return !!v.protected && (v.locked === true || v.locked === undefined);
});
const mine = computed(() => people.isMe(view.value.owner.email));
const ownerName = computed(() => people.nameFor(view.value.owner.email));
const audienceEmails = computed(() => Object.keys(view.value.audience || {}).filter((e) => !people.isMe(e) && e !== view.value.owner.email));
const audienceCount = computed(() => view.value.audienceCount ?? audienceEmails.value.length);
const social = computed(() => posts.social[view.value.id]);
const canReact = computed(() => {
  if (locked.value) return false;
  // likes follow who the post is open to (likes.json), not the comment mode
  return !!view.value.ids?.lj;
});
const liked = computed(() => !!social.value?.likes.includes(session.me?.email));
const likeCount = computed(() => social.value?.likes.length || 0);
const commentCount = computed(() => social.value?.comments.length || 0);
const last = computed(() => social.value?.comments[social.value.comments.length - 1]);

const scope = computed(() => {
  if (!mine.value) return { icon: 'inbox', text: t('post.sharedWithYou') };
  const n = audienceCount.value;
  return { icon: 'lock', text: n === 0 ? t('post.onlyYou') : n === 1 ? t('post.people1') : t('post.people', { n }) };
});
const mediaTotal = computed(() => view.value.mediaCount ?? view.value.media.length);

function openPhoto(i) {
  // a feed card only knows its first photos; the detail page has them all
  if (!props.detail && mediaTotal.value > view.value.media.length) { router.push({ name: 'post', params: { id: view.value.id } }); return; }
  ui.openViewer({ post: view.value, items: view.value.media }, i);
}

async function like() {
  if (!canReact.value) return;
  if (!social.value) await posts.loadSocial(view.value.id).catch(() => {});
  try {
    await posts.toggleLike(view.value.id);
    if (liked.value) { popped.value = true; setTimeout(() => { popped.value = false; }, 500); }
  } catch { ui.toast(t('error.generic'), { kind: 'error' }); }
}

function edit() { emit('menu', null); router.push({ name: 'edit', params: { id: view.value.id } }); }
async function remove() {
  emit('menu', null);
  if (!(await ui.confirm({ text: t('post.deleteConfirm'), yes: t('post.delete') }))) return;
  try {
    await posts.remove(view.value);
    ui.toast(t('toast.deleted'));
    if (props.detail) router.replace({ name: 'home' });
  } catch { ui.toast(t('error.generic'), { kind: 'error' }); }
}
async function copyLink() {
  emit('menu', null);
  ui.toast((await copyText(postLink(view.value))) ? t('toast.linkCopied') : t('error.generic'));
}

let observer;
onMounted(() => {
  if (props.detail || !('IntersectionObserver' in window)) return;
  observer = new IntersectionObserver((entries) => {
    if (!entries.some((e) => e.isIntersecting)) return;
    observer.disconnect();
    const p = props.post;
    if (p.protected && posts.hasKey(p.id)) posts.open(p.id).then(() => posts.loadSocial(p.id)).catch(() => {});
    else if (!p.protected) posts.loadSocial(p.id).catch(() => {});
  }, { rootMargin: '300px' });
  observer.observe(el.value);
});
onBeforeUnmount(() => observer?.disconnect());

const ariaPeople = computed(() => listOf(audienceEmails.value.map((e) => people.nameFor(e))));
</script>

<template>
  <article ref="el" class="post" :class="{ detail }">
    <header class="post-head">
      <AppAvatar :email="view.owner.email" />
      <div class="who">
        <span v-if="detail" class="name">{{ ownerName }}</span>
        <RouterLink v-else class="name" :to="{ name: 'post', params: { id: view.id } }">{{ ownerName }}</RouterLink>
        <span class="meta">
          <span>{{ ago(view.createdAt) }}</span>
          <span class="scope"><AppIcon :name="scope.icon" :size="14" />{{ scope.text }}</span>
          <span v-if="view.protected" class="scope" :title="t('post.protected')"><AppIcon name="key" :size="14" /></span>
          <span v-if="view.linkShare" class="scope" :title="t('post.linkOn')"><AppIcon name="link" :size="14" /></span>
        </span>
      </div>
      <AvatarPile :emails="audienceEmails" :total="audienceCount" :aria-label="ariaPeople" />
      <button v-if="mine" class="icon-btn" aria-haspopup="menu" :aria-expanded="menuOpen" :aria-label="t('post.more')" @click.stop="emit('menu', menuOpen ? null : view.id)"><AppIcon name="more" :size="20" /></button>
    </header>
    <div v-if="mine && menuOpen" class="menu" role="menu" @click.stop>
      <button role="menuitem" @click="edit"><AppIcon name="edit" :size="18" />{{ t('post.edit') }}</button>
      <button role="menuitem" @click="copyLink"><AppIcon name="link" :size="18" />{{ t('post.copyLink') }}</button>
      <button role="menuitem" class="danger" @click="remove"><AppIcon name="trash" :size="18" />{{ t('post.delete') }}</button>
    </div>

    <SealedBox v-if="locked" :post="view" @unlocked="emit('unlocked')" />
    <template v-else>
      <p v-if="view.text" class="post-text"><RichText :text="view.text" /><template v-if="view.truncated && !detail"> <RouterLink class="readmore" :to="{ name: 'post', params: { id: view.id } }">{{ t('post.readMore') }}</RouterLink></template></p>
      <PhotoGrid :post="view" :media="view.media" :total="mediaTotal" :detail="detail" @open="openPhoto" />
    </template>

    <div class="actions">
      <button class="btn" :class="{ on: liked, pop: popped }" :disabled="!canReact" :aria-pressed="liked" :aria-label="t('post.like')" :title="canReact ? '' : t('post.likeDisabled')" @click="like">
        <AppIcon name="heart" :size="20" :fill="liked" /><span>{{ likeCount || '' }}</span>
      </button>
      <RouterLink class="btn" :to="{ name: 'post', params: { id: view.id }, hash: '#comments' }" :aria-label="t('post.comment')"><AppIcon name="chat" :size="20" /><span>{{ commentCount || '' }}</span></RouterLink>
      <span class="grow" />
      <button v-if="mine && detail" class="btn" @click="copyLink"><AppIcon name="link" :size="18" />{{ t('post.copyLink') }}</button>
      <RouterLink v-if="mine && !detail" class="btn" :to="{ name: 'post', params: { id: view.id }, hash: '#who' }"><AppIcon name="share" :size="18" />{{ t('post.share') }}</RouterLink>
    </div>

    <div v-if="!detail && !locked && last" class="peek">
      <div class="line"><b>{{ people.nameFor(last.by) }}</b><span>{{ plainMentions(last.text, people.nameFor) }}</span></div>
      <RouterLink v-if="commentCount > 1" :to="{ name: 'post', params: { id: view.id }, hash: '#comments' }">{{ t('post.allComments', { n: commentCount }) }}</RouterLink>
    </div>
  </article>
</template>

<style scoped>
.readmore { color: var(--accent); font-weight: 550; font-family: var(--ui); font-size: .8em; }
.autolink { color: var(--accent); }
.btn:disabled { opacity: .5; cursor: not-allowed; }
.btn:disabled:hover { background: transparent; color: var(--muted); }
</style>
