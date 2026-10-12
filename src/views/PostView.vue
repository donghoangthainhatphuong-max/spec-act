<script setup>
import { computed, nextTick, onBeforeUnmount, onMounted, ref } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useI18n } from '@/i18n';
import AppAvatar from '../components/ui/AppAvatar.vue';
import AppIcon from '../components/ui/AppIcon.vue';
import PostCard from '../components/post/PostCard.vue';
import RichText from '../components/post/RichText.vue';
import AudienceRow from '../components/post/AudienceRow.vue';
import { usePostsStore } from '../stores/posts';
import { usePeopleStore } from '../stores/people';
import { useSessionStore } from '../stores/session';
import { useUiStore } from '../stores/ui';
import { ago } from '../i18n';
import { isEmail, normEmail } from '../services/mentions';

const props = defineProps({ id: { type: String, required: true } });
const { t } = useI18n();
const route = useRoute();
const router = useRouter();
const posts = usePostsStore();
const people = usePeopleStore();
const session = useSessionStore();
const ui = useUiStore();

const state = ref('loading'); // loading | ok | forbidden | not-found | error
const menu = ref(null);
const audience = ref({});
const linkShare = ref(false);
const busy = ref(false);
const comment = ref('');
const sending = ref(false);
const newEmail = ref('');
const newPassword = ref('');
const changingPw = ref(false);

const post = computed(() => posts.full[props.id]);
const mine = computed(() => post.value?.mine);
const unlocked = computed(() => post.value && !post.value.locked);
const canComment = computed(() => unlocked.value && (mine.value || post.value.role === 'comment'));
const soc = computed(() => posts.social[props.id]);
const comments = computed(() => soc.value?.comments || []);
const others = computed(() => people.sorted.filter((c) => !audience.value[c.email]));

async function load() {
  state.value = 'loading';
  try {
    const p = await posts.open(props.id, { fresh: true });
    audience.value = { ...p.audience };
    linkShare.value = p.linkShare;
    state.value = 'ok';
    if (!p.locked) posts.loadSocial(props.id, { fresh: true }).catch(() => {});
    if (p.mine && session.mode === 'drive') {
      session.repo.readAudience(p).then((a) => { audience.value = a.audience; linkShare.value = a.linkShare; }).catch(() => {});
    }
    await nextTick();
    if (route.hash) document.querySelector(route.hash)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
  } catch (e) {
    state.value = e.code === 'forbidden' ? 'forbidden' : e.code === 'not-found' ? 'not-found' : e.code === 'not-a-post' ? 'not-found' : 'error';
  }
}
const closeMenu = () => { menu.value = null; };
const onEsc = (e) => { if (e.key === 'Escape') closeMenu(); };
onMounted(() => { load(); document.addEventListener('click', closeMenu); document.addEventListener('keydown', onEsc); });
onBeforeUnmount(() => { document.removeEventListener('click', closeMenu); document.removeEventListener('keydown', onEsc); });

async function onUnlocked() {
  audience.value = { ...post.value.audience };
  posts.loadSocial(props.id, { fresh: true }).catch(() => {});
}

/* ---- sharing ---- */
async function setAccess(email, role) {
  if (busy.value) return;
  const before = { ...audience.value };
  busy.value = true;
  if (role) audience.value = { ...audience.value, [email]: role }; else { const { [email]: _x, ...rest } = audience.value; audience.value = rest; }
  try {
    const res = await posts.setAccess(post.value, email, role);
    if (role && !before[email]) { ui.flash(email); ui.toast(t('toast.shared', { name: people.nameFor(email) })); }
    else if (!role) ui.toast(t('toast.removed', { name: people.nameFor(email) }));
    if (res.warnings.length) ui.toast(t('toast.shareFailed', { name: people.nameFor(res.warnings[0].email) }), { kind: 'error' });
  } catch {
    audience.value = before;
    ui.toast(t('error.generic'), { kind: 'error' });
  } finally { busy.value = false; }
}
async function addByEmail() {
  const e = normEmail(newEmail.value);
  if (!isEmail(e)) { ui.toast(t('friends.invalid'), { kind: 'error' }); return; }
  if (people.isMe(e)) return;
  newEmail.value = '';
  if (!people.isContact(e)) await people.add(e).catch(() => {});
  await setAccess(e, 'view');
}
async function toggleLink() {
  if (busy.value) return;
  busy.value = true;
  const next = !linkShare.value;
  linkShare.value = next;
  try { await posts.setLinkShare(post.value, next); ui.toast(next ? t('toast.linkOn') : t('toast.linkOff')); }
  catch { linkShare.value = !next; ui.toast(t('error.generic'), { kind: 'error' }); }
  finally { busy.value = false; }
}
async function savePassword() {
  if (newPassword.value.length < 6) { ui.toast(t('compose.passwordShort'), { kind: 'error' }); return; }
  busy.value = true;
  try {
    await posts.update(post.value, { newPassword: newPassword.value, keepMedia: post.value.media.map((m) => m.id), files: [] });
    newPassword.value = ''; changingPw.value = false;
    ui.toast(t('toast.passwordChanged'));
  } catch { ui.toast(t('error.generic'), { kind: 'error' }); }
  finally { busy.value = false; }
}

