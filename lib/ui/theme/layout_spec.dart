/// Where things go on screen, as described by a theme's `layout` section.
///
/// Everything here is plain data. The widgets that read it live in
/// lib/ui/screens/home_shell.dart and lib/ui/components/.
library;

/// A named area of the main screen that a theme can place anywhere.
enum ShellRegion { header, content, navigation, player }

enum ShellAxis { row, column }

sealed class ShellNode {
  const ShellNode();

  Object toJson();

  Iterable<ShellRegion> get regions;
}

class ShellLeaf extends ShellNode {
  const ShellLeaf(this.region);

  final ShellRegion region;

  @override
  Object toJson() => region.name;

  @override
  Iterable<ShellRegion> get regions => [region];
}

class ShellBox extends ShellNode {
  const ShellBox(this.axis, this.children);

  final ShellAxis axis;
  final List<ShellNode> children;

  @override
  Object toJson() => {axis.name: [for (final c in children) c.toJson()]};

  @override
  Iterable<ShellRegion> get regions => children.expand((c) => c.regions);
}

enum AppTab { library, forYou, playlists, stats }

enum PlayerControl { previous, play, next, shuffle, repeat, favorite, queue }

enum ProgressPlacement { top, bottom, hidden }

enum PlayerStyle { raised, flat }

enum NavigationLabels { always, selected, never }

enum NowPlayingArrangement { vertical, horizontal }

enum RowLeading { cover, number, none }

enum RowSubtitle { artist, duration }

enum RowTrailing { favorite, status, duration, menu }

class LayoutSpec {
  const LayoutSpec({
    this.shell,
    this.shellWide,
    this.tabs = AppTab.values,
    this.navigationLabels = NavigationLabels.always,
    this.playerStyle = PlayerStyle.raised,
    this.playerProgress = ProgressPlacement.bottom,
    this.playerControls = const [
      PlayerControl.previous,
      PlayerControl.play,
      PlayerControl.next,
    ],
    this.playerShowCover = true,
    this.nowPlayingArrangement = NowPlayingArrangement.vertical,
    this.nowPlayingControls = const [
      PlayerControl.shuffle,
      PlayerControl.previous,
      PlayerControl.play,
      PlayerControl.next,
      PlayerControl.repeat,
    ],
    this.rowLeading = RowLeading.cover,
    this.rowCoverSize = 44,
    this.rowSubtitle = const [RowSubtitle.artist, RowSubtitle.duration],
    this.rowTrailing = const [RowTrailing.favorite, RowTrailing.status, RowTrailing.menu],
  });

  /// Phone-like layout: header on top, player and navigation at the bottom.
  static const defaultNarrow = ShellBox(ShellAxis.column, [
    ShellLeaf(ShellRegion.header),
    ShellLeaf(ShellRegion.content),
    ShellLeaf(ShellRegion.player),
    ShellLeaf(ShellRegion.navigation),
  ]);

  /// Desktop layout: navigation rail on the left.
  static const defaultWide = ShellBox(ShellAxis.row, [
    ShellLeaf(ShellRegion.navigation),
    ShellBox(ShellAxis.column, [
      ShellLeaf(ShellRegion.header),
      ShellLeaf(ShellRegion.content),
      ShellLeaf(ShellRegion.player),
    ]),
  ]);

  static const wideBreakpoint = 800.0;

  /// Used at every width unless [shellWide] is also set. Null means the app default.
  final ShellNode? shell;

  /// Used from [wideBreakpoint] up. Falls back to [shell], then to the app default.
  final ShellNode? shellWide;

  final List<AppTab> tabs;
  final NavigationLabels navigationLabels;

  final PlayerStyle playerStyle;
  final ProgressPlacement playerProgress;
  final List<PlayerControl> playerControls;
  final bool playerShowCover;

  final NowPlayingArrangement nowPlayingArrangement;
  final List<PlayerControl> nowPlayingControls;

  final RowLeading rowLeading;
  final double rowCoverSize;
  final List<RowSubtitle> rowSubtitle;
  final List<RowTrailing> rowTrailing;

  ShellNode shellFor(double width) {
    if (width >= wideBreakpoint) return shellWide ?? shell ?? defaultWide;
    return shell ?? defaultNarrow;
  }

