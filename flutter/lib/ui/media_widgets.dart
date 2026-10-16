import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../core/media_kinds.dart';
import '../core/temp_io.dart'
    if (dart.library.js_interop) '../core/temp_web.dart';
import '../state.dart';
import 'widgets.dart';

/// One photo/video thumbnail with the play badge (+ duration) for videos.
class MediaThumb extends StatelessWidget {
  const MediaThumb({
    super.key,
    required this.post,
    required this.item,
    this.thumb = true,
    this.fit = BoxFit.cover,
  });
  final Map<String, dynamic> post;
  final Map item;
  final bool thumb;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final video = item['kind'] == 'video';
    return Stack(
      fit: StackFit.expand,
      children: [
        if (video && item['thumb'] == null)
          const ColoredBox(color: Colors.black87)
        else
          DriveImage(post: post, item: item, thumb: thumb || video, fit: fit),
        if (video)
          Center(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.black45,
                shape: BoxShape.circle,
              ),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        if (video && (item['duration'] ?? 0) > 0)
          Positioned(
            right: 8,
            bottom: 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  clock(item['duration'] as num),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Photo grid like the web feed: 1 = wide, 2 = side by side, 3+ = big + two stacked; "+N" on the last tile when there are more.
class PhotoGrid extends StatelessWidget {
  const PhotoGrid({
    super.key,
    required this.post,
    required this.items,
    required this.onOpen,
    this.max = 3,
  });
  final Map<String, dynamic> post;
  final List<Map> items;
  final void Function(int index) onOpen;
  final int max;

  @override
  Widget build(BuildContext context) {
    final head = items.take(max).toList();
    final hidden = items.length - head.length;
    Widget tile(int i, {bool big = false}) => GestureDetector(
      onTap: () => onOpen(i),
      child: Stack(
        fit: StackFit.expand,
        children: [
          MediaThumb(
            post: post,
            item: head[i],
            thumb: !(big || head.length == 1),
          ),
          if (i == head.length - 1 && hidden > 0)
            ColoredBox(
              color: Colors.black45,
              child: Center(
                child: Text(
                  '+$hidden',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    const gap = 3.0;
    if (head.length == 1)
      return AspectRatio(aspectRatio: 3 / 2, child: tile(0, big: true));
    if (head.length == 2) {
      return AspectRatio(
        aspectRatio: 8 / 5,
        child: Row(
          children: [
            Expanded(child: tile(0)),
            const SizedBox(width: gap),
            Expanded(child: tile(1)),
          ],
        ),
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 11,
      child: Row(
        children: [
          Expanded(flex: 16, child: tile(0, big: true)),
          const SizedBox(width: gap),
          Expanded(
            flex: 10,
            child: Column(
              children: [
                Expanded(child: tile(1)),
                const SizedBox(height: gap),
                Expanded(child: tile(2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen viewer for photos and videos: swipe between them, pinch to zoom photos, tap a video to play.
class MediaViewer extends StatefulWidget {
  const MediaViewer({
    super.key,
    required this.post,
    required this.items,
    this.start = 0,
  });
  final Map<String, dynamic> post;
  final List<Map> items;
  final int start;
  @override
  State<MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<MediaViewer> {
  late final PageController ctl = PageController(initialPage: widget.start);
  late int i = widget.start;

  @override
  void dispose() {
    ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${i + 1} / ${widget.items.length}',
          style: const TextStyle(fontSize: 14),
        ),
      ),
      body: PageView.builder(
        controller: ctl,
        itemCount: widget.items.length,
        onPageChanged: (v) => setState(() => i = v),
        itemBuilder: (_, k) {
          final m = widget.items[k];
          return m['kind'] == 'video'
              ? VideoPane(post: widget.post, item: m, active: k == i)
              : InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: MediaThumb(
                    post: widget.post,
                    item: m,
                    thumb: false,
                    fit: BoxFit.contain,
                  ),
                );
        },
      ),
    );
  }
}

/// Downloads (and decrypts) a video, then plays it with simple controls.
class VideoPane extends StatefulWidget {
  const VideoPane({
    super.key,
    required this.post,
    required this.item,
    this.active = true,
  });
  final Map<String, dynamic> post;
  final Map item;
  final bool active;
  @override
  State<VideoPane> createState() => _VideoPaneState();
}

class _VideoPaneState extends State<VideoPane> {
  VideoPlayerController? c;
  bool failed = false, loading = false;

  Future<void> _start() async {
    setState(() => loading = true);
    try {
      final bytes = await context.read<AppState>().repo!.mediaBytes(
        widget.post,
        widget.item,
      );
      final ctl = await playerFor(
        bytes,
        '${widget.item['mime']}',
        extOf('${widget.item['name']}').isEmpty
            ? 'mp4'
            : extOf('${widget.item['name']}'),
      );
      await ctl.initialize();
      await ctl.play();
      if (!mounted) return ctl.dispose();
      setState(() {
        c = ctl;
        loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          failed = true;
          loading = false;
        });
    }
  }

  @override
  void didUpdateWidget(VideoPane old) {
    super.didUpdateWidget(old);
    if (!widget.active) c?.pause();
  }

  @override
  void dispose() {
    c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctl = c;
    if (ctl == null) {
      return GestureDetector(
        onTap: loading ? null : _start,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.item['thumb'] != null)
              DriveImage(
                post: widget.post,
                item: widget.item,
                thumb: true,
                fit: BoxFit.contain,
              ),
            Center(
              child: loading
                  ? const CircularProgressIndicator()
                  : Icon(
                      failed ? Icons.error_outline : Icons.play_circle_fill,
                      color: Colors.white,
                      size: 72,
                    ),
            ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () =>
          setState(() => ctl.value.isPlaying ? ctl.pause() : ctl.play()),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: ctl.value.aspectRatio,
              child: VideoPlayer(ctl),
            ),
          ),
          VideoProgressIndicator(
            ctl,
            allowScrubbing: true,
            padding: const EdgeInsets.all(16),
          ),
          if (!ctl.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white70,
                size: 72,
              ),
            ),
        ],
      ),
    );
  }
}

/// Voice recordings (play inline) and documents (download only — never rendered by the app).
class AttachmentList extends StatefulWidget {
  const AttachmentList({super.key, required this.post, required this.items});
  final Map<String, dynamic> post;
  final List<Map> items;
  @override
  State<AttachmentList> createState() => _AttachmentListState();
}

class _AttachmentListState extends State<AttachmentList> {
  final players = <String, VideoPlayerController>{};
  final busy = <String>{};

  @override
  void dispose() {
    for (final p in players.values) {
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _toggle(Map m) async {
    final id = '${m['id']}';
    final existing = players[id];
    if (existing != null) {
      setState(
        () => existing.value.isPlaying ? existing.pause() : existing.play(),
      );
      return;
    }
    setState(() => busy.add(id));
    try {
      final bytes = await context.read<AppState>().repo!.mediaBytes(
        widget.post,
        m,
      );
      final ext = extOf('${m['name']}');
      final c = await playerFor(
        bytes,
        '${m['mime']}',
        ext.isEmpty ? 'm4a' : ext,
      );
      await c.initialize();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      await c.play();
      if (mounted) setState(() => players[id] = c);
    } catch (_) {
      if (mounted) toast(context, tr(context, 'error.generic'));
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  Future<void> _download(Map m) async {
    final id = '${m['id']}';
    setState(() => busy.add(id));
    try {
      final Uint8List bytes = await context.read<AppState>().repo!.mediaBytes(
        widget.post,
        m,
      );
      await FilePicker.saveFile(
        fileName: '${m['name']}'.isEmpty ? 'file' : '${m['name']}',
        bytes: bytes,
        mimeType: '${m['mime']}',
      );
    } catch (_) {
      if (mounted) toast(context, tr(context, 'error.generic'));
    } finally {
      if (mounted) setState(() => busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final m in widget.items)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: cs.primaryContainer,
                child: m['kind'] == 'audio'
                    ? const Icon(Icons.mic_none)
                    : Text(
                        extOf('${m['name']}')
                            .toUpperCase()
                            .padRight(1)
                            .substring(
                              0,
                              extOf('${m['name']}').length.clamp(1, 4),
                            ),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              title: Text(
                '${m['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                [
                  if (m['kind'] == 'audio' && (m['duration'] ?? 0) > 0)
                    clock(m['duration'] as num),
                  humanSize((m['size'] ?? 0) as int),
                ].where((e) => e.isNotEmpty).join(' · '),
              ),
              trailing: busy.contains('${m['id']}')
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : m['kind'] == 'audio'
                  ? IconButton(
                      icon: Icon(
                        players['${m['id']}']?.value.isPlaying == true
                            ? Icons.pause_circle
                            : Icons.play_circle,
                      ),
                      onPressed: () => _toggle(m),
                    )
                  : IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _download(m),
                    ),
            ),
          ),
      ],
    );
  }
}
