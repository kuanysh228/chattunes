import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../../settings.dart';
import '../../stats.dart';
import '../components/components.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_spec.dart';
import '../theme/theme_controller.dart';
import 'for_you_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'playlists_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

/// The main screen. It owns no layout of its own: the arrangement of header,
/// content, navigation and player comes from the theme's `layout.shell`.
class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
    required this.settings,
    required this.themes,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;
  final AppSettings settings;
  final ThemeController themes;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab? _tab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.library, widget.player, widget.stats]),
      builder: (context, _) {
        final layout = context.tokens.layout;
        final tabs = layout.tabs;
        // A theme may hide the tab we were on.
        final tab = tabs.contains(_tab) ? _tab! : tabs.first;
        final root = layout.shellFor(MediaQuery.sizeOf(context).width);

        return Scaffold(
          body: SafeArea(child: _build(root, tab, tabs, layout, Axis.vertical)),
        );
      },
    );
  }

  /// [parent] is the direction of the box this node sits in. A column stacks
  /// children vertically, so a navigation or player there is a horizontal
  /// strip; in a row they turn into a rail and a side panel.
  Widget _build(ShellNode node, AppTab tab, List<AppTab> tabs, LayoutSpec layout, Axis parent) {
    switch (node) {
      case ShellLeaf(:final region):
        final across = parent == Axis.vertical ? Axis.horizontal : Axis.vertical;
        switch (region) {
          case ShellRegion.header:
            return AppHeader(
              axis: across,
              title: tabInfo(tab).title,
              busy: widget.library.busy,
              onSync: widget.library.refresh,
              onSettings: _openSettings,
            );
          case ShellRegion.content:
            return Expanded(child: _content(tab, tabs));
          case ShellRegion.navigation:
            return AppNavigation(
              axis: across,
              tabs: tabs,
              selected: tab,
              onSelect: (t) => setState(() => _tab = t),
              labels: layout.navigationLabels,
            );
          case ShellRegion.player:
            return PlayerDock(
              player: widget.player,
              library: widget.library,
              axis: across,
              onOpen: _openNowPlaying,
            );
        }
      case ShellBox(:final axis, :final children):
        final direction = axis == ShellAxis.row ? Axis.horizontal : Axis.vertical;
        final kids = [
          for (final c in children)
            switch (c) {
              // Nested boxes share the leftover space; leaves keep their own size.
              ShellBox() => Expanded(child: _build(c, tab, tabs, layout, direction)),
              ShellLeaf() => _build(c, tab, tabs, layout, direction),
            }
        ];
        // Stretch so a side panel or rail fills the whole height (or a strip the width).
        return Flex(
          direction: direction,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: kids,
        );
    }
  }

  Widget _content(AppTab tab, List<AppTab> tabs) {
    final lib = widget.library;
    Widget page(AppTab t) => switch (t) {
          AppTab.library =>
            LibraryScreen(library: lib, player: widget.player, stats: widget.stats),
          AppTab.forYou => ForYouScreen(library: lib, player: widget.player, stats: widget.stats),
          AppTab.playlists => PlaylistsScreen(library: lib, player: widget.player),
          AppTab.stats => StatsScreen(library: lib, stats: widget.stats),
        };

    return Column(
      children: [
        if (lib.status != null) StatusBanner(lib.status!),
        Expanded(
          child: IndexedStack(
            index: tabs.indexOf(tab),
            children: [for (final t in tabs) KeyedSubtree(key: ValueKey(t), child: page(t))],
          ),
        ),
      ],
    );
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(
          library: widget.library,
          player: widget.player,
          settings: widget.settings,
          stats: widget.stats,
          themes: widget.themes,
        ),
      ));

  void _openNowPlaying() => Navigator.of(context).push(MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NowPlayingScreen(library: widget.library, player: widget.player),
      ));
}
