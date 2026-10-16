import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:specact/core/repo.dart';
import 'package:specact/core/vault.dart';

import 'package:specact/core/memory_drive.dart';

Future<DriveRepo> repoFor(MemoryStore s, String email) async {
  final v = Vault(store: MemoryKeyValueStore(), iterations: 1000);
  await v.create('135790');
  return DriveRepo(drive: MemoryDrive(s, email), email: email, vault: v);
}

NewMedia img(String name) => NewMedia(main: Uint8List.fromList([1, 2, 3, 4]), thumb: Uint8List.fromList([9, 9]), w: 2, h: 2, name: name);

void main() {
  late MemoryStore store;
  late DriveRepo ann, bob, eve;

  setUp(() async {
    store = MemoryStore();
    ann = await repoFor(store, 'ann@x.com');
    bob = await repoFor(store, 'bob@x.com');
    eve = await repoFor(store, 'eve@x.com');
  });

  test('creates the open-format layout and a post that the owner lists', () async {
    final r = await ann.createPost(text: 'xin chào', media: [img('a.jpg')]);
    final root = store.nodes.values.firstWhere((n) => n.name == 'SPECACT');
    expect(root.props['specact'], 'root');
    final folder = store.nodes[r.post['id']]!;
    expect(folder.name, startsWith('__S.P.E.C.T.A.C.T__ '));
    expect(folder.props['specact'], 'post');
    final kids = store.nodes.values.where((n) => n.parent == folder.id).map((n) => n.name).toSet();
    expect(kids, containsAll(['post.json', '__S.P.E.C.T.A.C.T__ comments.json', '__S.P.E.C.T.A.C.T__ likes.json', 'media']));
    final mine = await ann.listPosts(mine: true);
    expect(mine.single['text'], 'xin chào');
    expect(mine.single['mine'], true);
  });

  test('sharing: only invited people see it; commenter can comment, viewer cannot; both can like', () async {
    final r = await ann.createPost(text: 'hi', audience: {'bob@x.com': 'comment', 'eve@x.com': 'view'});
    final id = r.post['id'] as String;
    final bobPost = await bob.openPost(id);
    expect(bobPost['role'], 'comment');
    expect((await eve.openPost(id))['role'], 'view');
    final sharedForBob = await bob.listPosts(mine: false);
    expect(sharedForBob.single['id'], id);

    final out = await bob.addComment(bobPost, 'đẹp quá');
    expect(out!.single['text'], 'đẹp quá');
    final evePost = await eve.openPost(id);
    await expectLater(eve.addComment(evePost, 'nope'), throwsA(isA<RepoError>()));
    expect(await eve.toggleLike(evePost), ['eve@x.com']);
    final c = await ann.loadComments(await ann.openPost(id));
    expect(c.comments.single['by'], 'bob@x.com');
    expect(c.likes, ['eve@x.com']);

    final stranger = await repoFor(store, 'mallory@x.com');
    await expectLater(stranger.openPost(id), throwsA(isA<RepoError>().having((e) => e.code, 'code', 'not-found')));
  });

  test('link sharing opens files only, never the folder or comments.json', () async {
    final r = await ann.createPost(text: 'public', media: [img('a.jpg')], linkShare: true);
    final folder = store.nodes[r.post['id']]!;
    expect(folder.perms.where((p) => p['type'] == 'anyone'), isEmpty);
    final cj = store.nodes.values.firstWhere((n) => n.name.endsWith('comments.json'));
    expect(cj.perms.where((p) => p['type'] == 'anyone'), isEmpty);
    final pj = store.nodes.values.firstWhere((n) => n.name == 'post.json');
    expect(pj.perms.any((p) => p['type'] == 'anyone' && p['role'] == 'reader'), true);
  });

  test('locked comment mode blocks comments; password-protected posts are sealed in Drive', () async {
    final r = await ann.createPost(text: 'top secret', media: [img('s.jpg')], password: 'hunter22', audience: {'bob@x.com': 'comment'});
    final id = r.post['id'] as String;
    final raw = store.nodes.values.firstWhere((n) => n.name == 'post.json').data!;
    expect(String.fromCharCodes(raw).contains('top secret'), false);
    expect(store.nodes.values.where((n) => n.parent != null && store.nodes[n.parent]?.name == 'media').every((n) => n.name.endsWith('.bin')), true);

    final bp = await bob.openPost(id);
    expect(bp['locked'], true);
    await expectLater(bob.unlockPost(id, bp['doc'] as Map<String, dynamic>, 'wrong'), throwsA(isA<RepoError>().having((e) => e.code, 'code', 'wrong-password')));
    await bob.unlockPost(id, bp['doc'] as Map<String, dynamic>, 'hunter22');
    final opened = await bob.openPost(id);
    expect(opened['text'], 'top secret');
    expect((await bob.mediaBytes(opened, (opened['media'] as List).first as Map)), [1, 2, 3, 4]);

    final r2 = await ann.createPost(text: 'x', commentMode: 'locked', audience: {'bob@x.com': 'comment'});
    final p2 = await bob.openPost(r2.post['id'] as String);
    await expectLater(bob.addComment(p2, 'hi'), throwsA(isA<RepoError>().having((e) => e.code, 'code', 'comments-locked')));
  });

  test('videos, voice notes and documents are uploaded, listed apart and survive a round trip', () async {
    final r = await ann.createPost(text: 'mix', audience: {'bob@x.com': 'view'}, media: [
      img('a.jpg'),
      NewMedia(main: Uint8List.fromList([5, 5, 5]), thumb: Uint8List.fromList([8]), name: 'clip.mp4', kind: 'video', mime: 'video/mp4', w: 640, h: 360, duration: 12),
      NewMedia(main: Uint8List.fromList([6, 6]), name: 'note.m4a', kind: 'audio', mime: 'audio/mp4', duration: 7),
      NewMedia(main: Uint8List.fromList([7]), name: 'plan.pdf', kind: 'file', mime: 'application/pdf'),
    ]);
    final bp = await bob.openPost(r.post['id'] as String);
    final m = (bp['media'] as List).cast<Map>();
    expect(m.map((e) => e['kind']), [null, 'video', 'audio', 'file']);
    expect(m[1]['duration'], 12);
    expect(m[1]['thumb'], isNotNull);
    expect(m[2]['thumb'], isNull);
    expect(m[3]['mime'], 'application/octet-stream'); // documents are never typed as anything renderable
    expect(await bob.mediaBytes(bp, m[2]), [6, 6]);
  });

  test('a photo is downloaded once, then served from the encrypted copy on the device', () async {
    final r = await ann.createPost(text: 'x', media: [img('a.jpg')]);
    final drive = ann.drive as MemoryDrive;
    final item = (r.post['media'] as List).first as Map;
    expect(await ann.mediaBytes(r.post, item), [1, 2, 3, 4]);
    expect(drive.downloads, hasLength(1));
  });

  test('delete moves the post to trash', () async {
    final r = await ann.createPost(text: 'bye');
    await ann.deletePost(r.post);
    expect(await ann.listPosts(mine: true), isEmpty);
  });
}
