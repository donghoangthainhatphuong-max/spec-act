import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'i18n.dart';
import 'state.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/legal_screen.dart';
import 'ui/pin_screen.dart';
import 'ui/setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterCryptography.enable(); // native AES-GCM / PBKDF2 (the PIN key derivation is far too slow in pure Dart)
  final i18n = I18n();
  await i18n.init();
  final themeCtl = ThemeController();
  await themeCtl.init();
  final app = AppState();
  app.translate = i18n.t;
  await app.init();
  runApp(MultiProvider(providers: [ChangeNotifierProvider.value(value: i18n), ChangeNotifierProvider.value(value: app), ChangeNotifierProvider.value(value: themeCtl)], child: const SpecActApp()));
}

class SpecActApp extends StatelessWidget {
  const SpecActApp({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final app = context.watch<AppState>();
    final themeMode = context.watch<ThemeController>().mode;
    return MaterialApp(
      title: 'SPECACT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      builder: (c, child) => Directionality(textDirection: i18n.rtl ? TextDirection.rtl : TextDirection.ltr, child: child!),
      home: switch (app.phase) {
        Phase.boot => const Scaffold(body: Center(child: CircularProgressIndicator())),
        Phase.consent => const ConsentScreen(),
        Phase.setup => const SetupScreen(),
        Phase.locked => const UnlockScreen(),
        Phase.signIn => const SignInScreen(),
        Phase.ready => const HomeScreen(),
      },
    );
  }
}
