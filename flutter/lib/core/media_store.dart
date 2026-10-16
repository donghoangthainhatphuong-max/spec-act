import 'dart:typed_data';

/// Where sealed photo bytes are kept (a folder on the phone; nothing on the web).
abstract class MediaStore {
  Future<Uint8List?> read(String id);
  Future<void> write(String id, Uint8List bytes);
  Future<void> clear();
}
