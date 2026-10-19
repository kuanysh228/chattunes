import 'package:flutter/material.dart';

import '../../models.dart';
import '../theme/app_tokens.dart';

/// There is no real artwork yet, so a cover is derived from the track id:
/// a stable color plus the title's first letter. How it looks (gradient,
/// solid, flat), how round it is and how vivid are all theme tokens.
class Cover extends StatelessWidget {
  const Cover({super.key, required this.track, this.size = 44});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;

    final hue = (track.uniqueId.hashCode.abs() % 360).toDouble();
    double clamp01(double v) => v.clamp(0.0, 1.0);
    final base = HSLColor.fromAHSL(1, hue, clamp01(t.coverSaturation), clamp01(t.coverLightness))
        .toColor();
    final top = HSLColor.fromAHSL(
            1, (hue + 40) % 360, clamp01(t.coverSaturation + 0.05), clamp01(t.coverLightness + 0.15))
        .toColor();

    final flat = t.coverStyle == CoverStyle.flat;
    final letter = track.title.trim().isEmpty ? '♪' : track.title.trim()[0].toUpperCase();

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * t.coverRadius),
        color: switch (t.coverStyle) {
          CoverStyle.gradient => null,
          CoverStyle.solid => base,
          CoverStyle.flat => scheme.surfaceContainerHigh,
        },
        gradient: t.coverStyle == CoverStyle.gradient
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, base],
              )
            : null,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: flat ? scheme.primary : t.onCover.withValues(alpha: 0.9),
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
