import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'library_store.dart';
import 'player_service.dart';
import 'screens/home_shell.dart';
import 'screens/setup_screen.dart';
import 'settings.dart';
import 'stats.dart';

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

  runApp(ChatTunesApp(library: library, player: player, stats: stats, settings: settings));
}

class ChatTunesApp extends StatelessWidget {
  const ChatTunesApp({
    super.key,
    required this.library,
    required this.player,
    required this.stats,
    required this.settings,
  });

  final LibraryStore library;
  final PlayerService player;
  final StatsStore stats;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatTunes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: library,
        builder: (context, _) => library.configured
            ? HomeShell(library: library, player: player, stats: stats, settings: settings)
            : SetupScreen(library: library),
      ),
    );
  }
}
