import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/links.dart';

import 'widgets.dart';

/// Link preview card (Open Graph). All text is untrusted and rendered as text; only http(s) addresses open.
class LinkCard extends StatelessWidget {
  const LinkCard({
    super.key,
    required this.link,
    this.post,
    this.imageBytes,
    this.onRemove,
  });
  final Map<String, dynamic> link;
  final Map<String, dynamic>? post; // owner of the picture file
  final Uint8List? imageBytes; // local picture of a card still being written
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = '${link['url']}';
    final safe = RegExp(r'^https?://', caseSensitive: false).hasMatch(url);
    final host =
        Uri.tryParse(url)?.host.replaceFirst(RegExp(r'^www\.'), '') ?? '';
    final title = '${link['title'] ?? ''}',
        desc = '${link['description'] ?? ''}';
    final site = '${link['site'] ?? ''}'.isEmpty ? host : '${link['site']}';
    final image = link['image'];
    Widget? picture;
    if (imageBytes != null) {
      picture = Image.memory(imageBytes!, fit: BoxFit.cover);
    } else if (image != null && post != null) {
      picture = DriveImage(
        post: post!,
        item: {'id': image, 'thumb': null, 'mime': 'image/jpeg'},
      );
    }
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: safe ? () => openLink(url) : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (picture != null)
                  AspectRatio(
                    aspectRatio: 1.91,
                    child: SizedBox.expand(child: picture),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.open_in_new,
                            size: 13,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              site.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurfaceVariant,
                                letterSpacing: .3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (title.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      if (desc.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            desc,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: cs.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 6,
              right: 6,
              child: InkWell(
                onTap: onRemove,
                child: const CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.black54,
                  child: Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
