/// Pure helpers describing what is stored in Drive (port of src/services/postModel.js, same open format v1).
///   SPECACT/{index.json, contacts.json, shared/, posts/<__S.P.E.C.T.A.C.T__ date_id>/{post.json, comments.json, likes.json, media/}}
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';

const schema = 1;
const brandPrefix = '__S.P.E.C.T.A.C.T__';
String brandName(String n) => '$brandPrefix $n';
bool isBranded(String? n) => (n ?? '').startsWith(brandPrefix);

const roleView = 'view';
const roleComment = 'comment';
const commentModes = ['open', 'shared', 'locked'];
String normMode(Object? m) => commentModes.contains(m) ? m as String : 'shared';
bool canCommentWith(String mode, String role) => mode == 'open' || (mode == 'shared' && role == roleComment);

String normEmail(Object? s) => (s ?? '').toString().trim().toLowerCase();

String folderNameFor(int createdAt, String id) {
  final d = DateTime.fromMillisecondsSinceEpoch(createdAt, isUtc: true);
  String p(int n) => n.toString().padLeft(2, '0');
  return brandName('${d.year}-${p(d.month)}-${p(d.day)}_$id');
}

final _driveId = RegExp(r'^[A-Za-z0-9_-]{1,200}$');
final _safeMime = RegExp(r'^(image/(jpeg|png|gif|webp|avif|heic|heif)|video/[a-z0-9.+-]+|audio/[a-z0-9.+-]+)$', caseSensitive: false);
final _unsafeChars = RegExp('[\\u0000-\\u001f\\u007f\\u200e\\u200f\\u202a-\\u202e\\u2066-\\u2069\\ufeff]');

/// Control characters and bidi overrides let a name pretend to be something else.
String cleanName(Object? s, [int max = 200]) {
  final t = (s ?? '').toString().replaceAll(_unsafeChars, '').replaceAll(RegExp(r'[\\/]'), '_');
  return t.length > max ? t.substring(0, max) : t;
}

int _nat(Object? n) {
  final v = n is num ? n : num.tryParse('$n');
  return v != null && v > 0 && v.isFinite ? v.round().clamp(0, 1000000000000) : 0;
}

