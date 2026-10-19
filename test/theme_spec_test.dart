import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/ui/theme/app_tokens.dart';
import 'package:telemusic/ui/theme/layout_spec.dart';
import 'package:telemusic/ui/theme/theme_spec.dart';

ThemeSpec parse(Map<String, dynamic> json) => ThemeSpec.parse(jsonEncode(json));

List<String> errorsOf(Map<String, dynamic> json) {
  try {
    parse(json);
  } on ThemeFormatException catch (e) {
    return e.errors;
  }
  fail('expected the theme to be rejected');
}

void main() {
  group('parsing', () {
    test('a name alone is a valid theme and gets the default look', () {
      final spec = parse({'name': 'Mini'});
      expect(spec.brightness, Brightness.dark);
      expect(spec.seed, ThemeSpec.defaultSeed);
      expect(spec.radius, 14);
      expect(spec.layout.shell, isNull);
      expect(spec.warnings, isEmpty);
    });

    test('rejects broken JSON and non-objects with a readable message', () {
      expect(() => ThemeSpec.parse('{nope'), throwsA(isA<ThemeFormatException>()));
      expect(() => ThemeSpec.parse('[1,2]'), throwsA(isA<ThemeFormatException>()));
    });

    test('reports every problem at once, not just the first', () {
      final errors = errorsOf({
        'colors': {'primary': 'red', 'seed': '#12'},
        'shape': {'radius': 99},
        'cover': {'style': 'wavy'},
        'brightness': 'dim',
      });
      expect(errors.length, greaterThanOrEqualTo(5));
      expect(errors.join('\n'), contains('name'));
      expect(errors.join('\n'), contains('colors.primary'));
      expect(errors.join('\n'), contains('shape.radius'));
      expect(errors.join('\n'), contains('cover.style'));
      expect(errors.join('\n'), contains('brightness'));
    });

    test('unknown keys are warnings, so newer themes still load', () {
      final spec = parse({
        'name': 'X',
        'sparkles': true,
        'colors': {'glitter': '#FFFFFF'},
        'layout': {'player': {'wobble': 1}},
      });
      expect(spec.warnings, containsAll(["Unknown key 'sparkles'", "Unknown key 'colors.glitter'", "Unknown key 'layout.player.wobble'"]));
    });

    test('refuses a format from the future instead of misreading it', () {
      expect(errorsOf({'name': 'X', 'format': 2}).join(), contains('newer version'));
    });

    test('parses short, long and alpha hex colors', () {
      expect(ThemeSpec.parseColor('#fff'), const Color(0xFFFFFFFF));
      expect(ThemeSpec.parseColor('#336699'), const Color(0xFF336699));
      expect(ThemeSpec.parseColor('#33669980'), const Color(0x80336699));
      expect(ThemeSpec.parseColor('336699'), isNull);
      expect(ThemeSpec.parseColor('#12345'), isNull);
      expect(ThemeSpec.parseColor(5), isNull);
    });

    test('colors survive a hex round trip', () {
      for (final c in [const Color(0xFF123456), const Color(0x80ABCDEF)]) {
        expect(ThemeSpec.parseColor(ThemeSpec.colorToHex(c)), c);
      }
    });
  });

  group('building the Flutter theme', () {
    test('explicit colors override the generated palette', () {
      final data = parse({
        'name': 'X',
        'colors': {'seed': '#009688', 'primary': '#FF0000', 'surface': '#101010'},
      }).toThemeData();
      expect(data.colorScheme.primary, const Color(0xFFFF0000));
      expect(data.colorScheme.surface, const Color(0xFF101010));
    });

    test('tokens reach widgets through the theme extension', () {
      final data = parse({
        'name': 'X',
        'colors': {'favorite': '#FFD54F'},
        'shape': {'radius': 4, 'coverRadius': 0.5},
        'spacing': {'pad': 20},
        'cover': {'style': 'flat'},
      }).toThemeData();
      final tokens = data.extension<AppTokens>()!;
      expect(tokens.favorite, const Color(0xFFFFD54F));
      expect(tokens.radius, 4);
      expect(tokens.coverRadius, 0.5);
      expect(tokens.pad, 20);
      expect(tokens.coverStyle, CoverStyle.flat);
    });

    test('font scale multiplies text sizes', () {
      final base = parse({'name': 'X'}).toThemeData().textTheme.bodyMedium!.fontSize!;
      final big = parse({'name': 'X', 'typography': {'scale': 1.2}})
          .toThemeData()
          .textTheme
          .bodyMedium!
          .fontSize!;
      expect(big, closeTo(base * 1.2, 0.001));
    });

    test('text keeps the font family and color Material gives it', () {
      final plain = ThemeData(useMaterial3: true, brightness: Brightness.dark).textTheme.bodyMedium!;
      final spec = parse({'name': 'X'});
      final ours = spec.toThemeData().textTheme;
      for (final style in [ours.bodyMedium!, ours.titleLarge!, ours.labelSmall!]) {
        expect(style.fontFamily, plain.fontFamily);
        expect(style.color, isNotNull);
        expect(style.fontSize, isNotNull);
      }
      expect(ours.bodyMedium!.color, spec.colorScheme.onSurface);
    });

    test('light and dark produce matching brightness', () {
      expect(parse({'name': 'X', 'brightness': 'light'}).toThemeData().brightness, Brightness.light);
      expect(parse({'name': 'X'}).toThemeData().brightness, Brightness.dark);
    });

    test('warns when text would be unreadable', () {
      final spec = parse({
        'name': 'X',
        'colors': {'surface': '#222222', 'onSurface': '#2A2A2A'},
      });
      expect(spec.warnings.join(), contains('Text on background'));
    });

    test('the default look has no readability warnings', () {
      expect(parse({'name': 'X'}).warnings, isEmpty);
      expect(parse({'name': 'X', 'brightness': 'light'}).warnings, isEmpty);
    });
  });

  group('layout', () {
    LayoutSpec layoutOf(Map<String, dynamic> layout) =>
        parse({'name': 'X', 'layout': layout}).layout;

    test('a column with the player on top is accepted', () {
      final l = layoutOf({
        'shell': {'column': ['header', 'player', 'content', 'navigation']},
      });
      final shell = l.shell as ShellBox;
      expect(shell.axis, ShellAxis.column);
      expect([for (final c in shell.children) (c as ShellLeaf).region.name],
          ['header', 'player', 'content', 'navigation']);
    });

    test('nested rows and columns are accepted', () {
      final l = layoutOf({
        'shell': {
          'row': [
            'navigation',
            {'column': ['header', 'content']},
            'player',
          ],
        },
      });
      expect(l.shell!.regions.toSet(), ShellRegion.values.toSet());
    });

    test('shell is used at every width unless shellWide overrides it', () {
      final only = layoutOf({
        'shell': {'column': ['header', 'content', 'navigation']},
      });
      expect(only.shellFor(400), same(only.shell));
      expect(only.shellFor(1400), same(only.shell));

      final both = layoutOf({
        'shell': {'column': ['header', 'content', 'navigation']},
        'shellWide': {'row': ['navigation', {'column': ['header', 'content']}]},
      });
      expect(both.shellFor(400), same(both.shell));
      expect(both.shellFor(1400), same(both.shellWide));

      final none = layoutOf({});
      expect(none.shellFor(400), same(LayoutSpec.defaultNarrow));
      expect(none.shellFor(1400), same(LayoutSpec.defaultWide));
    });

    test('content and header are mandatory', () {
      expect(errorsOf({'name': 'X', 'layout': {'shell': {'column': ['header', 'navigation']}}}).join(),
          contains("must include 'content'"));
      expect(errorsOf({'name': 'X', 'layout': {'shell': {'column': ['content', 'navigation']}}}).join(),
          contains("must include 'header'"));
    });

    test('a region cannot appear twice', () {
      expect(
        errorsOf({
          'name': 'X',
          'layout': {'shell': {'column': ['header', 'content', 'player', 'player', 'navigation']}},
        }).join(),
        contains("'player' 2 times"),
      );
    });

    test('several tabs need a navigation region to switch between them', () {
      expect(
        errorsOf({'name': 'X', 'layout': {'shell': {'column': ['header', 'content']}}}).join(),
        contains('navigation'),
      );
      // With a single tab there is nothing to switch.
      expect(
        layoutOf({
          'tabs': ['library'],
          'shell': {'column': ['header', 'content']},
        }).tabs,
        [AppTab.library],
      );
    });

    test('unknown regions and bad shapes name the offending path', () {
      expect(errorsOf({'name': 'X', 'layout': {'shell': {'column': ['header', 'sidebar', 'content']}}}).join(),
          contains("unknown region 'sidebar'"));
      expect(errorsOf({'name': 'X', 'layout': {'shell': {'diagonal': ['content']}}}).join(),
          contains('layout.shell'));
      expect(errorsOf({'name': 'X', 'layout': {'shell': 'content'}}).join(), contains('header'));
    });

    test('absurdly deep nesting is rejected', () {
      Object deep(int n) => n == 0 ? 'content' : {'column': [deep(n - 1)]};
      expect(errorsOf({'name': 'X', 'layout': {'shell': deep(7)}}).join(), contains('too deep'));
    });

    test('tabs can be reordered or hidden, but not duplicated or emptied', () {
      expect(layoutOf({'tabs': ['stats', 'library']}).tabs, [AppTab.stats, AppTab.library]);
      expect(errorsOf({'name': 'X', 'layout': {'tabs': ['library', 'library']}}).join(), contains('twice'));
      expect(errorsOf({'name': 'X', 'layout': {'tabs': []}}).join(), contains('at least 1'));
      expect(errorsOf({'name': 'X', 'layout': {'tabs': ['radio']}}).join(), contains('unknown item'));
    });

    test('playback stays controllable: some play button must remain', () {
      expect(
        errorsOf({
          'name': 'X',
          'layout': {
            'player': {'controls': ['next']},
            'nowPlaying': {'controls': ['shuffle']},
          },
        }).join(),
        contains("'play' must be"),
      );
      // One of the two places is enough.
      expect(
        layoutOf({
          'player': {'controls': ['next']},
        }).nowPlayingControls,
        contains(PlayerControl.play),
      );
    });

    test('controls and row parts keep the order the theme wrote', () {
      final l = layoutOf({
        'player': {'controls': ['play', 'previous', 'next', 'favorite']},
        'trackRow': {'leading': 'number', 'subtitle': ['duration', 'artist'], 'trailing': ['menu', 'favorite'], 'coverSize': 60},
      });
      expect(l.playerControls, [PlayerControl.play, PlayerControl.previous, PlayerControl.next, PlayerControl.favorite]);
      expect(l.rowLeading, RowLeading.number);
      expect(l.rowSubtitle, [RowSubtitle.duration, RowSubtitle.artist]);
      expect(l.rowTrailing, [RowTrailing.menu, RowTrailing.favorite]);
      expect(l.rowCoverSize, 60);
    });

    test('cover size is range checked', () {
      expect(errorsOf({'name': 'X', 'layout': {'trackRow': {'coverSize': 500}}}).join(), contains('coverSize'));
    });
  });

  group('bundled themes', () {
    final files = Directory('themes')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();

    test('there are examples to ship', () => expect(files, isNotEmpty));

    for (final f in files) {
      test('${f.path} loads cleanly with no warnings', () {
        final spec = ThemeSpec.parse(f.readAsStringSync());
        expect(spec.warnings, isEmpty, reason: spec.warnings.join('\n'));
      });

      test('${f.path} survives export and re-import unchanged', () {
        final spec = ThemeSpec.parse(f.readAsStringSync());
        final again = ThemeSpec.parse(spec.toPrettyJson());
        expect(again.toPrettyJson(), spec.toPrettyJson());
        expect(again.toThemeData().colorScheme, spec.toThemeData().colorScheme);
      });
    }
  });

  group('JSON schema', () {
    final schema = jsonDecode(File('docs/theme.schema.json').readAsStringSync()) as Map<String, dynamic>;
    Map<String, dynamic> props(Map<String, dynamic> node) =>
        node['properties'] as Map<String, dynamic>;
    List<String> enumOf(Map<String, dynamic> node) =>
        [for (final v in (node['enum'] as List)) v as String];

    Set<String> keys(Map<String, dynamic> node) => props(node).keys.toSet();

    test('lists exactly the keys the parser understands', () {
      final top = props(schema);
      expect(top.keys.toSet(), {...ThemeSpec.knownKeys[''] !, 'colors', 'shape', 'spacing', 'typography', 'cover', 'layout'});
      expect(keys(top['colors']), ThemeSpec.knownKeys['colors']!.toSet());
      expect(keys(top['shape']), ThemeSpec.knownKeys['shape']!.toSet());
      expect(keys(top['spacing']), ThemeSpec.knownKeys['spacing']!.toSet());
      expect(keys(top['typography']), ThemeSpec.knownKeys['typography']!.toSet());
      expect(keys(top['cover']), ThemeSpec.knownKeys['cover']!.toSet());

      final layout = top['layout'] as Map<String, dynamic>;
      expect(keys(layout), LayoutSpec.knownKeys['layout']!.toSet());
      expect(keys(props(layout)['player']), LayoutSpec.knownKeys['layout.player']!.toSet());
      expect(keys(props(layout)['nowPlaying']), LayoutSpec.knownKeys['layout.nowPlaying']!.toSet());
      expect(keys(props(layout)['trackRow']), LayoutSpec.knownKeys['layout.trackRow']!.toSet());
    });

    test('lists exactly the values the parser accepts', () {
      final layout = props(schema)['layout'] as Map<String, dynamic>;
      final player = props(props(layout)['player']);
      final nowPlaying = props(props(layout)['nowPlaying']);
      final row = props(props(layout)['trackRow']);
      final defs = schema[r'$defs'] as Map<String, dynamic>;

      expect(enumOf(props(schema)['brightness']), ['dark', 'light']);
      expect(enumOf(props(props(schema)['cover'])['style']), CoverStyle.values.map((e) => e.name));
      expect(enumOf(props(props(schema)['spacing'])['density']), ThemeSpec.densities);
      expect(enumOf((props(layout)['tabs'] as Map)['items']), AppTab.values.map((e) => e.name));
      expect(enumOf(props(layout)['navigationLabels']), NavigationLabels.values.map((e) => e.name));
      expect(enumOf(player['style']), PlayerStyle.values.map((e) => e.name));
      expect(enumOf(player['progress']), ProgressPlacement.values.map((e) => e.name));
      expect(enumOf(nowPlaying['arrangement']), NowPlayingArrangement.values.map((e) => e.name));
      expect(enumOf(row['leading']), RowLeading.values.map((e) => e.name));
      expect(enumOf((row['subtitle'] as Map)['items']), RowSubtitle.values.map((e) => e.name));
      expect(enumOf((row['trailing'] as Map)['items']), RowTrailing.values.map((e) => e.name));
      expect(enumOf((defs['controls'] as Map)['items']), PlayerControl.values.map((e) => e.name));

      final shellLeaf = ((defs['shellNode'] as Map)['oneOf'] as List).first as Map<String, dynamic>;
      expect(enumOf(shellLeaf), ShellRegion.values.map((e) => e.name));
    });
  });
}
