import 'dart:js_interop';
import 'dart:typed_data';

import 'package:video_player/video_player.dart';
import 'package:web/web.dart' as web;

Future<String> tempPath(String ext) async => 'specact.$ext';

Future<VideoPlayerController> playerFor(Uint8List bytes, String mime, String ext) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  return VideoPlayerController.networkUrl(Uri.parse(web.URL.createObjectURL(blob)));
}

Future<Uint8List?> posterFor(Uint8List video, String ext) async => null;
