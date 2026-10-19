import 'package:flutter/material.dart';

import '../../player_service.dart';
import '../format.dart';

/// Slider with elapsed and total time.
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

/// Thin progress line for the compact player.
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, required this.player});

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
