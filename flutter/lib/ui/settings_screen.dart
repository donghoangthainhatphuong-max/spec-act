import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/links.dart';
import '../core/updater.dart';
import '../core/vault.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import 'design.dart';
import 'legal_screen.dart';
import 'pin_screen.dart';
import 'widgets.dart';

/// Settings → "Check for updates": same Google Play flow as the automatic check, but reports the outcome.
Future<void> manualUpdateCheck(BuildContext context) async {
  final r = await checkForUpdate();
  if (!context.mounted) return;
  announceUpdate(context, r);
}

void announceUpdate(BuildContext context, UpdateResult r) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  switch (r) {
    case UpdateResult.downloaded:
      m.showSnackBar(
        SnackBar(
          duration: const Duration(days: 1),
          content: Text(tr(context, 'update.downloaded')),
          action: SnackBarAction(
            label: tr(context, 'update.restart'),
            onPressed: installUpdate,
          ),
        ),
      );
    case UpdateResult.latest:
      m.showSnackBar(SnackBar(content: Text(tr(context, 'update.latest'))));
    case UpdateResult.unavailable:
      m.showSnackBar(
        SnackBar(content: Text(tr(context, 'update.unavailable'))),
      );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<bool> _confirm(BuildContext c, String msg, String action) async =>
      await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(tr(c, 'compose.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _changePin(BuildContext context) async {
    final app = context.read<AppState>();
    String? old, fresh;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => StatefulBuilder(
          builder: (c, set) {
            final t = (String k) => tr(c, k);
            final step = old == null
                ? 0
                : fresh == null
                ? 1
                : 2;
            return Scaffold(
              appBar: AppBar(),
              body: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: PinPad(
                    key: ValueKey(step),
                    title: t(
                      [
                        'pin.change.old',
                        'pin.change.new',
                        'pin.change.confirm',
                      ][step],
                    ),
                    onComplete: (pin) async {
                      if (step == 0) {
                        try {
                          await app.vault.verify(pin);
                        } on VaultError {
                          return t('pin.wrong').replaceAll('{n}', '').trim();
                        }
                        set(() => old = pin);
                      } else if (step == 1) {
                        if (pin == old) return t('pin.change.same');
                        if (weakPin(pin)) return t('pin.weak');
                        set(() => fresh = pin);
                      } else {
                        if (pin != fresh) {
                          set(() {
                            fresh = null;
                          });
                          return t('pin.mismatch');
                        }
                        await app.changePin(old!, pin);
                        if (c.mounted) Navigator.pop(c);
                      }
                      return null;
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final i18n = context.watch<I18n>();
    final theme = context.watch<ThemeController>();
    final cs = Theme.of(context).colorScheme;
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    Widget section(String? title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: .8,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(indent: 70, color: cs.outlineVariant),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
    Widget row(
      IconData icon,
      String title, {
      String? sub,
      VoidCallback? onTap,
      Widget? trailing,
      Color? tone,
    }) => ListTile(
      leading: TonalIcon(icon, color: tone),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: tone),
      ),
      subtitle: sub == null
          ? null
          : Text(sub, style: const TextStyle(fontSize: 12.5)),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(Icons.chevron_right_rounded, color: cs.outline)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Text(
              t('settings.title'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          // profile
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Brand.hero, Brand.heroDeep],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GradientAvatar(
                        app.account['name'] ?? '',
                        size: 58,
                        ring: true,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app.account['name'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              app.account['email'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: .75),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const BrandMark(size: 30, color: Colors.white70),
                    ],
                  ),
                  FutureBuilder<Map<String, dynamic>>(
                    future: app.repo?.quota(),
                    builder: (_, s) {
                      final q = s.data;
                      if (q == null) return const SizedBox(height: 4);
                      final used = int.tryParse('${q['usage'] ?? ''}') ?? 0,
                          limit = int.tryParse('${q['limit'] ?? ''}');
                      String gb(int v) => v >= 1073741824
                          ? '${(v / 1073741824).toStringAsFixed(1)} GB'
                          : '${(v / 1048576).round()} MB';
                      return Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (limit != null && limit > 0)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: (used / limit).clamp(0, 1).toDouble(),
                                  minHeight: 6,
                                  backgroundColor: Colors.white24,
                                  color: Brand.accentDark,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(
                                  Icons.cloud_outlined,
                                  size: 15,
                                  color: Colors.white70,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  limit != null
                                      ? t('settings.storageUsed', {
                                          'used': gb(used),
                                          'total': gb(limit),
                                        })
                                      : t('settings.storageUsedOnly', {
                                          'used': gb(used),
                                        }),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          section(t('settings.appearance'), [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_outlined, size: 18),
                      label: Text(t('settings.light')),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_outlined, size: 18),
                      label: Text(t('settings.dark')),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(
                        Icons.brightness_auto_outlined,
                        size: 18,
                      ),
                      label: Text(t('settings.system')),
                    ),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (s) =>
                      context.read<ThemeController>().set(s.first),
                ),
              ),
            ),
            row(
              Icons.language_rounded,
              t('settings.language'),
              trailing: DropdownButton<String>(
                value: i18n.lang,
                underline: const SizedBox.shrink(),
                items: [
                  for (final l in languages)
                    DropdownMenuItem(value: l.$1, child: Text(l.$2)),
                ],
                onChanged: (v) => v == null ? null : i18n.setLang(v),
              ),
            ),
          ]),
          section(t('settings.security'), [
            row(Icons.lock_rounded, t('settings.lockNow'), onTap: app.lock),
            row(
              Icons.pin_rounded,
              t('settings.changePin'),
              sub: t('settings.pinHint', {'n': 6}),
              onTap: () => _changePin(context),
            ),
          ]),
          section(t('settings.account'), [
            row(
              Icons.logout_rounded,
              t('settings.signOut'),
              onTap: () async {
                if (await _confirm(
                  context,
                  t('settings.signOutConfirm'),
                  t('settings.signOut'),
                ))
                  await app.signOut();
              },
            ),
          ]),
          section(t('settings.about'), [
            row(
              Icons.info_outline_rounded,
              t('legal.about'),
              onTap: () => openLegal(context, LegalPage.about),
            ),
            row(
              Icons.description_outlined,
              t('consent.termsLink'),
              onTap: () => openLegal(context, LegalPage.terms),
            ),
            row(
              Icons.privacy_tip_outlined,
              t('consent.privacyLink'),
              onTap: () => openLegal(context, LegalPage.privacy),
            ),
            row(
              Icons.code_rounded,
              t('settings.github'),
              sub: 'github.com/donghoangthainhatphuong-max/spec-act',
              onTap: () => openLink(githubUrl),
            ),
            row(
              Icons.public_rounded,
              t('settings.website'),
              onTap: () => openLink(websiteUrl),
            ),
            row(
              Icons.system_update_rounded,
              t('settings.update'),
              onTap: () => manualUpdateCheck(context),
            ),
          ]),
          section(t('settings.danger'), [
            row(
              Icons.delete_forever_rounded,
              t('settings.reset'),
              sub: t('settings.resetHint'),
              tone: cs.error,
              onTap: () async {
                if (await _confirm(
                  context,
                  t('settings.resetConfirm'),
                  t('settings.reset'),
                ))
                  await app.eraseEverything();
              },
            ),
          ]),
        ],
      ),
    );
  }
}
