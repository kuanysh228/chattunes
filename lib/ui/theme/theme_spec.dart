import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_tokens.dart';
import 'layout_spec.dart';

/// Thrown for a theme file that cannot be used. Lists every problem found,
/// not just the first, so authors can fix a file in one pass.
class ThemeFormatException implements Exception {
  ThemeFormatException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join('\n');
}

/// A theme as described by its JSON file. Pure data: no code is ever loaded
/// from a theme, so sharing and importing themes is safe.
///
/// See docs/THEMING.md for the file format.
class ThemeSpec {
  ThemeSpec({
    required this.name,
    this.author = '',
    this.description = '',
    this.brightness = Brightness.dark,
    this.seed = defaultSeed,
    this.colors = const {},
    this.radius = 14,
    this.coverRadius = 0.14,
    this.pad = 16,
    this.gap = 8,
    this.density = 'comfortable',
    this.fontScale = 1.0,
    this.coverStyle = CoverStyle.gradient,
    this.coverSaturation = 0.45,
    this.coverLightness = 0.35,
    this.layout = const LayoutSpec(),
    this.warnings = const [],
  });

  static const supportedFormat = 1;
  static const defaultSeed = Color(0xFF009688);

  /// Every key a theme file may contain, by section. The JSON schema in docs/
  /// is checked against this in tests, so the two cannot drift apart.
  static const knownKeys = <String, List<String>>{
    '': [r'$schema', 'format', 'name', 'author', 'description', 'brightness'],
    'colors': [
      'seed',
      'primary',
      'onPrimary',
      'secondary',
      'onSecondary',
      'tertiary',
      'onTertiary',
      'error',
      'onError',
      'surface',
      'onSurface',
      'surfaceContainer',
      'surfaceContainerHigh',
      'outline',
      'favorite',
      'onCover',
      'chartPrimary',
      'chartSecondary',
    ],
    'shape': ['radius', 'coverRadius'],
    'spacing': ['pad', 'gap', 'density'],
    'typography': ['scale'],
    'cover': ['style', 'saturation', 'lightness'],
    // 'layout' and its nested sections are described in LayoutSpec.knownKeys.
    'layout': [],
  };

  static const densities = ['comfortable', 'standard', 'compact'];

  final String name;
  final String author;
  final String description;
  final Brightness brightness;
  final Color seed;

  /// Explicit overrides by key (see [knownKeys]['colors']), excluding `seed`.
  final Map<String, Color> colors;
  final double radius;
  final double coverRadius;
  final double pad;
  final double gap;
  final String density;
  final double fontScale;
  final CoverStyle coverStyle;
  final double coverSaturation;
  final double coverLightness;
  final LayoutSpec layout;

  /// Non-fatal notes: unknown keys, and colors that are hard to read.
  final List<String> warnings;

  // ---- parsing ----

  factory ThemeSpec.parse(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException catch (e) {
      throw ThemeFormatException(['Not valid JSON: ${e.message}']);
    }
    if (json is! Map<String, dynamic>) {
      throw ThemeFormatException(['The file must contain a JSON object']);
    }
    return ThemeSpec.fromJson(json);
  }

