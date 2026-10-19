import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/ui/components/components.dart';
import 'package:telemusic/ui/screens/home_shell.dart';
import 'package:telemusic/ui/screens/library_screen.dart';
import 'package:telemusic/ui/theme/theme_spec.dart';

import 'support/sample_app.dart';

void main() {
  late SampleApp app;

  setUp(() async => app = await SampleApp.create());
  tearDown(() => app.dispose());

  Future<void> pump(WidgetTester tester, Map<String, dynamic> theme, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    app.showAsPlaying(1);
    final spec = ThemeSpec.parse(jsonEncode(theme));
    await tester.pumpWidget(MaterialApp(
      theme: spec.toThemeData(),
      home: HomeShell(
        library: app.library,
        player: app.player,
        stats: app.stats,
        settings: app.settings,
        themes: app.themes,
      ),
    ));
    await tester.pump();
  }

  Offset at(WidgetTester t, Type type) => t.getTopLeft(find.byType(type));
  Rect box(WidgetTester t, Type type) => t.getRect(find.byType(type));

  const phone = Size(420, 860);
  const desktop = Size(1280, 800);

  testWidgets('default on a phone: header on top, player and navigation at the bottom',
      (tester) async {
    await pump(tester, {'name': 'Default'}, phone);

    expect(box(tester, AppHeader).top, lessThan(box(tester, PlayerDock).top));
    expect(box(tester, PlayerDock).bottom, lessThanOrEqualTo(box(tester, AppNavigation).top + 0.5));
    expect(box(tester, AppNavigation).bottom, closeTo(phone.height, 1));
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('default on desktop: navigation becomes a rail on the left', (tester) async {
    await pump(tester, {'name': 'Default'}, desktop);

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(box(tester, AppNavigation).right, lessThanOrEqualTo(box(tester, AppHeader).left + 0.5));
  });

  testWidgets('a theme can put the player at the TOP with one line', (tester) async {
    await pump(tester, {
      'name': 'Top',
      'layout': {
        'shell': {'column': ['header', 'player', 'content', 'navigation']},
      },
    }, phone);

    expect(box(tester, AppHeader).bottom, lessThanOrEqualTo(box(tester, PlayerDock).top + 0.5));
    expect(box(tester, PlayerDock).bottom, lessThanOrEqualTo(at(tester, LibraryScreen).dy + 1));
    expect(box(tester, AppNavigation).top, greaterThan(box(tester, PlayerDock).bottom));
  });

  testWidgets('a theme can dock the player on the right as a side panel', (tester) async {
    await pump(tester, {
      'name': 'Right',
      'layout': {
        'shell': {
          'row': [
            'navigation',
            {'column': ['header', 'content']},
            'player',
          ],
        },
      },
    }, desktop);

    final player = box(tester, PlayerDock);
    expect(player.left, greaterThanOrEqualTo(box(tester, AppHeader).right));
    expect(player.width, 300);
    expect(player.right, closeTo(desktop.width, 1));
    expect(find.byType(NavigationRail), findsOneWidget);
  });

  testWidgets('navigation can move to the top of the screen', (tester) async {
    await pump(tester, {
      'name': 'TopNav',
      'layout': {
        'shell': {'column': ['navigation', 'header', 'content', 'player']},
      },
    }, phone);

    expect(box(tester, AppNavigation).top, closeTo(0, 1));
    expect(box(tester, PlayerDock).bottom, closeTo(phone.height, 1));
  });

  testWidgets('tabs can be hidden and reordered', (tester) async {
    await pump(tester, {
      'name': 'Few',
      'layout': {'tabs': ['stats', 'library']},
    }, phone);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 2);
    expect((bar.destinations.first as NavigationDestination).label, 'Статистика');
    expect(find.text('Плейлисты'), findsNothing);
  });

  testWidgets('player controls follow the theme order', (tester) async {
    await pump(tester, {
      'name': 'Controls',
      'layout': {
        'player': {'controls': ['next', 'play', 'favorite']},
      },
    }, phone);

    final dock = find.byType(PlayerDock);
    final next = tester.getCenter(find.descendant(of: dock, matching: find.byTooltip('Следующий')));
    final play = tester.getCenter(find.descendant(of: dock, matching: find.byIcon(Icons.play_circle_fill)));
    expect(next.dx, lessThan(play.dx));
    expect(find.descendant(of: dock, matching: find.byTooltip('Предыдущий')), findsNothing);
  });

  testWidgets('numbered track rows replace covers', (tester) async {
    await pump(tester, {
      'name': 'Numbers',
      'layout': {
        'trackRow': {'leading': 'number', 'trailing': ['duration', 'menu']},
      },
    }, phone);

    expect(find.descendant(of: find.byType(ListTile), matching: find.byType(Cover)), findsNothing);
    expect(find.text('1'), findsWidgets);
    expect(find.byIcon(Icons.cloud_outlined), findsNothing);
  });

  testWidgets('hiding the player cover removes it from the dock', (tester) async {
    await pump(tester, {
      'name': 'NoCover',
      'layout': {'player': {'showCover': false}},
    }, phone);

    expect(find.descendant(of: find.byType(PlayerDock), matching: find.byType(Cover)), findsNothing);
  });

  testWidgets('switching tabs works in any layout', (tester) async {
    await pump(tester, {
      'name': 'Rail',
      'layout': {
        'shell': {'row': ['navigation', {'column': ['header', 'content', 'player']}]},
      },
    }, phone);

    await tester.tap(find.text('Статистика'));
    await tester.pump();
    expect(find.text('Минуты по дням'), findsOneWidget);
  });
}
