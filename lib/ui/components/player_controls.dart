import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../l10n.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_spec.dart';
import 'queue_sheet.dart';

/// The row of playback buttons. Which buttons appear, and in what order, is
/// given by [controls], which themes set in `layout.player.controls` and
/// `layout.nowPlaying.controls`.
class PlayerControlsRow extends StatelessWidget {
  const PlayerControlsRow({
    super.key,
    required this.player,
    required this.library,
    required this.controls,
    this.size = 28,
  });

  final PlayerService player;
  final LibraryStore library;
  final List<PlayerControl> controls;

  /// Icon size of a regular button; play is drawn larger.
  final double size;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final t = context.tokens;
    final current = player.current;
    final fav = current != null && library.isFavorite(current);

    Widget button(PlayerControl c) {
      switch (c) {
        case PlayerControl.previous:
          return IconButton(
            tooltip: context.l10n.previous,
            iconSize: size,
            icon: const Icon(Icons.skip_previous),
            onPressed: player.previous,
          );
        case PlayerControl.next:
          return IconButton(
            tooltip: context.l10n.next,
            iconSize: size,
            icon: const Icon(Icons.skip_next),
            onPressed: player.next,
          );
        case PlayerControl.play:
          if (player.loading) {
            return Padding(
              padding: EdgeInsets.all(size * 0.4),
              child: SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return IconButton(
            tooltip: player.playing ? context.l10n.pause : context.l10n.play,
            iconSize: size * 1.6,
            icon: Icon(player.playing ? Icons.pause_circle_filled : Icons.play_circle_fill),
            onPressed: player.toggle,
          );
        case PlayerControl.shuffle:
          return IconButton(
            tooltip: context.l10n.shuffle,
            iconSize: size,
            icon: Icon(Icons.shuffle, color: player.shuffle ? primary : null),
            onPressed: player.toggleShuffle,
          );
        case PlayerControl.repeat:
          return IconButton(
            tooltip: context.l10n.repeat,
            iconSize: size,
            icon: Icon(
              player.repeat == QueueRepeat.one ? Icons.repeat_one : Icons.repeat,
              color: player.repeat == QueueRepeat.off ? null : primary,
            ),
            onPressed: player.cycleRepeat,
          );
        case PlayerControl.favorite:
          return IconButton(
            tooltip: fav ? context.l10n.removeFromFavorites : context.l10n.addToFavorites,
            iconSize: size,
            icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                color: fav ? t.favorite : null),
            onPressed: current == null ? null : () => library.toggleFavorite(current),
          );
        case PlayerControl.queue:
          return IconButton(
            tooltip: context.l10n.queueTitle,
            iconSize: size,
            icon: const Icon(Icons.queue_music),
            onPressed: () => showQueueSheet(context, player),
          );
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [for (final c in controls) button(c)],
    );
  }
}
