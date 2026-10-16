import { config } from '../config';

/**
 * Link that opens a post in this app. A post shared "with anyone who has the link" is addressed by its public
 * post.json (the folder stays private); otherwise by its folder, which only people it was shared with can open.
 */
export function postLink(post) {
  const id = post.linkShare && post.ids?.pj ? post.ids.pj : post.id;
  return `${location.origin}${config.basePath}#/post/${id}`;
}

/** Google Chat conversation with one person, opened in a new tab (SPECACT never reads or sends chat messages). */
export function chatLink(me, email) {
  const url = config.chatUrl.replaceAll('{me}', encodeURIComponent(me || '')).replaceAll('{email}', encodeURIComponent(email));
  // the template comes from configuration; only ever open it as an https page (never javascript:, data:, …)
  try { if (new URL(url).protocol === 'https:') return url; } catch { /* fall through */ }
  return `https://mail.google.com/chat/#chat/dm/${encodeURIComponent(email)}`;
}

export function openChat(me, email) {
  window.open(chatLink(me, email), '_blank', 'noopener,noreferrer');
}

export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { return document.execCommand('copy'); } catch { return false; } finally { ta.remove(); }
  }
}
