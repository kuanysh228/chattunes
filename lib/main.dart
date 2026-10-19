import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';

import 'l10n/app_localizations.dart';
import 'library_store.dart';
import 'mpris.dart';
import 'player_service.dart';
import 'settings.dart';
import 'stats.dart';
import 'ui/components/cover_scope.dart';
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
  await stats.init(library.dir, deviceId: library.deviceId);
  await library.attachStats(stats);
  final settings = AppSettings(library.prefs);
  final player = PlayerService(library, stats, settings)..attachLifecycle();
  // Media keys, the desktop's player widget and playerctl. Optional: if there
  // is no session bus the app simply runs without them.
  player.systemMediaControls = await MprisService(player).start();
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
      listenable: Listenable.merge([themes, settings]),
      builder: (context, _) => MaterialApp(
        onGenerateTitle: (context) => AppLocalizations.of(context).appName,
        debugShowCheckedModeBanner: false,
        theme: themes.themeData,
        builder: (context, child) => CoverScope(
          notifier: library,
          lookup: library.coverFor,
          child: child!,
        ),
        locale: settings.locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
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
