import 'package:flutter/material.dart';

import '../../models.dart';
import '../format.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_spec.dart';
import 'cover.dart';

enum CacheState { remote, cached, downloading, failed }

/// One row of a track list, drawn from plain values. It knows nothing about
/// the player or the library, which keeps it easy to restyle and to preview.
///
/// What it shows and in which order comes from the theme's `layout.trackRow`.
class TrackRow extends StatelessWidget {
  const TrackRow({
    super.key,
    required this.track,
    required this.index,
    required this.onTap,
    this.selected = false,
    this.playing = false,
    this.favorite = false,
    this.cache = CacheState.remote,
    this.message,
    this.subtitleOverride,
    this.menu,
  });

  final Track track;

  /// Position in the list, shown when the theme uses numbered rows.
  final int index;
  final VoidCallback onTap;
  final bool selected;
  final bool playing;
  final bool favorite;
  final CacheState cache;

  /// Replaces the subtitle, e.g. a download error.
  final String? message;

  /// Replaces the artist/duration subtitle, e.g. a recommendation reason.
  final String? subtitleOverride;

  /// Trailing menu button, supplied by the screen that owns the actions.
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final layout = t.layout;
    final scheme = Theme.of(context).colorScheme;

    Widget? leading;
    switch (layout.rowLeading) {
      case RowLeading.cover:
        leading = Stack(
          alignment: Alignment.center,
          children: [
            Cover(track: track, size: layout.rowCoverSize),
            if (playing) Icon(Icons.equalizer, color: t.onCover),
          ],
        );
      case RowLeading.number:
        leading = SizedBox(
          width: 32,
          child: Center(
            child: playing
                ? const Icon(Icons.equalizer, size: 20)
                : Text('${index + 1}', style: Theme.of(context).textTheme.bodySmall),
          ),
        );
      case RowLeading.none:
        leading = null;
    }

    final parts = <String>[
      for (final p in layout.rowSubtitle)
        if (p == RowSubtitle.artist && track.artist.isNotEmpty)
          track.artist
        else if (p == RowSubtitle.duration)
          fmtDuration(track.duration),
    ];

    Widget statusIcon() => switch (cache) {
          CacheState.downloading => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          CacheState.failed => Icon(Icons.error_outline, size: 18, color: scheme.error),
          CacheState.cached => const Icon(Icons.download_done, size: 18),
          CacheState.remote => const Icon(Icons.cloud_outlined, size: 18),
        };

    final trailing = <Widget>[];
    for (final part in layout.rowTrailing) {
      switch (part) {
        case RowTrailing.favorite:
          if (favorite) trailing.add(Icon(Icons.favorite, size: 16, color: t.favorite));
        case RowTrailing.status:
          trailing.add(statusIcon());
        case RowTrailing.duration:
          trailing.add(Text(fmtDuration(track.duration),
              style: Theme.of(context).textTheme.bodySmall));
        case RowTrailing.menu:
          if (menu != null) trailing.add(menu!);
      }
    }

    return ListTile(
      selected: selected,
      leading: leading,
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        message ?? subtitleOverride ?? parts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: trailing.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < trailing.length; i++) ...[
                  if (i > 0) SizedBox(width: t.gap),
                  trailing[i],
                ],
              ],
            ),
      onTap: onTap,
    );
  }
}
