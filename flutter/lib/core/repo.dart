/// All Drive domain logic for the mobile app (port of src/services/repo.js, phase 1:
/// browse mine + shared, open posts, photos, comments, likes, create/delete, share, password-protected posts).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'config.dart';
import 'crypto.dart';
import 'drive.dart';
import 'media_cache.dart';
import 'media_kinds.dart';
import 'post_model.dart';
import 'vault.dart';

class RepoError implements Exception {
  RepoError(this.code);
  final String code; // not-found | forbidden | offline | locked | wrong-password | comments-locked | too-many-images | not-a-post
  @override
  String toString() => 'RepoError($code)';
}

const _folderFields = 'id,name,createdTime,modifiedTime,trashed,properties,owners(emailAddress,displayName)';

/// One attachment ready to upload: a re-encoded photo, a video (+poster), a voice recording or a document.
class NewMedia {
  NewMedia({required this.main, this.thumb, this.w = 0, this.h = 0, required this.name, this.kind = 'image', String? mime, this.duration = 0}) : mime = mime ?? 'image/jpeg';
  final Uint8List main;
  final Uint8List? thumb;
  final int w, h;
  final String name;
  final String kind; // image | video | audio | file
  final String mime;
  final num duration; // seconds, video and audio only
}

class DriveRepo {
  DriveRepo({required this.drive, required String email, String? name, required this.vault})
      : me = (email: normEmail(email), name: (name == null || name.isEmpty) ? prettyName(email) : name);

  final DriveClient drive;
  final Vault vault;
  final ({String email, String name}) me;
  Map<String, String>? _layout;
  final Map<String, SecretKey> _keys = {};
  Map<String, dynamic>? _rawKeys;
  final Map<String, Uint8List> _bytes = {};
  late final MediaCache _cache = MediaCache(vault);

  Map<String, dynamic> _mapErrCheck(Object e) => throw _mapErr(e);

  Object _mapErr(Object e) {
    if (e is RepoError) return e;
    if (e is DriveError) {
      if (e.notFound) return RepoError('not-found');
      if (e.forbidden) return RepoError('forbidden');
      if (e.status == 0) return RepoError('offline');
    }
    return e;
  }

  /* ================= layout ================= */
  Future<Map<String, String>> ensureLayout() async {
    if (_layout != null) return _layout!;
    final root = await _findOrCreateFolder(Config.rootFolder, 'root', {'specact': 'root', 'v': '1'});
    final posts = await _findOrCreateFolder(Config.postsFolder, root['id'] as String, {'specact': 'posts', 'v': '1'});
    return _layout = {'rootId': root['id'] as String, 'postsId': posts['id'] as String};
  }

  Future<Map<String, dynamic>> _findOrCreateFolder(String name, String parentId, Map<String, String> props) async {
    final found = await drive.list(q: "name = ${qs(name)} and ${qs(parentId)} in parents and mimeType = ${qs(mimeFolder)} and trashed = false", fields: 'id,name,properties,createdTime', orderBy: 'createdTime', pageSize: 10);
    if (found.isNotEmpty) {
      final hit = found.firstWhere((f) => (f['properties'] as Map?)?['specact'] != null, orElse: () => found.first);
      if ((hit['properties'] as Map?)?['specact'] == null) await drive.updateMeta(hit['id'] as String, {'properties': props});
      return hit;
    }
    return drive.createFolder(name, parentId, props);
  }

  /* ================= keys of protected posts ================= */
  Future<Map<String, dynamic>> _loadRawKeys() async => _rawKeys ??= Map<String, dynamic>.from((await vault.get('postkeys:${me.email}', <String, dynamic>{})) as Map);

  Future<void> _rememberKey(String folderId, Uint8List raw, bool persist) async {
    _keys[folderId] = rawKey(raw);
    if (persist) {
      final s = await _loadRawKeys();
      s[folderId] = b64e(raw);
      await vault.set('postkeys:${me.email}', s);
    }
  }

