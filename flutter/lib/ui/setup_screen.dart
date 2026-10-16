import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/auth.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import 'design.dart';
import 'legal_screen.dart';
import 'pin_screen.dart';
import 'widgets.dart';

/// First run: Google client id/secret, then a PIN (twice). Nothing leaves the device.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final id = TextEditingController(), secret = TextEditingController();
  int step = 0; // 0 keys, 1 pin, 2 confirm
  String first = '';
  bool agreed = false; // Terms of Use + Privacy Policy, accepted on this page the first time

  @override
  void dispose() {
    id.dispose();
    secret.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k, [Map<String, Object?> p = const {}]) => tr(context, k, p);
    final i18n = context.read<I18n>();
    final cs = Theme.of(context).colorScheme;
    if (step > 0) {
      return Scaffold(
        appBar: AppBar(leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => setState(() => step = 0)), title: _Steps(current: 1)),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: PinPad(
                key: ValueKey(step),
                title: step == 1 ? t('pin.create', {'n': 6}) : t('pin.confirm'),
                hint: step == 1 ? t('pin.createHint') : null,
                onComplete: (pin) async {
                  if (step == 1) {
                    if (weakPin(pin)) return t('pin.weak');
                    first = pin;
                    setState(() => step = 2);
                    return null;
                  }
                  if (pin != first) {
                    setState(() => step = 1);
                    return t('pin.mismatch');
                  }
                  await context.read<AppState>().createVault(pin: pin, clientId: id.text, clientSecret: secret.text);
                  return null;
                },
              ),
            ),
          ),
        ),
      );
    }
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(children: [
          _Hero(title: t('welcome.title'), subtitle: t('welcome.quote'), languagePicker: SizedBox(
            width: 132,
            child: DropdownButton<String>(
              value: i18n.lang,
              isDense: true,
              isExpanded: true,
              dropdownColor: Brand.hero,
              underline: const SizedBox.shrink(),
              iconEnabledColor: Colors.white70,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              items: [for (final l in languages) DropdownMenuItem(value: l.$1, child: Text(l.$2, overflow: TextOverflow.ellipsis))],
              onChanged: (v) => v == null ? null : i18n.setLang(v),
            ),
          )),
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 28),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _Steps(current: 0),
                    const SizedBox(height: 18),
                    Text(t('welcome.sub'), style: TextStyle(color: cs.onSurfaceVariant, height: 1.45)),
                    const SizedBox(height: 18),
                    Text(t('welcome.flow2'), style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    const Guide(),
                    const SizedBox(height: 14),
                    TextField(controller: id, autocorrect: false, decoration: InputDecoration(labelText: t('welcome.clientId'), hintText: '123…apps.googleusercontent.com', prefixIcon: const Icon(Icons.key_rounded))),
                    const SizedBox(height: 12),
                    TextField(controller: secret, obscureText: true, autocorrect: false, decoration: InputDecoration(labelText: t('welcome.secret'), prefixIcon: const Icon(Icons.password_rounded))),
                    const SizedBox(height: 18),
                    if (!context.read<AppState>().consentOk) ...[ConsentCheck(agreed: agreed, onChanged: (v) => setState(() => agreed = v)), const SizedBox(height: 14)],
                    FilledButton.icon(
                      onPressed: (!context.read<AppState>().consentOk && !agreed)
                          ? null
                          : () async {
                              if (!looksLikeClientId.hasMatch(id.text.trim())) return toast(context, t('creds.badId'));
                              if (!context.read<AppState>().consentOk) await context.read<AppState>().recordConsent();
                              setState(() => step = 1);
                            },
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(t('pin.create', {'n': 6})),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(onPressed: (!context.read<AppState>().consentOk && !agreed) ? null : () async { if (!context.read<AppState>().consentOk) await context.read<AppState>().recordConsent(); if (context.mounted) await context.read<AppState>().startDemo(); }, icon: const Icon(Icons.auto_awesome_rounded, size: 18), label: Text(t('welcome.demo'))),
                    const SizedBox(height: 18),
                    Text(t('welcome.foot'), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: cs.outline)),
                    const LegalLinks(),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Brand hero: deep green gradient, soft light blobs and three tilted "photos".
class _Hero extends StatelessWidget {
  const _Hero({required this.title, required this.subtitle, this.languagePicker, this.compact = false});
  final String title, subtitle;
  final Widget? languagePicker;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    Widget photo(double angle, Offset o, List<Color> c, {double w = 74, double h = 94}) => Transform.translate(
          offset: o,
          child: Transform.rotate(angle: angle, child: Container(width: w, height: h, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white.withValues(alpha: .9), width: 3), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: c), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 16, offset: const Offset(0, 8))]))),
        );
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Brand.hero, Brand.heroDeep])),
      child: Stack(children: [
        Positioned(right: -60, top: -40, child: Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, color: Brand.heroLight.withValues(alpha: .28)))),
        Positioned(left: -80, bottom: -90, child: Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: .05)))),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 12, 24, compact ? 44 : 64),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Wordmark(size: 19, color: Colors.white, accent: Brand.accentDark), const Spacer(), if (languagePicker != null) languagePicker!]),
              SizedBox(height: compact ? 18 : 30),
              if (!compact)
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Stack(alignment: Alignment.center, children: [
                    photo(-.2, const Offset(-70, 6), const [Color(0xFFE0A370), Color(0xFFB4683A)]),
                    photo(.18, const Offset(70, 10), const [Color(0xFF6C8FD6), Color(0xFF3C5BA8)]),
                    photo(0, Offset.zero, const [Color(0xFF7CCFB0), Color(0xFF2E8A6D)], w: 84, h: 108),
                    Container(width: 36, height: 36, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white), child: const Icon(Icons.lock_rounded, size: 19, color: Brand.hero)),
                  ]),
                ),
              SizedBox(height: compact ? 0 : 22),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.22, letterSpacing: -.5)),
              const SizedBox(height: 10),
              Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .78), fontSize: 16, height: 1.45, fontFamily: readFont)),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Three-step progress: Google keys → PIN → sign in.
