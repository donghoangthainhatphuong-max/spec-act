import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:record/record.dart';

import '../core/media_kinds.dart';
import '../core/temp_io.dart' if (dart.library.js_interop) '../core/temp_web.dart';
import 'widgets.dart';

typedef Recording = ({Uint8List bytes, int seconds});

/// Voice recorder: record, stop, keep. Returns null when cancelled.
Future<Recording?> showRecorder(BuildContext context) => showModalBottomSheet<Recording>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const _Recorder(),
    );

class _Recorder extends StatefulWidget {
  const _Recorder();
  @override
  State<_Recorder> createState() => _RecorderState();
}

class _RecorderState extends State<_Recorder> {
  final rec = AudioRecorder();
  Timer? tick;
  int seconds = 0;
  bool recording = false, denied = false, saving = false;

  @override
  void dispose() {
    tick?.cancel();
    rec.dispose();
    super.dispose();
  }

  String detail = '';

  Future<void> _start() async {
    try {
      if (!await rec.hasPermission()) {
        setState(() => denied = true);
        return;
      }
      await rec.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: await tempPath('m4a'));
    } catch (e) {
      debugPrint('recorder: $e');
      if (mounted) setState(() { denied = true; detail = '$e'; });
      return;
    }
    setState(() { recording = true; seconds = 0; denied = false; });
    tick = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => seconds++);
      if (seconds >= maxAudioSeconds) _stop();
    });
  }

  Future<void> _stop() async {
    tick?.cancel();
    setState(() { recording = false; saving = true; });
    final path = await rec.stop();
    if (path == null) return Navigator.pop(context);
    final bytes = await XFile(path).readAsBytes();
    if (mounted) Navigator.pop(context, (bytes: bytes, seconds: seconds));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr(context, 'camera.audioOpen'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Text(clock(seconds), style: Theme.of(context).textTheme.displaySmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
          if (denied) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${tr(context, 'camera.denied')}${detail.isEmpty ? '' : '\n$detail'}', textAlign: TextAlign.center, style: TextStyle(color: cs.error))),
          const SizedBox(height: 20),
          if (saving)
            const CircularProgressIndicator()
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              TextButton(
                onPressed: () async {
                  tick?.cancel();
                  if (recording) await rec.cancel();
                  if (mounted) Navigator.pop(context);
                },
                child: Text(tr(context, 'compose.cancel')),
              ),
              const SizedBox(width: 24),
              FloatingActionButton.large(
                heroTag: null,
                backgroundColor: recording ? cs.error : cs.primary,
                foregroundColor: recording ? cs.onError : cs.onPrimary,
                tooltip: tr(context, recording ? 'camera.stop' : 'camera.record'),
                onPressed: recording ? _stop : _start,
                child: Icon(recording ? Icons.stop : Icons.mic),
              ),
            ]),
        ]),
      ),
    );
  }
}