  Future<void> restoreKeys() async {
    (await _loadRawKeys()).forEach((id, b) {
      try {
        _keys[id] = rawKey(b64d(b as String));
      } catch (_) {}
    });
  }

  bool hasKey(String folderId) => _keys.containsKey(folderId);

  Future<void> unlockPost(String folderId, Map<String, dynamic> doc, String password, {bool remember = false}) async {
    if (doc['protection'] == null) return;
    try {
      final p = await unlockProtection(Map<String, dynamic>.from(doc['protection'] as Map), password);
      await _rememberKey(folderId, p.raw, remember);
    } on CryptoError catch (e) {
      throw RepoError(e.code == 'wrong-password' ? 'wrong-password' : 'forbidden');
    }
  }

  /* ================= browsing ================= */
  bool _isPost(Map f) => (f['properties'] as Map?)?['specact'] == 'post';

  /// Lists folder metadata, then reads post.json only for posts whose `rev` changed since [known].
  Future<List<Map<String, dynamic>>> listPosts({required bool mine, List<Map<String, dynamic>> known = const []}) async {
    final L = await ensureLayout();
    List<Map<String, dynamic>> folders;
    if (mine) {
      folders = await drive.list(q: "${qs(L['postsId']!)} in parents and mimeType = ${qs(mimeFolder)} and trashed = false", fields: _folderFields);
    } else {
      final base = "sharedWithMe = true and mimeType = ${qs(mimeFolder)} and trashed = false";
      try {
        folders = await drive.list(q: "$base and properties has { key='specact' and value='post' }", fields: _folderFields);
      } on DriveError catch (e) {
        if (e.status != 400) rethrow;
        folders = await drive.list(q: base, fields: _folderFields);
      }
    }
    final byId = {for (final e in known) e['id'] as String: e};
    final out = <Map<String, dynamic>>[];
    final todo = <Map<String, dynamic>>[];
    for (final f in folders.where(_isPost)) {
      final old = byId[f['id']];
      final rev = ((f['properties'] as Map?)?['rev'] ?? f['modifiedTime']).toString();
      if (old != null && '${old['rev']}' == rev && old['locked'] != true) {
        out.add(old);
      } else {
        todo.add(f);
      }
    }
    final fresh = await Future.wait(todo.map((f) async {
      try {
        return await _entryFromFolder(f);
      } catch (e) {
        if (e is DriveError && (e.notFound || e.forbidden)) return null;
        return byId[f['id']];
      }
    }));
    out.addAll(fresh.whereType<Map<String, dynamic>>());
    out.sort((a, b) => ((b['createdAt'] ?? 0) as int).compareTo((a['createdAt'] ?? 0) as int));
    return out;
  }

  Future<Map<String, String?>> _idsOf(Map f) async {
    final p = (f['properties'] as Map?) ?? const {};
    if (p['pj'] != null && p['cj'] != null && p['lj'] != null) return {'pj': p['pj'], 'cj': p['cj'], 'mf': p['mf'], 'lj': p['lj']};
    final kids = await drive.list(q: "${qs(f['id'] as String)} in parents and trashed = false", fields: 'id,name,mimeType');
    String? find(String n) => kids.where((k) => k['name'] == n || k['name'] == brandName(n)).map((k) => k['id'] as String).firstOrNull;
    final pj = find('post.json');
    if (pj == null) throw RepoError('not-a-post');
    return {'pj': pj, 'cj': find('comments.json'), 'mf': find('media'), 'lj': find('likes.json')};
  }

  Future<Map<String, dynamic>> _entryFromFolder(Map<String, dynamic> f) async {
    final id = f['id'] as String;
    final ids = await _idsOf(f);
    final doc = await drive.downloadJson(ids['pj']!);
    final post = await openPostDoc(doc, _keys[id]);
    return _decorate(post, f, id, ids, doc);
  }

