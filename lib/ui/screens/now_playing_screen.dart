import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../components/components.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_spec.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key, required this.library, required this.player});

  final LibraryStore library;
  final PlayerService player;

  /// A side-by-side view needs room; on narrow screens it stacks anyway.
  static const _minHorizontalWidth = 560.0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, player]),
      builder: (context, _) {
        final track = player.current;
        if (track == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ничего не играет')));
        }
        final t = context.tokens;
        final layout = t.layout;
        final fav = library.isFavorite(track);

        final info = Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  if (track.artist.isNotEmpty)
                    Text(track.artist, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            IconButton(
              tooltip: fav ? 'Убрать из избранного' : 'В избранное',
              icon: Icon(fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? t.favorite : null),
              onPressed: () => library.toggleFavorite(track),
            ),
          ],
        );

        final controls = Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: PlayerControlsRow(
              player: player,
              library: library,
              controls: layout.nowPlayingControls,
              size: 36,
            ),
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Сейчас играет'),
            actions: [
              IconButton(
                tooltip: 'В плейлист',
                icon: const Icon(Icons.playlist_add),
                onPressed: () => showAddToPlaylist(context, library, track),
              ),
              IconButton(
                tooltip: 'Очередь',
                icon: const Icon(Icons.queue_music),
                onPressed: () => showQueueSheet(context, player),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, box) {
              final sideBySide = layout.nowPlayingArrangement == NowPlayingArrangement.horizontal &&
                  box.maxWidth >= _minHorizontalWidth;

              final cover = LayoutBuilder(
                builder: (_, c) => Cover(
                  track: track,
                  size: c.biggest.shortestSide.clamp(120, 360),
                ),
              );

              if (sideBySide) {
                return Padding(
                  padding: EdgeInsets.all(t.pad * 1.5),
                  child: Row(
                    children: [
                      Expanded(child: Center(child: cover)),
                      SizedBox(width: t.pad * 1.5),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [info, SeekBar(player: player), controls],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: EdgeInsets.all(t.pad * 1.5),
                    child: Column(
                      children: [
                        Expanded(child: Center(child: cover)),
                        SizedBox(height: t.pad),
                        info,
                        SeekBar(player: player),
                        controls,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
