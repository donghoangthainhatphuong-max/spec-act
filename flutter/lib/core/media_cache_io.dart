import 'dart:io';
import 'dart:typed_data';

import 'media_store.dart';

import 'package:path_provider/path_provider.dart';

/// Encrypted photos kept on the phone (Android cache dir). Oldest files go first once the folder passes [maxBytes].
class DiskStore implements MediaStore {
  static const maxBytes = 300 * 1024 * 1024;
  Directory? _dir;

  Future<Directory> _d() async => _dir ??= await Directory('${(await getApplicationCacheDirectory()).path}/specact-media').create(recursive: true);

  String _name(String id) => id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  @override
  Future<Uint8List?> read(String id) async {
    try {
      final f = File('${(await _d()).path}/${_name(id)}');
      if (!await f.exists()) return null;
      f.setLastAccessed(DateTime.now()).ignore();
      return await f.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String id, Uint8List bytes) async {
    try {
      await File('${(await _d()).path}/${_name(id)}').writeAsBytes(bytes, flush: false);
      if (DateTime.now().millisecond % 10 == 0) await _trim();
    } catch (_) {/* only an optimisation */}
  }

  Future<void> _trim() async {
    final files = <File>[];
    var total = 0;
    await for (final e in (await _d()).list()) {
      if (e is File) {
        files.add(e);
        total += await e.length();
      }
    }
    if (total <= maxBytes) return;
    files.sort((a, b) => a.statSync().accessed.compareTo(b.statSync().accessed));
    for (final f in files) {
      if (total <= maxBytes * .8) break;
      total -= await f.length();
      await f.delete();
    }
  }

  @override
  Future<void> clear() async {
    try {
      final d = await _d();
      if (await d.exists()) await d.delete(recursive: true);
      _dir = null;
    } catch (_) {}
  }
}