  Map<String, dynamic> _decorate(Map<String, dynamic> post, Map f, String id, Map<String, String?> ids, Map<String, dynamic> doc) {
    final owners = (f['owners'] as List?) ?? const [];
    final o0 = owners.isNotEmpty ? owners.first as Map : const {};
    final ownerEmail = (post['owner']['email'] as String).isNotEmpty ? post['owner']['email'] as String : normEmail(o0['emailAddress']);
    final ownerName = (post['owner']['name'] as String).isNotEmpty ? post['owner']['name'] as String : cleanName(o0['displayName'] ?? prettyName(ownerEmail), 120);
    return {
      ...post,
      'id': id,
      'ids': ids,
      'doc': doc,
      'owner': {'email': ownerEmail, 'name': ownerName},
      'mine': ownerEmail == me.email,
      'rev': ((f['properties'] as Map?)?['rev'] ?? f['modifiedTime'] ?? post['updatedAt']).toString(),
    };
  }

  /// Full post by Drive folder id (role: owner | comment | view).
  Future<Map<String, dynamic>> openPost(String id) async {
    Map<String, dynamic> meta;
    try {
      meta = await drive.get(id, _folderFields);
    } catch (e) {
      throw _mapErr(e);
    }
    if (meta['trashed'] == true) throw RepoError('not-found');
    if (!_isPost(meta)) throw RepoError('not-a-post');
    final ids = await _idsOf(meta);
    Map<String, dynamic> doc;
    try {
      doc = await drive.downloadJson(ids['pj']!);
    } catch (e) {
      throw _mapErr(e);
    }
    final post = _decorate(await openPostDoc(doc, _keys[id]), meta, id, ids, doc);
    var role = 'owner';
    if (post['mine'] != true) {
      role = roleView;
      final cj = ids['cj'];
      if (cj != null) {
        try {
          final c = await drive.get(cj, 'capabilities(canEdit)');
          if ((c['capabilities'] as Map?)?['canEdit'] == true) role = roleComment;
        } catch (_) {}
      }
    }
    return {...post, 'role': role};
  }

  /* ================= media ================= */
  Future<Uint8List> mediaBytes(Map<String, dynamic> post, Map item, {bool thumb = false}) async {
    final fileId = (thumb ? (item['thumb'] ?? item['id']) : item['id']) as String;
    final hit = _bytes[fileId];
    if (hit != null) return hit;
    // the encrypted copy on this phone first, then Drive
    var bytes = await _cache.get(fileId);
    if (bytes == null) {
      bytes = await drive.downloadBytes(fileId, high: !thumb);
      unawaited(_cache.put(fileId, bytes));
    }
    if (post['protected'] == true) {
      final key = _keys[post['id']];
      if (key == null) throw RepoError('locked');
      bytes = await decryptBytes(key, bytes, 'media:${post['pid']}');
    }
    if (_bytes.length > 120) _bytes.remove(_bytes.keys.first);
    return _bytes[fileId] = bytes;
  }

  /* ================= comments & likes ================= */
  Future<({List<Map<String, dynamic>> comments, List<String> likes})> loadComments(Map<String, dynamic> post) async {
    var comments = <Map<String, dynamic>>[];
    var likes = <String>[];
    final ids = post['ids'] as Map;
    if (ids['cj'] != null) {
      final data = await drive.downloadJson(ids['cj'] as String).catchError((e) => _mapErrCheck(e));
      final r = await _openComments(post, data);
      comments = r.comments;
      likes = r.likes;
    }
    if (ids['lj'] != null) {
      try {
        final l = await drive.downloadJson(ids['lj'] as String);
        likes = ((l['likes'] as List?) ?? []).map(normEmail).toList();
      } catch (_) {}
    }
    return (comments: comments, likes: likes);
  }

  Future<({List<Map<String, dynamic>> comments, List<String> likes})> _openComments(Map<String, dynamic> post, Map<String, dynamic> data) async {
    final key = post['protected'] == true ? _keys[post['id']] : null;
    final out = <Map<String, dynamic>>[];
    for (final raw in (data['comments'] as List?) ?? const []) {
      final c = raw as Map;
      final base = {'id': c['id'], 'by': normEmail(c['by']), 'name': cleanName(c['name'], 120), 'at': c['at']};
      if (c['enc'] != null) {
        if (key == null) continue;
        try {
          out.add({...base, 'text': (await decryptJson(key, c['enc'] as String, 'comment:${c['id']}'))['text']});
        } catch (_) {}
      } else {
        out.add({...base, 'text': (c['text'] ?? '').toString()});
      }
    }
    return (comments: out, likes: ((data['likes'] as List?) ?? []).map(normEmail).toList());
  }

