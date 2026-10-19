import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'library_store.dart';
import 'player_service.dart';
import 'settings.dart';
import 'stats.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/setup_screen.dart';
import 'ui/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isLinux || Platform.isWindows) {
    // just_audio has no native desktop backend; route it through libmpv.
    JustAudioMediaKit.ensureInitialized();
  }

  final library = LibraryStore();
  await library.init();
  final stats = StatsStore();
  await stats.init(library.dir);
  final settings = AppSettings(library.prefs);
  final player = PlayerService(library, stats, settings);
  final themes = ThemeController(prefs: library.prefs, dir: Directory('${library.dir.path}/themes'));
  await themes.load();
  themes.startWatching();

  runApp(ChatTunesApp(
    library: library,
    player: player,
    stats: stats,
    settings: settings,
    themes: themes,
  ));
}

class ChatTunesApp extends StatelessWidget {
  const ChatTunesApp({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
    required this.settings,
    required this.themes,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;
  final AppSettings settings;
  final ThemeController themes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) => MaterialApp(
        title: 'ChatTunes',
        debugShowCheckedModeBanner: false,
        theme: themes.themeData,
        home: ListenableBuilder(
          listenable: library,
          builder: (context, _) => library.configured
              ? HomeShell(
                  library: library,
                  player: player,
                  stats: stats,
                  settings: settings,
                  themes: themes,
                )
              : SetupScreen(library: library),
        ),
      ),
    );
  }
}
