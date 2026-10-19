import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Append-only play log kept on this device (one JSON object per line).
class StatsStore extends ChangeNotifier {
  late final File _file;
  List<PlayEvent> events = [];

  Future<void> init(Directory dir) async {
    _file = File('${dir.path}/plays.jsonl');
    if (!await _file.exists()) return;
    final loaded = <PlayEvent>[];
    for (final line in await _file.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        loaded.add(PlayEvent.fromJson(jsonDecode(line) as Map<String, dynamic>));
      } catch (_) {
        // A torn last line after a crash must not lose the rest of the history.
      }
    }
    events = loaded;
  }

  Future<void> record(PlayEvent e) async {
    events = [...events, e];
    notifyListeners();
    await _file.writeAsString('${jsonEncode(e.toJson())}\n', mode: FileMode.append);
  }

  Future<void> clear() async {
    events = [];
    if (await _file.exists()) await _file.delete();
    notifyListeners();
  }
}

class TopTrack {
  const TopTrack(this.track, this.plays, this.listenedMs);

  final Track track;
  final int plays;
  final int listenedMs;
}

class TopArtist {
  const TopArtist(this.name, this.plays, this.listenedMs);

  final String name;
  final int plays;
  final int listenedMs;
}

/// Read-only aggregates over a slice of the play log.
class StatsView {
  StatsView(
    List<PlayEvent> all,
    this.trackById, {
    DateTime? now,
    Duration? window,
  })  : now = now ?? DateTime.now(),
        events = window == null
            ? all
            : [
                for (final e in all)
                  if (e.at >= (now ?? DateTime.now()).subtract(window).millisecondsSinceEpoch)
                    e
              ];

  final DateTime now;
  final List<PlayEvent> events;
  final Map<String, Track> trackById;

  int get totalMs => events.fold(0, (s, e) => s + e.listenedMs);

  Iterable<PlayEvent> get _counted => events.where((e) => e.counted);

  int get plays => _counted.length;

  int get skips => events.where((e) => e.skipped).length;

  double get skipRate => events.isEmpty ? 0 : skips / events.length;

  List<TopTrack> topTracks(int n) {
    final plays = <String, int>{};
    final ms = <String, int>{};
    for (final e in events) {
      ms[e.trackId] = (ms[e.trackId] ?? 0) + e.listenedMs;
      if (e.counted) plays[e.trackId] = (plays[e.trackId] ?? 0) + 1;
    }
    final list = [
      for (final id in plays.keys)
        if (trackById[id] != null) TopTrack(trackById[id]!, plays[id]!, ms[id] ?? 0)
    ]..sort((a, b) {
        final c = b.plays.compareTo(a.plays);
        return c != 0 ? c : b.listenedMs.compareTo(a.listenedMs);
      });
    return list.take(n).toList();
  }

  List<TopArtist> topArtists(int n) {
    final names = <String, String>{};
    final plays = <String, int>{};
    final ms = <String, int>{};
    for (final e in events) {
      final t = trackById[e.trackId];
      if (t == null || t.artistKey.isEmpty) continue;
      names.putIfAbsent(t.artistKey, () => t.artist.trim());
      ms[t.artistKey] = (ms[t.artistKey] ?? 0) + e.listenedMs;
      if (e.counted) plays[t.artistKey] = (plays[t.artistKey] ?? 0) + 1;
    }
    final list = [
      for (final k in plays.keys) TopArtist(names[k]!, plays[k]!, ms[k] ?? 0)
    ]..sort((a, b) {
        final c = b.plays.compareTo(a.plays);
        return c != 0 ? c : b.listenedMs.compareTo(a.listenedMs);
      });
    return list.take(n).toList();
  }

  /// Listening minutes per local calendar day, oldest first, ending today.
  List<double> minutesPerDay(int days) {
    final today = DateTime(now.year, now.month, now.day);
    final out = List<double>.filled(days, 0);
    for (final e in events) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.at);
      final day = DateTime(d.year, d.month, d.day);
      // Compare calendar days, not 24h spans: DST shifts must not skip a day.
      final ago = DateTime.utc(today.year, today.month, today.day)
          .difference(DateTime.utc(day.year, day.month, day.day))
          .inDays;
      if (ago >= 0 && ago < days) out[days - 1 - ago] += e.listenedMs / 60000;
    }
    return out;
  }

  /// Listening minutes by hour of day (index 0..23).
  List<double> minutesByHour() {
    final out = List<double>.filled(24, 0);
    for (final e in events) {
      out[DateTime.fromMillisecondsSinceEpoch(e.at).hour] += e.listenedMs / 60000;
    }
    return out;
  }

  /// Consecutive days with at least one counted play. A streak that ended
  /// yesterday is still alive until today is over.
  int get streakDays {
    final days = <int>{};
    for (final e in _counted) {
      final d = DateTime.fromMillisecondsSinceEpoch(e.at);
      days.add(DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000);
    }
    var cursor = DateTime.utc(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;
    if (!days.contains(cursor)) cursor--;
    var n = 0;
    while (days.contains(cursor)) {
      n++;
      cursor--;
    }
    return n;
  }
}
