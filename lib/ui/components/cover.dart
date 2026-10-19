import 'package:flutter/material.dart';

import '../../models.dart';
import '../theme/app_tokens.dart';
import 'cover_scope.dart';

/// A track's cover: its artwork when it has one, otherwise a placeholder
/// derived from the track id (a stable color plus the title's first letter).
/// The placeholder's look (gradient, solid, flat), how round covers are and how
/// vivid they are, are all theme tokens.
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

    final placeholder = Container(
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

    final image = CoverScope.imageFor(context, track);
    if (image == null) return placeholder;

    // The placeholder stays underneath: it shows while the image decodes and
    // remains if the file turns out to be unreadable.
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Stack(
      children: [
        placeholder,
        ClipRRect(
          borderRadius: BorderRadius.circular(size * t.coverRadius),
          child: Image(
            image: ResizeImage(FileImage(image), width: px, height: px),
            width: size,
            height: size,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
            frameBuilder: (context, child, frame, sync) => AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: sync ? Duration.zero : const Duration(milliseconds: 150),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}