class _Steps extends StatelessWidget {
  const _Steps({required this.current});
  final int current;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(children: [
      for (var i = 0; i < 3; i++) ...[
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 6,
          width: i == current ? 34 : 18,
          decoration: BoxDecoration(color: i <= current ? cs.primary : cs.outlineVariant, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(width: 6),
      ],
    ]);
  }
}

class SignInScreen extends StatelessWidget {
  const SignInScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final t = (String k, [Map<String, Object?> p = const {}]) => tr(context, k, p);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(children: [
        _Hero(title: t('welcome.title'), subtitle: t('welcome.mission'), compact: true),
        Expanded(
          child: Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(32))),
              child: SafeArea(
                top: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  _Steps(current: 2),
                  const SizedBox(height: 22),
                  Text(t('welcome.flow3'), style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.4)),
                  const SizedBox(height: 24),
                  FilledButton.icon(onPressed: app.signIn, icon: const Icon(Icons.login_rounded), label: Text(t('welcome.google'))),
                  if (app.error != null) Padding(padding: const EdgeInsets.only(top: 14), child: Row(children: [Icon(Icons.error_outline_rounded, size: 18, color: cs.error), const SizedBox(width: 8), Expanded(child: Text(t(app.error!), style: TextStyle(color: cs.error)))])),
                  const Spacer(),
                  const LegalLinks(),
                  TextButton(onPressed: app.eraseEverything, child: Text(t('settings.reset'), style: TextStyle(color: cs.onSurfaceVariant))),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

/// [web] defaults to the build target: the web build shows the Web-client steps, Android shows the Desktop-client steps.
class Guide extends StatelessWidget {
  const Guide({super.key, this.web = kIsWeb, this.origin});
  final bool web;
  final String? origin; // the page address; only needed (and only valid) in the web build

  @override
  Widget build(BuildContext context) {
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    final cs = Theme.of(context).colorScheme;
    Widget link(String label, String url) => InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Text(
          label,
          style: TextStyle(
            color: cs.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
    Widget step(int n, String text, [Widget? extra]) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            child: Text('$n.', style: TextStyle(color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(text), ?extra],
            ),
          ),
        ],
      ),
    );
    // Uri.base.origin only exists on http(s) pages, i.e. in the web build
    final redirect = web ? '${origin ?? Uri.base.origin}/' : '';
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        leading: const Icon(Icons.info_outline, size: 20),
        title: Text(t('creds.howTo')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        expandedAlignment: Alignment.centerLeft,
        children: [
          step(
            1,
            t('creds.step1'),
            link(
              'console.cloud.google.com',
              'https://console.cloud.google.com/projectcreate',
            ),
          ),
          step(
            2,
            t('creds.step2'),
            link(
              'Google Drive API',
              'https://console.cloud.google.com/apis/library/drive.googleapis.com',
            ),
          ),
          step(3, t('creds.step3')),
          // Android signs in through a random local port (needs a Desktop client); the web preview uses its own address
          step(
            4,
            web ? t('creds.step4') : t('creds.step4Desktop'),
            web
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('creds.redirect'),
                          style: TextStyle(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                redirect,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Clipboard.setData(
                                ClipboardData(text: redirect),
                              ),
                              child: Text(t('creds.copy')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          step(5, t('creds.step5')),
        ],
      ),
    );
  }
}
