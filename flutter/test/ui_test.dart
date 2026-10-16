import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:specact/core/legal.dart';
import 'package:specact/core/repo.dart';
import 'package:specact/core/vault.dart';
import 'package:specact/i18n.dart';
import 'package:specact/main.dart';
import 'package:specact/state.dart';
import 'package:specact/theme.dart';

import 'package:specact/core/memory_drive.dart';

Uint8List jpg(int c) {
  final im = img.Image(width: 400, height: 300);
  img.fill(im, color: img.ColorRgb8(c, 120, 90));
  return Uint8List.fromList(img.encodeJpg(im));
}

Future<DriveRepo> repoFor(MemoryStore s, String email) async {
  final v = Vault(store: MemoryKeyValueStore(), iterations: 1000);
  await v.create('135790');
  return DriveRepo(drive: MemoryDrive(s, email), email: email, vault: v);
}

Future<void> boot(WidgetTester t, AppState app, I18n i18n) async {
  t.view.physicalSize = const Size(390 * 3, 844 * 3);
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: i18n), ChangeNotifierProvider.value(value: app), ChangeNotifierProvider(create: (_) => ThemeController())], child: const SpecActApp()));
  await t.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({'terms.accepted': termsVersion}));
  testWidgets('home feed, post detail and compose render with data', (t) async {
    final store = MemoryStore();
    final ann = await repoFor(store, 'ann@x.com');
    final bob = await repoFor(store, 'bob@x.com');
    final photos = [
      for (final c in [200, 90])
        (await _newImage(c)),
    ];
    final r = await bob.createPost(text: 'Chuyến đi Đà Lạt cuối tuần 🌲', media: photos, audience: {'ann@x.com': 'comment'});
    await ann.createPost(text: 'Bài của tôi, chỉ mình tôi xem.');
    await ann.addComment(await ann.openPost(r.post['id'] as String), 'Đẹp quá!');

    final i18n = I18n()..lang = 'en';
    final app = AppState(vault: Vault(store: MemoryKeyValueStore(), iterations: 1000));
    await app.init();
    app.debugReady(ann);
    await boot(t, app, i18n);
    await t.runAsync(() async => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('Bài của tôi'), findsOneWidget);
    await t.scrollUntilVisible(find.textContaining('Chuyến đi'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Chuyến đi'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.textContaining('Chuyến đi'));
    await t.pump(const Duration(milliseconds: 300));
    await t.runAsync(() async => Future.delayed(const Duration(milliseconds: 500)));
    await t.pump(const Duration(milliseconds: 500));
    expect(find.text('Đẹp quá!'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

Future<NewMedia> _newImage(int c) async => NewMedia(main: jpg(c), thumb: jpg(c), w: 400, h: 300, name: 'p$c.jpg');
