import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:specact/core/legal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:specact/i18n.dart';
import 'package:specact/ui/legal_screen.dart';
import 'package:specact/core/vault.dart';
import 'package:specact/state.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.files);
  final Map<String, String> files;
  @override
  Future<ByteData> load(String key) async {
    final v = files[key];
    if (v == null) throw FlutterError('missing $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(v)));
  }
}

String page(String title) => jsonEncode({
      'about': {'title': title, 'lead': 'lead', 'sections': [{'h': 'H', 'body': ['p1']}, {'h': 'L', 'list': ['a', 'b']}]},
      'terms': {'title': 'T', 'lead': 'l', 'sections': []},
      'privacy': {'title': 'P', 'lead': 'l', 'sections': []},
      'updated': termsVersion,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  legalLanguageTests();
  test('legal pages: own language when translated, English otherwise', () async {
    final b = _Bundle({'assets/locales/pages/en.json': page('About'), 'assets/locales/pages/vi.json': page('Giới thiệu')});
    final vi = await loadLegal('about', 'vi', bundle: b);
    expect(vi.title, 'Giới thiệu');
    expect(vi.native, true);
    expect(vi.sections[1].items, ['a', 'b']);
    final fr = await loadLegal('about', 'fr', bundle: b);
    expect(fr.title, 'About');
    expect(fr.native, false); // shown in English, and the screen says so
  });

  test('the version people accept is the date printed on the shipped legal pages', () async {
    final en = jsonDecode(await File('assets/locales/pages/en.json').readAsString()) as Map;
    final vi = jsonDecode(await File('assets/locales/pages/vi.json').readAsString()) as Map;
    expect(termsVersion, en['updated']);
    expect(termsVersion, vi['updated']);
  });

  test('a brand-new device starts at setup (it accepts on the keys page); an existing user must accept the current terms first', () async {
    SharedPreferences.setMockInitialValues({});
    var app = AppState(vault: Vault(store: MemoryKeyValueStore(), iterations: 1000));
    await app.init();
    expect(app.phase, Phase.setup);
    expect(app.consentOk, false);
    await app.recordConsent();
    expect(app.consentOk, true);

    // someone who already has a vault but never accepted (or accepted older terms) gets the stand-alone screen
    final kv = MemoryKeyValueStore();
    final v = Vault(store: kv, iterations: 1000);
    await v.create('135790');
    SharedPreferences.setMockInitialValues({});
    app = AppState(vault: Vault(store: kv, iterations: 1000));
    await app.init();
    expect(app.phase, Phase.consent);
    await app.acceptTerms();
    expect(app.phase, Phase.locked);

    app = AppState(vault: Vault(store: kv, iterations: 1000));
    await app.init();
    expect(app.phase, Phase.locked); // remembered

    SharedPreferences.setMockInitialValues({'terms.accepted': '2000-01-01'});
    app = AppState(vault: Vault(store: kv, iterations: 1000));
    await app.init();
    expect(app.phase, Phase.consent); // accepted an older text
  });

  testWidgets('consent screen: both links are in the sentence, the button waits for the tick', (t) async {
    SharedPreferences.setMockInitialValues({});
    final i18n = I18n();
    await t.runAsync(i18n.init);
    final app = AppState(vault: Vault(store: MemoryKeyValueStore(), iterations: 1000));
    t.view.physicalSize = const Size(390 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(MultiProvider(providers: [ChangeNotifierProvider.value(value: i18n), ChangeNotifierProvider.value(value: app)], child: const MaterialApp(home: ConsentScreen())));
    await t.pump();
    expect(find.text('Terms of Use'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
    FilledButton button() => t.widget<FilledButton>(find.byType(FilledButton));
    expect(button().onPressed, isNull);
    await t.tap(find.byType(Checkbox));
    await t.pump();
    expect(button().onPressed, isNotNull);
  });
}

void legalLanguageTests() {
  Future<void> show(WidgetTester t, String lang) async {
    SharedPreferences.setMockInitialValues({'lang': lang});
    final i18n = I18n();
    await t.runAsync(i18n.init);
    t.view.physicalSize = const Size(390 * 3, 900 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider.value(value: i18n, child: const MaterialApp(home: LegalScreen(page: LegalPage.terms))));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 300)));
    await t.pump();
  }

  testWidgets('a language without its own legal text gets a fully English page — never two languages at once', (t) async {
    await show(t, 'fr');
    expect(find.textContaining('Last updated'), findsOneWidget);
    expect(find.textContaining('Dernière mise à jour'), findsNothing);
    expect(find.textContaining('shown in English'), findsOneWidget);
  });

  testWidgets('Vietnamese has its own legal text, shown in Vietnamese with Vietnamese labels', (t) async {
    await show(t, 'vi');
    expect(find.textContaining('Cập nhật'), findsOneWidget);
    expect(find.textContaining('Last updated'), findsNothing);
  });
}
