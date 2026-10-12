<script setup>
import { computed, onMounted, ref } from 'vue';
import { onBeforeRouteLeave, useRouter } from 'vue-router';
import { useI18n } from '@/i18n';
import AppAvatar from '../components/ui/AppAvatar.vue';
import AppIcon from '../components/ui/AppIcon.vue';
import SecureImage from '../components/ui/SecureImage.vue';
import MentionTextarea from '../components/post/MentionTextarea.vue';
import AudienceRow from '../components/post/AudienceRow.vue';
import { useDraftStore } from '../stores/draft';
import { usePeopleStore } from '../stores/people';
import { usePostsStore } from '../stores/posts';
import { useSessionStore } from '../stores/session';
import { useUiStore } from '../stores/ui';
import { config } from '../config';
import { listOf } from '../i18n';
import { isEmail, normEmail } from '../services/mentions';

const props = defineProps({ id: { type: String, default: '' } });
const { t } = useI18n();
const router = useRouter();
const draft = useDraftStore();
const people = usePeopleStore();
const posts = usePostsStore();
const session = useSessionStore();
const ui = useUiStore();

const original = ref(null);
const loading = ref(!!props.id);
const progress = ref(null);
const submitting = ref(false);
const done = ref(false);
const showPw = ref(false);
const fileInput = ref(null);
const textarea = ref(null);
const dragging = ref(false);
const extraEmail = ref('');

const editing = computed(() => !!props.id);
const ids = computed(() => Object.keys(draft.audience));
const line = computed(() => (ids.value.length ? t('post.visibleTo', { names: listOf(ids.value.map((e) => people.nameFor(e))) }) : t('compose.onlyMe')));

onMounted(async () => {
  if (!props.id) {
    if (draft.editing) draft.reset();
    return;
  }
  try {
    const p = await posts.open(props.id, { fresh: true });
    if (!p.mine || p.locked) { router.replace({ name: 'post', params: { id: props.id } }); return; }
    original.value = p;
    draft.loadFrom(p);
  } catch { router.replace({ name: 'home' }); } finally { loading.value = false; }
});

function pick(e) {
  const skipped = draft.addFiles(e.target.files);
  e.target.value = '';
  if (skipped) ui.toast(t('compose.skipped', { n: skipped, max: config.maxImagesPerPost, mb: config.maxImageMb }), { kind: 'error' });
}
function onDrop(e) {
  dragging.value = false;
  const skipped = draft.addFiles(e.dataTransfer?.files || []);
  if (skipped) ui.toast(t('compose.skipped', { n: skipped, max: config.maxImagesPerPost, mb: config.maxImageMb }), { kind: 'error' });
}
function onPaste(e) {
  const files = Array.from(e.clipboardData?.files || []).filter((f) => f.type.startsWith('image/'));
  if (files.length) { e.preventDefault(); draft.addFiles(files); }
}

async function addExtra() {
  const e = normEmail(extraEmail.value);
  if (!isEmail(e)) { ui.toast(t('friends.invalid'), { kind: 'error' }); return; }
  if (people.isMe(e)) return;
  extraEmail.value = '';
  if (!people.isContact(e)) await people.add(e).catch(() => {});
  draft.addEmail(e);
  ui.flash(e);
}
function toggle(email) { const had = email in draft.audience; draft.toggle(email); if (!had) ui.flash(email); }

const stageText = computed(() => {
  const p = progress.value;
  if (!p) return '';
  if (p.stage === 'upload') return t('compose.uploading', { done: p.done + 1, total: p.total });
  if (p.stage === 'share') return t('compose.sharing');
  return t('compose.saving');
});

