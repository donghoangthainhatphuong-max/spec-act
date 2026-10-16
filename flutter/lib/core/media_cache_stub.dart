import 'dart:typed_data';

import 'media_store.dart';

/// The web build has the browser's own HTTP cache; nothing extra is kept.
class DiskStore implements MediaStore {
  @override
  Future<Uint8List?> read(String id) async => null;
  @override
  Future<void> write(String id, Uint8List bytes) async {}
  @override
  Future<void> clear() async {}
}
