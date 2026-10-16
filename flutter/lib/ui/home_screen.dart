import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/post_model.dart';
import '../core/updater.dart';
import '../state.dart';
import '../theme.dart';
import 'compose_screen.dart';
import 'design.dart';
import 'link_card.dart';
import 'media_widgets.dart';
import 'post_screen.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0; // 0 home, 1 shared, 2 mine, 3 settings
  List<Map<String, dynamic>> mine = [], shared = [];
  bool loading = false, loaded = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refresh();
      _autoUpdate();
    });
  }

  /// Silent Google Play update check at start-up; only speaks up once an update has been downloaded.
  Future<void> _autoUpdate() async {
    final r = await checkForUpdate();
    if (mounted && r == UpdateResult.downloaded) announceUpdate(context, r);
  }

  Future<void> refresh() async {
    final repo = context.read<AppState>().repo;
    if (repo == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([
        repo.listPosts(mine: true, known: mine),
        repo.listPosts(mine: false, known: shared),
      ]);
      if (!mounted) return;
      setState(() {
        mine = r[0];
        shared = r[1];
        loaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<Map<String, dynamic>> get items {
    final all = [...mine, ...shared]
      ..sort(
        (a, b) => ((b['createdAt'] ?? 0) as int).compareTo(
          (a['createdAt'] ?? 0) as int,
        ),
      );
    return tab == 0
        ? all
        : tab == 1
        ? shared
        : mine;
  }

  Future<void> open(Map<String, dynamic> e) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostScreen(id: e['id'] as String, entry: e),
      ),
    );
    if (changed == true) refresh();
  }

  Future<void> compose([ComposeStart start = ComposeStart.none]) async {
    HapticFeedback.lightImpact();
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ComposeScreen(start: start),
      ),
    );
    if (created == true) {
      setState(() => tab = tab == 1 ? 0 : tab);
      refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    return Scaffold(
      extendBody: false,
      body: tab == 3 ? const SettingsScreen() : _feed(t),
      bottomNavigationBar: _NavBar(
        index: tab,
        onTab: (i) => setState(() => tab = i),
        onCompose: compose,
        labels: [
          t('nav.home'),
          t('nav.sharedShort'),
          t('nav.mine'),
          t('nav.settings'),
        ],
      ),
    );
  }

  Widget _feed(String Function(String, [Map<String, Object?>]) t) {
    final cs = Theme.of(context).colorScheme;
    final list = items;
    final me = context.read<AppState>().account['name'] ?? '';
    final heading = tab == 1
        ? t('nav.shared')
        : tab == 2
        ? t('nav.mine')
        : null;
    return RefreshIndicator(
      onRefresh: refresh,
      color: cs.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            titleSpacing: 20,
            title: const Wordmark(size: 20),
            actions: [
              IconButton(
                tooltip: t('feed.refresh'),
                onPressed: loading ? null : refresh,
                icon: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (heading != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  heading,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
            ),
          if (tab == 0)
            SliverToBoxAdapter(
              child: _Prompt(
                name: me,
                hint: t('feed.prompt'),
                onStart: compose,
                labels: [
                  t('camera.photo'),
                  t('camera.video'),
                  t('camera.audio'),
                ],
              ),
            ),
          if (error != null)
            SliverToBoxAdapter(
              child: _ErrorBanner(
                text: error!,
                retry: t('error.retry'),
                onRetry: refresh,
              ),
            ),
          if (!loaded && list.isEmpty && error == null)
            SliverList.separated(
              itemCount: 3,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (_, __) => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14),
                child: PostSkeleton(),
              ),
            )
          else if (list.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                text: tab == 1
                    ? t('feed.emptyShared')
                    : tab == 2
                    ? t('feed.emptyMine')
                    : t('feed.empty'),
                action: tab == 1 ? null : t('nav.new'),
                onAction: compose,
                icon: tab == 1
                    ? Icons.group_outlined
                    : Icons.photo_library_outlined,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
              sliver: SliverList.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (_, i) =>
                    PostCard(entry: list[i], onTap: () => open(list[i])),
              ),
            ),
        ],
      ),
    );
  }
}

