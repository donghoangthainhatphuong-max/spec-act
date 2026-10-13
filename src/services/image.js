import { config } from '../config';
import { classify, mimeOf } from './mediaKinds';

export class ImageError extends Error {
  constructor(code) { super(code); this.name = 'ImageError'; this.code = code; }
}

export function fitWithin(w, h, max) {
  const scale = Math.min(1, max / Math.max(w, h));
  return { w: Math.max(1, Math.round(w * scale)), h: Math.max(1, Math.round(h * scale)) };
}

function canvasBlob(canvas, quality) {
  return new Promise((resolve, reject) => canvas.toBlob((b) => (b ? resolve(b) : reject(new ImageError('encode-failed'))), 'image/jpeg', quality));
}

async function render(bitmap, max, quality, sw = bitmap.width, sh = bitmap.height) {
  const { w, h } = fitWithin(sw, sh, max);
  const canvas = document.createElement('canvas');
  canvas.width = w;
  canvas.height = h;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#fff'; // JPEG has no alpha
  ctx.fillRect(0, 0, w, h);
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(bitmap, 0, 0, w, h);
  const blob = await canvasBlob(canvas, quality);
  canvas.width = canvas.height = 0;
  return { blob, w, h };
}

/**
 * Re-encode a picked image: correct orientation, cap its size, create a small thumbnail.
 * Re-encoding also removes EXIF (GPS position, camera serial …) before anything leaves the device.
 */
export async function prepareImage(file) {
  if (!file.type.startsWith('image/') || file.type === 'image/svg+xml') throw new ImageError('not-image');
  if (file.size > config.maxImageMb * 1024 * 1024) throw new ImageError('too-large');
  let bitmap;
  try { bitmap = await createImageBitmap(file, { imageOrientation: 'from-image' }); } catch { throw new ImageError('unsupported'); }
  try {
    const main = await render(bitmap, config.imageMaxDimension, config.imageQuality);
    const thumb = await render(bitmap, config.thumbDimension, 0.78);
    const base = (file.name || 'photo').replace(/\.[^.]+$/, '').replace(/[^\p{L}\p{N}._-]+/gu, '_').slice(0, 60) || 'photo';
    return { name: `${base}.jpg`, main, thumb };
  } finally {
    bitmap.close?.();
  }
}

export const isVideoFile = (f) => String(f?.type || '').startsWith('video/');

function loadVideo(url) {
  return new Promise((resolve, reject) => {
    const v = document.createElement('video');
    v.muted = true; v.playsInline = true; v.preload = 'auto';
    v.onloadedmetadata = () => resolve(v);
    v.onerror = () => reject(new ImageError('unsupported'));
    v.src = url;
  });
}
const seek = (v, t) => new Promise((resolve) => { v.onseeked = () => resolve(); v.currentTime = t; });

/**
 * A video is stored as recorded (no transcoding). What we add is a poster frame used as its thumbnail.
 * Recorded WebM often reports an infinite duration until the end is reached once, hence the seek trick.
 */
export async function prepareVideo(file) {
  if (!isVideoFile(file)) throw new ImageError('not-video');
  if (file.size > config.maxVideoMb * 1024 * 1024) throw new ImageError('too-large');
  const ext = (file.type.split('/')[1] || 'mp4').split(';')[0].replace('quicktime', 'mov');
  const base = (file.name || 'video').replace(/\.[^.]+$/, '').replace(/[^\p{L}\p{N}._-]+/gu, '_').slice(0, 60) || 'video';
  const url = URL.createObjectURL(file);
  let w = 0; let h = 0; let duration = Number.isFinite(file.duration) ? file.duration : 0; let thumb = null;
  try {
    const v = await loadVideo(url);
    if (!Number.isFinite(v.duration)) { await seek(v, 1e101).catch(() => {}); }
    if (Number.isFinite(v.duration)) duration = v.duration;
    await seek(v, Math.min(0.5, (duration || 1) / 2)).catch(() => {});
    w = v.videoWidth; h = v.videoHeight;
    if (w && h) thumb = await render(v, config.thumbDimension, 0.78, w, h);
  } catch { /* unplayable here: keep the file, use a plain poster */ } finally { URL.revokeObjectURL(url); }
  if (!thumb) thumb = await plainPoster();
  return { name: `${base}.${ext}`, main: { blob: file, w: w || thumb.w, h: h || thumb.h, duration: Math.round(duration || 0) }, thumb };
}

async function plainPoster() {
  const canvas = document.createElement('canvas');
  canvas.width = 480; canvas.height = 270;
  const ctx = canvas.getContext('2d');
  ctx.fillStyle = '#2a302c'; ctx.fillRect(0, 0, 480, 270);
  const blob = await canvasBlob(canvas, 0.7);
  return { blob, w: 480, h: 270 };
}

const safeName = (name, fallback) => (Array.from(String(name || fallback)).map((c) => (c.charCodeAt(0) < 32 || '\\/:*?"<>|'.includes(c) ? '_' : c)).join('').slice(0, 120) || fallback);

/** Audio is stored as recorded; only its length is read. */
export async function prepareAudio(file) {
  const mime = mimeOf(file).split(';')[0];
  if (file.size > config.maxFileMb * 1024 * 1024) throw new ImageError('too-large');
  const url = URL.createObjectURL(file);
  let duration = 0;
  try {
    const a = new Audio();
    a.preload = 'metadata';
    await new Promise((resolve) => { a.onloadedmetadata = resolve; a.onerror = resolve; a.src = url; setTimeout(resolve, 4000); });
    if (!Number.isFinite(a.duration) && a.duration !== 0) { a.currentTime = 1e101; await new Promise((r) => { a.ontimeupdate = r; setTimeout(r, 1500); }); }
    if (Number.isFinite(a.duration)) duration = a.duration;
  } catch { /* length unknown */ } finally { URL.revokeObjectURL(url); }
  return { name: safeName(file.name, 'audio'), main: { blob: file, duration: Math.round(duration) }, thumb: null, kind: 'audio', mime };
}

/** A document (or any other safe file): handed over untouched, shown as a download. */
export function prepareFile(file) {
  if (file.size > config.maxFileMb * 1024 * 1024) throw new ImageError('too-large');
  return { name: safeName(file.name, 'file'), main: { blob: file }, thumb: null, kind: 'file', mime: mimeOf(file) };
}

/** Anything attachable -> { name, main, thumb|null, kind, mime } */
export async function prepareMedia(file) {
  const kind = classify(file);
  if (!kind) throw new ImageError('blocked');
  if (kind === 'video') return { ...(await prepareVideo(file)), kind: 'video', mime: file.type.split(';')[0] };
  if (kind === 'audio') return prepareAudio(file);
  if (kind === 'file') return prepareFile(file);
  return { ...(await prepareImage(file)), kind: 'image', mime: 'image/jpeg' };
}
