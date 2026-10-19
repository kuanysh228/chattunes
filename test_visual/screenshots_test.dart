// Renders the app on sample data into PNG files, with no device or Telegram.
//
//   flutter test test_visual
//
// Output goes to build/screenshots (override with SCREENSHOT_DIR). Theme
// authors can use this to preview a theme: drop it in themes/ and run it.
// Not part of `flutter test`, because it needs the fonts shipped in the
// Flutter SDK and writes files.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/ui/screens/home_shell.dart';
import 'package:telemusic/ui/screens/now_playing_screen.dart';
import 'package:telemusic/ui/screens/playlists_screen.dart';
import 'package:telemusic/ui/screens/settings_screen.dart';
import 'package:telemusic/ui/screens/themes_screen.dart';
import 'package:telemusic/ui/theme/theme_spec.dart';

import '../test/support/sample_app.dart';

final outDir = Directory(Platform.environment['SCREENSHOT_DIR'] ?? 'build/screenshots');

Future<void> loadFonts() async {
  final root = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/flutter-sdk';
  final fonts = '$root/bin/cache/artifacts/material_fonts';

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('$fonts/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(Uint8List.fromList(bytes))));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
}

void main() {
  late SampleApp app;
  final key = GlobalKey();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadFonts();
    outDir.createSync(recursive: true);
  });

  setUp(() async {
    app = await SampleApp.create();
    app.showAsPlaying(0);
  });
  tearDown(() => app.dispose());

  Future<void> shot(
    WidgetTester tester,
    String name, {
    required ThemeSpec spec,
    required Widget Function() home,
    Size size = const Size(420, 860),
    double ratio = 2,
  }) async {
    tester.view.physicalSize = size * ratio;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: spec.toThemeData(),
        home: home(),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 1200));

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      return image.toByteData(format: ui.ImageByteFormat.png);
    });
    File('${outDir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  }

  Widget shell() => HomeShell(
        library: app.library,
        player: app.player,
        stats: app.stats,
        settings: app.settings,
        themes: app.themes,
      );

  ThemeSpec bundled(String file) => ThemeSpec.parse(File('themes/$file.json').readAsStringSync());

  final themeFiles = ['chattunes-dark', 'chattunes-light', 'amoled', 'sunset', 'terminal', 'paper'];

  for (final t in themeFiles) {
    testWidgets('theme $t, phone', (tester) async {
      await shot(tester, 'theme-$t-phone', spec: bundled(t), home: shell);
    });
    testWidgets('theme $t, desktop', (tester) async {
      await shot(tester, 'theme-$t-desktop',
          spec: bundled(t), home: shell, size: const Size(1280, 800), ratio: 1);
    });
  }

  testWidgets('tabs of the default theme', (tester) async {
    final spec = bundled('chattunes-dark');
    for (final (tab, label) in [
      ('foryou', 'Для вас'),
      ('playlists', 'Плейлисты'),
      ('stats', 'Статистика'),
    ]) {
      tester.view.physicalSize = const Size(840, 1720);
      tester.view.devicePixelRatio = 2;
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(debugShowCheckedModeBanner: false, theme: spec.toThemeData(), home: shell()),
      ));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text(label).last);
      await tester.pump(const Duration(milliseconds: 1200));
      final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
      final bytes = await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        return image.toByteData(format: ui.ImageByteFormat.png);
      });
      File('${outDir.path}/tab-$tab.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    }
    addTearDown(tester.view.reset);
  });

  testWidgets('now playing, vertical and side by side', (tester) async {
    await shot(tester, 'now-playing-phone',
        spec: bundled('chattunes-dark'),
        home: () => NowPlayingScreen(library: app.library, player: app.player));
    await shot(tester, 'now-playing-paper-desktop',
        spec: bundled('paper'),
        home: () => NowPlayingScreen(library: app.library, player: app.player),
        size: const Size(1100, 700),
        ratio: 1);
  });

  testWidgets('themes picker and settings', (tester) async {
    await shot(tester, 'themes-picker',
        spec: bundled('chattunes-dark'), home: () => ThemesScreen(themes: app.themes));
    await shot(tester, 'settings',
        spec: bundled('chattunes-dark'),
        home: () => SettingsScreen(
              library: app.library,
              player: app.player,
              settings: app.settings,
              stats: app.stats,
              themes: app.themes,
            ));
  });

  testWidgets('playlist detail', (tester) async {
    await shot(tester, 'playlist',
        spec: bundled('chattunes-dark'),
        home: () => PlaylistDetailScreen(library: app.library, player: app.player, playlistId: 'road'));
  });
}
