import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../../recommender.dart';
import '../../stats.dart';
import '../l10n.dart';
import '../theme/app_tokens.dart';
import '../components/components.dart';

class ForYouScreen extends StatefulWidget {
  const ForYouScreen({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;

  @override
  State<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends State<ForYouScreen> {
  // Recomputed on demand, not on every rebuild: the jitter in the scoring
  // would otherwise reshuffle the list each time the player ticks.
  late Recommender _rec = _build();
  late int _stamp = _signature();

  Recommender _build() => Recommender(
        tracks: widget.library.tracks,
        events: widget.stats.events,
        favorites: widget.library.favoriteIds,
      );

  int _signature() => Object.hash(
        widget.library.tracks.length,
        widget.stats.events.length ~/ 5,
        widget.library.favoriteIds.length,
      );

  void _refresh() => setState(() {
        _rec = _build();
        _stamp = _signature();
      });

  @override
  Widget build(BuildContext context) {
    if (_stamp != _signature()) {
      _rec = _build();
      _stamp = _signature();
    }

    final lib = widget.library;
    if (lib.tracks.isEmpty) {
      return Center(child: Text(context.l10n.forYouEmpty));
    }

    final mix = _rec.mix(limit: 30);
    final timeMix = _rec.timeMix();
    final forgotten = _rec.forgotten();
    final fresh = _rec.newFromFavoriteArtists();

    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: ListView(
        children: [
          if (_rec.coldStart)
            Container(
              margin: EdgeInsets.all(context.tokens.pad),
              padding: EdgeInsets.all(context.tokens.pad - 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(context.tokens.radius),
              ),
              child: Text(context.l10n.forYouColdStart),
            ),
          _section(context.l10n.mixOfTheDay, mix, trailing: [
            IconButton(
              tooltip: context.l10n.refresh,
              icon: const Icon(Icons.refresh),
              onPressed: _refresh,
            ),
          ]),
          // Only when there is a real habit to show: a mix of two tracks is noise.
          if (timeMix.length >= 3)
            _section(dayPartTitle(context.l10n, dayPartOf(DateTime.now().hour)), timeMix),
          if (forgotten.isNotEmpty) _section(context.l10n.forgottenTitle, forgotten),
          if (fresh.isNotEmpty) _section(context.l10n.newFromArtistsTitle, fresh),
        ],
      ),
    );
  }

  Widget _section(String title, List<Rec> recs, {List<Widget> trailing = const []}) {
    final tracks = [for (final r in recs) r.track];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          title,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...trailing,
              IconButton(
                tooltip: context.l10n.play,
                icon: const Icon(Icons.play_circle),
                onPressed: () => widget.player.playContext(tracks, 0, shuffleOn: false),
              ),
            ],
          ),
        ),
        for (var i = 0; i < recs.length; i++)
          TrackTile(
            index: i,
            track: recs[i].track,
            library: widget.library,
            player: widget.player,
            subtitle: reasonText(context.l10n, recs[i].reason),
            onTap: () => widget.player.playContext(tracks, i),
          ),
      ],
    );
  }
}