  /// Every key allowed in the `layout` section and its nested sections,
  /// keyed by dotted path. Checked against the JSON schema in tests.
  static const knownKeys = <String, List<String>>{
    'layout': ['shell', 'shellWide', 'tabs', 'navigationLabels', 'player', 'nowPlaying', 'trackRow'],
    'layout.player': ['style', 'progress', 'controls', 'showCover'],
    'layout.nowPlaying': ['arrangement', 'controls'],
    'layout.trackRow': ['leading', 'coverSize', 'subtitle', 'trailing'],
  };

  // ---- parsing ----

  factory LayoutSpec.parse(
    Map<String, dynamic> json,
    List<String> errors,
    List<String> warnings,
  ) {
    Map<String, dynamic> section(Map<String, dynamic> from, String key, String path) {
      final v = from[key];
      if (v == null) return const {};
      if (v is! Map<String, dynamic>) {
        errors.add("'$path' must be an object");
        return const {};
      }
      for (final k in v.keys) {
        if (!knownKeys[path]!.contains(k)) warnings.add("Unknown key '$path.$k'");
      }
      return v;
    }

    T one<T>(Map<String, dynamic> s, String path, String key, List<T> values, T def,
        String Function(T) nameOf) {
      final v = s[key];
      if (v == null) return def;
      for (final c in values) {
        if (nameOf(c) == v) return c;
      }
      errors.add("'$path.$key' must be one of: ${values.map(nameOf).join(', ')}");
      return def;
    }

    List<T> many<T>(Map<String, dynamic> s, String path, String key, List<T> values,
        List<T> def, String Function(T) nameOf,
        {int min = 0}) {
      final v = s[key];
      if (v == null) return def;
      if (v is! List) {
        errors.add("'$path.$key' must be a list");
        return def;
      }
      final out = <T>[];
      for (final item in v) {
        T? match;
        for (final c in values) {
          if (nameOf(c) == item) match = c;
        }
        if (match == null) {
          errors.add("'$path.$key' has unknown item '$item' (use: ${values.map(nameOf).join(', ')})");
        } else if (out.contains(match)) {
          errors.add("'$path.$key' lists '$item' twice");
        } else {
          out.add(match);
        }
      }
      if (out.length < min && errors.isEmpty) {
        errors.add("'$path.$key' needs at least $min item${min == 1 ? '' : 's'}");
      }
      return out;
    }

    final top = section({'layout': json}, 'layout', 'layout');
    final player = section(top, 'player', 'layout.player');
    final nowPlaying = section(top, 'nowPlaying', 'layout.nowPlaying');
    final row = section(top, 'trackRow', 'layout.trackRow');

    ShellNode? shell(String key) {
      final v = top[key];
      if (v == null) return null;
      final node = _parseNode(v, 'layout.$key', 0, errors);
      if (node != null) _checkRegions(node, 'layout.$key', errors);
      return node;
    }

    final tabs = many(top, 'layout', 'tabs', AppTab.values, AppTab.values, (t) => t.name, min: 1);

    double size = 44;
    final cs = row['coverSize'];
    if (cs != null) {
      if (cs is! num || cs < 28 || cs > 80) {
        errors.add("'layout.trackRow.coverSize' must be a number between 28 and 80");
      } else {
        size = cs.toDouble();
      }
    }

    var showCover = true;
    final sc = player['showCover'];
    if (sc != null) {
      if (sc is bool) {
        showCover = sc;
      } else {
        errors.add("'layout.player.showCover' must be true or false");
      }
    }

    final spec = LayoutSpec(
      shell: shell('shell'),
      shellWide: shell('shellWide'),
      tabs: tabs,
      navigationLabels: one(top, 'layout', 'navigationLabels', NavigationLabels.values,
          NavigationLabels.always, (v) => v.name),
      playerStyle: one(player, 'layout.player', 'style', PlayerStyle.values,
          PlayerStyle.raised, (v) => v.name),
      playerProgress: one(player, 'layout.player', 'progress', ProgressPlacement.values,
          ProgressPlacement.bottom, (v) => v.name),
      playerControls: many(player, 'layout.player', 'controls', PlayerControl.values,
          const [PlayerControl.previous, PlayerControl.play, PlayerControl.next], (v) => v.name),
      playerShowCover: showCover,
      nowPlayingArrangement: one(nowPlaying, 'layout.nowPlaying', 'arrangement',
          NowPlayingArrangement.values, NowPlayingArrangement.vertical, (v) => v.name),
      nowPlayingControls: many(nowPlaying, 'layout.nowPlaying', 'controls', PlayerControl.values,
          const LayoutSpec().nowPlayingControls, (v) => v.name),
      rowLeading: one(row, 'layout.trackRow', 'leading', RowLeading.values, RowLeading.cover,
          (v) => v.name),
      rowCoverSize: size,
      rowSubtitle: many(row, 'layout.trackRow', 'subtitle', RowSubtitle.values,
          const [RowSubtitle.artist, RowSubtitle.duration], (v) => v.name),
      rowTrailing: many(row, 'layout.trackRow', 'trailing', RowTrailing.values,
          const [RowTrailing.favorite, RowTrailing.status, RowTrailing.menu], (v) => v.name),
    );

    // Playback must stay controllable, whatever the theme hides.
    if (!spec.playerControls.contains(PlayerControl.play) &&
        !spec.nowPlayingControls.contains(PlayerControl.play)) {
      errors.add("'play' must be in layout.player.controls or layout.nowPlaying.controls");
    }
    final sh = spec.shellWide ?? spec.shell;
    final shn = spec.shell;
    for (final node in [shn, sh]) {
      if (node != null &&
          spec.tabs.length > 1 &&
          !node.regions.contains(ShellRegion.navigation)) {
        errors.add("the layout has several tabs but no 'navigation' region to switch between them");
        break;
      }
    }
    return spec;
  }

