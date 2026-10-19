import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';
import '../../player_service.dart';
import '../theme/app_tokens.dart';
import '../components/components.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key, required this.library, required this.player});

  final LibraryStore library;
  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final favCount = library.favoriteIds.length;
    final lists = library.playlists;

    return Scaffold(
      body: ListView(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: context.tokens.favorite,
              child: Icon(Icons.favorite, color: context.tokens.onCover),
            ),
            title: const Text('Избранное'),
            subtitle: Text('$favCount треков'),
            onTap: () => _open(context, null),
          ),
          for (final p in lists)
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.queue_music)),
              title: Text(p.name),
              subtitle: Text(
                '${library.playlistTracks(p).length} треков${p.offline ? ' · офлайн' : ''}',
              ),
              onTap: () => _open(context, p.id),
            ),
          if (lists.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Плейлистов пока нет. Создай первый кнопкой + '
                'или добавь трек через меню «В плейлист…».',
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Новый плейлист',
        onPressed: () async {
          final name = await askText(context, title: 'Название плейлиста');
          if (name != null) library.createPlaylist(name);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

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
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Плейлист удалён')));
        }

        final tracks = playlist == null
            ? ([
                for (final t in library.tracks)
                  if (library.isFavorite(t)) t
              ]..sort((a, b) => b.addedAt.compareTo(a.addedAt)))
            : library.playlistTracks(playlist);

        return Scaffold(
          appBar: AppBar(
            title: Text(playlist?.name ?? 'Избранное'),
            actions: [
              if (playlist != null)
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'rename') {
                      final name = await askText(context, title: 'Название', initial: playlist.name);
                      if (name != null) library.renamePlaylist(playlist, name);
                    } else if (v == 'delete') {
                      final ok = await confirm(
                        context,
                        title: 'Удалить плейлист?',
                        text: 'Треки останутся в библиотеке.',
                        action: 'Удалить',
                      );
                      if (ok) {
                        library.deletePlaylist(playlist);
                        if (context.mounted) Navigator.pop(context);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'rename', child: Text('Переименовать')),
                    PopupMenuItem(value: 'delete', child: Text('Удалить плейлист')),
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
                      label: const Text('Играть'),
                    ),
                    OutlinedButton.icon(
                      onPressed: tracks.isEmpty ? null : () => player.playContext(tracks, 0, shuffleOn: true),
                      icon: const Icon(Icons.shuffle),
                      label: const Text('Перемешать'),
                    ),
                    if (playlist != null)
                      FilterChip(
                        label: const Text('Офлайн'),
                        avatar: const Icon(Icons.download_for_offline, size: 16),
                        selected: playlist.offline,
                        onSelected: (v) => library.setPlaylistOffline(playlist, v),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: tracks.isEmpty
                    ? const Center(child: Text('Здесь пока пусто'))
                    : playlist == null
                        ? ListView.builder(
                            itemCount: tracks.length,
                            itemBuilder: (_, i) => _tile(tracks, i, null),
                          )
                        : ReorderableListView.builder(
                            buildDefaultDragHandles: false,
                            itemCount: tracks.length,
                            onReorderItem: (a, b) => library.reorderPlaylist(playlist, a, b),
                            itemBuilder: (_, i) => ReorderableDragStartListener(
                              key: ValueKey(tracks[i].uniqueId),
                              index: i,
                              child: _tile(tracks, i, playlist),
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(List<Track> tracks, int i, Playlist? playlist) => TrackTile(
        index: i,
        track: tracks[i],
        library: library,
        player: player,
        onTap: () => player.playContext(tracks, i),
        extraLabel: playlist == null ? null : 'Убрать из плейлиста',
        onExtra: playlist == null ? null : () => library.removeFromPlaylist(playlist, tracks[i]),
      );
}
