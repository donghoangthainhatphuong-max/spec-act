import { config } from '../config';

/** Link that opens a post in this app (the viewer still needs Drive access to it). */
export function postLink(id) {
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
