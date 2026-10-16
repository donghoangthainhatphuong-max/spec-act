// Renders the PWA / Android icons from the brand mark. Run: npm run icons
import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';

// the mark, drawn on a 64x64 grid (same geometry as public/brand/mark.svg and public/favicon.svg)
const mark = (cream = '#F6F3EC', spark = '#FF9A62') => `
  <mask id="k" maskUnits="userSpaceOnUse" x="0" y="0" width="64" height="64"><rect width="64" height="64" fill="#fff"/><circle cx="32" cy="29.5" r="4.3" fill="#000"/><rect x="29.8" y="30.5" width="4.4" height="11" rx="2.2" fill="#000"/></mask>
  <circle cx="32" cy="32" r="22" fill="none" stroke="${cream}" stroke-width="2.2" opacity=".45"/>
  <circle cx="32" cy="32" r="13" fill="${cream}" mask="url(#k)"/>
  <circle cx="47.6" cy="16.4" r="3.8" fill="${spark}"/><circle cx="28" cy="53.6" r="3" fill="${spark}"/><circle cx="10.4" cy="25" r="3" fill="${spark}"/>`;

// full-bleed square (the OS rounds it) with the mark scaled into a safe zone
const icon = (size, scale) => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 64 64">
  <defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#1B7A63"/><stop offset="1" stop-color="#0C3A31"/></linearGradient></defs>
  <rect width="64" height="64" fill="url(#g)"/>
  <g transform="translate(${32 - 32 * scale} ${32 - 32 * scale}) scale(${scale})">${mark()}</g>
</svg>`);

await mkdir('public/icons', { recursive: true });
await mkdir('docs/brand', { recursive: true });
const out = [['icon-192.png', 192, 1], ['icon-512.png', 512, 1], ['icon-maskable-512.png', 512, 0.78], ['apple-touch-icon.png', 180, 1]];
for (const [file, size, scale] of out) await sharp(icon(size, scale)).png().toFile(`public/icons/${file}`);
await sharp(icon(1024, 1)).png().toFile('docs/brand/app-icon-1024.png');
console.log('icons written');