async function publish() {
  if (submitting.value) return;
  if (!draft.text.trim() && !draft.photos.length) { textarea.value?.focus(); return; }
  const pw = draft.password;
  if (!editing.value && draft.protect && pw.length < 6) { ui.toast(t('compose.passwordShort'), { kind: 'error' }); return; }
  if (editing.value && draft.lockedProtection && pw && pw.length < 6) { ui.toast(t('compose.passwordShort'), { kind: 'error' }); return; }
  submitting.value = true;
  progress.value = { stage: 'prepare' };
  const files = draft.photos.filter((p) => p.kind === 'new').map((p) => p.file);
  try {
    let res;
    if (editing.value) {
      res = await posts.update(original.value, {
        text: draft.text, files, keepMedia: draft.photos.filter((p) => p.kind === 'old').map((p) => p.media.id),
        audience: draft.audience, linkShare: draft.linkShare, commentMode: draft.commentMode, newPassword: pw || undefined,
      }, (p) => { progress.value = p; });
    } else {
      res = await posts.create({ text: draft.text, files, audience: draft.audience, password: draft.protect ? pw : undefined, linkShare: draft.linkShare, commentMode: draft.commentMode }, (p) => { progress.value = p; });
    }
    done.value = true;
    draft.reset();
    ui.toast(editing.value ? t('toast.saved') : t('toast.posted'));
    if (res.warnings?.length) ui.toast(t('toast.shareFailed', { name: res.warnings.map((w) => w.email === '*' ? t('post.linkShare') : people.nameFor(w.email)).join(', ') }), { kind: 'error', ms: 5000 });
    router.push({ name: editing.value ? 'post' : 'mine', params: editing.value ? { id: props.id } : {} });
  } catch (e) {
    ui.toast(e.code === 'too-many-images' ? t('compose.skipped', { n: 1, max: config.maxImagesPerPost, mb: config.maxImageMb }) : e.status === 0 ? t('banner.offline') : t('error.publish'), { kind: 'error', ms: 4500 });
  } finally { submitting.value = false; progress.value = null; }
}

async function cancel() {
  if (draft.dirty && !(await ui.confirm({ text: t('compose.discardConfirm'), yes: t('compose.discard') }))) return;
  done.value = true;
  draft.reset();
  router.push(editing.value ? { name: 'post', params: { id: props.id } } : { name: 'home' });
}

onBeforeRouteLeave(async () => {
  if (done.value || submitting.value || !draft.dirty) return true;
  const ok = await ui.confirm({ text: t('compose.discardConfirm'), yes: t('compose.discard') });
  if (ok) draft.reset();
  return ok;
});
</script>

