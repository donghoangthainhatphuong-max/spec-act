/// AES-256-GCM / PBKDF2 helpers, byte-compatible with the web app (src/services/crypto.js).
/// Every ciphertext is: iv(12) || ciphertext || tag(16), exactly as WebCrypto produces it.
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class CryptoError implements Exception {
  CryptoError(this.code);
  final String code;
  @override
  String toString() => 'CryptoError($code)';
}

final _rng = Random.secure();
final _aes = AesGcm.with256bits();

Uint8List randomBytes(int n) =>
    Uint8List.fromList(List<int>.generate(n, (_) => _rng.nextInt(256)));

String randomId([int bytes = 8]) =>
    randomBytes(bytes).map((b) => b.toRadixString(16).padLeft(2, '0')).join();

String b64e(List<int> b) => base64.encode(b);
Uint8List b64d(String s) => base64.decode(s);
String b64url(List<int> b) => base64Url.encode(b).replaceAll('=', '');
Uint8List utf8b(String s) => Uint8List.fromList(utf8.encode(s));
String fromUtf8(List<int> b) => utf8.decode(b);

/// PBKDF2-SHA256 -> 256-bit AES key.
Future<SecretKey> deriveKey(String secret, List<int> salt, int iterations) {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  return kdf.deriveKeyFromPassword(password: secret, nonce: salt);
}

SecretKey rawKey(List<int> raw) => SecretKey(raw);
Uint8List newRawKey() => randomBytes(32);

Future<Uint8List> encryptBytes(
  SecretKey key,
  List<int> bytes, [
  String? aad,
]) async {
  final box = await _aes.encrypt(
    bytes,
    secretKey: key,
    nonce: randomBytes(12),
    aad: aad == null ? const [] : utf8.encode(aad),
  );
  return Uint8List.fromList(box.concatenation());
}

Future<Uint8List> decryptBytes(
  SecretKey key,
  List<int> packed, [
  String? aad,
]) async {
  if (packed.length < 12 + 16) throw CryptoError('malformed');
  try {
    final box = SecretBox.fromConcatenation(
      packed,
      nonceLength: 12,
      macLength: 16,
    );
    return Uint8List.fromList(
      await _aes.decrypt(
        box,
        secretKey: key,
        aad: aad == null ? const [] : utf8.encode(aad),
      ),
    );
  } catch (_) {
    throw CryptoError('decrypt-failed');
  }
}

Future<String> encryptJson(SecretKey key, Object? value, [String? aad]) async =>
    b64e(await encryptBytes(key, utf8.encode(jsonEncode(value)), aad));

Future<dynamic> decryptJson(SecretKey key, String text, [String? aad]) async =>
    jsonDecode(fromUtf8(await decryptBytes(key, b64d(text), aad)));

/// A protected post has a random content key wrapped by a key derived from the share password.
class Protection {
  Protection(this.meta, this.raw, this.key);
  final Map<String, dynamic> meta;
  final Uint8List raw;
  final SecretKey key;
}

Future<Protection> createProtection(String password, int iterations) async {
  final salt = randomBytes(16);
  final raw = newRawKey();
  final kek = await deriveKey(password, salt, iterations);
  final wrap = b64e(await encryptBytes(kek, raw, 'specact:wrap'));
  return Protection(
    {
      'alg': 'AES-256-GCM',
      'kdf': 'PBKDF2-SHA256',
      'iter': iterations,
      'salt': b64e(salt),
      'wrap': wrap,
    },
    raw,
    rawKey(raw),
  );
}

/// Throws CryptoError('wrong-password').
Future<Protection> unlockProtection(
  Map<String, dynamic> p,
  String password,
) async {
  final kek = await deriveKey(
    password,
    b64d(p['salt'] as String),
    p['iter'] as int,
  );
  try {
    final raw = await decryptBytes(
      kek,
      b64d(p['wrap'] as String),
      'specact:wrap',
    );
    return Protection(p, raw, rawKey(raw));
  } on CryptoError {
    throw CryptoError('wrong-password');
  }
}

/// PKCE pair (S256).
Future<({String verifier, String challenge})> pkcePair() async {
  final verifier = b64url(randomBytes(48));
  final digest = await Sha256().hash(utf8.encode(verifier));
  return (verifier: verifier, challenge: b64url(digest.bytes));
}
