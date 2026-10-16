/// Photos are downloaded once per device: the downloaded bytes (still sealed, for password-protected posts) are kept in
/// the app's cache folder, encrypted with a key that lives in the PIN vault — so nothing readable sits on the disk and a
/// locked app cannot read it. Drive media files never change (an edit uploads a new file), so the file id is a safe key.
import 'dart:typed_data';

import 'crypto.dart';
import 'media_cache_stub.dart' if (dart.library.io) 'media_cache_io.dart';
import 'media_store.dart';
import 'vault.dart';

class MediaCache {
  MediaCache(this.vault, {MediaStore? store}) : _store = store ?? DiskStore();
  final Vault vault;
  final MediaStore _store;
  static const maxItemBytes = 12 * 1024 * 1024;

  Future<dynamic> _key() async {
    final stored = await vault.get('mediakey');
    if (stored is String) return rawKey(b64d(stored));
    final raw = newRawKey();
    await vault.set('mediakey', b64e(raw));
    return rawKey(raw);
  }

  Future<Uint8List?> get(String id) async {
    try {
      if (!vault.unlocked) return null;
      final sealed = await _store.read(id);
      if (sealed == null) return null;
      return await decryptBytes(await _key(), sealed, 'cache:$id');
    } catch (_) {
      return null;
    }
  }

  Future<void> put(String id, Uint8List bytes) async {
    try {
      if (!vault.unlocked || bytes.length > maxItemBytes) return;
      await _store.write(id, await encryptBytes(await _key(), bytes, 'cache:$id'));
    } catch (_) {/* only an optimisation */}
  }

  Future<void> clear() => _store.clear();
}
