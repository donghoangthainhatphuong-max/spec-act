import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImagePicker, ImageSource;

import 'widgets.dart';

enum CameraMode { photo, video }

/// In-app camera (used on the web, where the browser has no camera app to hand over to).
/// Returns the captured photo or video, or null when closed.
Future<XFile?> openCamera(BuildContext context, CameraMode mode) async {
  final r = await Navigator.of(context).push<Object>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => CameraScreen(initial: mode),
    ),
  );
  if (r is XFile) return r;
  // the camera could not be opened: fall back to the browser's own capture / file chooser
  if (r == _fallback)
    return mode == CameraMode.video
        ? ImagePicker().pickVideo(source: ImageSource.camera)
        : ImagePicker().pickImage(source: ImageSource.camera);
  return null;
}

const _fallback = 'fallback';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.initial = CameraMode.photo});
  final CameraMode initial;
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  List<CameraDescription> cams = [];
  CameraController? ctl;
  int index = 0;
  late CameraMode mode = widget.initial;
  bool recording = false, denied = false, noCamera = false, busy = false;
  int seconds = 0;
  String detail = '';
  Timer? tick;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // a permission prompt nobody answers, a busy or missing camera: never spin forever
      cams = await availableCameras().timeout(const Duration(seconds: 12));
      if (cams.isEmpty) return setState(() => noCamera = true);
      await _open();
    } catch (e) {
      debugPrint('camera: availableCameras/open failed: $e');
      if (mounted)
        setState(() {
          denied = true;
          detail = '$e';
        });
    }
  }

  /// Photos need no microphone; videos ask for it, and fall back to silent video when the mic is unavailable.
  Future<void> _open() async {
    final old = ctl;
    setState(() {
      ctl = null;
      denied = false;
      detail = '';
    });
    await old?.dispose();
    for (final audio in mode == CameraMode.video ? [true, false] : [false]) {
      final c = CameraController(
        cams[index % cams.length],
        ResolutionPreset.high,
        enableAudio: audio,
      );
      try {
        await c.initialize().timeout(const Duration(seconds: 12));
        if (mounted) setState(() => ctl = c);
        return;
      } catch (e) {
        debugPrint('camera: initialize (audio: $audio) failed: $e');
        unawaited(
          c.dispose(),
        ); // never leave a half-open camera holding the device
        if (!audio || mode == CameraMode.photo) {
          if (mounted)
            setState(() {
              denied = true;
              detail = '$e';
            });
        }
      }
    }
  }

  @override
  void dispose() {
    tick?.cancel();
    ctl?.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final c = ctl;
    if (c == null || busy) return;
    setState(() => busy = true);
    try {
      if (mode == CameraMode.photo) {
        final f = await c.takePicture();
        if (mounted) Navigator.pop(context, f);
      } else if (!recording) {
        await c.startVideoRecording();
        seconds = 0;
        tick = Timer.periodic(
          const Duration(seconds: 1),
          (_) => setState(() => seconds++),
        );
        setState(() => recording = true);
      } else {
        tick?.cancel();
        final f = await c.stopVideoRecording();
        if (mounted) Navigator.pop(context, f);
      }
    } catch (_) {
      if (mounted) setState(() => denied = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k) => tr(context, k);
    final c = ctl;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: c != null && c.value.isInitialized
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: c.value.aspectRatio,
                        child: CameraPreview(c),
                      ),
                    )
                  : Center(
                      child: denied || noCamera
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    t(
                                      noCamera
                                          ? 'camera.noCamera'
                                          : 'camera.denied',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  if (detail.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        detail,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 16),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, _fallback),
                                    child: Text(t('camera.useApp')),
                                  ),
                                ],
                              ),
                            )
                          : const CircularProgressIndicator(),
                    ),
            ),
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                color: Colors.white,
                icon: const Icon(Icons.close),
                tooltip: t('close'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (recording)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '● ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!recording)
                    SegmentedButton<CameraMode>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(
                          value: CameraMode.photo,
                          label: Text(t('camera.photo')),
                        ),
                        ButtonSegment(
                          value: CameraMode.video,
                          label: Text(t('camera.video')),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (s) {
                        if (s.first == mode) return;
                        setState(() => mode = s.first);
                        if (cams.isNotEmpty) _open();
                      },
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(width: 56),
                      GestureDetector(
                        onTap: c == null ? null : _shoot,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: mode == CameraMode.video
                                  ? Colors.red
                                  : Colors.white,
                              shape: recording
                                  ? BoxShape.rectangle
                                  : BoxShape.circle,
                              borderRadius: recording
                                  ? BorderRadius.circular(8)
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 56,
                        child: cams.length > 1 && !recording
                            ? IconButton(
                                color: Colors.white,
                                tooltip: t('camera.switch'),
                                icon: const Icon(Icons.cameraswitch_outlined),
                                onPressed: () {
                                  index++;
                                  _open();
                                },
                              )
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
