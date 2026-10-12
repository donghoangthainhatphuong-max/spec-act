import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import { config } from '../config';
import { extractMentions } from '../services/mentions';
import { usePeopleStore } from './people';
import { on } from '../services/events';

/** The post being written / edited. Audience = explicit picks + people @mentioned in the text. */
export const useDraftStore = defineStore('draft', () => {
  const people = usePeopleStore();
  const text = ref('');
  const photos = ref([]); // { key, kind:'new'|'old', file?, url?, media? }
  const manual = ref({}); // email -> role (explicit picks, persisted when editing)
  const roles = ref({}); // role overrides for people only reachable through a mention
  const protect = ref(false);
  const password = ref('');
  const linkShare = ref(false);
  const editing = ref(null);
  const lockedProtection = ref(false); // editing an already protected post: protection can't be toggled
  let seq = 0;

  const mentions = computed(() => extractMentions(text.value).filter((e) => !people.isMe(e)));
  const audience = computed(() => {
    const out = {};
    for (const e of mentions.value) out[e] = roles.value[e] || 'view';
    for (const [e, r] of Object.entries(manual.value)) out[e] = r;
    return out;
  });
  const isMentionOnly = (email) => mentions.value.includes(email) && !(email in manual.value);

  function toggle(email) {
    if (email in manual.value) { const { [email]: _drop, ...rest } = manual.value; manual.value = rest; return; }
    manual.value = { ...manual.value, [email]: roles.value[email] || 'view' };
  }
  function setRole(email, role) {
    if (email in manual.value) manual.value = { ...manual.value, [email]: role };
    else roles.value = { ...roles.value, [email]: role };
  }
  function remove(email) {
    const { [email]: _a, ...rest } = manual.value;
    manual.value = rest;
    const { [email]: _b, ...r2 } = roles.value;
    roles.value = r2;
  }
  function addEmail(email, role = 'view') { manual.value = { ...manual.value, [email]: role }; }

  const room = computed(() => config.maxImagesPerPost - photos.value.length);
  /** @returns {number} how many files were skipped */
  function addFiles(list) {
    let skipped = 0;
    for (const f of Array.from(list)) {
      if (!f.type.startsWith('image/') || f.type === 'image/svg+xml' || f.size > config.maxImageMb * 1024 * 1024 || room.value <= 0) { skipped++; continue; }
      photos.value = [...photos.value, { key: `n${++seq}`, kind: 'new', file: f, url: URL.createObjectURL(f) }];
    }
    return skipped;
  }
  function removePhoto(key) {
    const p = photos.value.find((x) => x.key === key);
    if (p?.url) URL.revokeObjectURL(p.url);
    photos.value = photos.value.filter((x) => x.key !== key);
  }

  function reset() {
    for (const p of photos.value) if (p.url) URL.revokeObjectURL(p.url);
    text.value = ''; photos.value = []; manual.value = {}; roles.value = {}; protect.value = false; password.value = ''; linkShare.value = false; editing.value = null; lockedProtection.value = false;
  }
  on('session-end', reset);

  function loadFrom(post) {
    reset();
    editing.value = post.id;
    text.value = post.text;
    photos.value = post.media.map((m) => ({ key: m.id, kind: 'old', media: m }));
    manual.value = { ...post.audience };
    protect.value = post.protected;
    lockedProtection.value = post.protected;
    linkShare.value = post.linkShare;
  }

  const dirty = computed(() => !!(text.value.trim() || photos.value.length));

  return { text, photos, manual, roles, protect, password, linkShare, editing, lockedProtection, mentions, audience, isMentionOnly, room, dirty, toggle, setRole, remove, addEmail, addFiles, removePhoto, reset, loadFrom };
});
