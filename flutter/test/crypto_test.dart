import 'dart:convert';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:specact/core/media_cache.dart';
import 'package:specact/core/media_store.dart';
import 'package:specact/core/crypto.dart';
import 'package:specact/core/vault.dart';

void main() {
  mediaCacheTests();
  test('AES-GCM round trip with AAD', () async {
    final k = rawKey(newRawKey());
    final c = await encryptBytes(k, utf8b('xin chào'), 'post:1');
    expect(fromUtf8(await decryptBytes(k, c, 'post:1')), 'xin chào');
    expect(() => decryptBytes(k, c, 'post:2'), throwsA(isA<CryptoError>()));
  });

  test('decrypts what the web app produced (WebCrypto iv||ct||tag)', () async {
    // generated with node: PBKDF2-SHA256("hunter22", salt=16x1, 1000) -> AES-GCM, aad "post:abc"
    final kek = await deriveKey('hunter22', List.filled(16, 1), 1000);
    final plain = await decryptBytes(kek, b64d(_webCipher), 'post:abc');
    expect(jsonDecode(fromUtf8(plain)), {'text': 'từ web'});
  });

  test('protection wrap / unlock', () async {
    final p = await createProtection('secret1', 1000);
    final u = await unlockProtection(p.meta, 'secret1');
    expect(u.raw, p.raw);
    expect(() => unlockProtection(p.meta, 'nope'), throwsA(isA<CryptoError>()));
  });

  test('vault: unlock, wrong pin counting, wipe', () async {
    final v = Vault(store: MemoryKeyValueStore(), iterations: 1000, maxAttempts: 3);
    await v.create('135790');
    await v.set('a', {'x': 1});
    v.lock();
    expect(() => v.get('a'), throwsA(isA<VaultError>()));
    await expectLater(v.unlock('000000'), throwsA(isA<VaultError>().having((e) => e.code, 'code', 'bad-pin')));
    await v.unlock('135790');
    expect(await v.get('a'), {'x': 1});
    await v.changePin('135790', '246802');
    v.lock();
    await v.unlock('246802');
    expect(await v.get('a'), {'x': 1});
    v.lock();
    for (var i = 0; i < 2; i++) {
      await v.unlock('111111').catchError((_) {});
    }
    await expectLater(v.unlock('111111'), throwsA(isA<VaultError>().having((e) => e.code, 'code', 'wiped')));
    expect(await v.exists(), false);
  });
}

const _webCipher = 'hi8tHrtltonP/Bm9R9a4gF0VEBIHLnfXYjMTgAxwyKjQT1dAhuWQMuKXf1wdg0s=';

class _MemStore implements MediaStore {
  final m = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String id) async => m[id];
  @override
  Future<void> write(String id, Uint8List bytes) async => m[id] = bytes;
  @override
  Future<void> clear() async => m.clear();
}

void mediaCacheTests() {
  test('media cache keeps photos encrypted and only readable while unlocked', () async {
    final v = Vault(store: MemoryKeyValueStore(), iterations: 1000);
    await v.create('135790');
    final store = _MemStore();
    final c = MediaCache(v, store: store);
    await c.put('f1', Uint8List.fromList([1, 2, 3, 4]));
    expect(store.m['f1'], isNot([1, 2, 3, 4])); // sealed on disk
    expect(await c.get('f1'), [1, 2, 3, 4]);
    v.lock();
    expect(await c.get('f1'), isNull);
  });
}
