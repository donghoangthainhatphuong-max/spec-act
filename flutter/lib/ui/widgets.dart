import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/repo.dart';
import '../i18n.dart';
import '../state.dart';
import 'design.dart';

String tr(BuildContext c, String key, [Map<String, Object?> p = const {}]) => c.watch<I18n>().t(key, p);

void toast(BuildContext c, String msg) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

/// Maps a thrown error to a translated message; never shows raw exception text.
String errorText(BuildContext c, Object e) {
  final i = c.read<I18n>();
  if (e is RepoError) {
    switch (e.code) {
      case 'not-found': return i.t('post.notFound');
      case 'forbidden': return i.t('post.forbidden');
      case 'wrong-password': return i.t('post.wrongPassword');
      case 'offline': return i.t('error.sync');
    }
  }
  return i.t('error.generic');
}

String ago(int ms) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ms));
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  if (d.inDays < 30) return '${d.inDays}d';
  final t = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

/// Round avatar with a colour derived from the name.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 40});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => GradientAvatar(name, size: size);
}

/// Loads (and decrypts) one photo through the repo; shows a placeholder meanwhile.
class DriveImage extends StatefulWidget {
  const DriveImage({super.key, required this.post, required this.item, this.thumb = false, this.fit = BoxFit.cover});
  final Map<String, dynamic> post;
  final Map item;
  final bool thumb;
  final BoxFit fit;
  @override
  State<DriveImage> createState() => _DriveImageState();
}

class _DriveImageState extends State<DriveImage> {
  late Future<Uint8List> _f;
  @override
  void initState() {
    super.initState();
    _f = context.read<AppState>().repo!.mediaBytes(widget.post, widget.item, thumb: widget.thumb);
  }

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).colorScheme.surfaceContainerHighest;
    return FutureBuilder<Uint8List>(
      future: _f,
      builder: (_, s) {
        if (s.hasData) return Image.memory(s.data!, fit: widget.fit, gaplessPlayback: true, cacheWidth: widget.thumb ? 720 : 1600, filterQuality: FilterQuality.medium, errorBuilder: (_, __, ___) => ColoredBox(color: bg, child: const Icon(Icons.broken_image_outlined)));
        return ColoredBox(color: bg, child: Center(child: s.hasError ? const Icon(Icons.lock_outline) : const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))));
      },
    );
  }
}
