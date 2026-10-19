import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/library_store.dart';
import 'package:telemusic/ui/components/cover_scope.dart';
import 'package:telemusic/l10n/app_localizations.dart';

/// A MaterialApp with the app's localization set up, for widget tests.
MaterialApp testApp({
  required Widget home,
  ThemeData? theme,
  Locale locale = const Locale('en'),
  bool banner = false,
  LibraryStore? covers,
}) =>
    MaterialApp(
      debugShowCheckedModeBanner: banner,
      theme: theme,
      locale: locale,
      builder: covers == null
          ? null
          : (context, child) =>
              CoverScope(notifier: covers, lookup: covers.coverFor, child: child!),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    );

/// Image loading started inside the test's fake clock never finishes there,
/// so images must be decoded with real time *before* the widget tree asks for
/// them. Covers are drawn at a handful of sizes; load each size the app uses.
Future<void> preloadCovers(WidgetTester tester, LibraryStore library) async {
  const sizes = [36.0, 40.0, 44.0, 56.0, 80.0, 200.0, 320.0];
  final ratio = tester.view.devicePixelRatio;
  await tester.runAsync(() async {
    for (final t in library.tracks) {
      final file = library.coverFor(t);
      if (file == null) continue;
      for (final size in sizes) {
        final px = (size * ratio).round();
        await preloadImage(ResizeImage(FileImage(file), width: px, height: px));
      }
    }
  });
}

/// Resolves [provider] and waits until it is decoded (or has failed).
Future<void> preloadImage(ImageProvider provider) {
  final done = Completer<void>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
    onError: (_, _) {
      if (!done.isCompleted) done.complete();
      stream.removeListener(listener);
    },
  );
  stream.addListener(listener);
  return done.future;
}
