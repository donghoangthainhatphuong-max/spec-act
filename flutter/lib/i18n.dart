/// Translations: the same flat-able JSON files the web app uses (assets/locales/*.json), English fallback.
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const languages = <(String, String)>[
  ('en', 'English'), ('vi', 'Tiếng Việt'), ('zh', '中文'), ('ja', '日本語'), ('ko', '한국어'), ('ru', 'Русский'), ('fr', 'Français'),
  ('de', 'Deutsch'), ('es', 'Español'), ('th', 'ไทย'), ('id', 'Bahasa Indonesia'), ('hi', 'हिन्दी'), ('ar', 'العربية'), ('tr', 'Türkçe'),
];

Map<String, String> _flat(Map<String, dynamic> o, [String p = '']) {
  final out = <String, String>{};
  o.forEach((k, v) {
    if (v is Map<String, dynamic>) {
      out.addAll(_flat(v, '$p$k.'));
    } else {
      out['$p$k'] = '$v';
    }
  });
  return out;
}

class I18n extends ChangeNotifier {
  String lang = 'en';
  Map<String, String> _en = {};
  Map<String, String> _cur = {};

  bool get rtl => lang == 'ar';

  Future<void> init() async {
    _en = await _load('en');
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('lang');
    final device = PlatformDispatcher.instance.locale.languageCode;
    await setLang(saved ?? (languages.any((l) => l.$1 == device) ? device : 'en'), persist: false);
  }

  Future<Map<String, String>> _load(String code) async => _flat(jsonDecode(await rootBundle.loadString('assets/locales/$code.json')) as Map<String, dynamic>);

  Future<void> setLang(String code, {bool persist = true}) async {
    lang = code;
    _cur = code == 'en' ? _en : await _load(code);
    if (persist) (await SharedPreferences.getInstance()).setString('lang', code);
    notifyListeners();
  }

  /// English text regardless of the selected language (a page that only exists in English must not mix two languages).
  String tEn(String key, [Map<String, Object?> params = const {}]) {
    var s = _en[key] ?? key;
    params.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }

  String t(String key, [Map<String, Object?> params = const {}]) {
    var s = _cur[key] ?? _en[key] ?? key;
    params.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
    return s;
  }
}
