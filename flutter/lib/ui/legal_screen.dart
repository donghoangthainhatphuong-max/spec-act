import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/legal.dart';
import '../i18n.dart';
import '../state.dart';
import '../theme.dart';
import 'design.dart';

enum LegalPage { about, terms, privacy }

/// About / Terms of Use / Privacy Policy, in the reading serif.
class LegalScreen extends StatefulWidget {
  const LegalScreen({super.key, required this.page});
  final LegalPage page;
  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  Future<LegalDoc>? _doc;
  String? _lang;

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    if (_lang != i18n.lang) {
      _lang = i18n.lang;
      _doc = loadLegal(widget.page.name, i18n.lang);
    }
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<LegalDoc>(
      future: _doc,
      builder: (_, s) {
        final d = s.data;
        // Only English and Vietnamese have these texts. For any other language the WHOLE page is English — text, labels, dates, direction —
        // so two languages are never mixed on one screen.
        final t = (d == null || d.native) ? i18n.t : i18n.tEn;
        final body = d == null
            ? Center(
                child: s.hasError
                    ? Text(i18n.t('error.generic'))
                    : const CircularProgressIndicator(),
              )
            : _content(context, d, t, cs);
        return Directionality(
          textDirection: (d != null && !d.native)
              ? TextDirection.ltr
              : Directionality.of(context),
          child: Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              title: Text(d?.title ?? ''),
            ),
            body: body,
          ),
        );
      },
    );
  }

  Widget _content(
    BuildContext context,
    LegalDoc d,
    String Function(String, [Map<String, Object?>]) t,
    ColorScheme cs,
  ) {
    final updated = DateTime.tryParse(d.updated);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Text(d.title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          d.lead,
          style: const TextStyle(
            fontFamily: readFont,
            fontSize: 18,
            height: 1.55,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          [
            t('legal.updated', {
              'date': updated == null
                  ? d.updated
                  : '${updated.year}-${updated.month.toString().padLeft(2, '0')}-${updated.day.toString().padLeft(2, '0')}',
            }),
            if (!d.native) t('legal.fallback'),
          ].join(' · '),
          style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
        ),
        for (final sec in d.sections) ...[
          const SizedBox(height: 26),
          Text(sec.heading, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final p in sec.paragraphs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                p,
                style: const TextStyle(
                  fontFamily: readFont,
                  fontSize: 16.5,
                  height: 1.6,
                ),
              ),
            ),
          for (final li in sec.items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 9, right: 10),
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      li,
                      style: const TextStyle(
                        fontFamily: readFont,
                        fontSize: 16.5,
                        height: 1.55,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        if (legalContact.isNotEmpty) ...[
          const SizedBox(height: 26),
          InkWell(
            onTap: () => launchUrl(Uri(scheme: 'mailto', path: legalContact)),
            child: Text(
              '${t('legal.contact')}: $legalContact',
              style: TextStyle(
                color: cs.primary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Opens one of the legal pages.
void openLegal(BuildContext context, LegalPage page) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => LegalScreen(page: page)));

/// "About · Terms · Privacy" link row (welcome, sign-in, consent screens).
class LegalLinks extends StatelessWidget {
  const LegalLinks({super.key, this.color});
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final t = context.watch<I18n>().t;
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    Widget link(String label, LegalPage p) => InkWell(
      onTap: () => openLegal(context, p),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            color: c,
            decoration: TextDecoration.underline,
            decorationColor: c,
          ),
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      children: [
        link(t('legal.about'), LegalPage.about),
        link(t('legal.terms'), LegalPage.terms),
        link(t('legal.privacy'), LegalPage.privacy),
      ],
    );
  }
}

/// Shown before anything else until the current Terms of Use and Privacy Policy are accepted.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key});
  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool agreed = false;

  @override
  Widget build(BuildContext context) {
    final i18n = context.watch<I18n>();
    final t = i18n.t;
    final cs = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(termsVersion);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Wordmark(size: 20),
                      const Spacer(),
                      SizedBox(
                        width: 132,
                        child: DropdownButton<String>(
                          value: i18n.lang,
                          isDense: true,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final l in languages)
                              DropdownMenuItem(
                                value: l.$1,
                                child: Text(
                                  l.$2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => v == null ? null : i18n.setLang(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    t('consent.title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('consent.lead'),
                    style: TextStyle(
                      color: cs.onSurfaceVariant,
                      height: 1.5,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final k in ['k1', 'k2', 'k3', 'k4'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.verified_user_outlined,
                              size: 20,
                              color: cs.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t('consent.$k'),
                              style: const TextStyle(
                                height: 1.5,
                                fontSize: 15.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 8),
                  ConsentCheck(
                    agreed: agreed,
                    onChanged: (v) => setState(() => agreed = v),
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: agreed
                        ? () => context.read<AppState>().acceptTerms()
                        : null,
                    child: Text(t('consent.accept')),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('consent.version', {
                      'date': date == null
                          ? termsVersion
                          : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, color: cs.outline),
                  ),
                  const SizedBox(height: 6),
                  const LegalLinks(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "[ ] I have read and agree to the Terms of Use and the Privacy Policy." with both names as links.
class ConsentCheck extends StatelessWidget {
  const ConsentCheck({
    super.key,
    required this.agreed,
    required this.onChanged,
  });
  final bool agreed;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<I18n>().t;
    final cs = Theme.of(context).colorScheme;
    final link = TextStyle(
      color: cs.primary,
      fontWeight: FontWeight.w700,
      decoration: TextDecoration.underline,
      decorationColor: cs.primary,
    );
    final spans = <InlineSpan>[];
    final text = t('consent.check');
    var at = 0;
    for (final m in RegExp(r'\{terms\}|\{privacy\}').allMatches(text)) {
      if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
      final terms = m.group(0) == '{terms}';
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () =>
                openLegal(context, terms ? LegalPage.terms : LegalPage.privacy),
            child: Text(
              t(terms ? 'consent.termsLink' : 'consent.privacyLink'),
              style: link,
            ),
          ),
        ),
      );
      at = m.end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => onChanged(!agreed),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 14, 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(value: agreed, onChanged: (v) => onChanged(v ?? false)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(children: spans),
                  style: const TextStyle(height: 1.5, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