  factory ThemeSpec.fromJson(Map<String, dynamic> json) {
    final errors = <String>[];
    final warnings = <String>[];

    Map<String, dynamic> section(String key) {
      final v = json[key];
      if (v == null) return const {};
      if (v is Map<String, dynamic>) {
        for (final k in v.keys) {
          if (!knownKeys[key]!.contains(k)) warnings.add("Unknown key '$key.$k'");
        }
        return v;
      }
      errors.add("'$key' must be an object");
      return const {};
    }

    for (final k in json.keys) {
      if (!knownKeys['']!.contains(k) && !knownKeys.containsKey(k)) {
        warnings.add("Unknown key '$k'");
      }
    }

    final format = json['format'];
    if (format != null) {
      if (format is! int) {
        errors.add("'format' must be a whole number");
      } else if (format > supportedFormat) {
        errors.add("Theme format $format needs a newer version of the app "
            "(this one supports up to $supportedFormat)");
      }
    }

    final name = json['name'];
    if (name is! String || name.trim().isEmpty) {
      errors.add("'name' is required and must be a non-empty string");
    }

    String text(String key) {
      final v = json[key];
      if (v == null) return '';
      if (v is String) return v;
      errors.add("'$key' must be a string");
      return '';
    }

    var brightness = Brightness.dark;
    final b = json['brightness'];
    if (b != null) {
      if (b == 'dark') {
        brightness = Brightness.dark;
      } else if (b == 'light') {
        brightness = Brightness.light;
      } else {
        errors.add("'brightness' must be \"dark\" or \"light\"");
      }
    }

    // colors
    final colorsJson = section('colors');
    var seed = defaultSeed;
    final colors = <String, Color>{};
    for (final e in colorsJson.entries) {
      if (!knownKeys['colors']!.contains(e.key)) continue;
      final c = parseColor(e.value);
      if (c == null) {
        errors.add("'colors.${e.key}' is not a color (use \"#RRGGBB\"): ${e.value}");
      } else if (e.key == 'seed') {
        seed = c;
      } else {
        colors[e.key] = c;
      }
    }

    double number(Map<String, dynamic> s, String path, String key, double def,
        double min, double max) {
      final v = s[key];
      if (v == null) return def;
      if (v is! num) {
        errors.add("'$path.$key' must be a number");
        return def;
      }
      if (v < min || v > max) {
        errors.add("'$path.$key' must be between $min and $max (got $v)");
        return def;
      }
      return v.toDouble();
    }

    T pick<T>(Map<String, dynamic> s, String path, String key, List<T> values,
        T def, String Function(T) nameOf) {
      final v = s[key];
      if (v == null) return def;
      for (final candidate in values) {
        if (nameOf(candidate) == v) return candidate;
      }
      errors.add("'$path.$key' must be one of: ${values.map(nameOf).join(', ')}");
      return def;
    }

    final shape = section('shape');
    final spacing = section('spacing');
    final typography = section('typography');
    final cover = section('cover');
    var layout = const LayoutSpec();
    final layoutJson = json['layout'];
    if (layoutJson is Map<String, dynamic>) {
      layout = LayoutSpec.parse(layoutJson, errors, warnings);
    } else if (layoutJson != null) {
      errors.add("'layout' must be an object");
    }

    final spec = ThemeSpec(
      name: name is String ? name.trim() : '',
      author: text('author'),
      description: text('description'),
      brightness: brightness,
      seed: seed,
      colors: colors,
      radius: number(shape, 'shape', 'radius', 14, 0, 32),
      coverRadius: number(shape, 'shape', 'coverRadius', 0.14, 0, 0.5),
      pad: number(spacing, 'spacing', 'pad', 16, 8, 32),
      gap: number(spacing, 'spacing', 'gap', 8, 4, 16),
      density: pick(spacing, 'spacing', 'density', densities, 'comfortable', (s) => s),
      fontScale: number(typography, 'typography', 'scale', 1.0, 0.8, 1.3),
      coverStyle: pick(cover, 'cover', 'style', CoverStyle.values, CoverStyle.gradient,
          (v) => v.name),
      coverSaturation: number(cover, 'cover', 'saturation', 0.45, 0, 1),
      coverLightness: number(cover, 'cover', 'lightness', 0.35, 0.1, 0.9),
      layout: layout,
      warnings: warnings,
    );

    if (errors.isNotEmpty) throw ThemeFormatException(errors);
    return spec._withContrastWarnings();
  }

  /// Accepts `#RGB`, `#RRGGBB` and `#RRGGBBAA` (CSS order, alpha last).
  static Color? parseColor(Object? v) {
    if (v is! String) return null;
    var s = v.trim();
    if (!s.startsWith('#')) return null;
    s = s.substring(1);
    if (s.length == 3) s = s.split('').map((c) => '$c$c').join();
    if (s.length != 6 && s.length != 8) return null;
    final n = int.tryParse(s, radix: 16);
    if (n == null) return null;
    if (s.length == 6) return Color(0xFF000000 | n);
    return Color((n & 0xFF) << 24 | (n >> 8));
  }

  static String colorToHex(Color c) {
    String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
    final rgb = '#${h(c.r)}${h(c.g)}${h(c.b)}'.toUpperCase();
    return c.a >= 1 ? rgb : '$rgb${h(c.a).toUpperCase()}';
  }

  // ---- building the Flutter theme ----

  Color? _c(String key) => colors[key];

