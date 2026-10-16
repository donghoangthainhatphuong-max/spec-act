/// What a post attachment can be (port of src/services/mediaKinds.js).
///   image  photo, re-encoded on the device (EXIF stripped)   video  stored as recorded, with a poster frame
///   audio  voice recordings and audio files                   file   documents and anything safe to hand over as a download
/// Files that could run code when opened (web pages, scripts, executables, SVG…) are refused outright.
const denyExt = {
  'html',
  'htm',
  'xhtml',
  'shtml',
  'svg',
  'svgz',
  'xml',
  'xsl',
  'js',
  'mjs',
  'cjs',
  'jsx',
  'ts',
  'wasm',
  'php',
  'phtml',
  'jsp',
  'asp',
  'aspx',
  'exe',
  'dll',
  'msi',
  'msp',
  'com',
  'scr',
  'pif',
  'bat',
  'cmd',
  'ps1',
  'psm1',
  'vbs',
  'vbe',
  'wsf',
  'wsh',
  'sh',
  'bash',
  'zsh',
  'command',
  'app',
  'apk',
  'ipa',
  'jar',
  'deb',
  'rpm',
  'dmg',
  'pkg',
  'lnk',
  'url',
  'reg',
  'hta',
  'cpl',
  'gadget',
  'iso',
};
final denyMime = RegExp(
  r'^(text/html|application/xhtml|image/svg|text/xml|application/xml|text/javascript|application/javascript|application/x-msdownload|application/x-sh|application/x-httpd)',
);

const extMime = {
  'pdf': 'application/pdf',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'rtf': 'application/rtf',
  'json': 'application/json',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'odt': 'application/vnd.oasis.opendocument.text',
  'ods': 'application/vnd.oasis.opendocument.spreadsheet',
  'odp': 'application/vnd.oasis.opendocument.presentation',
  'zip': 'application/zip',
  '7z': 'application/x-7z-compressed',
  'rar': 'application/vnd.rar',
  'gz': 'application/gzip',
  'tar': 'application/x-tar',
  'm4a': 'audio/mp4',
  'mp3': 'audio/mpeg',
  'wav': 'audio/wav',
  'ogg': 'audio/ogg',
  'oga': 'audio/ogg',
  'opus': 'audio/ogg',
  'flac': 'audio/flac',
  'aac': 'audio/aac',
  'mp4': 'video/mp4',
  'mov': 'video/quicktime',
  'webm': 'video/webm',
  'm4v': 'video/mp4',
  'mkv': 'video/x-matroska',
  '3gp': 'video/3gpp',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'heic': 'image/heic',
};

String extOf(String name) =>
    name.contains('.') ? name.split('.').last.toLowerCase() : '';

String mimeOfName(String name) =>
    extMime[extOf(name)] ?? 'application/octet-stream';

/// 'image' | 'video' | 'audio' | 'file', or null when the file must not be attached.
String? classify(String name, [String? mime]) {
  final m = (mime == null || mime.isEmpty || mime == 'application/octet-stream')
      ? mimeOfName(name)
      : mime;
  if (denyMime.hasMatch(m) || denyExt.contains(extOf(name))) return null;
  if (m.startsWith('image/')) return 'image';
  if (m.startsWith('video/')) return 'video';
  if (m.startsWith('audio/')) return 'audio';
  return 'file';
}

const maxVideoMb = 200;
const maxVideoSeconds = 180;
const maxFileMb = 50;
const maxAudioSeconds = 600;

String humanSize(int bytes) {
  if (bytes <= 0) return '';
  const u = ['B', 'KB', 'MB', 'GB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < u.length - 1) {
    v /= 1024;
    i++;
  }
  return '${v >= 10 || i == 0 ? v.round() : v.toStringAsFixed(1)} ${u[i]}';
}

String clock(num seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).round().toString().padLeft(2, '0')}';
