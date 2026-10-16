/**
 * Link previews (Open Graph), the way Facebook / X show a pasted link.
 *
 * A browser may not read another site's HTML (CORS) and SPECACT has no backend, so the page is fetched through a
 * service YOU configure (VITE_LINK_PREVIEW_URL, e.g. your own tiny proxy). It is OFF by default: nothing about a pasted
 * link leaves the device unless an address is set. The service only has to return the page's HTML; the tags are read
 * here with DOMParser (which never runs scripts) and everything is length-limited and cleaned before it is stored.
 */
import { config } from '../config';
import { tokenize } from './mentions';
import { cleanLink, cleanText } from './postModel';

const TIMEOUT_MS = 8000;
const MAX_HTML = 1_500_000;
const MAX_IMAGE = 5 * 1024 * 1024;

/** The first http(s) address in a piece of text, or ''. */
export function firstUrl(text) {
  for (const seg of tokenize(text)) if (seg.t === 'link') return seg.v;
  return '';
}

export const previewEnabled = () => !!config.linkPreviewUrl;

const meta = (doc, ...names) => {
  for (const n of names) {
    const el = doc.querySelector(`meta[property="${n}"], meta[name="${n}"]`);
    const v = el?.getAttribute('content')?.trim();
    if (v) return v;
  }
  return '';
};

const absolute = (href, base) => {
  try {
    const u = new URL(href, base);
    return u.protocol === 'http:' || u.protocol === 'https:' ? u.href : '';
  } catch { return ''; }
};

/** Pure: HTML text -> { url, title, description, site, imageUrl } (or null when the page says nothing useful). */
export function parseOpenGraph(html, pageUrl) {
  const doc = new DOMParser().parseFromString(String(html || '').slice(0, MAX_HTML), 'text/html');
  const link = cleanLink({
    url: absolute(meta(doc, 'og:url') || pageUrl, pageUrl) || pageUrl,
    title: meta(doc, 'og:title', 'twitter:title') || doc.querySelector('title')?.textContent || '',
    description: meta(doc, 'og:description', 'twitter:description', 'description'),
    site: meta(doc, 'og:site_name') || (() => { try { return new URL(pageUrl).hostname.replace(/^www\./, ''); } catch { return ''; } })(),
  });
  if (!link || (!link.title && !link.description)) return null;
  // the address the person pasted is what a card opens, never an address a page claims for itself
  link.url = absolute(pageUrl, pageUrl) || link.url;
  return { link, imageUrl: absolute(meta(doc, 'og:image:secure_url', 'og:image', 'twitter:image'), pageUrl) };
}

async function timed(url, ms, opts = {}) {
  const ctl = new AbortController();
  const t = setTimeout(() => ctl.abort(), ms);
  try { return await fetch(url, { ...opts, signal: ctl.signal, credentials: 'omit', referrerPolicy: 'no-referrer' }); } finally { clearTimeout(t); }
}

const serviceUrl = (url) => config.linkPreviewUrl.replaceAll('{url}', encodeURIComponent(url));

/**
 * Best effort: the preview picture as a File (re-encoded later like any photo), or null when it can't be read.
 * It is asked of the same service first (`&kind=image`: same origin, so the CSP allows it); a plain fetch is the fallback.
 */
async function loadImage(url) {
  for (const target of [`${serviceUrl(url)}${config.linkPreviewUrl.includes('?') ? '&' : '?'}kind=image`, url]) {
    const file = await tryImage(target);
    if (file) return file;
  }
  return null;
}

async function tryImage(url) {
  try {
    const res = await timed(url, 5000);
    if (!res.ok) return null;
    const blob = await res.blob();
    if (!/^image\/(jpeg|png|webp|gif|avif)$/i.test(blob.type) || blob.size > MAX_IMAGE) return null; // never SVG
    return new File([blob], 'link-preview.jpg', { type: blob.type });
  } catch { return null; }
}

/**
 * @returns {Promise<{ link: object, image: File|null }|null>} null when disabled, unreachable or without Open Graph data.
 */
export async function fetchPreview(url) {
  if (!previewEnabled() || !/^https?:\/\//i.test(url)) return null;
  try {
    const res = await timed(serviceUrl(url), TIMEOUT_MS);
    if (!res.ok) return null;
    const parsed = parseOpenGraph((await res.text()).slice(0, MAX_HTML), url);
    if (!parsed) return null;
    return { link: parsed.link, image: parsed.imageUrl ? await loadImage(parsed.imageUrl) : null };
  } catch { return null; }
}

export { cleanText };
