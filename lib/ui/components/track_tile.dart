import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';
import '../../player_service.dart';
import 'dialogs.dart';
import 'track_row.dart';

enum TrackAction { playNext, queue, favorite, playlist, extra, remove }

/// A [TrackRow] wired to the player and the library, with its action menu.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.library,
    required this.player,
    required this.onTap,
    this.index = 0,
    this.subtitle,
    this.extraLabel,
    this.onExtra,
  });

  final Track track;
  final LibraryStore library;
  final PlayerService player;
  final VoidCallback onTap;
  final int index;

  /// Replaces the default subtitle (e.g. a recommendation reason).
  final String? subtitle;

  /// One context-specific menu entry, e.g. "remove from this playlist".
  final String? extraLabel;
  final VoidCallback? onExtra;

  CacheState get _cache {
    if (player.isDownloading(track)) return CacheState.downloading;
    if (player.errors.containsKey(track.uniqueId)) return CacheState.failed;
    return player.isCached(track) ? CacheState.cached : CacheState.remote;
  }

  @override
  Widget build(BuildContext context) {
    final fav = library.isFavorite(track);
    return TrackRow(
      track: track,
      index: index,
      onTap: onTap,
      selected: player.current?.uniqueId == track.uniqueId,
      playing: player.current?.uniqueId == track.uniqueId && player.playing,
      favorite: fav,
      cache: _cache,
      message: player.errors[track.uniqueId],
      subtitleOverride: subtitle,
      menu: PopupMenuButton<TrackAction>(
        tooltip: 'Действия',
        onSelected: (v) => _onAction(context, v),
        itemBuilder: (_) => [
          const PopupMenuItem(value: TrackAction.playNext, child: Text('Играть далее')),
          const PopupMenuItem(value: TrackAction.queue, child: Text('В очередь')),
          PopupMenuItem(
            value: TrackAction.favorite,
            child: Text(fav ? 'Убрать из избранного' : 'В избранное'),
          ),
          const PopupMenuItem(value: TrackAction.playlist, child: Text('В плейлист…')),
          if (extraLabel != null)
            PopupMenuItem(value: TrackAction.extra, child: Text(extraLabel!)),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: TrackAction.remove,
            child: Text('Удалить из библиотеки'),
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, TrackAction v) async {
    switch (v) {
      case TrackAction.playNext:
        player.playNext(track);
      case TrackAction.queue:
        player.addToQueue(track);
      case TrackAction.favorite:
        library.toggleFavorite(track);
      case TrackAction.playlist:
        await showAddToPlaylist(context, library, track);
      case TrackAction.extra:
        onExtra?.call();
      case TrackAction.remove:
        final ok = await confirm(
          context,
          title: 'Удалить трек?',
          text: '«${track.title}» исчезнет из библиотеки на всех устройствах и из канала.',
          action: 'Удалить',
        );
        if (ok) await library.removeTrack(track);
    }
  }
}
