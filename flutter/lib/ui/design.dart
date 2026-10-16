/// Shared building blocks of the SPECACT look: brand mark, gradient avatars, skeletons, empty states.
import 'package:flutter/material.dart';

import '../theme.dart';

/// The SPECACT mark: a moment with a keyhole (yours) inside the circle of the few people you chose.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 28, this.color, this.spark, this.hole});
  final double size;
  final Color? color, spark, hole; // hole is kept for old call sites: the keyhole is now cut out
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(size: Size.square(size), painter: _MarkPainter(color ?? cs.primary, spark ?? Brand.spark));
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color, this.spark);
  final Color color, spark;
  @override
  void paint(Canvas canvas, Size s) {
    final k = s.width / 64;
    canvas.saveLayer(Offset.zero & s, Paint());
    canvas.drawCircle(Offset(32 * k, 32 * k), 27 * k, Paint()..color = color.withValues(alpha: .4)..style = PaintingStyle.stroke..strokeWidth = 2.4 * k);
    canvas.drawCircle(Offset(32 * k, 32 * k), 15.5 * k, Paint()..color = color);
    final cut = Paint()..blendMode = BlendMode.clear; // the keyhole is cut out, whatever sits behind shows through
    canvas.drawCircle(Offset(32 * k, 29.5 * k), 4.3 * k, cut);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(29.8 * k, 30.5 * k, 4.4 * k, 11 * k), Radius.circular(2.2 * k)), cut);
    canvas.restore();
    final dot = Paint()..color = spark;
    canvas.drawCircle(Offset(51.1 * k, 12.9 * k), 4.2 * k, dot);
    canvas.drawCircle(Offset(27.3 * k, 58.6 * k), 3.4 * k, dot);
    canvas.drawCircle(Offset(6.6 * k, 22.8 * k), 3.4 * k, dot);
  }

  @override
  bool shouldRepaint(_MarkPainter o) => o.color != color || o.spark != spark;
}

/// Mark + wordmark: "spec" (the open format) in regular weight, "act" (what you do) bold in the accent colour.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 22, this.color, this.accent});
  final double size;
  final Color? color, accent;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.onSurface;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      BrandMark(size: size + 8, color: color ?? cs.primary),
      const SizedBox(width: 8),
      Flexible(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: 'spec', style: TextStyle(fontWeight: FontWeight.w500, color: c)),
            TextSpan(text: 'act', style: TextStyle(fontWeight: FontWeight.w800, color: accent ?? color ?? cs.primary)),
          ]),
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: TextStyle(fontSize: size * 1.12, letterSpacing: -.4, height: 1.25),
        ),
      ),
    ]);
  }
}

/// A person's colour is derived from the name, so the same friend always looks the same.
Color avatarColor(String name, {double l = .42}) {
  final h = name.runes.fold<int>(7, (a, r) => (a * 31 + r) & 0xFFFFFF) % 360;
  return HSLColor.fromAHSL(1, h.toDouble(), .42, l).toColor();
}

class GradientAvatar extends StatelessWidget {
  const GradientAvatar(this.name, {super.key, this.size = 44, this.ring = false});
  final String name;
  final double size;
  final bool ring;
  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    final a = avatarColor(name), b = HSLColor.fromColor(a).withHue((HSLColor.fromColor(a).hue + 28) % 360).withLightness(.58).toColor();
    final core = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [b, a])),
      child: Text(letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * .42)),
    );
    if (!ring) return core;
    return Container(padding: const EdgeInsets.all(2.5), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2)), child: core);
  }
}

/// "Only you" / "4 people" / "Shared with you" pill.
class MetaPill extends StatelessWidget {
  const MetaPill({super.key, required this.icon, required this.label, this.tone});
  final IconData icon;
  final String label;
  final Color? tone;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = tone ?? cs.onSurfaceVariant;
    return Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 14, color: c), const SizedBox(width: 4), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: c)))]);
  }
}

/// Shimmering placeholder block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 10});
  final double height;
  final double? width;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();
  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: c,
      builder: (_, __) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(begin: Alignment(-1.5 + c.value * 3, 0), end: Alignment(-0.5 + c.value * 3, 0), colors: [cs.surfaceContainerHigh, cs.surfaceContainerHighest, cs.surfaceContainerHigh]),
        ),
      ),
    );
  }
}

/// A feed card made of skeletons while posts load.
class PostSkeleton extends StatelessWidget {
  const PostSkeleton({super.key});
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Skeleton(height: 44, width: 44, radius: 22), SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Skeleton(width: 120), SizedBox(height: 8), Skeleton(width: 80, height: 12)]))]),
            const SizedBox(height: 14),
            const Skeleton(height: 180, radius: 18),
            const SizedBox(height: 14),
            const Skeleton(),
            const SizedBox(height: 8),
            Skeleton(width: MediaQuery.sizeOf(context).width * .5),
          ]),
        ),
      );
}

/// Friendly empty state: three tilted "photos", a line of text and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text, this.action, this.onAction, this.icon = Icons.photo_library_outlined});
  final String text;
  final String? action;
  final VoidCallback? onAction;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget card(double angle, Color c, Offset o, {IconData? i}) => Transform.translate(
          offset: o,
          child: Transform.rotate(
            angle: angle,
            child: Container(width: 92, height: 112, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(18), border: Border.all(color: cs.surface, width: 4), boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: .12), blurRadius: 18, offset: const Offset(0, 8))]), child: i == null ? null : Icon(i, color: Colors.white.withValues(alpha: .9), size: 34)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
          height: 150,
          width: 240,
          child: Stack(alignment: Alignment.center, children: [
            card(-.22, cs.primaryContainer, const Offset(-58, 8)),
            card(.2, cs.secondaryContainer, const Offset(58, 10)),
            card(0, Brand.accent, Offset.zero, i: icon),
          ]),
        ),
        const SizedBox(height: 24),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500, height: 1.4)),
        if (action != null) ...[const SizedBox(height: 20), FilledButton.icon(onPressed: onAction, icon: const Icon(Icons.add), label: Text(action!))],
      ]),
    );
  }
}

/// Icon in a soft tinted circle (settings rows, feature lists).
class TonalIcon extends StatelessWidget {
  const TonalIcon(this.icon, {super.key, this.color, this.size = 40});
  final IconData icon;
  final Color? color;
  final double size;
  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(width: size, height: size, decoration: BoxDecoration(color: c.withValues(alpha: .12), borderRadius: BorderRadius.circular(size * .32)), child: Icon(icon, color: c, size: size * .52));
  }
}
