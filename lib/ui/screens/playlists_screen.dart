import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';
import '../../player_service.dart';
import '../../smart_playlists.dart';
import '../../stats.dart';
import '../l10n.dart';
import '../theme/app_tokens.dart';
import '../components/components.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;

  @override
  Widget build(BuildContext context) {
    final favCount = library.favoriteIds.length;
    final lists = library.playlists;
    final smart = SmartPlaylists(
      tracks: library.tracks,
      events: stats.events,
      favorites: library.favoriteIds,
    ).nonEmpty();

    return Scaffold(
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: context.tokens.favorite,
              child: Icon(Icons.favorite, color: context.tokens.onCover),
            ),
            title: Text(context.l10n.favorites),
            subtitle: Text(context.l10n.trackCount(favCount)),
            onTap: () => _open(context, null),
          ),
          if (smart.isNotEmpty) ...[
            SectionTitle(context.l10n.smartPlaylists),
            for (final e in smart.entries)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                  child: Icon(_smartIcon(e.key),
                      color: Theme.of(context).colorScheme.onSecondaryContainer),
                ),
                title: Text(smartPlaylistTitle(context.l10n, e.key)),
                subtitle: Text(context.l10n.trackCount(e.value.length)),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SmartPlaylistScreen(
                    library: library,
                    player: player,
                    stats: stats,
                    kind: e.key,
                  ),
                )),
              ),
            SectionTitle(context.l10n.tabPlaylists),
          ],
          for (final p in lists)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.queue_music)),
              title: Text(p.name),
              subtitle: Text(
                '${context.l10n.trackCount(library.playlistTracks(p).length)}'
                '${p.offline ? ' · ${context.l10n.offline.toLowerCase()}' : ''}',
              ),
              onTap: () => _open(context, p.id),
            ),
          if (lists.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.l10n.playlistsEmpty),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: context.l10n.newPlaylist,
        onPressed: () async {
          final fallback = context.l10n.defaultPlaylistName;
          final name = await askText(context, title: context.l10n.playlistName);
          if (name != null) library.createPlaylist(name.trim().isEmpty ? fallback : name);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  static IconData _smartIcon(SmartPlaylist k) => switch (k) {
        SmartPlaylist.topMonth => Icons.trending_up,
        SmartPlaylist.recentlyAdded => Icons.fiber_new,
        SmartPlaylist.neverPlayed => Icons.visibility_off,
        SmartPlaylist.loved => Icons.favorite,
        SmartPlaylist.skipped => Icons.skip_next,
      };

  void _open(BuildContext context, String? playlistId) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PlaylistDetailScreen(
        library: library,
        player: player,
        playlistId: playlistId,
      ),
    ));
  }
}

/// A user playlist, or the favorites list when [playlistId] is null.
class PlaylistDetailScreen extends StatelessWidget {
  const PlaylistDetailScreen({
    super.key,
    required this.library,
    required this.player,
    required this.playlistId,
  });

  final LibraryStore library;
  final PlayerService player;
  final String? playlistId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, player]),
      builder: (context, _) {
        final playlist = playlistId == null ? null : library.data.playlists[playlistId];
        if (playlistId != null && (playlist == null || playlist.deleted)) {
          return Scaffold(
              appBar: AppBar(), body: Center(child: Text(context.l10n.playlistDeleted)));
        }

        final tracks = playlist == null
            ? ([
                for (final t in library.tracks)
                  if (library.isFavorite(t)) t
              ]..sort((a, b) => b.addedAt.compareTo(a.addedAt)))
            : library.playlistTracks(playlist);

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist?.name ?? context.l10n.favorites),
            actions: [
              if (playlist != null)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name =
                          await askText(context, title: context.l10n.name, initial: playlist.name);
                      if (name != null) library.renamePlaylist(playlist, name);
                    } else if (v == 'delete') {
                      final ok = await confirm(
                        context,
                        title: context.l10n.deletePlaylistTitle,
                        text: context.l10n.deletePlaylistBody,
                        action: context.l10n.delete,
                      );
                      if (ok) {
                        library.deletePlaylist(playlist);
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'rename', child: Text(context.l10n.rename)),
                    PopupMenuItem(value: 'delete', child: Text(context.l10n.deletePlaylistAction)),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(context.tokens.pad, context.tokens.gap, context.tokens.pad, 0),
                child: Wrap(
                  spacing: context.tokens.gap,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: tracks.isEmpty ? null : () => player.playContext(tracks, 0, shuffleOn: false),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.l10n.play),
                    ),
                    OutlinedButton.icon(
                      onPressed: tracks.isEmpty ? null : () => player.playContext(tracks, 0, shuffleOn: true),
                      icon: const Icon(Icons.shuffle),
                      label: Text(context.l10n.shuffle),
                    ),
                    if (playlist != null)
                      FilterChip(
                        label: Text(context.l10n.offline),
                        avatar: const Icon(Icons.download_for_offline, size: 16),
                        selected: playlist.offline,
                        onSelected: (v) => library.setPlaylistOffline(playlist, v),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? Center(child: Text(context.l10n.nothingHereYet))
                    : playlist == null
                        ? ListView.builder(
                            itemCount: tracks.length,
                            itemBuilder: (ctx, i) => _tile(ctx, tracks, i, null),
                          )
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: tracks.length,
                            onReorderItem: (a, b) => library.reorderPlaylist(playlist, a, b),
                            itemBuilder: (ctx, i) => ReorderableDragStartListener(
                              key: ValueKey(tracks[i].uniqueId),
                              index: i,
                              child: _tile(ctx, tracks, i, playlist),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, List<Track> tracks, int i, Playlist? playlist) => TrackTile(
        index: i,
        track: tracks[i],
        library: library,
        player: player,
        onTap: () => player.playContext(tracks, i),
        extraLabel: playlist == null ? null : context.l10n.removeFromPlaylist,
        onExtra: playlist == null ? null : () => library.removeFromPlaylist(playlist, tracks[i]),
      );
}

/// A read-only list that fills itself from how the library is used.
class SmartPlaylistScreen extends StatelessWidget {
  const SmartPlaylistScreen({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
    required this.kind,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;
  final SmartPlaylist kind;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, player, stats]),
      builder: (context, _) {
        final tracks = SmartPlaylists(
          tracks: library.tracks,
          events: stats.events,
          favorites: library.favoriteIds,
        ).tracksFor(kind);

        return Scaffold(
          appBar: AppBar(title: Text(smartPlaylistTitle(context.l10n, kind))),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    context.tokens.pad, context.tokens.gap, context.tokens.pad, 0),
                child: Wrap(
                  spacing: context.tokens.gap,
                  children: [
                    FilledButton.icon(
                      onPressed: tracks.isEmpty
                          ? null
                          : () => player.playContext(tracks, 0, shuffleOn: false),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(context.l10n.play),
                    ),
                    OutlinedButton.icon(
                      onPressed: tracks.isEmpty
                          ? null
                          : () => player.playContext(tracks, 0, shuffleOn: true),
                      icon: const Icon(Icons.shuffle),
                      label: Text(context.l10n.shuffle),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? Center(child: Text(context.l10n.nothingHereYet))
                    : ListView.builder(
                        itemCount: tracks.length,
                        itemBuilder: (ctx, i) => TrackTile(
                          index: i,
                          track: tracks[i],
                          library: library,
                          player: player,
                          onTap: () => player.playContext(tracks, i),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
