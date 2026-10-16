/// Local vault: two independent AES-256-GCM layers, both required to read any record.
///   inner: random device key kept in the Android Keystore (flutter_secure_storage)
///   outer: key derived from the user's numeric PIN (PBKDF2-SHA256)
/// Same rules as the web vault: wrong PINs are counted, throttled, and finally wipe everything.
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'config.dart';
import 'crypto.dart';

abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<Map<String, String>> readAll();
}

class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore() : _s = const FlutterSecureStorage();
  final FlutterSecureStorage _s;
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
  @override
  Future<Map<String, String>> readAll() => _s.readAll();
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> m = {};
  @override
  Future<String?> read(String key) async => m[key];
  @override
  Future<void> write(String key, String value) async => m[key] = value;
  @override
  Future<void> delete(String key) async => m.remove(key);
  @override
  Future<Map<String, String>> readAll() async => Map.of(m);
}

class VaultError implements Exception {
  VaultError(this.code, {this.retryInMs = 0, this.remaining = 0});
  final String
  code; // no-vault | throttled | bad-pin | wiped | locked | corrupt
  final int retryInMs;
  final int remaining;
  @override
  String toString() => 'VaultError($code)';
}

class Vault {
  Vault({
    KeyValueStore? store,
    this.iterations = Config.pbkdf2Iterations,
    this.maxAttempts = Config.pinMaxAttempts,
  }) : _kv = store ?? SecureKeyValueStore();

  final KeyValueStore _kv;
  final int iterations;
  final int maxAttempts;
  SecretKey? _pin;
  SecretKey? _dev;

  static const _prefix = 'v1.';
  static const _check = '__check__';
  static const _metaKey = 'vault.meta';
  static const _devKey = 'vault.dev';
  static const _recPrefix = 'rec.';

  bool get unlocked => _pin != null && _dev != null;

  Future<Map<String, dynamic>?> _meta() async {
    final s = await _kv.read(_metaKey);
    return s == null ? null : jsonDecode(s) as Map<String, dynamic>;
  }

  Future<bool> exists() async => (await _meta()) != null;

  Future<({int attempts, int lockedUntil})> status() async {
    final m = await _meta();
    return (
      attempts: (m?['attempts'] ?? 0) as int,
      lockedUntil: (m?['lockedUntil'] ?? 0) as int,
    );
  }

  Future<String> _seal(
    String name,
    Object? value,
    SecretKey pin,
    SecretKey dev,
  ) async {
    final inner = await encryptBytes(
      dev,
      utf8b(jsonEncode(value)),
      'dev:$name',
    );
    final outer = await encryptBytes(pin, inner, 'pin:$name');
    return _prefix + b64e(outer);
  }

  Future<dynamic> _open(
    String name,
    String sealed,
    SecretKey pin,
    SecretKey dev,
  ) async {
    if (!sealed.startsWith(_prefix)) throw VaultError('corrupt');
    final inner = await decryptBytes(
      pin,
      b64d(sealed.substring(_prefix.length)),
      'pin:$name',
    );
    return jsonDecode(fromUtf8(await decryptBytes(dev, inner, 'dev:$name')));
  }

