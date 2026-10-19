import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemusic/library_store.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/player_service.dart';
import 'package:telemusic/settings.dart';
import 'package:telemusic/stats.dart';
import 'package:telemusic/sync_data.dart';
import 'package:telemusic/ui/theme/theme_controller.dart';

/// Everything the main screen needs, filled with believable sample data and
/// no network or audio device. Used by layout tests and the screenshot tool.
class SampleApp {
  SampleApp._(this.dir, this.library, this.stats, this.settings, this.player, this.themes);

  final Directory dir;
  final LibraryStore library;
  final StatsStore stats;
  final AppSettings settings;
  final PlayerService player;
  final ThemeController themes;

  static const _songs = [
    ('Midnight City', 'Neon Harbor', 247),
    ('Paper Planes', 'Neon Harbor', 201),
    ('Slow Burn', 'Aurora Lane', 312),
    ('Glass Houses', 'Aurora Lane', 188),
    ('Dust and Gold', 'The Foxglove', 265),
    ('Static', 'The Foxglove', 174),
    ('Last Train Home', 'Marlow', 298),
    ('Blue Hour', 'Marlow', 223),
    ('Wildfire', 'Juniper Kid', 207),
    ('Cassette Summer', 'Juniper Kid', 236),
  ];

  /// Writes a generated cover for [id] so screens can show real images.
  static void _writeCover(Directory covers, String id, int hue) {
    final image = img.Image(width: 160, height: 160);
    for (final p in image) {
      final t = (p.x + p.y) / 320;
      p
        ..r = (40 + 180 * ((hue % 3 == 0) ? t : 1 - t)).round()
        ..g = (60 + 150 * ((hue % 3 == 1) ? t : 0.4)).round()
        ..b = (90 + 140 * ((hue % 3 == 2) ? t : 1 - t)).round();
    }
    File('${covers.path}/$id.jpg')
        .writeAsBytesSync(Uint8List.fromList(img.encodeJpg(image, quality: 80)));
  }

  static Future<SampleApp> create({String? themeId, bool covers = false}) async {
    SharedPreferences.setMockInitialValues({'theme': ?themeId});
    final prefs = await SharedPreferences.getInstance();
    final dir = Directory.systemTemp.createTempSync('sample_app');

    if (covers) {
      final coverDir = Directory('${dir.path}/covers')..createSync(recursive: true);
      for (final i in [0, 2, 3, 6, 8]) {
        _writeCover(coverDir, 'u$i', i);
      }
    }

    final library = LibraryStore();
    await library.initForTest(prefs: prefs, dir: dir);

    final base = DateTime(2026, 10, 1).millisecondsSinceEpoch;
    final tracks = [
      for (var i = 0; i < _songs.length; i++)
        Track(
          fileId: 'f$i',
          uniqueId: 'u$i',
          title: _songs[i].$1,
          artist: _songs[i].$2,
          duration: _songs[i].$3,
          addedAt: base + i * 86400000,
        ),
    ];
    library.data = SyncData(
      tracks: tracks,
      favorites: {
        'u0': Fav(true, base),
        'u4': Fav(true, base),
        'u6': Fav(true, base),
      },
      playlists: {
        'road': Playlist(
          id: 'road',
          name: 'Road trip',
          updatedAt: base,
          trackIds: ['u0', 'u2', 'u6', 'u7'],
          offline: true,
        ),
        'focus': Playlist(id: 'focus', name: 'Focus', updatedAt: base, trackIds: ['u3', 'u5']),
      },
    );

    // A believable fortnight of listening, so stats and recommendations have data.
    final stats = StatsStore();
    await stats.init(dir);
    final now = DateTime(2026, 10, 19, 20);
    final events = <PlayEvent>[];
    for (var day = 0; day < 14; day++) {
      for (var k = 0; k < 3 + (day % 3); k++) {
        final t = tracks[(day * 3 + k * 2) % 6];
        final at = DateTime(now.year, now.month, now.day - day, 8 + k * 5 + (day % 4));
        events.add(PlayEvent(
          trackId: t.uniqueId,
          at: at.millisecondsSinceEpoch,
          listenedMs: t.duration * 1000,
          durationMs: t.duration * 1000,
          completed: true,
        ));
      }
    }
    stats.ownEvents = events;

    final settings = AppSettings(prefs);
    final player = PlayerService(library, stats, settings);
    final themes = ThemeController(prefs: prefs, dir: Directory('${dir.path}/themes'));
    await themes.load();
    return SampleApp._(dir, library, stats, settings, player, themes);
  }

  /// Pretends [index] of the library (newest first) is playing, without audio.
  void showAsPlaying(int index) {
    final list = library.tracks.reversed.toList();
    player.queue = list;
    player.index = index;
  }

  void dispose() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  }
}
