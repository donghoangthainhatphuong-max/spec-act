// Renders the PWA icons from the logo. Run: npm run icons
import sharp from 'sharp';
import { mkdir } from 'node:fs/promises';

const logo = (size, pad, bg = '#1B6650') => Buffer.from(`<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <rect width="${size}" height="${size}" fill="${bg}"/>
  <g transform="translate(${pad} ${pad}) scale(${(size - pad * 2) / 40})">
    <circle cx="20" cy="20" r="17" fill="none" stroke="#fff" stroke-width="3"/><path d="M20 3a17 17 0 0 1 0 34z" fill="#fff"/>
    <circle cx="20" cy="17" r="3.4" fill="${bg}"/><rect x="18.3" y="18" width="3.4" height="9" rx="1.2" fill="${bg}"/>
  </g></svg>`);

await mkdir('public/icons', { recursive: true });
const out = [
  ['icon-192.png', 192, 26], ['icon-512.png', 512, 70], ['icon-maskable-512.png', 512, 128], ['apple-touch-icon.png', 180, 24],
];
for (const [file, size, pad] of out) await sharp(logo(size, pad)).png().toFile(`public/icons/${file}`);
console.log('icons written');
