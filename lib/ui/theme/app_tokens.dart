import 'package:flutter/material.dart';

import 'layout_spec.dart';

/// How a track cover is painted. There is no real artwork yet, so every cover
/// is generated from the track id.
enum CoverStyle { gradient, solid, flat }

/// Design values that Material's [ColorScheme] has no slot for.
///
/// Widgets read these through `context.tokens` instead of hardcoding colors,
/// radii or spacing, so a theme file can restyle the whole app.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.favorite,
    required this.onCover,
    required this.chartPrimary,
    required this.chartSecondary,
    required this.radius,
    required this.coverRadius,
    required this.pad,
    required this.gap,
    required this.coverStyle,
    required this.coverSaturation,
    required this.coverLightness,
    required this.layout,
  });

  /// Defaults used when a widget is built outside a ChatTunes theme (tests, previews).
  factory AppTokens.defaults(ColorScheme scheme) => AppTokens(
        favorite: const Color(0xFFFF4081),
        onCover: Colors.white,
        chartPrimary: scheme.primary,
        chartSecondary: scheme.tertiary,
        radius: 14,
        coverRadius: 0.14,
        pad: 16,
        gap: 8,
        coverStyle: CoverStyle.gradient,
        coverSaturation: 0.45,
        coverLightness: 0.35,
        layout: const LayoutSpec(),
      );

  // Colors
  final Color favorite;
  final Color onCover;
  final Color chartPrimary;
  final Color chartSecondary;

  // Shape
  /// Corner radius of cards, dialogs, sheets and buttons.
  final double radius;

  /// Cover corner radius as a fraction of the cover size (0.5 is a circle).
  final double coverRadius;

  // Spacing
  /// Outer padding of screens and sections.
  final double pad;

  /// Small gap between related elements.
  final double gap;

  // Cover look
  final CoverStyle coverStyle;
  final double coverSaturation;
  final double coverLightness;

  /// Where regions go and which controls show; see [LayoutSpec].
  final LayoutSpec layout;

  @override
  AppTokens copyWith({
    Color? favorite,
    Color? onCover,
    Color? chartPrimary,
    Color? chartSecondary,
    double? radius,
    double? coverRadius,
    double? pad,
    double? gap,
    CoverStyle? coverStyle,
    double? coverSaturation,
    double? coverLightness,
    LayoutSpec? layout,
  }) =>
      AppTokens(
        favorite: favorite ?? this.favorite,
        onCover: onCover ?? this.onCover,
        chartPrimary: chartPrimary ?? this.chartPrimary,
        chartSecondary: chartSecondary ?? this.chartSecondary,
        radius: radius ?? this.radius,
        coverRadius: coverRadius ?? this.coverRadius,
        pad: pad ?? this.pad,
        gap: gap ?? this.gap,
        coverStyle: coverStyle ?? this.coverStyle,
        coverSaturation: coverSaturation ?? this.coverSaturation,
        coverLightness: coverLightness ?? this.coverLightness,
        layout: layout ?? this.layout,
      );

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    double d(double a, double b) => a + (b - a) * t;
    return AppTokens(
      favorite: Color.lerp(favorite, other.favorite, t)!,
      onCover: Color.lerp(onCover, other.onCover, t)!,
      chartPrimary: Color.lerp(chartPrimary, other.chartPrimary, t)!,
      chartSecondary: Color.lerp(chartSecondary, other.chartSecondary, t)!,
      radius: d(radius, other.radius),
      coverRadius: d(coverRadius, other.coverRadius),
      pad: d(pad, other.pad),
      gap: d(gap, other.gap),
      coverStyle: t < 0.5 ? coverStyle : other.coverStyle,
      coverSaturation: d(coverSaturation, other.coverSaturation),
      coverLightness: d(coverLightness, other.coverLightness),
      layout: t < 0.5 ? layout : other.layout,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AppTokens>() ?? AppTokens.defaults(theme.colorScheme);
  }
}
