import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:specact/i18n.dart';
import 'package:specact/ui/setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'lang': 'en'});

  Future<void> show(WidgetTester t, bool web) async {
    final i18n = I18n();
    await t.runAsync(i18n.init);
    t.view.physicalSize = const Size(390 * 3, 1200 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(ChangeNotifierProvider.value(value: i18n, child: MaterialApp(home: Scaffold(body: SingleChildScrollView(child: Guide(web: web, origin: 'http://localhost:8099'))))));
    await t.tap(find.byType(ExpansionTile));
    await t.pumpAndSettle();
  }

  testWidgets('Android build: Desktop client, no redirect to register', (t) async {
    await show(t, false);
    expect(find.textContaining('Desktop app'), findsOneWidget);
    expect(find.textContaining('Web application'), findsNothing);
    expect(find.text('Copy'), findsNothing);
  });

  testWidgets('Web build: Web client with the redirect address and a copy button', (t) async {
    await show(t, true);
    expect(find.textContaining('Web application'), findsOneWidget);
    expect(find.textContaining('Desktop app'), findsNothing);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('http://localhost:8099/'), findsOneWidget);
  });
}
