import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:specact/core/link_preview.dart';
import 'package:specact/core/memory_drive.dart';
import 'package:specact/core/post_model.dart';
import 'package:specact/core/repo.dart';
import 'package:specact/core/vault.dart';

const page = '''<!doctype html><html><head><title>Fallback title</title>
<meta property="og:title" content="  A great\u202E article  ">
<meta property="og:description" content="Line one
   line two">
<meta property="og:image" content="/cover.png">
<meta property="og:site_name" content="Example News">
<meta property="og:url" content="https://evil.example/phish">
<script>window.pwned = 1</script></head><body><img src=x onerror="window.pwned=2"></body></html>''';

Future<DriveRepo> repoFor(MemoryStore s, String email) async {
  final v = Vault(store: MemoryKeyValueStore(), iterations: 1000);
  await v.create('135790');
  return DriveRepo(drive: MemoryDrive(s, email), email: email, vault: v);
}

void main() {
  test('reads title, description, picture and site as clean text', () {
    final r = parseOpenGraph(page, 'https://news.example/a/b')!;
    expect(r.link['title'], 'A great article');
    expect(r.link['description'], 'Line one line two');
    expect(r.link['site'], 'Example News');
    expect(r.imageUrl, 'https://news.example/cover.png');
    expect(r.link['url'], 'https://news.example/a/b'); // never the address the page claims
  });

  test('falls back to <title>; pages that say nothing give no card', () {
    expect(parseOpenGraph('<title>Only title</title>', 'https://x.example/')!.link['title'], 'Only title');
    expect(parseOpenGraph('<html><body>hi</body></html>', 'https://x.example/'), isNull);
  });

  test('first link in a text', () {
    expect(firstUrl('look https://a.example/x?y=1, and https://b.example'), 'https://a.example/x?y=1');
    expect(firstUrl('nothing'), '');
  });

  test('hostile cards are neutralised', () {
    expect(cleanLink({'url': 'javascript:alert(1)', 'title': 'x'}), isNull);
    expect(cleanLink({'url': 'data:text/html,<script>', 'title': 'x'}), isNull);
    final c = cleanLink({'url': 'https://ok.example/', 'title': 'T' * 999, 'description': 'a\u0000b\u202Ec', 'image': '../../x'})!;
    expect((c['title'] as String).length, 200);
    expect(c['description'], 'a b c');
    expect(c['image'], isNull);
  });

  test('fetches the page straight from the device and loads the picture (never SVG)', () async {
    final calls = <String>[];
    final client = MockClient((req) async {
      calls.add(req.url.toString());
      if (req.url.path == '/cover.png') return http.Response.bytes([1, 2, 3], 200, headers: {'content-type': 'image/png'});
      return http.Response(page, 200, headers: {'content-type': 'text/html; charset=utf-8'});
    });
    final r = await fetchPreview('https://news.example/a/b', client: client, web: false);
    expect(calls, ['https://news.example/a/b', 'https://news.example/cover.png']);
    expect(r!.link['title'], 'A great article');
    expect(r.image, [1, 2, 3]);

    final svg = MockClient((req) async => req.url.path.endsWith('.png') ? http.Response('<svg onload=alert(1)>', 200, headers: {'content-type': 'image/svg+xml'}) : http.Response(page, 200, headers: {'content-type': 'text/html; charset=utf-8'}));
    expect((await fetchPreview('https://news.example/a', client: svg, web: false))!.image, isNull);
  });

  test('silent on failure, refuses non-http(s), web needs the configured service', () async {
    expect(await fetchPreview('https://x.example/', client: MockClient((_) async => throw Exception('offline')), web: false), isNull);
    expect(await fetchPreview('javascript:alert(1)'), isNull);
    expect(await fetchPreview('https://x.example/', client: MockClient((_) async => http.Response(page, 200, headers: {'content-type': 'text/html; charset=utf-8'})), web: true), isNull); // no LINK_PREVIEW_URL
  });

  test('the card travels with the post: picture is a file of the post, sealed when protected, opened to link visitors', () async {
    final store = MemoryStore();
    final ann = await repoFor(store, 'ann@x.com');
    final bob = await repoFor(store, 'bob@x.com');
    final card = {'url': 'https://news.example/a', 'title': 'Hello', 'description': 'World', 'site': 'News'};
    final pic = NewMedia(main: Uint8List.fromList([9, 9, 9]), name: 'link-preview.jpg');

    final r = await ann.createPost(text: 'https://news.example/a', link: card, linkImage: pic, audience: {'bob@x.com': 'view'});
    expect(r.post['link']['title'], 'Hello');
    expect((r.post['media'] as List), isEmpty);
    final seen = await bob.openPost(r.post['id'] as String);
    expect(seen['link']['site'], 'News');
    expect(await bob.mediaBytes(seen, {'id': seen['link']['image'], 'thumb': null, 'mime': 'image/jpeg'}), [9, 9, 9]);
    expect((await ann.listPosts(mine: true)).single['link']['title'], 'Hello');

    final prot = await ann.createPost(text: 'secret', link: card, linkImage: pic, password: 'hunter22');
    final raw = String.fromCharCodes(store.nodes[(prot.post['ids'] as Map)['pj']]!.data!);
    expect(raw.contains('news.example'), isFalse);
    expect(store.nodes[prot.post['link']['image']]!.name, endsWith('.bin'));

    final pub = await ann.createPost(text: 'public', link: card, linkImage: pic, linkShare: true);
    bool anyone(String id) => store.nodes[id]!.perms.any((p) => p['type'] == 'anyone');
    expect(anyone(pub.post['link']['image'] as String), isTrue);
    expect(anyone(pub.post['id'] as String), isFalse);
    expect(anyone((pub.post['ids'] as Map)['cj'] as String), isFalse);
  });
}