  ColorScheme get colorScheme => ColorScheme.fromSeed(
        seedColor: seed,
        brightness: brightness,
        primary: _c('primary'),
        onPrimary: _c('onPrimary'),
        secondary: _c('secondary'),
        onSecondary: _c('onSecondary'),
        tertiary: _c('tertiary'),
        onTertiary: _c('onTertiary'),
        error: _c('error'),
        onError: _c('onError'),
        surface: _c('surface'),
        onSurface: _c('onSurface'),
        surfaceContainer: _c('surfaceContainer'),
        surfaceContainerHigh: _c('surfaceContainerHigh'),
        outline: _c('outline'),
      );

  AppTokens get tokens {
    final scheme = colorScheme;
    return AppTokens(
      favorite: _c('favorite') ?? AppTokens.defaults(scheme).favorite,
      onCover: _c('onCover') ?? Colors.white,
      chartPrimary: _c('chartPrimary') ?? scheme.primary,
      chartSecondary: _c('chartSecondary') ?? scheme.tertiary,
      radius: radius,
      coverRadius: coverRadius,
      pad: pad,
      gap: gap,
      coverStyle: coverStyle,
      coverSaturation: coverSaturation,
      coverLightness: coverLightness,
      layout: layout,
    );
  }

  VisualDensity get visualDensity => switch (density) {
        'compact' => VisualDensity.compact,
        'standard' => VisualDensity.standard,
        _ => VisualDensity.comfortable,
      };

  ThemeData toThemeData() {
    final scheme = colorScheme;
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      visualDensity: visualDensity,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final sheetShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    );

    return base.copyWith(
      textTheme: _textTheme(base),
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(shape: shape),
      dialogTheme: DialogThemeData(shape: shape),
      bottomSheetTheme: BottomSheetThemeData(shape: sheetShape),
      popupMenuTheme: PopupMenuThemeData(shape: shape),
      chipTheme: ChipThemeData(shape: shape),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: shape)),
      extensions: [tokens],
    );
  }

  /// ThemeData only gets font sizes once a MaterialApp localizes it, so scaling
  /// has to start from the full Material type scale, not from the raw theme.
  TextTheme _textTheme(ThemeData base) {
    // Same order Flutter uses when it localizes a theme: sizes underneath,
    // the theme's own colors and font family on top.
    final sized = Typography.englishLike2021.merge(base.textTheme);
    return fontScale == 1.0 ? sized : sized.apply(fontSizeFactor: fontScale);
  }

  // ---- export ----

  Map<String, dynamic> toJson() => {
        'format': supportedFormat,
        'name': name,
        if (author.isNotEmpty) 'author': author,
        if (description.isNotEmpty) 'description': description,
        'brightness': brightness.name,
        'colors': {
          'seed': colorToHex(seed),
          for (final k in knownKeys['colors']!)
            if (colors[k] != null) k: colorToHex(colors[k]!),
        },
        'shape': {'radius': radius, 'coverRadius': coverRadius},
        'spacing': {'pad': pad, 'gap': gap, 'density': density},
        'typography': {'scale': fontScale},
        'cover': {
          'style': coverStyle.name,
          'saturation': coverSaturation,
          'lightness': coverLightness,
        },
        'layout': layout.toJson(),
      };

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());

  // ---- readability ----

  static double contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  ThemeSpec _withContrastWarnings() {
    final s = colorScheme;
    final notes = <String>[];
    void check(String label, Color fg, Color bg, double min) {
      final r = contrast(fg, bg);
      if (r < min) {
        notes.add('$label is hard to read (contrast ${r.toStringAsFixed(1)}:1, '
            'aim for at least $min:1)');
      }
    }

    check('Text on background', s.onSurface, s.surface, 4.5);
    check('Text on primary buttons', s.onPrimary, s.primary, 3.0);
    check('Favorite heart on background', tokens.favorite, s.surface, 3.0);

    if (notes.isEmpty) return this;
    return ThemeSpec(
      name: name,
      author: author,
      description: description,
      brightness: brightness,
      seed: seed,
      colors: colors,
      radius: radius,
      coverRadius: coverRadius,
      pad: pad,
      gap: gap,
      density: density,
      fontScale: fontScale,
      coverStyle: coverStyle,
      coverSaturation: coverSaturation,
      coverLightness: coverLightness,
      layout: layout,
      warnings: [...warnings, ...notes],
    );
  }
}