/// One line of untrusted text: control and bidi characters out, whitespace collapsed, length-limited.
String cleanText(Object? s, [int max = 300]) {
  final t = (s ?? '').toString().replaceAll(_unsafeChars, ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length > max ? t.substring(0, max) : t;
}

/// The link card of a post (Open Graph data somebody else wrote): http(s) only, plain limited text,
/// the picture is just the id of a file in the post's own Drive folder.
Map<String, dynamic>? cleanLink(Object? raw) {
  if (raw is! Map) return null;
  final u = Uri.tryParse('${raw['url']}');
  if (u == null || !(u.scheme == 'http' || u.scheme == 'https') || u.host.isEmpty) return null;
  final url = u.toString();
  return {
    'url': url.length > 2000 ? url.substring(0, 2000) : url,
    'title': cleanText(raw['title'], 200),
    'description': cleanText(raw['description'], 500),
    'site': cleanText(raw['site'], 80),
    'image': _id(raw['image']) ? raw['image'] : null,
  };
}

bool _id(Object? v) => v is String && _driveId.hasMatch(v);

/// post.json is written by another person: ids must look like Drive ids and only passively-played media
/// types keep their type; anything else is a plain download labelled application/octet-stream.
Map<String, dynamic> publicMedia(Object? raw) {
  final m = raw is Map ? raw : const {};
  final declared = (m['mime'] ?? '').toString().toLowerCase().split(';').first.trim();
  var kind = 'file';
  if (_safeMime.hasMatch(declared)) {
    kind = declared.startsWith('video/') ? 'video' : declared.startsWith('audio/') ? 'audio' : m['kind'] == 'file' ? 'file' : 'image';
  }
  final out = <String, dynamic>{
    'id': _id(m['id']) ? m['id'] : '',
    'thumb': _id(m['thumb']) ? m['thumb'] : null,
    'name': cleanName(m['name']),
    'mime': kind == 'file' ? 'application/octet-stream' : declared,
    'w': _nat(m['w']),
    'h': _nat(m['h']),
    'size': _nat(m['size']),
  };
  if (kind == 'video' || kind == 'audio') {
    out['kind'] = kind;
    out['duration'] = _nat(m['duration']);
  } else if (kind == 'file') {
    out['kind'] = 'file';
  }
  return out;
}

bool isVisual(Map m) => m['kind'] == null || m['kind'] == 'image' || m['kind'] == 'video';

Map<String, String> cleanAudience(Object? aud, String ownerEmail) {
  final out = <String, String>{};
  if (aud is Map) {
    aud.forEach((k, v) {
      final e = normEmail(k);
      if (e.isEmpty || e == normEmail(ownerEmail)) return;
      out[e] = v == roleComment ? roleComment : roleView;
    });
  }
  return out;
}

Future<Map<String, dynamic>> buildPostDoc({
  required String id,
  required Map<String, String> owner,
  required int createdAt,
  required int updatedAt,
  required String text,
  required List<Map<String, dynamic>> media,
  required List<String> mentions,
  required Map<String, String> audience,
  required bool linkShare,
  required String commentMode,
  String? cj,
  String? lj,
  Map<String, dynamic>? protection,
  SecretKey? key,
  Map<String, dynamic>? link,
}) async {
  final body = <String, dynamic>{'text': text, 'media': media.map(publicMedia).toList(), 'mentions': mentions};
  final card = cleanLink(link);
  if (card != null) body['link'] = card; // inside the sealed payload of a protected post
  final base = <String, dynamic>{
    'v': schema,
    'id': id,
    'owner': {'email': normEmail(owner['email']), 'name': cleanName(owner['name'], 120)},
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'audience': cleanAudience(audience, owner['email'] ?? ''),
    'linkShare': linkShare,
    'commentMode': normMode(commentMode),
    'cj': cj,
    'lj': lj,
  };
  if (protection != null) {
    if (key == null) throw StateError('content key required');
    return {...base, 'protection': protection, 'payload': await encryptJson(key, body, 'post:$id')};
  }
  return {...base, 'protection': null, ...body};
}

/// Post as the UI works with it, from a post.json document (plus the content key for protected posts).
Future<Map<String, dynamic>> openPostDoc(Map<String, dynamic> doc, SecretKey? key) async {
  if (doc['v'] != schema) throw StateError('unsupported-version');
  final isProtected = doc['protection'] != null;
  Map<String, dynamic> body = {'text': doc['text'] ?? '', 'media': doc['media'] ?? [], 'mentions': doc['mentions'] ?? [], 'link': doc['link']};
  var locked = false;
  if (isProtected) {
    if (key != null) {
      body = Map<String, dynamic>.from(await decryptJson(key, doc['payload'] as String, 'post:${doc['id']}') as Map);
    } else {
      body = {'text': '', 'media': [], 'mentions': []};
      locked = true;
    }
  }
  final owner = doc['owner'] is Map ? doc['owner'] as Map : const {};
  final media = body['media'] is List ? (body['media'] as List) : const [];
  return {
    'pid': doc['id'],
    'owner': {'email': normEmail(owner['email']), 'name': cleanName(owner['name'], 120)},
    'createdAt': doc['createdAt'] ?? 0,
    'updatedAt': doc['updatedAt'] ?? 0,
    'protected': isProtected,
    'locked': locked,
    'linkShare': doc['linkShare'] == true,
    'commentMode': normMode(doc['commentMode']),
    'cj': doc['cj'],
    'lj': doc['lj'],
    'text': (body['text'] ?? '').toString(),
    'link': cleanLink(body['link']),
    'media': media.map(publicMedia).where((m) => (m['id'] as String).isNotEmpty).toList(),
    'mentions': body['mentions'] ?? [],
    'audience': cleanAudience(doc['audience'], owner['email']?.toString() ?? ''),
    'protection': doc['protection'],
  };
}

final _email = r'[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}';
final _mention = RegExp('(?<![A-Za-z0-9._%+-])@($_email)');
List<String> extractMentions(String text) => {for (final m in _mention.allMatches(text)) normEmail(m.group(1))}.toList();

String prettyName(String email) {
  final local = email.split('@').first.replaceAll(RegExp(r'[._+-]+'), ' ').replaceAll(RegExp(r'\d+$'), '').trim();
  final base = local.isEmpty ? email : local;
  return base.replaceAllMapped(RegExp(r'\b\p{L}', unicode: true), (m) => m.group(0)!.toUpperCase());
}

String prettyJson(Object? o) => const JsonEncoder.withIndent('  ').convert(o);