/// "What would you like to share?" card at the top of the home feed, with one-tap shortcuts.
class _Prompt extends StatelessWidget {
  const _Prompt({
    required this.name,
    required this.hint,
    required this.onStart,
    required this.labels,
  });
  final String name, hint;
  final void Function(ComposeStart) onStart;
  final List<String> labels;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget quick(IconData i, String label, Color c, ComposeStart s) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onStart(s),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(i, color: c, size: 22),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onStart(ComposeStart.none),
                child: Row(
                  children: [
                    GradientAvatar(name, size: 42),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  quick(
                    Icons.photo_camera_rounded,
                    labels[0],
                    const Color(0xFF2E8A6D),
                    ComposeStart.photo,
                  ),
                  quick(
                    Icons.videocam_rounded,
                    labels[1],
                    const Color(0xFFD1603D),
                    ComposeStart.video,
                  ),
                  quick(
                    Icons.mic_rounded,
                    labels[2],
                    const Color(0xFF6B5BD2),
                    ComposeStart.voice,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.text,
    required this.retry,
    required this.onRetry,
  });
  final String text, retry;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: cs.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: cs.onSurface)),
          ),
          TextButton(onPressed: onRetry, child: Text(retry)),
        ],
      ),
    );
  }
}

/// Bottom navigation with a raised "+" in the middle.
class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.onTab,
    required this.onCompose,
    required this.labels,
  });
  final int index;
  final ValueChanged<int> onTab;
  final VoidCallback onCompose;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget item(int i, IconData off, IconData on, String label) {
      final sel = index == i;
      return Expanded(
        child: InkWell(
          onTap: () {
            if (!sel) HapticFeedback.selectionClick();
            onTab(i);
          },
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? cs.primaryContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Icon(
                    sel ? on : off,
                    size: 24,
                    color: sel ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            item(0, Icons.home_outlined, Icons.home_rounded, labels[0]),
            item(1, Icons.group_outlined, Icons.group_rounded, labels[1]),
            SizedBox(
              width: 76,
              child: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Align(
                  heightFactor: 1,
                  child: GestureDetector(
                    onTap: onCompose,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Brand.heroLight, Brand.accent],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Brand.accent.withValues(alpha: .35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            item(
              2,
              Icons.photo_library_outlined,
              Icons.photo_library_rounded,
              labels[2],
            ),
            item(3, Icons.settings_outlined, Icons.settings_rounded, labels[3]),
          ],
        ),
      ),
    );
  }
}

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.entry, required this.onTap});
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool down = false;

  @override
  Widget build(BuildContext context) {
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    final cs = Theme.of(context).colorScheme;
    final entry = widget.entry;
    final owner = entry['owner'] as Map;
    final all = (entry['media'] as List).cast<Map>();
    final media = all.where(isVisual).toList();
    final others = all.where((m) => !isVisual(m)).toList();
    final text = (entry['text'] ?? '').toString();
    final locked = entry['locked'] == true;
    final aud = (entry['audience'] as Map).length;
    final mine = entry['mine'] == true;
    final meta = mine
        ? (aud == 0
              ? MetaPill(
                  icon: Icons.lock_outline_rounded,
                  label: t('post.onlyYou'),
                )
              : MetaPill(
                  icon: Icons.group_outlined,
                  label: t('post.people', {'n': aud}),
                  tone: cs.primary,
                ))
        : MetaPill(
            icon: Icons.favorite_rounded,
            label: t('post.sharedWithYou'),
            tone: cs.primary,
          );
    return AnimatedScale(
      scale: down ? .985 : 1,
      duration: const Duration(milliseconds: 120),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (v) => setState(() => down = v),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                child: Row(
                  children: [
                    GradientAvatar('${owner['name']}', size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${owner['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(child: meta),
                              Text(
                                '  ·  ${ago((entry['createdAt'] ?? 0) as int)}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (entry['protected'] == true)
                      Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: cs.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
              if (locked)
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [cs.primaryContainer, cs.surfaceContainerHigh],
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.lock_rounded, size: 32, color: cs.primary),
                      const SizedBox(height: 8),
                      Text(
                        t('post.protected'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              else ...[
                if (text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      text,
                      maxLines: 6,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: readFont,
                        fontSize: 17,
                        height: 1.5,
                      ),
                    ),
                  ),
                if (media.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: PhotoGrid(
                        post: entry,
                        items: media,
                        onOpen: (_) => widget.onTap(),
                      ),
                    ),
                  ),
                if (entry['link'] != null)
                  LinkCard(
                    link: Map<String, dynamic>.from(entry['link'] as Map),
                    post: entry,
                  ),
                if (others.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final m in others.take(3))
                          _Chip(
                            icon: m['kind'] == 'audio'
                                ? Icons.mic_rounded
                                : Icons.attach_file_rounded,
                            label: '${m['name']}',
                          ),
                        if (others.length > 3)
                          _Chip(
                            icon: Icons.more_horiz_rounded,
                            label: '+${others.length - 3}',
                          ),
                      ],
                    ),
                  ),
                if (text.isEmpty &&
                    media.isEmpty &&
                    entry['link'] == null &&
                    others.isEmpty)
                  const SizedBox(height: 6),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: cs.primary),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
