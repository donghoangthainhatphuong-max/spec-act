/**
 * Pure helpers describing what is stored in Drive. No I/O in here so it is easy to test.
 *
 *  SPECACT/                     root folder (properties: specact=root)
 *    index.json                 per-user fast index: my posts + posts shared with me
 *    contacts.json              people I am connected with (mention / share targets)
 *    posts/
 *      2026-10-12_ab12cd/       one folder per post (properties: specact=post, rev, pj, cj, mf)
 *        post.json              content + metadata (or an encrypted payload when password protected)
 *        comments.json          comments + likes
 *        media/                 photos (+ thumbnails)
 */
import { decryptJson, encryptJson } from './crypto';
import { normEmail } from './mentions';

export const SCHEMA = 1;
export const SNIPPET_LENGTH = 600;
export const ENTRY_MEDIA = 3;
export const ENTRY_AUDIENCE = 12;

export const ROLE_VIEW = 'view';
export const ROLE_COMMENT = 'comment';

/**
 * Who may write comments (and react):
 *   open   everyone who can see the post — shared people at any level and, if the post is public by link, link visitors
 *   shared only people shared with at the "comment" level (default); link visitors can only read
 *   locked nobody (existing comments stay visible; the owner can still delete)
 */
export const COMMENT_MODES = ['open', 'shared', 'locked'];
export const normMode = (m) => (COMMENT_MODES.includes(m) ? m : 'shared');
export const canCommentWith = (mode, role) => mode === 'open' || (mode === 'shared' && role === ROLE_COMMENT);

export function folderNameFor(createdAt, id) {
  const d = new Date(createdAt);
  const p = (n) => String(n).padStart(2, '0');
  return `${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}_${id}`;
}

export function snippetOf(text) {
  const t = String(text || '');
  return t.length > SNIPPET_LENGTH ? { text: `${t.slice(0, SNIPPET_LENGTH).trimEnd()}…`, truncated: true } : { text: t, truncated: false };
}

export function cleanAudience(aud, ownerEmail) {
  const out = {};
  for (const [email, role] of Object.entries(aud || {})) {
    const e = normEmail(email);
    if (!e || e === normEmail(ownerEmail)) continue;
    out[e] = role === ROLE_COMMENT ? ROLE_COMMENT : ROLE_VIEW;
  }
  return out;
}

export function publicMedia(m) {
  return { id: m.id, thumb: m.thumb || null, name: m.name || '', mime: m.mime || 'image/jpeg', w: m.w || 0, h: m.h || 0, size: m.size || 0 };
}

/** The JSON written to post.json. For protected posts the sensitive part is sealed in `payload`. */
export async function buildPostDoc({ id, owner, createdAt, updatedAt, text, media, mentions, audience, linkShare, commentMode, cj, protection, key }) {
  const body = { text: text || '', media: (media || []).map(publicMedia), mentions: mentions || [] };
  const base = { v: SCHEMA, id, owner: { email: normEmail(owner.email), name: owner.name || '' }, createdAt, updatedAt, audience: cleanAudience(audience, owner.email), linkShare: !!linkShare, commentMode: normMode(commentMode), cj: cj || null };
  if (protection) {
    if (!key) throw new Error('content key required');
    return { ...base, protection, payload: await encryptJson(key, body, `post:${id}`) };
  }
  return { ...base, protection: null, ...body };
}

/** Turn a post.json document (plus optional content key) into the object the UI works with. */
export async function openPostDoc(doc, key) {
  if (!doc || doc.v !== SCHEMA) throw Object.assign(new Error('unsupported-version'), { code: 'unsupported-version' });
  const isProtected = !!doc.protection;
  let body = { text: doc.text || '', media: doc.media || [], mentions: doc.mentions || [] };
  let locked = false;
  if (isProtected) {
    if (key) body = await decryptJson(key, doc.payload, `post:${doc.id}`);
    else { body = { text: '', media: [], mentions: [] }; locked = true; }
  }
  return {
    pid: doc.id,
    owner: { email: normEmail(doc.owner?.email), name: doc.owner?.name || '' },
    createdAt: doc.createdAt,
    updatedAt: doc.updatedAt,
    protected: isProtected,
    locked,
    linkShare: !!doc.linkShare,
    commentMode: normMode(doc.commentMode),
    cj: doc.cj || null,
    text: body.text || '',
    media: (body.media || []).map(publicMedia),
    mentions: body.mentions || [],
    audience: cleanAudience(doc.audience, doc.owner?.email),
    protection: doc.protection || null,
  };
}

/** Lightweight record kept in index.json — enough to paint a feed card without opening the post. */
export function toEntry(post, { id, ids, rev }) {
  const snip = post.protected ? { text: '', truncated: false } : snippetOf(post.text);
  const aud = Object.entries(post.audience || {}).slice(0, ENTRY_AUDIENCE);
  return {
    id,
    pid: post.pid,
    owner: post.owner,
    createdAt: post.createdAt,
    updatedAt: post.updatedAt,
    rev: String(rev ?? post.updatedAt),
    protected: post.protected,
    linkShare: post.linkShare,
    commentMode: post.commentMode,
    text: snip.text,
    truncated: snip.truncated,
    mediaCount: post.protected ? 0 : post.media.length,
    media: post.protected ? [] : post.media.slice(0, ENTRY_MEDIA),
    audience: Object.fromEntries(aud),
    audienceCount: Object.keys(post.audience || {}).length,
    ids,
  };
}

export const emptyIndex = (email) => ({ v: SCHEMA, owner: normEmail(email), updatedAt: 0, syncedAt: 0, mine: [], shared: [] });

export const byNewest = (a, b) => (b.createdAt || 0) - (a.createdAt || 0);