  Future<List<Map<String, dynamic>>> _mutateComments(Map<String, dynamic> post, void Function(Map<String, dynamic>) fn) async {
    final cj = (post['ids'] as Map)['cj'] as String?;
    if (cj == null) throw RepoError('forbidden');
    final data = await drive.downloadJson(cj);
    data['comments'] = List<dynamic>.from((data['comments'] as List?) ?? []);
    data['likes'] ??= [];
    fn(data);
    try {
      await drive.updateJson(cj, data);
    } catch (e) {
      throw _mapErr(e);
    }
    return (await _openComments(post, data)).comments;
  }

  Future<List<Map<String, dynamic>>?> addComment(Map<String, dynamic> post, String text) async {
    final value = text.trim();
    if (value.isEmpty) return null;
    if (post['locked'] == true) throw RepoError('locked');
    if (post['commentMode'] == 'locked') throw RepoError('comments-locked');
    final id = randomId(5);
    final entry = <String, dynamic>{'id': id, 'by': me.email, 'name': me.name, 'at': DateTime.now().millisecondsSinceEpoch};
    if (post['protected'] == true) {
      final key = _keys[post['id']];
      if (key == null) throw RepoError('locked');
      entry['enc'] = await encryptJson(key, {'text': value}, 'comment:$id');
    } else {
      entry['text'] = value;
    }
    return _mutateComments(post, (d) => (d['comments'] as List).add(entry));
  }

  Future<List<Map<String, dynamic>>> deleteComment(Map<String, dynamic> post, String commentId) => _mutateComments(post, (d) {
        final list = d['comments'] as List;
        final i = list.indexWhere((c) => (c as Map)['id'] == commentId);
        if (i < 0) return;
        if (normEmail((list[i] as Map)['by']) != me.email && post['mine'] != true) throw RepoError('forbidden');
        list.removeAt(i);
      });

  /// Likes live in likes.json, writable by everyone the post is open to.
  Future<List<String>> toggleLike(Map<String, dynamic> post) async {
    final lj = (post['ids'] as Map)['lj'] as String?;
    if (lj == null) throw RepoError('forbidden');
    try {
      final data = await drive.downloadJson(lj);
      final likes = ((data['likes'] as List?) ?? []).map(normEmail).toList();
      data['likes'] = likes.contains(me.email) ? likes.where((x) => x != me.email).toList() : [...likes, me.email];
      await drive.updateJson(lj, data);
      return List<String>.from(data['likes'] as List);
    } catch (e) {
      throw _mapErr(e);
    }
  }

  /* ================= sharing ================= */
  Future<({List<Map<String, dynamic>> perms, Map<String, Map<String, dynamic>> map})> _permsByEmail(String fileId) async {
    final perms = await drive.listPermissions(fileId);
    return (perms: perms, map: {for (final p in perms) if (p['type'] == 'user' && p['emailAddress'] != null) normEmail(p['emailAddress']): p});
  }

  Future<void> _setCommentAccess(String fileId, String email, bool allow) async {
    final have = (await _permsByEmail(fileId)).map[email];
    if (allow) {
      if (have != null && (have['role'] == 'writer' || have['role'] == 'owner')) return;
      try {
        await drive.addPermission(fileId, email: email, role: 'writer');
      } catch (e) {
        if (have == null) rethrow;
        await drive.updatePermission(fileId, have['id'] as String, 'writer');
      }
    } else if (have != null && have['role'] == 'writer') {
      try {
        await drive.removePermission(fileId, have['id'] as String);
      } catch (_) {
        await drive.updatePermission(fileId, have['id'] as String, 'reader');
      }
    }
  }

