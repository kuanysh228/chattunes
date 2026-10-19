import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/stats.dart';

PlayEvent ev(String id, {int at = 1000, int ms = 5000, bool done = false}) => PlayEvent(
      trackId: id,
      at: at,
      listenedMs: ms,
      durationMs: 200000,
      completed: done,
    );

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('stats_store'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<StatsStore> openAwaited() async {
    final s = StatsStore();
    await s.init(dir);
    return s;
  }

  test('recorded events survive a restart', () async {
    final a = await openAwaited();
    await a.record(ev('x'));
    await a.record(ev('y', at: 2000));

    final b = await openAwaited();
    expect(b.events.map((e) => e.trackId), ['x', 'y']);
  });

  test('a listen interrupted by closing the app is recovered on the next start', () async {
    final a = await openAwaited();
    await a.checkpoint(ev('cut-off', at: 5000, ms: 42000));
    // The app dies here: no record() call.

    final b = await openAwaited();
    expect(b.events.single.trackId, 'cut-off');
    expect(b.events.single.listenedMs, 42000);
    expect(b.events.single.completed, isFalse);
  });

  test('a finished listen replaces its checkpoint instead of counting twice', () async {
    final a = await openAwaited();
    await a.checkpoint(ev('t', at: 7000, ms: 10000));
    await a.record(ev('t', at: 7000, ms: 200000, done: true));

    final b = await openAwaited();
    expect(b.events.length, 1);
    expect(b.events.single.completed, isTrue);
  });

  test('a checkpoint left next to an already logged event is not logged twice', () async {
    final a = await openAwaited();
    await a.record(ev('t', at: 9000, ms: 30000));
    // Crash between writing the event and deleting the checkpoint.
    await a.checkpoint(ev('t', at: 9000, ms: 28000));

    final b = await openAwaited();
    expect(b.events.length, 1);
  });

  test('a blip shorter than a second is not recovered as a listen', () async {
    final a = await openAwaited();
    await a.checkpoint(ev('blip', ms: 400));

    final b = await openAwaited();
    expect(b.events, isEmpty);
  });

  test('a corrupt checkpoint does not stop the app from starting', () async {
    File('${dir.path}/pending_play.json').writeAsStringSync('{ not json');
    final s = await openAwaited();
    expect(s.events, isEmpty);
    expect(File('${dir.path}/pending_play.json').existsSync(), isFalse);
  });

  test('a torn last line in the log keeps the earlier history', () async {
    final a = await openAwaited();
    await a.record(ev('good'));
    File('${dir.path}/plays.jsonl').writeAsStringSync('{"id":"half', mode: FileMode.append);

    final b = await openAwaited();
    expect(b.events.map((e) => e.trackId), ['good']);
  });

  test('clearing stats also drops a pending checkpoint', () async {
    final a = await openAwaited();
    await a.record(ev('x'));
    await a.checkpoint(ev('y', at: 3000, ms: 9000));
    await a.reset(1);

    final b = await openAwaited();
    expect(b.events, isEmpty);
  });
}
