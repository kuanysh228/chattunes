import 'package:flutter/material.dart';

import '../library_store.dart';
import '../player_service.dart';
import '../settings.dart';
import '../stats.dart';
import '../widgets.dart';
import 'for_you_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
    required this.settings,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;
  final AppSettings settings;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  static const _destinations = [
    (Icons.library_music_outlined, Icons.library_music, 'Библиотека'),
    (Icons.auto_awesome_outlined, Icons.auto_awesome, 'Для вас'),
    (Icons.queue_music_outlined, Icons.queue_music, 'Плейлисты'),
    (Icons.insights_outlined, Icons.insights, 'Статистика'),
  ];

  @override
  Widget build(BuildContext context) {
    final lib = widget.library;
    return ListenableBuilder(
      listenable: Listenable.merge([lib, widget.player, widget.stats]),
      builder: (context, _) {
        final wide = MediaQuery.sizeOf(context).width >= 800;
        final pages = [
          LibraryScreen(library: lib, player: widget.player, stats: widget.stats),
          ForYouScreen(library: lib, player: widget.player, stats: widget.stats),
          PlaylistsScreen(library: lib, player: widget.player),
          StatsScreen(library: lib, stats: widget.stats),
        ];

        final body = Column(
          children: [
            if (lib.status != null)
              Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.secondaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(lib.status!),
              ),
            Expanded(child: IndexedStack(index: _tab, children: pages)),
            if (widget.player.current != null)
              _MiniPlayer(
                player: widget.player,
                onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  fullscreenDialog: true,
                  builder: (_) => NowPlayingScreen(library: lib, player: widget.player),
                )),
              ),
          ],
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(_destinations[_tab].$3),
            actions: [
              IconButton(
                tooltip: 'Синхронизировать',
                icon: const Icon(Icons.sync),
                onPressed: lib.refresh,
              ),
              IconButton(
                tooltip: 'Настройки',
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(
                    library: lib,
                    player: widget.player,
                    settings: widget.settings,
                    stats: widget.stats,
                  ),
                )),
              ),
            ],
            bottom: lib.busy
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(2),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      selectedIndex: _tab,
                      labelType: NavigationRailLabelType.all,
                      onDestinationSelected: (i) => setState(() => _tab = i),
                      destinations: [
                        for (final d in _destinations)
                          NavigationRailDestination(
                            icon: Icon(d.$1),
                            selectedIcon: Icon(d.$2),
                            label: Text(d.$3),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                )
              : body,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _tab,
                  onDestinationSelected: (i) => setState(() => _tab = i),
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.$1),
                        selectedIcon: Icon(d.$2),
                        label: d.$3,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.player, required this.onOpen});

  final PlayerService player;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final track = player.current!;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 4, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Cover(track: track, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                        if (track.artist.isNotEmpty)
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.skip_previous), onPressed: player.previous),
                  player.loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          iconSize: 36,
                          icon: Icon(player.playing ? Icons.pause_circle : Icons.play_circle),
                          onPressed: player.toggle,
                        ),
                  IconButton(icon: const Icon(Icons.skip_next), onPressed: player.next),
                ],
              ),
              _MiniProgress(player: player),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniProgress extends StatelessWidget {
  const _MiniProgress({required this.player});

  final PlayerService player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.player.positionStream,
      builder: (context, snap) {
        final total = player.player.duration?.inMilliseconds ?? 0;
        final pos = snap.data?.inMilliseconds ?? 0;
        return LinearProgressIndicator(
          value: total <= 0 ? 0 : (pos / total).clamp(0.0, 1.0),
          minHeight: 2,
        );
      },
    );
  }
}
