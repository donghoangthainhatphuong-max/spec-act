/// Demo data for trying the app without Google: an in-memory Drive with a few sample posts.
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'memory_drive.dart';
import 'repo.dart';
import 'vault.dart';

Uint8List _photo(int r, int g, int b) {
  final im = img.Image(width: 480, height: 320);
  for (var y = 0; y < im.height; y++) {
    for (var x = 0; x < im.width; x++) {
      final t = x / im.width;
      im.setPixelRgb(
        x,
        y,
        (r * (1 - t) + 255 * t * 0.35).round(),
        (g * (1 - y / im.height * 0.5)).round(),
        (b * (0.6 + 0.4 * t)).round(),
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 80));
}

NewMedia _img(String name, int r, int g, int b) => NewMedia(
  main: _photo(r, g, b),
  thumb: _photo(r, g, b),
  w: 480,
  h: 320,
  name: name,
);

/// Returns the repo of "You" (you@demo.specact) with a shared and an own post already in place.
Future<DriveRepo> buildDemoRepo() async {
  final store = MemoryStore();
  Future<DriveRepo> repo(String email, String name) async {
    final v = Vault(store: MemoryKeyValueStore(), iterations: 1000);
    await v.create('135790');
    return DriveRepo(
      drive: MemoryDrive(store, email),
      email: email,
      name: name,
      vault: v,
    );
  }

  final me = await repo('you@demo.specact', 'You');
  final lan = await repo('lan@demo.specact', 'Lan Nguyen');
  final shared = await lan.createPost(
    text:
        'Weekend in Da Lat 🌲 The pine forest was so quiet — shared only with you.',
    media: [
      _img('a.jpg', 70, 140, 110),
      _img('b.jpg', 200, 150, 90),
      _img('c.jpg', 90, 110, 170),
      _img('e.jpg', 160, 90, 60),
      _img('f.jpg', 60, 90, 160),
      NewMedia(
        main: Uint8List.fromList(List.filled(2048, 7)),
        name: 'voice-note.m4a',
        kind: 'audio',
        mime: 'audio/mp4',
        duration: 42,
      ),
      NewMedia(
        main: Uint8List.fromList(List.filled(4096, 1)),
        name: 'itinerary.pdf',
        kind: 'file',
        mime: 'application/pdf',
      ),
    ],
    audience: {'you@demo.specact': 'comment'},
  );
  await lan.addComment(
    await lan.openPost(shared.post['id'] as String),
    'Wish you were here!',
  );
  await me.createPost(
    text: 'My own post — only I can see it. Try the + button to write another.',
    media: [_img('d.jpg', 150, 90, 120)],
  );
  return me;
}