  /// view -> reader on the folder; comment -> also writer on comments.json only; everyone who sees the post may like.
  Future<void> _grant(String folderId, String? cj, String email, String role, String mode, String? lj) async {
    final folder = await _permsByEmail(folderId);
    if (!folder.map.containsKey(email)) await drive.addPermission(folderId, email: email, role: 'reader');
    if (cj != null) await _setCommentAccess(cj, email, canCommentWith(mode, role));
    if (lj != null) await _setCommentAccess(lj, email, true);
  }

  Future<void> _setAnyone(String fileId, String role, bool enabled) async {
    final any = (await _permsByEmail(fileId)).perms.where((p) => p['type'] == 'anyone').firstOrNull;
    if (enabled) {
      if (any == null) {
        await drive.addPermission(fileId, type: 'anyone', role: role);
      } else if (any['role'] != role) {
        await drive.updatePermission(fileId, any['id'] as String, role);
      }
    } else if (any != null) {
      try {
        await drive.removePermission(fileId, any['id'] as String);
      } on DriveError catch (e) {
        if (!e.notFound) rethrow;
      }
    }
  }

  /// "Anyone with the link" is granted on individual FILES only (post.json + photos), never on the folder or comments.json.
  Future<void> _applyLink(String pj, List<Map<String, dynamic>> media) async {
    final ids = [pj, ...media.expand((m) => [m['id'], m['thumb']])].whereType<String>().toSet();
    for (final id in ids) {
      await _setAnyone(id, 'reader', true);
    }
  }

  /* ================= writing ================= */
  Future<({Map<String, dynamic> post, List<String> warnings})> createPost({
    required String text,
    List<NewMedia> media = const [],
    Map<String, String> audience = const {},
    String commentMode = 'shared',
    bool linkShare = false,
    String? password,
    Map<String, dynamic>? link,
    NewMedia? linkImage,
    void Function(String stage, int done, int total)? onProgress,
  }) async {
    final L = await ensureLayout();
    if (media.length > Config.maxImagesPerPost) throw RepoError('too-many-images');
    final id = randomId(5);
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final prot = (password != null && password.isNotEmpty) ? await createProtection(password, Config.postKdfIterations) : null;
    final aud = cleanAudience(audience, me.email);
    final mode = normMode(commentMode);
    final warnings = <String>[];
    final folder = await drive.createFolder(folderNameFor(createdAt, id), L['postsId'], {'specact': 'post', 'v': '1', 'rev': '$createdAt'});
    final folderId = folder['id'] as String;
    try {
      final mf = await drive.createFolder('media', folderId);
      final items = <Map<String, dynamic>>[];
      for (var i = 0; i < media.length; i++) {
        onProgress?.call('upload', i, media.length);
        items.add(await _uploadMedia(media[i], mf['id'] as String, prot?.key, id));
      }
      final card = await _linkCard(link, linkImage, mf['id'] as String, prot?.key, id);
      final cj = await drive.createJson(brandName('comments.json'), folderId, {'v': 1, 'comments': [], 'likes': []});
      final lj = await drive.createJson(brandName('likes.json'), folderId, {'v': 1, 'likes': []});
      final doc = await buildPostDoc(
        id: id, owner: {'email': me.email, 'name': me.name}, createdAt: createdAt, updatedAt: createdAt, text: text, media: items,
        mentions: extractMentions(text), audience: aud, linkShare: linkShare, commentMode: mode, cj: cj['id'] as String, lj: lj['id'] as String,
        protection: prot?.meta, key: prot?.key, link: card,
      );
      final pj = await drive.createJson('post.json', folderId, doc);
      final ids = <String, String?>{'pj': pj['id'] as String, 'cj': cj['id'] as String, 'lj': lj['id'] as String, 'mf': mf['id'] as String};
      await drive.updateMeta(folderId, {'properties': {'specact': 'post', 'v': '1', 'rev': '$createdAt', 'pj': ids['pj'], 'cj': ids['cj'], 'lj': ids['lj'], 'mf': ids['mf']}});

      // nothing is shared until the content is complete
      onProgress?.call('share', 0, 0);
      final audienceOut = Map<String, String>.from(aud);
      for (final e in aud.entries) {
        try {
          await _grant(folderId, ids['cj'], e.key, e.value, mode, ids['lj']);
        } catch (_) {
          warnings.add(e.key);
          audienceOut.remove(e.key);
        }
      }
      var isPublic = linkShare;
      if (isPublic) {
        try {
          await _applyLink(ids['pj']!, card?['image'] == null ? items : [...items, {'id': card!['image'], 'thumb': null}]);
          await _setAnyone(ids['lj']!, 'writer', true);
          if (mode == 'open') await _setAnyone(ids['cj']!, 'writer', true);
        } catch (_) {
          isPublic = false;
          warnings.add('*');
        }
      }
      if (warnings.isNotEmpty) {
        doc['audience'] = audienceOut;
        doc['linkShare'] = isPublic;
        await drive.updateJson(ids['pj']!, doc);
      }
      if (prot != null) await _rememberKey(folderId, prot.raw, true);
      final post = _decorate(await openPostDoc(doc, prot?.key), {'properties': {'rev': '$createdAt'}}, folderId, ids, doc);
      return (post: {...post, 'role': 'owner'}, warnings: warnings);
    } catch (e) {
      try {
        await drive.trash(folderId);
      } catch (_) {}
      throw _mapErr(e);
    }
  }

