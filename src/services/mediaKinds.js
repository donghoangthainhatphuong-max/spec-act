/**
 * What a post attachment can be, and what is allowed.
 *   image  photo, re-encoded in the browser (EXIF stripped)
 *   video  stored as recorded, with a poster frame
 *   audio  voice / sound recordings and audio files
 *   file   documents and anything else that is safe to hand over as a download
 * Files that could run code when opened (web pages, scripts, executables, SVG…) are refused outright.
 */
import { config } from '../config';

const DENY_EXT = new Set([
  'html', 'htm', 'xhtml', 'shtml', 'svg', 'svgz', 'xml', 'xsl', 'js', 'mjs', 'cjs', 'jsx', 'ts', 'wasm', 'php', 'phtml', 'jsp', 'asp', 'aspx',
  'exe', 'dll', 'msi', 'msp', 'com', 'scr', 'pif', 'bat', 'cmd', 'ps1', 'psm1', 'vbs', 'vbe', 'wsf', 'wsh', 'sh', 'bash', 'zsh', 'command',
  'app', 'apk', 'ipa', 'jar', 'deb', 'rpm', 'dmg', 'pkg', 'lnk', 'url', 'reg', 'hta', 'cpl', 'gadget', 'iso',
]);
const DENY_MIME = /^(text\/html|application\/xhtml|image\/svg|text\/xml|application\/xml|text\/javascript|application\/javascript|application\/x-msdownload|application\/x-sh|application\/x-httpd)/;

export const extOf = (name) => (String(name || '').split('.').pop() || '').toLowerCase();

const EXT_MIME = {
  pdf: 'application/pdf', txt: 'text/plain', md: 'text/markdown', csv: 'text/csv', rtf: 'application/rtf', json: 'application/json',
  doc: 'application/msword', docx: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  xls: 'application/vnd.ms-excel', xlsx: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ppt: 'application/vnd.ms-powerpoint', pptx: 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  odt: 'application/vnd.oasis.opendocument.text', ods: 'application/vnd.oasis.opendocument.spreadsheet', odp: 'application/vnd.oasis.opendocument.presentation',
  zip: 'application/zip', '7z': 'application/x-7z-compressed', rar: 'application/vnd.rar', gz: 'application/gzip', tar: 'application/x-tar',
  m4a: 'audio/mp4', mp3: 'audio/mpeg', wav: 'audio/wav', ogg: 'audio/ogg', oga: 'audio/ogg', opus: 'audio/ogg', flac: 'audio/flac', aac: 'audio/aac',
  mp4: 'video/mp4', mov: 'video/quicktime', webm: 'video/webm', m4v: 'video/mp4', mkv: 'video/x-matroska',
  jpg: 'image/jpeg', jpeg: 'image/jpeg', png: 'image/png', gif: 'image/gif', webp: 'image/webp', heic: 'image/heic',
};

/** The MIME type the browser reported, or a guess from the extension when it reported nothing. */
export const mimeOf = (file) => (file.type && file.type !== 'application/octet-stream' ? file.type : EXT_MIME[extOf(file.name)] || 'application/octet-stream');

/** 'image' | 'video' | 'audio' | 'file', or null when the file must not be attached. */
export function classify(file) {
  const mime = mimeOf(file);
  if (DENY_MIME.test(mime) || DENY_EXT.has(extOf(file.name))) return null;
  if (mime.startsWith('image/')) return 'image';
  if (mime.startsWith('video/')) return 'video';
  if (mime.startsWith('audio/')) return 'audio';
  return 'file';
}

export function limitMb(kind) {
  return kind === 'image' ? config.maxImageMb : kind === 'video' ? config.maxVideoMb : config.maxFileMb;
}

/** Photos and videos are shown in the visual grid / viewer; audio and documents as an attachment list. */
export const isVisual = (m) => !m || !m.kind || m.kind === 'image' || m.kind === 'video';

export function humanSize(bytes) {
  if (!bytes) return '';
  const u = ['B', 'KB', 'MB', 'GB'];
  let i = 0;
  let v = bytes;
  while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
  return `${v >= 10 || i === 0 ? Math.round(v) : v.toFixed(1)} ${u[i]}`;
}

/** Short label for a document tile: "PDF", "DOCX", "ZIP"… */
export const labelOf = (name) => extOf(name).slice(0, 4).toUpperCase() || 'FILE';
