import 'package:flutter/material.dart';

import '../library_store.dart';
import '../player_service.dart';
import '../widgets.dart';

class NowPlayingScreen extends StatelessWidget {
  const NowPlayingScreen({super.key, required this.library, required this.player});

  final LibraryStore library;
  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([library, player]),
      builder: (context, _) {
        final track = player.current;
        if (track == null) {
          return Scaffold(appBar: AppBar(), body: const Center(child: Text('Ничего не играет')));
        }
        final fav = library.isFavorite(track);
        final scheme = Theme.of(context).colorScheme;

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
                onPressed: () => _showQueue(context),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: LayoutBuilder(
                          builder: (_, c) => Cover(
                            track: track,
                            size: c.biggest.shortestSide.clamp(120, 320),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
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
                              color: fav ? Colors.pinkAccent : null),
                          onPressed: () => library.toggleFavorite(track),
                        ),
                      ],
                    ),
                    SeekBar(player: player),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          tooltip: 'Перемешать',
                          icon: Icon(Icons.shuffle,
                              color: player.shuffle ? scheme.primary : null),
                          onPressed: player.toggleShuffle,
                        ),
                        IconButton(
                          iconSize: 36,
                          icon: const Icon(Icons.skip_previous),
                          onPressed: player.previous,
                        ),
                        player.loading
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            : IconButton(
                                iconSize: 64,
                                icon: Icon(player.playing
                                    ? Icons.pause_circle_filled
                                    : Icons.play_circle_fill),
                                onPressed: player.toggle,
                              ),
                        IconButton(
                          iconSize: 36,
                          icon: const Icon(Icons.skip_next),
                          onPressed: player.next,
                        ),
                        IconButton(
                          tooltip: 'Повтор',
                          icon: Icon(
                            player.repeat == QueueRepeat.one ? Icons.repeat_one : Icons.repeat,
                            color: player.repeat == QueueRepeat.off ? null : scheme.primary,
                          ),
                          onPressed: player.cycleRepeat,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListenableBuilder(
          listenable: player,
          builder: (context, _) => Column(
            children: [
              const SectionTitle('Очередь'),
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: scroll,
                  buildDefaultDragHandles: false,
                  itemCount: player.queue.length,
                  onReorderItem: player.reorderQueue,
                  itemBuilder: (_, i) {
                    final t = player.queue[i];
                    final isCurrent = i == player.index;
                    return ReorderableDragStartListener(
                      key: ValueKey('$i-${t.uniqueId}'),
                      index: i,
                      child: ListTile(
                        selected: isCurrent,
                        leading: Cover(track: t, size: 36),
                        title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: isCurrent
                            ? const Icon(Icons.graphic_eq)
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => player.removeFromQueue(i),
                              ),
                        onTap: () => player.jumpTo(i),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SeekBar extends StatelessWidget {
  const SeekBar({super.key, required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    final p = player.player;
    return StreamBuilder<Duration>(
      stream: p.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final total = p.duration ?? Duration.zero;
        final max = total.inMilliseconds.toDouble();
        final style = Theme.of(context).textTheme.bodySmall;
        return Row(
          children: [
            SizedBox(width: 44, child: Text(fmtDuration(pos.inSeconds), style: style)),
            Expanded(
              child: Slider(
                value: max <= 0 ? 0 : pos.inMilliseconds.clamp(0, total.inMilliseconds).toDouble(),
                max: max <= 0 ? 1 : max,
                onChanged: max <= 0 ? null : (v) => player.seek(Duration(milliseconds: v.round())),
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(fmtDuration(total.inSeconds), style: style, textAlign: TextAlign.end),
            ),
          ],
        );
      },
    );
  }
}