  Future<Map<String, dynamic>> _uploadMedia(NewMedia m, String mediaFolderId, SecretKey? key, String pid) async {
    final base = randomId(5);
    Future<Map<String, dynamic>> put(Uint8List bytes, String stem, String mime, String ext, {bool large = false}) async {
      Future<Map<String, dynamic>> create(String name, String mt, Uint8List data) =>
          large ? drive.createFileLarge(name: name, parentId: mediaFolderId, mimeType: mt, data: data) : drive.createFile(name: name, parentId: mediaFolderId, mimeType: mt, data: data);
      if (key == null) return create('$stem.$ext', mime, bytes);
      // protected posts: bytes are sealed before upload and carry an opaque name
      return create('$stem.bin', 'application/octet-stream', await encryptBytes(key, bytes, 'media:$pid'));
    }

    final clean = m.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final ext = m.kind == 'image' ? 'jpg' : (extOf(m.name).isNotEmpty ? extOf(m.name) : (m.mime.split('/').last));
    final main = await put(m.main, key != null ? base : '${base}_$clean', m.mime, ext, large: m.kind != 'image');
    final thumb = m.thumb == null ? null : await put(m.thumb!, '${base}_t', 'image/jpeg', 'jpg');
    final item = <String, dynamic>{'id': main['id'], 'thumb': thumb?['id'], 'name': m.name, 'mime': m.mime, 'w': m.w, 'h': m.h, 'size': m.main.length};
    if (m.kind != 'image') {
      item['kind'] = m.kind;
      if (m.kind != 'file') item['duration'] = m.duration.round();
    }
    return item;
  }

  /// The card's picture is one more file of the post (sealed like any photo in a protected post); the card keeps only its id.
  Future<Map<String, dynamic>?> _linkCard(Map<String, dynamic>? link, NewMedia? image, String mediaFolderId, SecretKey? key, String pid) async {
    final card = cleanLink(link);
    if (card == null) return null;
    card['image'] = null;
    if (image != null) {
      try {
        card['image'] = (await _uploadMedia(image, mediaFolderId, key, pid))['id'];
      } catch (_) {/* a card without a picture is fine */}
    }
    return card;
  }

  Future<void> deletePost(Map<String, dynamic> post) async {
    try {
      await drive.trash(post['id'] as String);
    } catch (e) {
      throw _mapErr(e);
    }
  }

  Future<Map<String, dynamic>> quota() async => (await drive.about())['storageQuota'] as Map<String, dynamic>? ?? {};
}

String prettyJsonDebug(Object? o) => jsonEncode(o);
