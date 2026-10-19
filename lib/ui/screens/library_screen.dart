import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';
import '../../player_service.dart';
import '../../stats.dart';
import '../l10n.dart';
import '../theme/app_tokens.dart';
import '../components/components.dart';

enum _Sort { newest, title, artist, mostPlayed }

String _sortLabel(AppLocalizations l, _Sort s) => switch (s) {
      _Sort.newest => l.sortNewest,
      _Sort.title => l.sortTitle,
      _Sort.artist => l.sortArtist,
      _Sort.mostPlayed => l.sortMostPlayed,
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
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: context.l10n.searchHint,
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
                  label: Text(context.l10n.favoritesFilter),
                  avatar: const Icon(Icons.favorite, size: 16),
                  selected: _onlyFavorites,
                  onSelected: (v) => setState(() => _onlyFavorites = v),
                ),
                PopupMenuButton<_Sort>(
                  tooltip: context.l10n.sortTooltip,
                  icon: const Icon(Icons.sort),
                  initialValue: _sort,
                  onSelected: (v) => setState(() => _sort = v),
                  itemBuilder: (_) => [
                    for (final s in _Sort.values)
                      PopupMenuItem(value: s, child: Text(_sortLabel(context.l10n, s))),
                  ],
                ),
                if (tracks.isNotEmpty) ...[
                  Text(context.l10n.trackCount(tracks.length),
                      style: Theme.of(context).textTheme.bodySmall),
                  TextButton.icon(
                    onPressed: () => widget.player.playContext(tracks, 0, shuffleOn: true),
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: Text(context.l10n.shuffle),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: tracks.isEmpty
                ? Center(
                    child: Text(lib.tracks.isEmpty
                        ? context.l10n.libraryEmpty
                        : context.l10n.nothingFound),
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
        tooltip: context.l10n.addTracksTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