  static const _maxDepth = 4;

  static ShellNode? _parseNode(Object? v, String path, int depth, List<String> errors) {
    if (depth > _maxDepth) {
      errors.add("'$path' is nested too deep (at most $_maxDepth levels)");
      return null;
    }
    if (v is String) {
      for (final r in ShellRegion.values) {
        if (r.name == v) return ShellLeaf(r);
      }
      errors.add("'$path' has unknown region '$v' "
          "(use: ${ShellRegion.values.map((r) => r.name).join(', ')}, or {\"row\": [...]} / {\"column\": [...]})");
      return null;
    }
    if (v is Map<String, dynamic> && v.length == 1) {
      final axisName = v.keys.first;
      final axis = ShellAxis.values.where((a) => a.name == axisName).firstOrNull;
      final items = v.values.first;
      if (axis != null && items is List && items.isNotEmpty) {
        final children = <ShellNode>[];
        for (var i = 0; i < items.length; i++) {
          final c = _parseNode(items[i], '$path.$axisName[$i]', depth + 1, errors);
          if (c != null) children.add(c);
        }
        return children.isEmpty ? null : ShellBox(axis, children);
      }
    }
    errors.add("'$path' must be a region name or {\"row\": [...]} / {\"column\": [...]} with at least one item");
    return null;
  }

  static void _checkRegions(ShellNode node, String path, List<String> errors) {
    final counts = <ShellRegion, int>{};
    for (final r in node.regions) {
      counts[r] = (counts[r] ?? 0) + 1;
    }
    for (final r in ShellRegion.values) {
      final n = counts[r] ?? 0;
      final required = r == ShellRegion.content || r == ShellRegion.header;
      if (n > 1) errors.add("'$path' uses '${r.name}' $n times (once at most)");
      if (n == 0 && required) errors.add("'$path' must include '${r.name}'");
    }
  }

  // ---- export ----

  /// Explicit form with defaults filled in, so an exported theme shows every
  /// option an author can change.
  Map<String, dynamic> toJson() => {
        'shell': (shell ?? defaultNarrow).toJson(),
        'shellWide': (shellWide ?? shell ?? defaultWide).toJson(),
        'tabs': [for (final t in tabs) t.name],
        'navigationLabels': navigationLabels.name,
        'player': {
          'style': playerStyle.name,
          'progress': playerProgress.name,
          'controls': [for (final c in playerControls) c.name],
          'showCover': playerShowCover,
        },
        'nowPlaying': {
          'arrangement': nowPlayingArrangement.name,
          'controls': [for (final c in nowPlayingControls) c.name],
        },
        'trackRow': {
          'leading': rowLeading.name,
          'coverSize': rowCoverSize,
          'subtitle': [for (final s in rowSubtitle) s.name],
          'trailing': [for (final t in rowTrailing) t.name],
        },
      };
}
