import 'dart:async';
import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

typedef LoopbackResult = ({String redirect, String? code, String? state, String? error});

/// Texts of the page the browser lands on after Google redirects to the local listener.
typedef DonePage = ({String title, String text, String button});

const _defaultPage = (title: 'Signed in', text: 'Returning to SPECACT…', button: 'Return to SPECACT');

/// The system browser cannot open the app by itself after the redirect, so the landing page sends it back with an
/// `intent:` link (the app registers the `specact` scheme). The button is the fallback for browsers that block the automatic jump.
String _donePage(DonePage p, bool ok) {
  const back = 'intent://done#Intent;scheme=specact;package=app.specact.specact;end';
  String esc(String s) => s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  return '''<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>SPECACT</title>
<style>:root{color-scheme:light dark}body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;font-family:system-ui,sans-serif;background:#0C3A31;color:#fff;text-align:center}
main{padding:32px;max-width:360px}h1{font-size:26px;margin:0 0 8px}p{opacity:.8;line-height:1.45;margin:0 0 24px}
a{display:inline-block;background:#fff;color:#0C3A31;text-decoration:none;font-weight:700;padding:14px 26px;border-radius:99px}</style></head>
<body><main><h1>${esc(p.title)}</h1><p>${esc(p.text)}</p>${ok ? '<a href="$back">${esc(p.button)}</a><script>setTimeout(function(){location.href="$back"},350)</script>' : ''}</main></body></html>''';
}

/// Listens on http://127.0.0.1:<random port>, opens the consent page in the system browser and returns what Google sends back.
Future<LoopbackResult> loopbackAuthorize(Uri Function(String redirect) buildUrl, {DonePage? page}) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  try {
    final redirect = 'http://127.0.0.1:${server.port}';
    if (!await launchUrl(buildUrl(redirect), mode: LaunchMode.externalApplication)) throw StateError('cannot open browser');
    // browsers also ask for /favicon.ico and open speculative connections: only the request that carries the answer counts
    await for (final req in server.timeout(const Duration(minutes: 10))) {
      final q = req.uri.queryParameters;
      final answer = q.containsKey('code') || q.containsKey('error');
      req.response
        ..statusCode = answer ? 200 : 404
        ..headers.contentType = ContentType.html
        ..headers.set('Cache-Control', 'no-store')
        ..write(answer ? _donePage(page ?? _defaultPage, q.containsKey('code')) : '');
      await req.response.close();
      if (answer) return (redirect: redirect, code: q['code'], state: q['state'], error: q['error']);
    }
    throw TimeoutException('sign-in');
  } finally {
    await server.close(force: true);
  }
}