/* ---- comments ---- */
async function send() {
  const v = comment.value.trim();
  if (!v || sending.value) return;
  sending.value = true;
  try { await posts.addComment(props.id, v); comment.value = ''; }
  catch (e) { ui.toast(e.code === 'forbidden' ? t('comments.viewOnly') : t('error.generic'), { kind: 'error' }); }
  finally { sending.value = false; await nextTick(); document.getElementById(`c-${props.id}`)?.focus(); }
}
async function removeComment(c) {
  if (!(await ui.confirm({ text: t('comments.deleteConfirm'), yes: t('post.delete') }))) return;
  try { await posts.removeComment(props.id, c.id); } catch { ui.toast(t('error.generic'), { kind: 'error' }); }
}
async function forget() {
  if (!(await ui.confirm({ text: t('post.forgetConfirm'), yes: t('post.forget'), danger: false }))) return;
  await posts.forgetShared(props.id).catch(() => {});
  router.replace({ name: 'home' });
}
const inIndex = computed(() => !!posts.entryById(props.id));
</script>

<template>
  <RouterLink class="btn ghost back" :to="{ name: 'home' }"><AppIcon name="back" :size="18" />{{ t('post.back') }}</RouterLink>

  <div v-if="state === 'loading'" class="post skeleton-detail" aria-busy="true"><i class="sk" /><i class="sk w" /><i class="sk img" /></div>

  <div v-else-if="state !== 'ok'" class="empty">
    <AppIcon :name="state === 'forbidden' ? 'lock' : 'alert'" :size="30" />
    <p>{{ state === 'forbidden' ? t('post.forbidden') : state === 'not-found' ? t('post.notFound') : t('error.generic') }}</p>
    <div class="footer-actions">
      <button v-if="inIndex" class="btn" @click="forget">{{ t('post.forget') }}</button>
      <button class="btn primary" @click="load">{{ t('error.retry') }}</button>
    </div>
  </div>

  <template v-else>
    <PostCard :post="post" detail :menu-open="menu === post.id" @menu="(v) => (menu = v)" @unlocked="onUnlocked" />

    <section id="who" class="section" :aria-label="t('post.whoCanSee')">
      <h2>{{ t('post.whoCanSee') }}</h2>
      <template v-if="mine">
        <AudienceRow v-for="(role, email) in audience" :key="email" :email="email" :role="role" :uid="'d'" :disabled="busy" @role="(r) => setAccess(email, r)" @remove="setAccess(email, null)" />
        <p v-if="!Object.keys(audience).length" class="hint">{{ t('post.onlyYou') }}</p>
        <div v-if="others.length" class="addrow">
          <button v-for="c in others" :key="c.email" class="addchip" :disabled="busy" @click="setAccess(c.email, 'view')"><AppAvatar :email="c.email" size="xs" />{{ c.name }}<AppIcon name="plus" :size="14" /></button>
        </div>
        <form class="add-friend" @submit.prevent="addByEmail">
          <label class="sr" for="share-email">{{ t('friends.email') }}</label>
          <input id="share-email" v-model="newEmail" class="input" type="email" inputmode="email" autocomplete="off" :placeholder="t('post.shareByEmail')" />
          <button class="btn primary" style="min-height:46px" :disabled="busy || !newEmail"><AppIcon name="plus" :size="18" />{{ t('post.addPerson') }}</button>
        </form>
        <div class="linkrow">
          <div>
            <b>{{ t('post.linkShare') }}</b>
            <p class="hint">{{ post.protected ? t('post.linkShareHintPw') : t('post.linkShareHint') }}</p>
          </div>
          <button class="switch" role="switch" :aria-checked="linkShare" :aria-label="t('post.linkShare')" :disabled="busy" @click="toggleLink"><span /></button>
        </div>
        <div v-if="post.protected && !post.locked" class="linkrow">
          <div><b>{{ t('post.changePassword') }}</b><p class="hint">{{ t('post.changePasswordHint') }}</p></div>
          <button v-if="!changingPw" class="btn sm" @click="changingPw = true">{{ t('post.change') }}</button>
        </div>
        <form v-if="changingPw" class="add-friend" @submit.prevent="savePassword">
          <label class="sr" for="newpw">{{ t('post.password') }}</label>
          <input id="newpw" v-model="newPassword" class="input" type="password" autocomplete="new-password" :placeholder="t('post.newPassword')" />
          <button class="btn primary" style="min-height:46px" :disabled="busy">{{ t('compose.save') }}</button>
        </form>
      </template>
      <template v-else>
        <p class="hint">{{ t('post.ownerOnly', { name: people.nameFor(post.owner.email) }) }}</p>
        <button v-if="inIndex" class="btn sm forget" @click="forget">{{ t('post.forget') }}</button>
      </template>
    </section>

    <section v-if="unlocked" id="comments" class="section" :aria-label="t('comments.title')">
      <h2>{{ t('comments.title') }}</h2>
      <div v-for="c in comments" :key="c.id" class="comment">
        <AppAvatar :email="c.by" size="sm" />
        <div class="cbody">
          <div class="bubble"><b>{{ people.nameFor(c.by) }}</b><p><RichText :text="c.text" /></p></div>
          <time>{{ ago(c.at) }}</time>
        </div>
        <button v-if="mine || people.isMe(c.by)" class="icon-btn cdel" :aria-label="t('post.delete')" @click="removeComment(c)"><AppIcon name="trash" :size="16" /></button>
      </div>
      <p v-if="soc?.loaded && !comments.length" class="hint">{{ t('comments.empty') }}</p>
      <form v-if="canComment" class="reply" @submit.prevent="send">
        <AppAvatar :email="session.me.email" size="sm" />
        <label class="sr" :for="`c-${id}`">{{ t('comments.placeholder') }}</label>
        <input :id="`c-${id}`" v-model="comment" class="input" :placeholder="t('comments.placeholder')" autocomplete="off" maxlength="2000" />
        <button class="btn primary" :disabled="sending || !comment.trim()">{{ t('comments.send') }}</button>
      </form>
      <p v-else class="hint">{{ t('comments.viewOnly') }}</p>
    </section>
  </template>
</template>

<style scoped>
.add-friend { margin-top: 2px; }
.linkrow { display: flex; align-items: center; justify-content: space-between; gap: 16px; padding-top: 14px; border-top: 1px solid var(--line); }
.linkrow b { font-weight: 600; }
.switch:disabled { opacity: .5; cursor: not-allowed; }
.comment { align-items: flex-start; }
.cbody { flex: 1; min-width: 0; }
.cdel { opacity: 0; width: 32px; height: 32px; }
.comment:hover .cdel, .cdel:focus-visible { opacity: 1; }
@media (hover: none) { .cdel { opacity: .7; } }
.forget { align-self: flex-start; }
.skeleton-detail { padding: 18px; display: flex; flex-direction: column; gap: 12px; }
.sk { display: block; height: 14px; width: 40%; border-radius: 10px; background: var(--sunken); animation: pulse 1.4s ease-in-out infinite; }
.sk.w { width: 90%; } .sk.img { width: 100%; height: 260px; border-radius: 14px; }
@keyframes pulse { 50% { opacity: .55; } }
.empty :deep(svg) { color: var(--muted); }
</style>
