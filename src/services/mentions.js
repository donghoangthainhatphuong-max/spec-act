/**
 * @mention parsing. A mention is `@` immediately followed by an e-mail address: `@an.nhien@gmail.com`.
 * Rendering never uses innerHTML — callers get segments and build text nodes.
 */
const EMAIL = '[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\\.[A-Za-z0-9-]+)*\\.[A-Za-z]{2,}';
const TOKEN = new RegExp(`(?<![A-Za-z0-9._%+-])@(${EMAIL})|(https?:\\/\\/[^\\s<>"']+)`, 'g');
export const EMAIL_RE = new RegExp(`^${EMAIL}$`);

export const normEmail = (s) => String(s || '').trim().toLowerCase();
export const isEmail = (s) => EMAIL_RE.test(String(s || '').trim());

export function extractMentions(text) {
  const out = new Set();
  for (const m of String(text || '').matchAll(TOKEN)) if (m[1]) out.add(normEmail(m[1]));
  return [...out];
}

/** Split text into [{ t:'text', v } | { t:'mention', email } | { t:'link', v }]. */
export function tokenize(text) {
  const src = String(text || '');
  const out = [];
  let last = 0;
  for (const m of src.matchAll(TOKEN)) {
    let end = m.index + m[0].length;
    let value = m[0];
    if (m[2]) { // url: drop trailing punctuation that is almost never part of the link
      const trimmed = value.replace(/[.,;:!?)\]}'"]+$/, '');
      end -= value.length - trimmed.length;
      value = trimmed;
    }
    if (m.index > last) out.push({ t: 'text', v: src.slice(last, m.index) });
    out.push(m[1] ? { t: 'mention', email: normEmail(m[1]) } : { t: 'link', v: value });
    last = end;
  }
  if (last < src.length) out.push({ t: 'text', v: src.slice(last) });
  return out;
}

/** Find an in-progress mention ("@par") ending at the caret, for the autocomplete popup. */
export function activeMentionQuery(text, caret) {
  const before = String(text || '').slice(0, caret);
  const m = /(?:^|[\s(])@([^\s@]*)$/.exec(before);
  if (!m) return null;
  return { query: m[1], start: caret - m[1].length - 1, end: caret };
}

export function prettyName(email) {
  const local = String(email || '').split('@')[0].replace(/[._+-]+/g, ' ').replace(/\d+$/g, '').trim() || String(email || '');
  return local.replace(/\b\p{L}/gu, (c) => c.toUpperCase());
}
