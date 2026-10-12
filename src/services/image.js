import { config } from '../config';

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

async function render(bitmap, max, quality) {
  const { w, h } = fitWithin(bitmap.width, bitmap.height, max);
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
