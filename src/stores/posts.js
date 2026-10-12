import { defineStore } from 'pinia';
import { computed, reactive, ref, shallowRef } from 'vue';
import { useSessionStore } from './session';
import { usePeopleStore } from './people';
import { on } from '../services/events';
import { byNewest } from '../services/postModel';

export const usePostsStore = defineStore('posts', () => {
  const session = useSessionStore();
  const people = usePeopleStore();

  const mine = shallowRef([]);
  const shared = shallowRef([]);
  const loading = ref(true);
  const syncing = ref(false);
  const error = ref(null);
  const syncedAt = ref(0);
  const full = reactive({}); // folderId -> opened post
  const social = reactive({}); // folderId -> { comments, likes, loaded }
  const inflight = new Map();
  let timer = null;

  function reset() {
    mine.value = []; shared.value = []; loading.value = true; syncing.value = false; error.value = null; syncedAt.value = 0;
    for (const k of Object.keys(full)) delete full[k];
    for (const k of Object.keys(social)) delete social[k];
    inflight.clear();
    clearInterval(timer); timer = null;
  }
  on('session-end', reset);

  const repo = () => session.repo;
  const feed = computed(() => [...mine.value, ...shared.value].sort(byNewest));
  const entryById = (id) => mine.value.find((e) => e.id === id) || shared.value.find((e) => e.id === id) || null;

  function apply(idx) {
    mine.value = [...idx.mine];
    shared.value = [...idx.shared];
    syncedAt.value = idx.syncedAt || syncedAt.value;
    for (const e of [...idx.mine, ...idx.shared]) people.learn(e.owner.email, e.owner.name);
  }

  async function init() {
    reset();
    try { apply(await repo().loadIndex()); } catch (e) { error.value = e; }
    loading.value = false;
    sync();
  }

  function startAutoSync(seconds) {
    clearInterval(timer);
    if (seconds > 0 && session.mode === 'drive') timer = setInterval(() => { if (!document.hidden) sync(); }, seconds * 1000);
  }

  async function sync() {
    if (!repo() || syncing.value) return;
    syncing.value = true;
    try {
      apply(await repo().syncIndex());
      error.value = null;
      session.offline = false;
    } catch (e) {
      error.value = e;
      if (e.status === 0) session.offline = true;
    } finally { syncing.value = false; }
  }

  async function open(id, { fresh = false } = {}) {
    if (!fresh && full[id] && !full[id].locked) return full[id];
    const post = await repo().openPost(id);
    full[id] = post;
    people.learn(post.owner.email, post.owner.name);
    apply(repo().index || { mine: mine.value, shared: shared.value });
    return post;
  }

  async function unlock(id, password, remember = false) {
    const post = await repo().unlockAndOpen(id, password, { remember });
    full[id] = post;
    delete social[id];
    return post;
  }
  const hasKey = (id) => !!repo()?.hasKey?.(id);

  async function loadSocial(id, { fresh = false } = {}) {
    const post = full[id] || entryById(id);
    if (!post) return null;
    if (!fresh && social[id]?.loaded) return social[id];
    if (inflight.has(id)) return inflight.get(id);
    const job = (async () => {
      // comments need the folder ids; entries carry them
      const data = await repo().loadComments(full[id] || { ...post, id });
      for (const c of data.comments) people.learn(c.by, c.name);
      social[id] = { ...data, loaded: true };
      return social[id];
    })().finally(() => inflight.delete(id));
    inflight.set(id, job);
    return job;
  }

  const setSocial = (id, data) => { social[id] = { ...data, loaded: true }; };

  async function addComment(id, text) {
    const data = await repo().addComment(full[id], text);
    if (data) { setSocial(id, data); for (const c of data.comments) people.learn(c.by, c.name); }
  }
  async function removeComment(id, commentId) { setSocial(id, await repo().deleteComment(full[id], commentId)); }
  async function toggleLike(id) {
    const target = full[id] || entryById(id);
    const optimistic = social[id]?.loaded ? social[id] : null;
    if (optimistic) {
      const me = session.me.email;
      const likes = optimistic.likes.includes(me) ? optimistic.likes.filter((x) => x !== me) : [...optimistic.likes, me];
      social[id] = { ...optimistic, likes };
    }
    try {
      setSocial(id, await repo().toggleLike({ ...target, id }));
    } catch (e) { if (optimistic) social[id] = optimistic; throw e; }
  }

  async function create(input, onProgress) {
    const res = await repo().createPost(input, onProgress);
    full[res.post.id] = res.post;
    apply(repo().index);
    return res;
  }
  async function update(post, input, onProgress) {
    const res = await repo().updatePost(post, input, onProgress);
    full[post.id] = res.post;
    apply(repo().index);
    return res;
  }
  async function remove(post) {
    await repo().deletePost(post);
    delete full[post.id]; delete social[post.id];
    apply(repo().index);
  }
  async function setAccess(post, email, role) {
    const res = await repo().setAccess(post, email, role);
    full[post.id] = res.post;
    apply(repo().index);
    return res;
  }
  async function setCommentMode(post, mode) {
    const next = await repo().setCommentMode(post, mode);
    full[post.id] = next;
    apply(repo().index);
    return next;
  }
  async function setLinkShare(post, on_) {
    const next = await repo().setLinkShare(post, on_);
    full[post.id] = next;
    return next;
  }
  async function forgetShared(id) {
    await repo().forgetShared(id);
    apply(repo().index);
    delete full[id];
  }

  return {
    mine, shared, feed, loading, syncing, error, syncedAt, full, social, entryById,
    init, sync, startAutoSync, open, unlock, hasKey, loadSocial, addComment, removeComment, toggleLike, create, update, remove, setAccess, setCommentMode, setLinkShare, forgetShared,
  };
});
