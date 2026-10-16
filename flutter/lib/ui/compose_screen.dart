import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/config.dart';
import '../core/link_preview.dart';
import '../core/media_kinds.dart';
import '../core/temp_io.dart'
    if (dart.library.js_interop) '../core/temp_web.dart';
import '../core/post_model.dart';
import '../core/repo.dart';
import '../state.dart';
import '../theme.dart';
import 'camera_dialog.dart';
import 'design.dart';
import 'link_card.dart';
import 'recorder_dialog.dart';
import 'widgets.dart';

/// Re-encodes a photo as JPEG: orientation baked in, EXIF (GPS, device…) dropped, long side capped; plus a thumbnail.
NewMedia prepareImage((Uint8List, String) arg) {
  final decoded = img.decodeImage(arg.$1);
  if (decoded == null) throw const FormatException('not an image');
  var im = img.bakeOrientation(decoded);
  img.Image fit(img.Image src, int side) =>
      (src.width > side || src.height > side)
      ? img.copyResize(
          src,
          width: src.width >= src.height ? side : null,
          height: src.height > src.width ? side : null,
          interpolation: img.Interpolation.average,
        )
      : src;
  im = fit(im, Config.maxImageSide);
  im.exif.clear();
  final thumb = fit(im, 480)..exif.clear();
  return NewMedia(
    main: Uint8List.fromList(img.encodeJpg(im, quality: 85)),
    thumb: Uint8List.fromList(img.encodeJpg(thumb, quality: 75)),
    w: im.width,
    h: im.height,
    name: arg.$2,
  );
}

