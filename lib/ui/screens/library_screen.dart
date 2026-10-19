import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';
import '../../player_service.dart';
import '../../stats.dart';
import '../theme/app_tokens.dart';
import '../components/components.dart';

enum _Sort { newest, title, artist, mostPlayed }

const _sortLabels = {
  _Sort.newest: 'Сначала новые',
  _Sort.title: 'По названию',
  _Sort.artist: 'По исполнителю',
  _Sort.mostPlayed: 'Чаще слушаемые',
};

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  String _query = '';
  _Sort _sort = _Sort.newest;
  bool _onlyFavorites = false;

  List<Track> _visible() {
    final lib = widget.library;
    final q = _query.trim().toLowerCase();
    final favs = lib.favoriteIds;
    final list = [
      for (final t in lib.tracks)
        if ((!_onlyFavorites || favs.contains(t.uniqueId)) &&
            (q.isEmpty ||
                t.title.toLowerCase().contains(q) ||
                t.artist.toLowerCase().contains(q)))
          t
    ];

    switch (_sort) {
      case _Sort.newest:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
      case _Sort.title:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _Sort.artist:
        list.sort((a, b) {
          final c = a.artistKey.compareTo(b.artistKey);
          return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
      case _Sort.mostPlayed:
        final plays = <String, int>{};
        for (final e in widget.stats.events) {
          if (e.counted) plays[e.trackId] = (plays[e.trackId] ?? 0) + 1;
        }
        list.sort((a, b) => (plays[b.uniqueId] ?? 0).compareTo(plays[a.uniqueId] ?? 0));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final lib = widget.library;
    final tracks = _visible();

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(context.tokens.pad, context.tokens.gap, context.tokens.pad, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Поиск по названию и исполнителю',
                border: InputBorder.none,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // A Wrap, not a Row: themes can squeeze this column next to side panels.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.tokens.pad),
            child: Wrap(
              spacing: context.tokens.gap,
              runSpacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilterChip(
                  label: const Text('Избранное'),
                  avatar: const Icon(Icons.favorite, size: 16),
                  selected: _onlyFavorites,
                  onSelected: (v) => setState(() => _onlyFavorites = v),
                ),
                PopupMenuButton<_Sort>(
                  tooltip: 'Сортировка',
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => [
                    for (final e in _sortLabels.entries)
                      PopupMenuItem(value: e.key, child: Text(e.value)),
                  ],
                ),
                if (tracks.isNotEmpty) ...[
                  Text('${tracks.length} треков', style: Theme.of(context).textTheme.bodySmall),
                  TextButton.icon(
                    onPressed: () => widget.player.playContext(tracks, 0, shuffleOn: true),
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('Перемешать'),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Text(lib.tracks.isEmpty
                        ? 'Пока пусто. Добавь треки кнопкой + или кинь их в канал.'
                        : 'Ничего не найдено'),
                  )
                : ListView.builder(
                    itemCount: tracks.length,
                    itemBuilder: (context, i) => TrackTile(
                      index: i,
                      track: tracks[i],
                      library: lib,
                      player: widget.player,
                      onTap: () => widget.player.playContext(tracks, i),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: lib.busy ? null : lib.pickAndUpload,
        tooltip: 'Добавить треки',
        child: const Icon(Icons.add),
      ),
    );
  }
}
