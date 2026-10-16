import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/post_model.dart';
import '../core/repo.dart';
import '../state.dart';
import '../theme.dart';
import 'design.dart';
import 'link_card.dart';
import 'media_widgets.dart';
import 'widgets.dart';

class PostScreen extends StatefulWidget {
  const PostScreen({super.key, required this.id, this.entry});
  final String id;
  final Map<String, dynamic>? entry;
  @override
  State<PostScreen> createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  Map<String, dynamic>? post;
  List<Map<String, dynamic>> comments = [];
  List<String> likes = [];
  String? error;
  bool busy = false;
  final pw = TextEditingController(), draft = TextEditingController();
  bool changed = false;

  DriveRepo get repo => context.read<AppState>().repo!;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    pw.dispose();
    draft.dispose();
    super.dispose();
  }

  Future<void> load() async {
    try {
      final p = await repo.openPost(widget.id);
      final c = p['locked'] == true ? (comments: <Map<String, dynamic>>[], likes: <String>[]) : await repo.loadComments(p);
      if (!mounted) return;
      setState(() { post = p; comments = c.comments; likes = c.likes; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = errorText(context, e));
    }
  }

  Future<void> unlock() async {
    setState(() => busy = true);
    try {
      await repo.unlockPost(widget.id, post!['doc'] as Map<String, dynamic>, pw.text, remember: post!['mine'] == true);
      pw.clear();
      await load();
    } catch (e) {
      if (mounted) toast(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> like() async {
    try {
      final l = await repo.toggleLike(post!);
      setState(() => likes = l);
    } catch (e) {
      toast(context, errorText(context, e));
    }
  }

  Future<void> send() async {
    final text = draft.text;
    if (text.trim().isEmpty) return;
    setState(() => busy = true);
    try {
      final r = await repo.addComment(post!, text);
      if (r != null) setState(() { comments = r; draft.clear(); });
    } catch (e) {
      toast(context, errorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> delete() async {
    final t = (String k) => tr(context, k);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(t('post.deleteConfirm')),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t('compose.cancel'))), FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t('post.delete')))],
      ),
    );
    if (ok != true) return;
    try {
      await repo.deletePost(post!);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errorText(context, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k, [Map<String, Object?> p = const {}]) => tr(context, k, p);
    final cs = Theme.of(context).colorScheme;
    final p = post;
    final me = repo.me.email;
    if (p == null) {
      return Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.cloud_off_rounded, size: 40, color: cs.onSurfaceVariant), const SizedBox(height: 12), Text(error!, textAlign: TextAlign.center), const SizedBox(height: 16), FilledButton(onPressed: () { setState(() => error = null); load(); }, child: Text(t('error.retry')))])))
            : const Padding(padding: EdgeInsets.all(16), child: PostSkeleton()),
      );
    }
    final owner = p['owner'] as Map;
    final media = (p['media'] as List).cast<Map>();
    final visual = media.where(isVisual).toList();
    final others = media.where((m) => !isVisual(m)).toList();
    final mine = p['mine'] == true;
    final aud = (p['audience'] as Map).length;
    final canComment = p['commentMode'] != 'locked' && p['locked'] != true && (mine || canCommentWith(p['commentMode'] as String, p['role'] as String) || p['commentMode'] == 'open');
    final liked = likes.contains(me);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) { if (!didPop) Navigator.pop(context, changed); },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: () => Navigator.pop(context, changed)),
          actions: [if (mine) IconButton(tooltip: t('post.delete'), onPressed: delete, icon: const Icon(Icons.delete_outline_rounded))],
        ),
        body: ListView(padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(children: [
              GradientAvatar('${owner['name']}', size: 50),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${owner['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Flexible(child: mine ? (aud == 0 ? MetaPill(icon: Icons.lock_outline_rounded, label: t('post.onlyYou')) : MetaPill(icon: Icons.group_outlined, label: t('post.people', {'n': aud}), tone: cs.primary)) : MetaPill(icon: Icons.favorite_rounded, label: t('post.sharedWithYou'), tone: cs.primary)),
                    Text('  ·  ${ago((p['createdAt'] ?? 0) as int)}', style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant)),
                  ]),
                ]),
              ),
            ]),
          ),
          if (p['locked'] == true)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [cs.primaryContainer, cs.surfaceContainerHigh])),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [Icon(Icons.lock_rounded, color: cs.primary), const SizedBox(width: 10), Text(t('post.protected'), style: Theme.of(context).textTheme.titleMedium)]),
                const SizedBox(height: 8),
                Text(t('post.protectedHint', {'name': '${owner['name']}'}), style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 14),
                TextField(controller: pw, obscureText: true, onSubmitted: (_) => unlock(), decoration: InputDecoration(labelText: t('post.password'), fillColor: cs.surface)),
                const SizedBox(height: 12),
                FilledButton(onPressed: busy ? null : unlock, child: Text(t('post.unlock'))),
              ]),
            )
          else ...[
            if ((p['text'] as String).isNotEmpty)
              Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 14), child: SelectableText(p['text'] as String, style: const TextStyle(fontFamily: readFont, fontSize: 19, height: 1.55))),
            if (visual.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(children: [
                    PhotoGrid(post: p, items: visual, max: 3, onOpen: (i) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaViewer(post: p, items: visual, start: i)))),
                    if (visual.length > 3)
                      Padding(padding: const EdgeInsets.only(top: 3), child: Wrap(spacing: 3, runSpacing: 3, children: [for (var k = 3; k < visual.length; k++) SizedBox(width: 76, height: 76, child: GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => MediaViewer(post: p, items: visual, start: k))), child: MediaThumb(post: p, item: visual[k])))])),
                  ]),
                ),
              ),
            if (p['link'] != null) LinkCard(link: Map<String, dynamic>.from(p['link'] as Map), post: p),
            if (others.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: AttachmentList(post: p, items: others)),
            // reactions
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Row(children: [
                _LikeButton(liked: liked, count: likes.length, onTap: like),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(99)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.chat_bubble_outline_rounded, size: 19, color: cs.onSurfaceVariant), const SizedBox(width: 6), Text('${comments.length}', style: const TextStyle(fontWeight: FontWeight.w600))]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
            if (comments.isNotEmpty) const Divider(height: 24),
            for (final c in comments)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  GradientAvatar('${c['name']}', size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: const BorderRadius.only(topLeft: Radius.circular(6), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(18))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Expanded(child: Text('${c['name']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))), Text(ago((c['at'] ?? 0) as int), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))]),
                        const SizedBox(height: 3),
                        Text('${c['text']}', style: const TextStyle(fontFamily: readFont, fontSize: 16, height: 1.4)),
                      ]),
                    ),
                  ),
                  if (c['by'] == me || mine)
                    IconButton(visualDensity: VisualDensity.compact, icon: Icon(Icons.close_rounded, size: 18, color: cs.onSurfaceVariant), onPressed: () async { try { final r = await repo.deleteComment(p, '${c['id']}'); setState(() => comments = r); } catch (e) { toast(context, errorText(context, e)); } }),
                ]),
              ),
            if (!canComment && p['locked'] != true)
              Padding(padding: const EdgeInsets.all(20), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline_rounded, size: 16, color: cs.onSurfaceVariant), const SizedBox(width: 6), Flexible(child: Text(t('comments.lockedNotice'), style: TextStyle(color: cs.onSurfaceVariant)))])),
          ],
        ]),
        bottomNavigationBar: p['locked'] != true && canComment
            ? SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.viewInsetsOf(context).bottom),
                  child: Row(children: [
                    GradientAvatar(repo.me.name, size: 36),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: draft, minLines: 1, maxLines: 4, textInputAction: TextInputAction.send, onSubmitted: (_) => send(), decoration: InputDecoration(hintText: t('post.comment'), contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12), border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide(color: cs.primary, width: 1.6))))),
                    const SizedBox(width: 6),
                    IconButton.filled(onPressed: busy ? null : send, icon: const Icon(Icons.arrow_upward_rounded)),
                  ]),
                ),
              )
            : null,
      ),
    );
  }
}

/// Heart with a little pop when it turns on.
class _LikeButton extends StatelessWidget {
  const _LikeButton({required this.liked, required this.count, required this.onTap});
  final bool liked;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: liked ? Brand.spark.withValues(alpha: .14) : cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          TweenAnimationBuilder<double>(
            key: ValueKey(liked),
            tween: Tween(begin: liked ? .5 : 1, end: 1),
            duration: const Duration(milliseconds: 420),
            curve: Curves.elasticOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 21, color: liked ? Brand.spark : cs.onSurfaceVariant),
          ),
          const SizedBox(width: 6),
          Text('$count', style: TextStyle(fontWeight: FontWeight.w600, color: liked ? Brand.spark : null)),
        ]),
      ),
    );
  }
}
