import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';

Future<String> tempPath(String ext) async =>
    '${(await getTemporaryDirectory()).path}/specact_${DateTime.now().microsecondsSinceEpoch}.$ext';

/// A player for media held in memory (video_player needs a file on mobile).
Future<VideoPlayerController> playerFor(
  Uint8List bytes,
  String mime,
  String ext,
) async {
  final p = await tempPath(ext);
  await File(p).writeAsBytes(bytes);
  return VideoPlayerController.file(File(p));
}

/// First-frame poster (JPEG) of a video, or null if it cannot be made.
Future<Uint8List?> posterFor(Uint8List video, String ext) async {
  try {
    final p = await tempPath(ext);
    await File(p).writeAsBytes(video);
    return await FcNativeVideoThumbnail().saveThumbnailToBytes(
      srcFile: p,
      width: 480,
      height: 480,
      quality: 75,
    );
  } catch (_) {
    return null;
  }
}
