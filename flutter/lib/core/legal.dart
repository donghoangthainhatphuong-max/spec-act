/// The About / Terms / Privacy texts: the same JSON the web app shows (assets/locales/pages/<lang>.json, English and Vietnamese;
/// every other language shows the English text).
import 'dart:convert';

import 'package:flutter/services.dart';

/// Date of the Terms / Privacy text people must have accepted. Same value as `updated` in the pages JSON — bump both together.
const termsVersion = '2026-10-12';

const legalContact = String.fromEnvironment('LEGAL_CONTACT');

class LegalSection {
  LegalSection(this.heading, this.paragraphs, this.items);
  final String heading;
  final List<String> paragraphs, items;
}

class LegalDoc {
  LegalDoc({required this.title, required this.lead, required this.sections, required this.updated, required this.native});
  final String title, lead, updated;
  final List<LegalSection> sections;
  final bool native; // false: shown in English because the app language has no translation of this page
}

/// [page] is 'about', 'terms' or 'privacy'.
Future<LegalDoc> loadLegal(String page, String lang, {AssetBundle? bundle}) async {
  final b = bundle ?? rootBundle;
  Future<Map<String, dynamic>?> read(String code) async {
    try {
      return jsonDecode(await b.loadString('assets/locales/pages/$code.json')) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  final own = lang == 'en' ? null : await read(lang);
  final src = own ?? (await read('en'))!;
  final doc = src[page] as Map<String, dynamic>;
  return LegalDoc(
    title: '${doc['title']}',
    lead: '${doc['lead']}',
    updated: '${src['updated']}',
    native: own != null || lang == 'en',
    sections: [
      for (final s in (doc['sections'] as List).cast<Map<String, dynamic>>())
        LegalSection('${s['h']}', [for (final p in (s['body'] as List?) ?? const []) '$p'], [for (final p in (s['list'] as List?) ?? const []) '$p']),
    ],
  );
}
