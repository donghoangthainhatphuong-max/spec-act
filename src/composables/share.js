import { config } from '../config';

/**
 * Link that opens a post in this app. A post shared "with anyone who has the link" is addressed by its public
 * post.json (the folder stays private); otherwise by its folder, which only people it was shared with can open.
 */
export function postLink(post) {
  const id = post.linkShare && post.ids?.pj ? post.ids.pj : post.id;
  return `${location.origin}${config.basePath}#/post/${id}`;
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
