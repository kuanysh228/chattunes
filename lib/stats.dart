import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

/// Append-only play log kept on this device (one JSON object per line), plus
/// the logs of the user's other devices, which arrive through the shared index.
class StatsStore extends ChangeNotifier {
  late final File _file;
  late final File _pending;
  late final File _meta;

  /// Identifies this device's own log in the shared index.
  String deviceId = 'local';

  /// Goes up when stats are reset, see [DeviceHistory].
  int epoch = 0;

  /// What this device listened to.
  List<PlayEvent> ownEvents = [];

  /// Other devices' logs, as last synced.
  Map<String, DeviceHistory> others = {};

  List<PlayEvent>? _all;

  /// Everything the user listened to, on every device. Stats and
  /// recommendations are computed from this.
  List<PlayEvent> get events =>
      _all ??= [...ownEvents, for (final h in others.values) ...h.events];

  DeviceHistory get ownHistory => DeviceHistory(epoch, ownEvents);

  Future<void> init(Directory dir, {String? deviceId}) async {
    if (deviceId != null) this.deviceId = deviceId;
    _file = File('${dir.path}/plays.jsonl');
    _pending = File('${dir.path}/pending_play.json');
    _meta = File('${dir.path}/stats_meta.json');

    if (await _meta.exists()) {
      try {
        epoch = ((jsonDecode(await _meta.readAsString()) as Map)['epoch'] as num).toInt();
      } catch (_) {
        epoch = 0;
      }
    }
    if (await _file.exists()) {
      final loaded = <PlayEvent>[];
      for (final line in await _file.readAsLines()) {
        if (line.trim().isEmpty) continue;
        try {
          loaded.add(PlayEvent.fromJson(jsonDecode(line) as Map<String, dynamic>));
        } catch (_) {
          // A torn last line after a crash must not lose the rest of the history.
        }
      }
      ownEvents = loaded;
    }
    _all = null;
    await _recoverPending();
  }

  /// A track that was still playing when the app died or was closed leaves a
  /// checkpoint behind. Turn it into a normal event on the next start.
  Future<void> _recoverPending() async {
    if (!await _pending.exists()) return;
    try {
      final e = PlayEvent.fromJson(jsonDecode(await _pending.readAsString()) as Map<String, dynamic>);
      final alreadyLogged = ownEvents.any((x) => x.trackId == e.trackId && x.at == e.at);
      if (!alreadyLogged && e.listenedMs >= minLoggedMs) await record(e);
    } catch (_) {
      // A half-written checkpoint is not worth failing startup for.
    }
    if (await _pending.exists()) await _pending.delete();
  }

  /// Listening shorter than this is an accidental tap, not a listen.
  static const minLoggedMs = 1000;

  /// Saves the track currently playing, so closing the app loses at most the
  /// last few seconds.
  Future<void> checkpoint(PlayEvent partial) =>
      _pending.writeAsString(jsonEncode(partial.toJson()), flush: true);

  Future<void> record(PlayEvent e) async {
    ownEvents = [...ownEvents, e];
    _all = null;
    notifyListeners();
    await _file.writeAsString('${jsonEncode(e.toJson())}\n', mode: FileMode.append);
    // The finished event supersedes any checkpoint of the same listen.
    if (await _pending.exists()) await _pending.delete();
  }

  /// Takes in the logs from the shared index. Other devices' logs replace what
  /// we had; our own log is only touched if another device reset stats, which
  /// shows as a higher epoch for our id.
  Future<void> applyRemote(Map<String, DeviceHistory> all) async {
    final mine = all[deviceId];
    if (mine != null && mine.epoch > epoch) {
      epoch = mine.epoch;
      ownEvents = [...mine.events];
      await _rewriteOwn();
    }
    others = {
      for (final e in all.entries)
        if (e.key != deviceId) e.key: e.value,
    };
    _all = null;
    notifyListeners();
  }

  /// Wipes the history on every device: [newEpoch] must be above every epoch in
  /// the index, and is then written for all devices by the caller.
  Future<void> reset(int newEpoch) async {
    epoch = newEpoch;
    ownEvents = [];
    others = {for (final e in others.entries) e.key: DeviceHistory(newEpoch, const [])};
    _all = null;
    if (await _file.exists()) await _file.delete();
    if (await _pending.exists()) await _pending.delete();
    await _writeMeta();
    notifyListeners();
  }

  /// Epoch to use for a reset: one above anything seen so far.
  int nextEpoch(Iterable<DeviceHistory> known) =>
      [epoch, for (final h in known) h.epoch].reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _rewriteOwn() async {
    await _file.writeAsString(
      [for (final e in ownEvents) jsonEncode(e.toJson())].join('\n') + (ownEvents.isEmpty ? '' : '\n'),
    );
    await _writeMeta();
  }

  Future<void> _writeMeta() => _meta.writeAsString(jsonEncode({'epoch': epoch}));
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
