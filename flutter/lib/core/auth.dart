/// Google OAuth 2.0 authorization code + PKCE for Android using the loopback redirect (http://127.0.0.1:<port>).
/// The user's own client id (and secret, for "Desktop app" clients) are used; the only servers contacted are Google's.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'loopback_stub.dart'
    if (dart.library.io) 'loopback_io.dart'
    if (dart.library.js_interop) 'loopback_web.dart';

import 'config.dart';
import 'crypto.dart';

class AuthError implements Exception {
  AuthError(this.code, [this.detail]);
  final String
  code; // denied | state-mismatch | expired | network | invalid-grant | invalid-client | token-error | oauth-error
  final String? detail;
  @override
  String toString() => 'AuthError($code${detail == null ? '' : ': $detail'})';
}

class Tokens {
  Tokens({
    required this.accessToken,
    this.refreshToken,
    required this.expiresAt,
  });
  final String accessToken;
  final String? refreshToken;
  final int expiresAt;
}

final looksLikeClientId = RegExp(
  r'^[\w.-]+\.apps\.googleusercontent\.com$',
  caseSensitive: false,
);

const _authUrl = 'https://accounts.google.com/o/oauth2/v2/auth';
const _tokenUrl = 'https://oauth2.googleapis.com/token';
const _revokeUrl = 'https://oauth2.googleapis.com/revoke';

/// Opens the system browser, waits for Google to redirect to the local listener and exchanges the code.
Future<Tokens> signIn({
  required String clientId,
  String? clientSecret,
  String? loginHint,
  ({String title, String text, String button})? donePage,
}) async {
  final pkce = await pkcePair();
  final state = b64url(randomBytes(24));
  Uri build(String redirect) => Uri.parse(_authUrl).replace(
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirect,
      'response_type': 'code',
      'scope': Config.oauthScope,
      'code_challenge': pkce.challenge,
      'code_challenge_method': 'S256',
      'state': state,
      'access_type': 'offline',
      'include_granted_scopes': 'true',
      'prompt': 'consent select_account',
      'login_hint': ?loginHint,
    },
  );
  final r = await loopbackAuthorize(build, page: donePage);
  if (r.error != null)
    throw AuthError(
      r.error == 'access_denied' ? 'denied' : 'oauth-error',
      r.error,
    );
  if (r.state != state || r.code == null) throw AuthError('state-mismatch');
  return _token({
    'grant_type': 'authorization_code',
    'client_id': clientId,
    if (clientSecret != null && clientSecret.isNotEmpty)
      'client_secret': clientSecret,
    'code': r.code!,
    'code_verifier': pkce.verifier,
    'redirect_uri': r.redirect,
  });
}

Future<Tokens> refresh({
  required String clientId,
  String? clientSecret,
  required String refreshToken,
  http.Client? client,
}) => _token({
  'grant_type': 'refresh_token',
  'client_id': clientId,
  if (clientSecret != null && clientSecret.isNotEmpty)
    'client_secret': clientSecret,
  'refresh_token': refreshToken,
}, client: client);

Future<Tokens> _token(Map<String, String> body, {http.Client? client}) async {
  http.Response res;
  try {
    res = await (client ?? http.Client()).post(
      Uri.parse(_tokenUrl),
      body: body,
    );
  } catch (_) {
    throw AuthError('network');
  }
  final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  if (res.statusCode != 200) {
    final e = j['error'];
    throw AuthError(
      e == 'invalid_grant'
          ? 'invalid-grant'
          : e == 'invalid_client'
          ? 'invalid-client'
          : 'token-error',
      (j['error_description'] ?? e)?.toString(),
    );
  }
  return Tokens(
    accessToken: j['access_token'] as String,
    refreshToken: j['refresh_token'] as String?,
    expiresAt:
        DateTime.now().millisecondsSinceEpoch +
        ((j['expires_in'] ?? 3600) as int) * 1000,
  );
}

Future<void> revoke(String token) async {
  try {
    await http.post(Uri.parse(_revokeUrl), body: {'token': token});
  } catch (_) {
    /* best effort */
  }
}