/// What the composer should open right away (the shortcuts of the home screen).
enum ComposeStart { none, photo, video, voice }

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key, this.start = ComposeStart.none});
  final ComposeStart start;
  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final text = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  final media = <NewMedia>[];
  final audience = <String, String>{};
  String mode = 'shared';
  bool link = false, protect = false, busy = false;
  String status = '';
  // link preview: a pasted link becomes a card, unless the person closed it
  LinkPreview? card;
  bool fetchingLink = false;
  final dismissed = <String>{};
  Timer? linkTimer;
  int linkSeq = 0;

  @override
  void initState() {
    super.initState();
    text.addListener(_onText);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (widget.start) {
        case ComposeStart.photo:
          addPhotos(ImageSource.camera);
        case ComposeStart.video:
          addVideo(ImageSource.camera);
        case ComposeStart.voice:
          addVoice();
        case ComposeStart.none:
          break;
      }
    });
  }

  void _onText() {
    linkTimer?.cancel();
    final url = firstUrl(text.text);
    if (url.isEmpty || card != null || dismissed.contains(url)) return;
    linkTimer = Timer(const Duration(milliseconds: 700), () async {
      final mine = ++linkSeq;
      setState(() => fetchingLink = true);
      final r = await fetchPreview(url);
      if (!mounted) return;
      setState(() => fetchingLink = false);
      if (mine == linkSeq &&
          r != null &&
          card == null &&
          !dismissed.contains(url) &&
          firstUrl(text.text) == url)
        setState(() => card = r);
    });
  }

  @override
  void dispose() {
    linkTimer?.cancel();
    text.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  bool get full => media.length >= Config.maxImagesPerPost;

  void _skip() => toast(context, tr(context, 'error.generic'));

  Future<void> addPhotos(ImageSource src) async {
    final picker = ImagePicker();
    // phones hand over to the camera app; a browser has none, so it gets the in-app camera
    final files = src == ImageSource.camera
        ? [
            if ((kIsWeb
                    ? await openCamera(context, CameraMode.photo)
                    : await picker.pickImage(source: src))
                case final f?)
              f,
          ]
        : await picker.pickMultiImage();
    for (final f in files) {
      if (full) break;
      try {
        final n = await compute(prepareImage, (await f.readAsBytes(), f.name));
        if (mounted) setState(() => media.add(n));
      } catch (_) {
        if (mounted) _skip();
      }
    }
  }

  /// Video from the camera or the gallery: kept as recorded, with a poster frame and its duration.
  Future<void> addVideo(ImageSource src) async {
    final f = (kIsWeb && src == ImageSource.camera)
        ? await openCamera(context, CameraMode.video)
        : await ImagePicker().pickVideo(
            source: src,
            maxDuration: const Duration(seconds: maxVideoSeconds),
          );
    if (f != null)
      await _addVideoBytes(
        await f.readAsBytes(),
        f.name.isEmpty ? 'video.mp4' : f.name,
      );
  }

  Future<void> _addVideoBytes(Uint8List bytes, String name) async {
    if (full || bytes.length > maxVideoMb * 1024 * 1024) return _skip();
    setState(() => busy = true);
    try {
      final ext = extOf(name).isEmpty ? 'mp4' : extOf(name);
      final mime = mimeOfName(name).startsWith('video/')
          ? mimeOfName(name)
          : 'video/mp4';
      final player = await playerFor(bytes, mime, ext);
      await player.initialize();
      final seconds = player.value.duration.inSeconds;
      final size = player.value.size;
      await player.dispose();
      if (seconds > maxVideoSeconds) return _skip();
      final poster = await posterFor(bytes, ext);
      if (mounted)
        setState(
          () => media.add(
            NewMedia(
              main: bytes,
              thumb: poster,
              w: size.width.round(),
              h: size.height.round(),
              name: name,
              kind: 'video',
              mime: mime,
              duration: seconds,
            ),
          ),
        );
    } catch (_) {
      if (mounted) _skip();
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  /// Record a voice message in a small dialog.
  Future<void> addVoice() async {
    final r = await showRecorder(context);
    if (r == null || full) return;
    setState(
      () => media.add(
        NewMedia(
          main: r.bytes,
          name: 'voice-${DateTime.now().millisecondsSinceEpoch ~/ 1000}.m4a',
          kind: 'audio',
          mime: 'audio/mp4',
          duration: r.seconds,
        ),
      ),
    );
  }

  /// Any file from the device: photos are re-encoded, videos and audio keep their player, everything else is a download.
  Future<void> addFiles() async {
    final files = await FilePicker.pickFiles();
    for (final f in files) {
      if (full) break;
      final bytes = await f.xFile.readAsBytes();
      final kind = classify(f.name);
      if (kind == null) {
        _skip(); // web pages, scripts, executables… are refused
        continue;
      }
      try {
        if (kind == 'image') {
          final n = await compute(prepareImage, (bytes, f.name));
          if (mounted) setState(() => media.add(n));
        } else if (kind == 'video') {
          await _addVideoBytes(bytes, f.name);
        } else if (bytes.length >
            (kind == 'audio' ? maxFileMb : maxFileMb) * 1024 * 1024) {
          _skip();
        } else if (mounted) {
          setState(
            () => media.add(
              NewMedia(
                main: bytes,
                name: f.name,
                kind: kind,
                mime: mimeOfName(f.name),
              ),
            ),
          );
        }
      } catch (_) {
        if (mounted) _skip();
      }
    }
  }

  /// The card's picture goes through the same re-encoding as any photo (EXIF out, size capped, always JPEG).
  Future<NewMedia?> _cardImage(Uint8List bytes) async {
    try {
      return await compute(prepareImage, (bytes, 'link-preview.jpg'));
    } catch (_) {
      return null; // not a decodable image: the card goes without it
    }
  }

  void addPerson() {
    final e = normEmail(email.text);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) return;
    setState(() {
      audience[e] = roleView;
      email.clear();
    });
  }

  Future<void> post() async {
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    if (protect && password.text.length < 6)
      return toast(context, t('compose.passwordShort'));
    if (text.text.trim().isEmpty && media.isEmpty) return;
    setState(() {
      busy = true;
      status = t('compose.uploading', {'done': 0, 'total': media.length});
    });
    try {
      final r = await context.read<AppState>().repo!.createPost(
        text: text.text.trim(),
        media: media,
        audience: audience,
        commentMode: mode,
        linkShare: link,
        password: protect ? password.text : null,
        link: card?.link,
        linkImage: card?.image == null ? null : await _cardImage(card!.image!),
        onProgress: (s, d, n) {
          if (mounted)
            setState(
              () => status = s == 'upload'
                  ? t('compose.uploading', {'done': d, 'total': n})
                  : t('compose.sharing'),
            );
        },
      );
      if (!mounted) return;
      if (r.warnings.isNotEmpty) toast(context, t('error.publish'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        toast(context, errorText(context, e));
      }
    }
  }

  /// Who sees it, how they may react, public link, password — one sheet instead of a long form.
  Future<void> _openSharing() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          void both(VoidCallback f) {
            setState(f);
            set(() {});
          }

          final t = (String k, [Map<String, Object?> p = const {}]) =>
              tr(ctx, k, p);
          final cs = Theme.of(ctx).colorScheme;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('compose.shareWith'),
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          onSubmitted: (_) => both(addPerson),
                          decoration: InputDecoration(
                            hintText: t('post.shareByEmail'),
                            prefixIcon: const Icon(
                              Icons.alternate_email_rounded,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => both(addPerson),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (audience.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 16,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t('compose.onlyMe'),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  for (final e in audience.entries)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: GradientAvatar(prettyName(e.key), size: 36),
                      title: Text(e.key, overflow: TextOverflow.ellipsis),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButton<String>(
                            value: e.value,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: roleView,
                                child: Text(t('post.canView')),
                              ),
                              DropdownMenuItem(
                                value: roleComment,
                                child: Text(t('post.canComment')),
                              ),
                            ],
                            onChanged: (v) =>
                                both(() => audience[e.key] = v ?? roleView),
                          ),
                          IconButton(
                            onPressed: () => both(() => audience.remove(e.key)),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  Text(
                    t('comments.mode'),
                    style: Theme.of(ctx).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'open',
                          label: Text(t('comments.modeOpen')),
                          icon: const Icon(Icons.forum_outlined),
                        ),
                        ButtonSegment(
                          value: 'shared',
                          label: Text(t('comments.modeShared')),
                          icon: const Icon(Icons.group_outlined),
                        ),
                        ButtonSegment(
                          value: 'locked',
                          label: Text(t('comments.modeLocked')),
                          icon: const Icon(Icons.lock_outline_rounded),
                        ),
                      ],
                      selected: {mode},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) => both(() => mode = s.first),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const TonalIcon(Icons.link_rounded),
                    value: link,
                    onChanged: (v) => both(() => link = v),
                    title: Text(t('post.linkShare')),
                    subtitle: Text(
                      t('post.linkShareHint'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const TonalIcon(Icons.password_rounded),
                    value: protect,
                    onChanged: (v) => both(() => protect = v),
                    title: Text(t('compose.protect')),
                    subtitle: Text(
                      t('compose.protectHint'),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                  ),
                  if (protect)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextField(
                        controller: password,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: t('post.password'),
                          helperText: t('compose.passwordHint'),
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(t('camera.done')),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = (String k, [Map<String, Object?> p = const {}]) =>
        tr(context, k, p);
    final cs = Theme.of(context).colorScheme;
    final me = context.read<AppState>().account['name'] ?? '';
    final people = audience.length;
    final canPost = !busy && (text.text.trim().isNotEmpty || media.isNotEmpty);
    Widget tool(IconData i, String label, VoidCallback? f, Color c) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: busy ? null : f,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(i, color: busy ? cs.outline : c, size: 26),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: busy ? null : () => Navigator.pop(context),
        ),
        title: Text(t('compose.title')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton(
              onPressed: canPost ? post : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 42),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              child: Text(t('compose.post')),
            ),
          ),
        ],
        bottom: busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3),
              )
            : null,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              children: [
                Row(
                  children: [
                    GradientAvatar(me, size: 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            me,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(99),
                            onTap: busy ? null : _openSharing,
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(10, 5, 8, 5),
                              decoration: BoxDecoration(
                                color: people == 0
                                    ? cs.surfaceContainerHigh
                                    : cs.primaryContainer,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    people == 0
                                        ? Icons.lock_outline_rounded
                                        : Icons.group_outlined,
                                    size: 15,
                                    color: people == 0
                                        ? cs.onSurfaceVariant
                                        : cs.onPrimaryContainer,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    people == 0
                                        ? t('post.onlyYou')
                                        : t('post.people', {'n': people}),
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: people == 0
                                          ? cs.onSurfaceVariant
                                          : cs.onPrimaryContainer,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.expand_more_rounded,
                                    size: 17,
                                    color: people == 0
                                        ? cs.onSurfaceVariant
                                        : cs.onPrimaryContainer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (link || protect)
                      Row(
                        children: [
                          if (link)
                            Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                          if (protect)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                Icons.password_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: text,
                  minLines: 5,
                  maxLines: 14,
                  enabled: !busy,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontFamily: readFont,
                    fontSize: 20,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: t('compose.placeholder'),
                    hintStyle: TextStyle(
                      fontFamily: readFont,
                      fontSize: 20,
                      color: cs.outline,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                if (card != null)
                  LinkCard(
                    link: card!.link,
                    imageBytes: card!.image,
                    onRemove: busy
                        ? null
                        : () => setState(() {
                            dismissed.add('${card!.link['url']}');
                            card = null;
                          }),
                  )
                else if (fetchingLink)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          t('attach.loading'),
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                if (media.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: media.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: SizedBox(
                                width: 112,
                                height: 112,
                                child: _Preview(media[i]),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: InkWell(
                                onTap: busy
                                    ? null
                                    : () => setState(() => media.removeAt(i)),
                                child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.close_rounded,
                                    size: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Text(
                  '${media.length}/${Config.maxImagesPerPost}',
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 12, color: cs.outline),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                child: Row(
                  children: [
                    tool(
                      Icons.photo_camera_rounded,
                      t('camera.photo'),
                      () => addPhotos(ImageSource.camera),
                      const Color(0xFF2E8A6D),
                    ),
                    tool(
                      Icons.videocam_rounded,
                      t('camera.video'),
                      () => addVideo(ImageSource.camera),
                      const Color(0xFFD1603D),
                    ),
                    tool(
                      Icons.mic_rounded,
                      t('camera.audio'),
                      addVoice,
                      const Color(0xFF6B5BD2),
                    ),
                    tool(
                      Icons.photo_library_rounded,
                      t('compose.addPhoto'),
                      () => addPhotos(ImageSource.gallery),
                      const Color(0xFF2F7FD1),
                    ),
                    tool(
                      Icons.attach_file_rounded,
                      '',
                      addFiles,
                      const Color(0xFF8A6D2E),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small preview tile for any attachment kind.
class _Preview extends StatelessWidget {
  const _Preview(this.m);
  final NewMedia m;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (m.kind == 'image' || (m.kind == 'video' && m.thumb != null)) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(m.thumb!, fit: BoxFit.cover),
          if (m.kind == 'video')
            const Center(
              child: Icon(
                Icons.play_circle_fill,
                color: Colors.white,
                size: 32,
              ),
            ),
        ],
      );
    }
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              m.kind == 'audio'
                  ? Icons.mic_none
                  : m.kind == 'video'
                  ? Icons.videocam_outlined
                  : Icons.attach_file,
              color: cs.primary,
            ),
            const SizedBox(height: 4),
            Text(
              m.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11),
            ),
            if (m.kind == 'audio' || m.kind == 'video')
              Text(
                clock(m.duration),
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}