<template>
  <h1 class="page-title">{{ editing ? t('post.edit') : t('compose.title') }}</h1>

  <div v-if="loading" class="write" aria-busy="true"><div class="ph" /></div>
  <template v-else>
    <form class="write" :class="{ drop: dragging }" @submit.prevent="publish" @dragover.prevent="dragging = true" @dragleave="dragging = false" @drop.prevent="onDrop" @paste="onPaste">
      <div class="person" style="min-height:0">
        <AppAvatar :email="session.me.email" />
        <div class="who"><b>{{ session.me.name }}</b><span class="aud-line" :class="{ has: ids.length }"><AppIcon :name="ids.length ? 'users' : 'lock'" :size="14" />{{ line }}</span></div>
      </div>
      <label class="sr" for="draft">{{ t('compose.placeholder') }}</label>
      <MentionTextarea ref="textarea" v-model="draft.text" input-id="draft" :placeholder="t('compose.placeholder')" @submit="publish" />
      <p class="hint mention-hint"><AppIcon name="at" :size="14" />{{ t('compose.mentionHint') }}</p>
      <div class="thumbs">
        <div v-for="p in draft.photos" :key="p.key" class="thumb">
          <img v-if="p.url" :src="p.url" alt="" />
          <SecureImage v-else :post="original" :item="p.media" thumb eager />
          <button type="button" :aria-label="t('post.remove')" @click="draft.removePhoto(p.key)"><AppIcon name="x" :size="14" /></button>
        </div>
        <button v-if="draft.room > 0" type="button" class="add-photo" @click="fileInput.click()"><AppIcon name="image" :size="24" /><span>{{ t('compose.addPhoto') }}</span></button>
        <input ref="fileInput" class="sr" type="file" accept="image/*" multiple tabindex="-1" @change="pick" />
      </div>
    </form>

    <section class="section">
      <div>
        <h2>{{ t('compose.shareWith') }}</h2>
        <p class="hint" style="margin-top:4px">{{ people.sorted.length ? t('compose.tapToAdd') : t('compose.noFriends') }}</p>
      </div>
      <div v-if="people.sorted.length" class="pickgrid">
        <button v-for="c in people.sorted" :key="c.email" type="button" class="pick" :class="{ on: c.email in draft.audience }" :aria-pressed="c.email in draft.audience" @click="toggle(c.email)">
          <AppAvatar :email="c.email" size="lg" /><span>{{ c.name }}</span><i class="tick"><AppIcon name="check" :size="12" /></i>
        </button>
      </div>
      <form class="add-friend" @submit.prevent="addExtra">
        <label class="sr" for="extra-email">{{ t('friends.email') }}</label>
        <input id="extra-email" v-model="extraEmail" class="input" type="email" inputmode="email" autocomplete="off" :placeholder="t('compose.findFriend')" />
        <button class="btn" style="min-height:46px" :disabled="!extraEmail"><AppIcon name="plus" :size="18" />{{ t('friends.add') }}</button>
      </form>
      <div v-if="ids.length">
        <AudienceRow
          v-for="(role, email) in draft.audience" :key="email" :email="email" :role="role" uid="c" :via-mention="draft.isMentionOnly(email)" :removable="!draft.isMentionOnly(email)"
          @role="(r) => draft.setRole(email, r)" @remove="draft.remove(email)"
        />
      </div>
    </section>

    <section class="section">
      <div class="row-between">
        <div>
          <b style="font-weight:600">{{ t('compose.protect') }}</b>
          <p class="hint">{{ draft.lockedProtection ? t('compose.protectLocked') : editing ? t('compose.protectFixed') : t('compose.protectHint') }}</p>
        </div>
        <button type="button" class="switch" role="switch" :aria-checked="draft.protect" :aria-label="t('compose.protect')" :disabled="editing" @click="draft.protect = !draft.protect"><span /></button>
      </div>
      <div v-if="draft.protect" class="field">
        <label for="dpw">{{ draft.lockedProtection ? t('post.newPassword') : t('post.password') }}</label>
        <div class="pwrow">
          <input id="dpw" v-model="draft.password" class="input" :type="showPw ? 'text' : 'password'" autocomplete="new-password" :placeholder="draft.lockedProtection ? t('compose.keepPassword') : ''" />
          <button type="button" class="icon-btn" :aria-label="t('compose.showPassword')" :aria-pressed="showPw" @click="showPw = !showPw"><AppIcon name="eye" :size="20" /></button>
        </div>
        <p class="hint">{{ t('compose.passwordHint') }}</p>
      </div>
    </section>

    <section class="section">
      <div class="row-between">
        <div>
          <b style="font-weight:600">{{ t('post.linkShare') }}</b>
          <p class="hint">{{ draft.protect ? t('post.linkShareHintPw') : t('post.linkShareHint') }}</p>
        </div>
        <button type="button" class="switch" role="switch" :aria-checked="draft.linkShare" :aria-label="t('post.linkShare')" @click="draft.linkShare = !draft.linkShare"><span /></button>
      </div>
    </section>

    <section class="section">
      <div>
        <b style="font-weight:600">{{ t('comments.mode') }}</b>
        <p class="hint">{{ t('comments.hint' + draft.commentMode[0].toUpperCase() + draft.commentMode.slice(1)) }}</p>
      </div>
      <div class="seg" role="radiogroup" :aria-label="t('comments.mode')">
        <button v-for="m in ['open', 'shared', 'locked']" :key="m" type="button" role="radio" :aria-checked="draft.commentMode === m" :class="{ on: draft.commentMode === m }" @click="draft.commentMode = m">{{ t('comments.mode' + m[0].toUpperCase() + m.slice(1)) }}</button>
      </div>
    </section>

    <div class="footer-actions">
      <button type="button" class="btn lg" :disabled="submitting" @click="cancel">{{ t('compose.cancel') }}</button>
      <button type="button" class="btn primary lg" :disabled="submitting" @click="publish">
        <template v-if="submitting"><span class="spinner" aria-hidden="true" />{{ stageText }}</template>
        <template v-else>{{ editing ? t('compose.save') : t('compose.post') }}</template>
      </button>
    </div>
  </template>
</template>

<style scoped>
.write.drop { border-color: var(--accent); box-shadow: 0 0 0 4px var(--accent-soft); }
.mention-hint { display: flex; align-items: center; gap: 6px; margin-top: -4px; }
.pwrow { display: flex; gap: 6px; align-items: center; }
.linkrow { padding-top: 14px; border-top: 1px solid var(--line); }
.switch:disabled { opacity: .5; cursor: not-allowed; }
.ph { height: 220px; border-radius: 14px; background: var(--sunken); animation: pulse 1.4s ease-in-out infinite; }
@keyframes pulse { 50% { opacity: .55; } }
.spinner { width: 16px; height: 16px; border-radius: 50%; border: 2px solid color-mix(in srgb, var(--on-accent) 35%, transparent); border-top-color: var(--on-accent); animation: spin .8s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }
.btn:disabled { opacity: .7; cursor: progress; }
</style>
