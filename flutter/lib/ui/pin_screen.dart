import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/vault.dart';
import '../state.dart';
import 'design.dart';
import 'widgets.dart';

/// Numeric keypad. [onComplete] gets the full PIN; return an error text to show (and clear), or null on success.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.title,
    this.hint,
    required this.onComplete,
  });
  final String title;
  final String? hint;
  final Future<String?> Function(String pin) onComplete;
  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String pin = '';
  String? err;
  bool busy = false;
  late final AnimationController shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    shake.dispose();
    super.dispose();
  }

  Future<void> _tap(String d) async {
    if (busy || pin.length >= Config.pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      pin += d;
      err = null;
    });
    if (pin.length == Config.pinLength) {
      setState(() => busy = true);
      final e = await widget.onComplete(pin);
      if (!mounted) return;
      if (e != null) {
        HapticFeedback.heavyImpact();
        shake.forward(from: 0);
      }
      setState(() {
        busy = false;
        err = e;
        if (e != null) pin = '';
      });
    }
  }

  void _back() {
    if (busy || pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => pin = pin.substring(0, pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget key(String label, {VoidCallback? onTap, IconData? icon}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: AspectRatio(
          aspectRatio: 1.35,
          child: Material(
            color: label.isEmpty && icon == null
                ? Colors.transparent
                : cs.surfaceContainerHigh,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Center(
                child: icon != null
                    ? Icon(icon, color: cs.onSurfaceVariant)
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
    Widget row(List<String> ds) =>
        Row(children: [for (final d in ds) key(d, onTap: () => _tap(d))]);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        if (widget.hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.hint!,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
        const SizedBox(height: 24),
        AnimatedBuilder(
          animation: shake,
          builder: (_, child) => Transform.translate(
            offset: Offset(
              math.sin(shake.value * math.pi * 6) * 12 * (1 - shake.value),
              0,
            ),
            child: child,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < Config.pinLength; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOutBack,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: i < pin.length ? 18 : 14,
                  height: i < pin.length ? 18 : 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < pin.length
                        ? (err != null ? cs.error : cs.primary)
                        : Colors.transparent,
                    border: Border.all(
                      color: err != null ? cs.error : cs.primary,
                      width: 1.8,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 40,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                err ?? '',
                key: ValueKey(err),
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.error, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
        row(['1', '2', '3']),
        row(['4', '5', '6']),
        row(['7', '8', '9']),
        Row(
          children: [
            key('', onTap: null),
            key('0', onTap: () => _tap('0')),
            key('', icon: Icons.backspace_outlined, onTap: _back),
          ],
        ),
      ],
    );
  }
}

/// PIN is too easy to guess: all the same digit or a straight run.
bool weakPin(String p) {
  if (RegExp(r'^(\d)\1+$').hasMatch(p)) return true;
  const up = '01234567890', down = '09876543210';
  return up.contains(p) || down.contains(p);
}

class UnlockScreen extends StatelessWidget {
  const UnlockScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 56),
                  const SizedBox(height: 20),
                  PinPad(
                    title: t('pin.unlock'),
                    hint: t('pin.unlockHint'),
                    onComplete: (pin) async {
                      try {
                        await app.unlock(pin);
                        return null;
                      } on VaultError catch (e) {
                        if (e.code == 'wiped') {
                          await app.wiped();
                          return t('pin.wiped');
                        }
                        if (e.code == 'throttled' ||
                            (e.code == 'bad-pin' && e.retryInMs > 0))
                          return t('pin.wait', {
                            'n': (e.retryInMs / 1000).ceil(),
                          });
                        return t('pin.wrong', {'n': e.remaining});
                      }
                    },
                  ),
                  TextButton(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          content: Text(t('pin.forgotConfirm')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: Text(t('compose.cancel')),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: Text(t('settings.reset')),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) await app.eraseEverything();
                    },
                    child: Text(t('pin.forgot')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
