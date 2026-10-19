import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../theme/app_tokens.dart';
import '../theme/layout_spec.dart';
import 'cover.dart';
import 'player_controls.dart';
import 'seek_bar.dart';

/// The always-visible player. In a column it is a compact strip; placed in a
/// row by a theme it becomes a side panel. Position is the theme's choice,
/// see `layout.shell`.
class PlayerDock extends StatelessWidget {
  const PlayerDock({
    super.key,
    required this.player,
    required this.library,
    required this.axis,
    required this.onOpen,
  });

  final PlayerService player;
  final LibraryStore library;

  /// [Axis.horizontal] draws the strip, [Axis.vertical] the side panel.
  final Axis axis;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final track = player.current;
    final layout = context.tokens.layout;
    final scheme = Theme.of(context).colorScheme;
    final raised = layout.playerStyle == PlayerStyle.raised;

    if (axis == Axis.vertical) {
      return SizedBox(
        width: 300,
        child: Material(
          color: scheme.surfaceContainerHigh,
          elevation: raised ? 3 : 0,
          child: track == null
              ? Center(
                  child: Text('Ничего не играет', style: Theme.of(context).textTheme.bodySmall),
                )
              : _panel(context, layout),
        ),
      );
    }

    if (track == null) return const SizedBox.shrink();
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: raised ? 3 : 0,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (layout.playerProgress == ProgressPlacement.top) ProgressLine(player: player),
            _strip(context, layout),
            if (layout.playerProgress == ProgressPlacement.bottom) ProgressLine(player: player),
          ],
        ),
      ),
    );
  }

  Widget _strip(BuildContext context, LayoutSpec layout) {
    final t = context.tokens;
    final track = player.current!;
    return Padding(
      padding: EdgeInsets.fromLTRB(t.pad - 4, t.gap - 2, t.gap / 2, t.gap - 2),
      child: Row(
        children: [
          if (layout.playerShowCover) ...[
            Cover(track: track, size: 40),
            SizedBox(width: t.pad - 4),
          ],
          Expanded(child: _info(context, track.title, track.artist)),
          Flexible(
            flex: 0,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: PlayerControlsRow(
                player: player,
                library: library,
                controls: layout.playerControls,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _panel(BuildContext context, LayoutSpec layout) {
    final t = context.tokens;
    final track = player.current!;
    return SingleChildScrollView(
      padding: EdgeInsets.all(t.pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (layout.playerShowCover)
            Center(child: Cover(track: track, size: 200)),
          SizedBox(height: t.pad),
          _info(context, track.title, track.artist, large: true),
          if (layout.playerProgress != ProgressPlacement.hidden) SeekBar(player: player),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: PlayerControlsRow(
                player: player,
                library: library,
                controls: layout.playerControls,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onOpen, child: const Text('Открыть')),
          ),
        ],
      ),
    );
  }

  Widget _info(BuildContext context, String title, String artist, {bool large = false}) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: large ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: large ? text.titleMedium : null,
        ),
        if (artist.isNotEmpty)
          Text(artist, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
      ],
    );
  }
}