  Future<void> create(String pin) async {
    await wipe();
    final salt = randomBytes(16);
    final dev = rawKey(randomBytes(32));
    final pinKey = await deriveKey(pin, salt, iterations);
    await _kv.write(_devKey, b64e(await dev.extractBytes()));
    await _kv.write(
      _recPrefix + _check,
      await _seal(_check, 'specact-ok', pinKey, dev),
    );
    await _kv.write(
      _metaKey,
      jsonEncode({
        'v': 1,
        'salt': b64e(salt),
        'iter': iterations,
        'attempts': 0,
        'lockedUntil': 0,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    _pin = pinKey;
    _dev = dev;
  }

  Future<({SecretKey pin, SecretKey dev, Map<String, dynamic> meta})> _checkPin(
    String pin,
  ) async {
    final meta = await _meta();
    final devRaw = await _kv.read(_devKey);
    if (meta == null || devRaw == null) throw VaultError('no-vault');
    final wait =
        ((meta['lockedUntil'] ?? 0) as int) -
        DateTime.now().millisecondsSinceEpoch;
    if (wait > 0) throw VaultError('throttled', retryInMs: wait);
    final dev = rawKey(b64d(devRaw));
    final pinKey = await deriveKey(
      pin,
      b64d(meta['salt'] as String),
      meta['iter'] as int,
    );
    try {
      final c = await _open(
        _check,
        (await _kv.read(_recPrefix + _check)) ?? '',
        pinKey,
        dev,
      );
      if (c != 'specact-ok') throw VaultError('corrupt');
    } catch (_) {
      final attempts = ((meta['attempts'] ?? 0) as int) + 1;
      if (attempts >= maxAttempts) {
        await wipe();
        throw VaultError('wiped');
      }
      // 3 free tries, then 5s, 10s, 20s ... capped at 15 minutes
      final delay = attempts < 3
          ? 0
          : (5000 * (1 << (attempts - 3))).clamp(0, 15 * 60000);
      meta['attempts'] = attempts;
      meta['lockedUntil'] = delay == 0
          ? 0
          : DateTime.now().millisecondsSinceEpoch + delay;
      await _kv.write(_metaKey, jsonEncode(meta));
      throw VaultError(
        'bad-pin',
        remaining: maxAttempts - attempts,
        retryInMs: delay,
      );
    }
    if ((meta['attempts'] ?? 0) != 0 || (meta['lockedUntil'] ?? 0) != 0) {
      meta['attempts'] = 0;
      meta['lockedUntil'] = 0;
      await _kv.write(_metaKey, jsonEncode(meta));
    }
    return (pin: pinKey, dev: dev, meta: meta);
  }

  Future<void> unlock(String pin) async {
    final r = await _checkPin(pin);
    _pin = r.pin;
    _dev = r.dev;
  }

  Future<void> verify(String pin) async {
    _need();
    await _checkPin(pin);
  }

  void lock() {
    _pin = null;
    _dev = null;
  }

  void _need() {
    if (!unlocked) throw VaultError('locked');
  }

  Future<dynamic> get(String name, [dynamic fallback]) async {
    _need();
    final sealed = await _kv.read(_recPrefix + name);
    if (sealed == null) return fallback;
    try {
      return await _open(name, sealed, _pin!, _dev!);
    } catch (_) {
      return fallback;
    }
  }

  Future<void> set(String name, Object? value) async {
    _need();
    await _kv.write(_recPrefix + name, await _seal(name, value, _pin!, _dev!));
  }

  Future<void> remove(String name) async {
    _need();
    await _kv.delete(_recPrefix + name);
  }

  Future<void> changePin(String oldPin, String newPin) async {
    _need();
    final r = await _checkPin(oldPin);
    final all = await _kv.readAll();
    final plain = <String, dynamic>{};
    for (final e in all.entries) {
      if (!e.key.startsWith(_recPrefix)) continue;
      final name = e.key.substring(_recPrefix.length);
      if (name == _check) continue;
      try {
        plain[name] = await _open(name, e.value, r.pin, _dev!);
      } catch (_) {
        /* drop unreadable */
      }
    }
    final salt = randomBytes(16);
    final nk = await deriveKey(newPin, salt, iterations);
    await _kv.write(
      _recPrefix + _check,
      await _seal(_check, 'specact-ok', nk, _dev!),
    );
    for (final e in plain.entries) {
      await _kv.write(
        _recPrefix + e.key,
        await _seal(e.key, e.value, nk, _dev!),
      );
    }
    await _kv.write(
      _metaKey,
      jsonEncode({
        'v': 1,
        'salt': b64e(salt),
        'iter': iterations,
        'attempts': 0,
        'lockedUntil': 0,
        'createdAt': r.meta['createdAt'],
        'changedAt': DateTime.now().millisecondsSinceEpoch,
      }),
    );
    _pin = nk;
  }

  Future<void> wipe() async {
    lock();
    for (final k in (await _kv.readAll()).keys) {
      if (k == _metaKey || k == _devKey || k.startsWith(_recPrefix))
        await _kv.delete(k);
    }
  }
}
