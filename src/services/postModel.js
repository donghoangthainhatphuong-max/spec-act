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
import { isVisual } from './mediaKinds';
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

/** Marks everything SPECACT creates so it is easy to spot (and search) in Drive, e.g. in "Shared with me". */
export const BRAND_PREFIX = '__S.P.E.C.T.A.C.T__';
export const brandName = (name) => `${BRAND_PREFIX} ${name}`;
export const isBranded = (name) => String(name || '').startsWith(BRAND_PREFIX);

export function shortcutNameFor(ownerName, createdAt) {
  const d = new Date(createdAt);
  const p = (n) => String(n).padStart(2, '0');
  return brandName(`${ownerName || '?'} · ${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}`);
}

export function folderNameFor(createdAt, id) {
  const d = new Date(createdAt);
  const p = (n) => String(n).padStart(2, '0');
  return brandName(`${d.getUTCFullYear()}-${p(d.getUTCMonth() + 1)}-${p(d.getUTCDate())}_${id}`);
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

const DRIVE_ID_RE = /^[A-Za-z0-9_-]{1,200}$/;
const DRIVE_ID = { test: (v) => typeof v === 'string' && DRIVE_ID_RE.test(v) };
const SAFE_MIME = /^(image\/(jpeg|png|gif|webp|avif|heic|heif)|video\/[a-z0-9.+-]+|audio\/[a-z0-9.+-]+)$/i;
// control characters and bidi overrides ("evil\u202Efdp.exe") let a name pretend to be something else
// eslint-disable-next-line no-control-regex
const UNSAFE_CHARS = /[\u0000-\u001f\u007f\u200e\u200f\u202a-\u202e\u2066-\u2069\ufeff]/g;
export const cleanName = (s, max = 200) => String(s ?? '').replace(UNSAFE_CHARS, '').replace(/[\\/]/g, '_').slice(0, max);
const nat = (n) => (Number.isFinite(+n) && +n > 0 ? Math.min(Math.round(+n), 1e12) : 0);

/**
 * Normalise one attachment. post.json is written by another person and cannot be trusted: ids must look like
 * Drive ids, and only media types the browser plays passively keep their type — anything else is a plain
 * download labelled application/octet-stream, so it can never be rendered as a page.
 */
/** One line/paragraph of untrusted text: control and bidi characters out, whitespace collapsed, length-limited. */
export const cleanText = (s, max = 300) => String(s ?? '').replace(UNSAFE_CHARS, ' ').replace(/\s+/g, ' ').trim().slice(0, max);

/**
 * The link card of a post (Open Graph data somebody else wrote): only http(s) addresses, plain limited text, and the
 * preview picture is just the id of a file in the post's own Drive folder.
 */
export function cleanLink(raw) {
  if (!raw || typeof raw !== 'object') return null;
  let url = '';
  try { const u = new URL(String(raw.url)); if (u.protocol === 'http:' || u.protocol === 'https:') url = u.href.slice(0, 2000); } catch { /* not a link */ }
  if (!url) return null;
  return {
    url,
    title: cleanText(raw.title, 200),
    description: cleanText(raw.description, 500),
    site: cleanText(raw.site, 80),
    image: DRIVE_ID.test(raw.image) ? raw.image : null,
  };
}

export function publicMedia(m) {
  const id = DRIVE_ID.test(m?.id) ? String(m.id) : '';
  const declared = String(m?.mime || '').toLowerCase().split(';')[0].trim();
  let kind = 'file';
  if (SAFE_MIME.test(declared)) kind = declared.startsWith('video/') ? 'video' : declared.startsWith('audio/') ? 'audio' : m?.kind === 'file' ? 'file' : 'image';
  const out = { id, thumb: DRIVE_ID.test(m?.thumb) ? String(m.thumb) : null, name: cleanName(m?.name), mime: kind === 'file' ? 'application/octet-stream' : declared, w: nat(m?.w), h: nat(m?.h), size: nat(m?.size) };
  if (kind === 'video' || kind === 'audio') { out.kind = kind; out.duration = nat(m?.duration); }
  else if (kind === 'file') out.kind = 'file';
  return out;
}

/** The JSON written to post.json. For protected posts the sensitive part is sealed in `payload`. */
export async function buildPostDoc({ id, owner, createdAt, updatedAt, text, media, mentions, audience, linkShare, commentMode, cj, lj, protection, key, link }) {
  const body = { text: text || '', media: (media || []).map(publicMedia), mentions: mentions || [] };
  const card = cleanLink(link);
  if (card) body.link = card; // sits inside the sealed payload of a protected post
  const base = { v: SCHEMA, id, owner: { email: normEmail(owner.email), name: cleanName(owner.name, 120) }, createdAt, updatedAt, audience: cleanAudience(audience, owner.email), linkShare: !!linkShare, commentMode: normMode(commentMode), cj: cj || null, lj: lj || null };
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
  let body = { text: doc.text || '', media: doc.media || [], mentions: doc.mentions || [], link: doc.link };
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
    lj: doc.lj || null,
    text: body.text || '',
    link: cleanLink(body.link),
    media: (Array.isArray(body.media) ? body.media : []).map(publicMedia).filter((m) => m.id),
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
    link: post.protected ? null : (post.link || null),
    // the feed card shows the first photos/videos and lists audio and documents next to them
    mediaCount: post.protected ? 0 : post.media.filter(isVisual).length,
    media: post.protected ? [] : post.media.filter(isVisual).slice(0, ENTRY_MEDIA),
    files: post.protected ? [] : post.media.filter((x) => !isVisual(x)).slice(0, 6),
    fileCount: post.protected ? 0 : post.media.filter((x) => !isVisual(x)).length,
    audience: Object.fromEntries(aud),
    audienceCount: Object.keys(post.audience || {}).length,
    ids,
  };
}

export const emptyIndex = (email) => ({ v: SCHEMA, owner: normEmail(email), updatedAt: 0, syncedAt: 0, mine: [], shared: [] });

export const byNewest = (a, b) => (b.createdAt || 0) - (a.createdAt || 0);
