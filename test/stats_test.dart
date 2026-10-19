import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/stats.dart';

Track track(String id, String artist) => Track(
      fileId: id,
      uniqueId: id,
      title: id,
      artist: artist,
      duration: 200,
      addedAt: 0,
    );

PlayEvent play(String id, DateTime at, {int ms = 200000, bool done = true}) => PlayEvent(
      trackId: id,
      at: at.millisecondsSinceEpoch,
      listenedMs: ms,
      durationMs: 200000,
      completed: done,
    );

void main() {
  final now = DateTime(2026, 10, 19, 12);
  final tracks = {
    'a': track('a', 'Band'),
    'b': track('b', 'band'),
    'c': track('c', 'Solo'),
  };

  test('a play counts after 30 seconds, not before', () {
    expect(play('a', now, ms: 31000, done: false).counted, isTrue);
    expect(play('a', now, ms: 20000, done: false).counted, isFalse);
  });

  test('a short track counts after half of it', () {
    final e = PlayEvent(
      trackId: 'a',
      at: 0,
      listenedMs: 11000,
      durationMs: 20000,
      completed: false,
    );
    expect(e.counted, isTrue);
  });

  test('quick abandon is a skip', () {
    expect(play('a', now, ms: 3000, done: false).skipped, isTrue);
    expect(play('a', now, ms: 3000, done: true).skipped, isFalse);
  });

  test('top artists merge names that differ only by case', () {
    final view = StatsView([
      play('a', now),
      play('b', now),
      play('c', now),
    ], tracks, now: now);

    final top = view.topArtists(5);
    expect(top.first.name.toLowerCase(), 'band');
    expect(top.first.plays, 2);
  });

  test('top tracks order by counted plays and ignore skips', () {
    final view = StatsView([
      play('a', now),
      play('a', now),
      play('c', now),
      play('c', now, ms: 2000, done: false),
      play('c', now, ms: 2000, done: false),
    ], tracks, now: now);

    final top = view.topTracks(5);
    expect(top.first.track.uniqueId, 'a');
    expect(top.first.plays, 2);
    expect(top[1].plays, 1);
  });

  test('minutes per day puts today last and drops older days', () {
    final view = StatsView([
      play('a', now, ms: 120000),
      play('a', now.subtract(const Duration(days: 1)), ms: 60000),
      play('a', now.subtract(const Duration(days: 10)), ms: 600000),
    ], tracks, now: now);

    final days = view.minutesPerDay(3);
    expect(days, [0, 1, 2]);
  });

  test('streak counts back from today, or from yesterday if today is empty', () {
    DateTime d(int back) => now.subtract(Duration(days: back));

    final active = StatsView([play('a', d(0)), play('a', d(1)), play('a', d(2))], tracks, now: now);
    expect(active.streakDays, 3);

    final lapsedToday = StatsView([play('a', d(1)), play('a', d(2))], tracks, now: now);
    expect(lapsedToday.streakDays, 2);

    final broken = StatsView([play('a', d(3))], tracks, now: now);
    expect(broken.streakDays, 0);
  });

  test('window filter only keeps recent events', () {
    final view = StatsView(
      [play('a', now), play('a', now.subtract(const Duration(days: 40)))],
      tracks,
      now: now,
      window: const Duration(days: 7),
    );
    expect(view.events.length, 1);
  });
}
