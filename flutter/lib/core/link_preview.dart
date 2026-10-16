/// Link previews (Open Graph), the way Facebook / X show a pasted link. Port of src/services/linkPreview.js.
/// On the phone the page is fetched straight from the device (there is no CORS in a native app and nothing goes
/// through any server of ours); the web build has no such access, so it needs LINK_PREVIEW_URL (a service you choose).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:html/parser.dart' as html;
import 'package:http/http.dart' as http;

import 'post_model.dart';

/// Web only: a service that returns a page's HTML (see docker/link-preview). Phones fetch pages themselves.
const _previewService = String.fromEnvironment('LINK_PREVIEW_URL');
const _maxHtml = 1500000;
const _maxImage = 5 * 1024 * 1024;

class LinkPreview {
  LinkPreview(this.link, this.image);
  final Map<String, dynamic> link;
  final Uint8List? image; // picture bytes, null when it could not be read
}

/// The first http(s) address in a piece of text, or ''.
String firstUrl(String text) {
  final m = RegExp(r'https?:\/\/[^\s<>"\x27]+').firstMatch(text);
  if (m == null) return '';
  return m.group(0)!.replaceAll(RegExp(r'[.,;:!?)\]}"\x27]+$'), '');
}

String? _abs(String? href, Uri base) {
  if (href == null || href.trim().isEmpty) return null;
  try {
    final u = base.resolve(href.trim());
    return (u.scheme == 'http' || u.scheme == 'https') ? u.toString() : null;
  } catch (_) {
    return null;
  }
}

/// Pure: HTML text -> card + picture address (or null when the page says nothing useful). Never runs scripts.
({Map<String, dynamic> link, String? imageUrl})? parseOpenGraph(
  String page,
  String pageUrl,
) {
  final doc = html.parse(
    page.length > _maxHtml ? page.substring(0, _maxHtml) : page,
  );
  String meta(List<String> names) {
    for (final n in names) {
      final el = doc.querySelector('meta[property="$n"], meta[name="$n"]');
      final v = el?.attributes['content']?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return '';
  }

  final base = Uri.parse(pageUrl);
  final site = meta(['og:site_name']);
  final ogTitle = meta(['og:title', 'twitter:title']);
  final link = cleanLink({
    // the address that was pasted is what a card opens, never an address the page claims for itself
    'url': pageUrl,
    'title': ogTitle.isNotEmpty
        ? ogTitle
        : (doc.querySelector('title')?.text ?? ''),
    'description': meta([
      'og:description',
      'twitter:description',
      'description',
    ]),
    'site': site.isNotEmpty
        ? site
        : base.host.replaceFirst(RegExp(r'^www\.'), ''),
  });
  if (link == null ||
      ((link['title'] as String).isEmpty &&
          (link['description'] as String).isEmpty))
    return null;
  return (
    link: link,
    imageUrl: _abs(
      meta(['og:image:secure_url', 'og:image', 'twitter:image']),
      base,
    ),
  );
}

Future<http.Response> _get(String url, Duration timeout, http.Client c) => c
    .get(
      Uri.parse(url),
      headers: const {
        'User-Agent': 'Mozilla/5.0 (compatible; SPECACTLinkPreview/1.0)',
        'Accept': 'text/html,application/xhtml+xml,image/*;q=0.8',
      },
    )
    .timeout(timeout);

Future<Uint8List?> _loadImage(String url, http.Client c) async {
  try {
    final r = await _get(url, const Duration(seconds: 6), c);
    final type = (r.headers['content-type'] ?? '').toLowerCase();
    if (r.statusCode != 200 ||
        !RegExp(r'^image/(jpeg|png|webp|gif|avif)').hasMatch(type) ||
        r.bodyBytes.length > _maxImage)
      return null; // never SVG
    return r.bodyBytes;
  } catch (_) {
    return null;
  }
}

/// null when there is nothing to show or the page can't be reached.
Future<LinkPreview?> fetchPreview(
  String url, {
  http.Client? client,
  bool? web,
}) async {
  if (!RegExp(r'^https?://', caseSensitive: false).hasMatch(url)) return null;
  final c = client ?? http.Client();
  final viaService = web ?? kIsWeb;
  try {
    if (viaService && _previewService.isEmpty) {
      debugPrint(
        'link preview: a browser cannot read other sites; start with --dart-define=LINK_PREVIEW_URL=…',
      );
      return null;
    }
    final target = viaService
        ? _previewService.replaceAll('{url}', Uri.encodeComponent(url))
        : url;
    final r = await _get(target, const Duration(seconds: 8), c);
    if (r.statusCode != 200) {
      debugPrint('link preview: $url answered ${r.statusCode}');
      return null;
    }
    final type = (r.headers['content-type'] ?? 'text/html').toLowerCase();
    if (!type.contains('html') &&
        !type.contains('xml') &&
        !type.contains('text'))
      return null;
    final parsed = parseOpenGraph(r.body, url);
    if (parsed == null) {
      debugPrint('link preview: no Open Graph data in $url');
      return null;
    }
    final img = parsed.imageUrl;
    final bytes = img == null
        ? null
        : (viaService
              ? await _loadImage(
                  '$_previewService${_previewService.contains('?') ? '&' : '?'}kind=image'
                      .replaceAll('{url}', Uri.encodeComponent(img)),
                  c,
                )
              : await _loadImage(img, c));
    return LinkPreview(parsed.link, bytes);
  } catch (e) {
    debugPrint('link preview failed for $url: $e');
    return null;
  } finally {
    if (client == null) c.close();
  }
}
