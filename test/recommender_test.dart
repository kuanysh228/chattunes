import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/recommender.dart';

final now = DateTime(2026, 10, 19, 21);

Track track(String id, String artist, {int at = 0}) => Track(
      fileId: id,
      uniqueId: id,
      title: id,
      artist: artist,
      duration: 200,
      addedAt: at,
    );

PlayEvent listen(String id, {int daysAgo = 1, int hour = 21, bool skip = false}) {
  final at = DateTime(now.year, now.month, now.day - daysAgo, hour);
  return PlayEvent(
    trackId: id,
    at: at.millisecondsSinceEpoch,
    listenedMs: skip ? 2000 : 200000,
    durationMs: 200000,
    completed: !skip,
  );
}

Recommender build(
  List<Track> tracks,
  List<PlayEvent> events, {
  Set<String> favorites = const {},
}) =>
    Recommender(
      tracks: tracks,
      events: events,
      favorites: favorites,
      now: now,
      random: Random(1),
    );

void main() {
  final tracks = [
    track('rock1', 'Rockers'),
    track('rock2', 'Rockers'),
    track('rock3', 'Rockers'),
    track('pop1', 'Popstar'),
    track('pop2', 'Popstar'),
    track('jazz1', 'Jazzman'),
  ];

  test('cold start falls back to newest tracks instead of noise', () {
    final r = build([track('old', 'X', at: 1), track('new', 'X', at: 9)], []);
    expect(r.coldStart, isTrue);
    expect(r.mix().first.track.uniqueId, 'new');
  });

  test('prefers the artist the user plays most', () {
    final events = [
      for (var i = 0; i < 8; i++) listen('rock1', daysAgo: 2 + i),
      for (var i = 0; i < 8; i++) listen('rock2', daysAgo: 2 + i),
      listen('pop1', daysAgo: 5),
    ];
    final mix = build(tracks, events).mix(limit: 6);

    final order = [for (final r in mix) r.track.uniqueId];
    // The unplayed rock track should outrank the unplayed jazz track.
    expect(order.indexOf('rock3'), lessThan(order.indexOf('jazz1')));
  });

  test('tracks that are always skipped sink', () {
    final events = [
      for (var i = 0; i < 6; i++) listen('pop1', daysAgo: 3 + i),
      for (var i = 0; i < 6; i++) listen('rock1', daysAgo: 3 + i, skip: true),
    ];
    final mix = build(tracks, events).mix(limit: 6);
    final order = [for (final r in mix) r.track.uniqueId];

    expect(order.indexOf('pop1'), lessThan(order.indexOf('rock1')));
  });

  test('something played an hour ago is not pushed again', () {
    final events = [
      for (var i = 0; i < 6; i++) listen('rock1', daysAgo: 2 + i),
      for (var i = 0; i < 6; i++) listen('pop1', daysAgo: 2 + i),
      PlayEvent(
        trackId: 'rock1',
        at: now.subtract(const Duration(hours: 1)).millisecondsSinceEpoch,
        listenedMs: 200000,
        durationMs: 200000,
        completed: true,
      ),
    ];
    final mix = build(tracks, events).mix(limit: 6);
    final order = [for (final r in mix) r.track.uniqueId];

    expect(order.indexOf('pop1'), lessThan(order.indexOf('rock1')));
  });

  test('radio follows what usually plays next', () {
    // Every time pop1 ends, jazz1 follows; rock tracks are never after it.
    final events = <PlayEvent>[];
    for (var day = 2; day < 8; day++) {
      final base = DateTime(now.year, now.month, now.day - day, 20);
      events.add(PlayEvent(
        trackId: 'pop1',
        at: base.millisecondsSinceEpoch,
        listenedMs: 200000,
        durationMs: 200000,
        completed: true,
      ));
      events.add(PlayEvent(
        trackId: 'jazz1',
        at: base.add(const Duration(minutes: 4)).millisecondsSinceEpoch,
        listenedMs: 200000,
        durationMs: 200000,
        completed: true,
      ));
      events.add(listen('rock1', daysAgo: day, hour: 9));
    }
    final rec = build(tracks, events);
    final radio = rec.radio(tracks.firstWhere((t) => t.uniqueId == 'pop1'), limit: 3);

    expect(radio.first.track.uniqueId, 'jazz1');
  });

  test('radio never returns the seed or excluded tracks', () {
    final events = [for (var i = 0; i < 6; i++) listen('rock1', daysAgo: 2 + i)];
    final seed = tracks.first;
    final radio = build(tracks, events)
        .radio(seed, limit: 10, exclude: {'rock2', 'rock3'});

    final ids = {for (final r in radio) r.track.uniqueId};
    expect(ids, isNot(contains('rock1')));
    expect(ids, isNot(contains('rock2')));
    expect(ids, isNot(contains('rock3')));
  });

  test('forgotten lists loved tracks that went quiet', () {
    final events = [
      for (var i = 0; i < 5; i++) listen('jazz1', daysAgo: 60 + i),
      for (var i = 0; i < 5; i++) listen('pop1', daysAgo: 1 + i),
    ];
    final forgotten = build(tracks, events).forgotten();
    final ids = [for (final r in forgotten) r.track.uniqueId];

    expect(ids, contains('jazz1'));
    expect(ids, isNot(contains('pop1')));
  });

  test('new tracks from a liked artist are surfaced', () {
    final events = [
      for (var i = 0; i < 6; i++) listen('rock1', daysAgo: 2 + i),
    ];
    final fresh = build(tracks, events).newFromFavoriteArtists();
    final ids = [for (final r in fresh) r.track.uniqueId];

    expect(ids, containsAll(['rock2', 'rock3']));
    expect(ids, isNot(contains('rock1')));
    expect(ids, isNot(contains('jazz1')));
  });

  test('a mix does not stack one artist at the top', () {
    final many = [
      for (var i = 0; i < 6; i++) track('r$i', 'Rockers'),
      for (var i = 0; i < 6; i++) track('p$i', 'Popstar'),
    ];
    final events = [
      for (var i = 0; i < 10; i++) listen('r0', daysAgo: 2 + i),
      for (var i = 0; i < 9; i++) listen('p0', daysAgo: 2 + i),
    ];
    final mix = build(many, events).mix(limit: 6);
    final firstFour = mix.take(4).map((r) => r.track.artist).toSet();

    expect(firstFour.length, 2);
  });

  group('time of day', () {
    final tracks = [
      track('morning1', 'Dawn'),
      track('morning2', 'Dawn'),
      track('morning3', 'Dawn'),
      track('evening1', 'Dusk'),
      track('evening2', 'Dusk'),
      track('mixed', 'Both'),
      track('fresh', 'Dawn'),
    ];

    List<PlayEvent> playsAt(String id, int hour, int n) =>
        [for (var i = 0; i < n; i++) listen(id, daysAgo: 2 + i, hour: hour)];

    test('day parts split the clock sensibly', () {
      expect(dayPartOf(5), DayPart.morning);
      expect(dayPartOf(10), DayPart.morning);
      expect(dayPartOf(11), DayPart.day);
      expect(dayPartOf(17), DayPart.evening);
      expect(dayPartOf(22), DayPart.evening);
      expect(dayPartOf(23), DayPart.night);
      expect(dayPartOf(3), DayPart.night);
    });

    test('morning mix holds what you play in the morning, not the evening favorites', () {
      final events = [
        ...playsAt('morning1', 8, 6),
        ...playsAt('morning2', 9, 4),
        ...playsAt('evening1', 20, 8),
        ...playsAt('evening2', 21, 8),
      ];
      final rec = build(tracks, events);
      final mix = rec.timeMix(at: DateTime(2026, 10, 19, 8));
      final ids = [for (final r in mix) r.track.uniqueId];

      expect(ids, containsAll(['morning1', 'morning2']));
      expect(ids, isNot(contains('evening1')));
      expect(ids, isNot(contains('evening2')));
      expect(mix.first.reason.kind, RecReasonKind.timeMix);
    });

    test('the same history gives a different mix in the evening', () {
      final events = [
        ...playsAt('morning1', 8, 6),
        ...playsAt('evening1', 20, 8),
        ...playsAt('evening2', 21, 5),
      ];
      final rec = build(tracks, events);
      final ids = [for (final r in rec.timeMix(at: DateTime(2026, 10, 19, 20))) r.track.uniqueId];

      expect(ids, containsAll(['evening1', 'evening2']));
      expect(ids, isNot(contains('morning1')));
    });

    test('a track played at every hour belongs to no particular time', () {
      final events = [
        ...playsAt('mixed', 8, 2),
        ...playsAt('mixed', 14, 2),
        ...playsAt('mixed', 20, 2),
        ...playsAt('morning1', 8, 5),
      ];
      final ids = [for (final r in build(tracks, events).timeMix(at: DateTime(2026, 10, 19, 8))) r.track.uniqueId];

      expect(ids, contains('morning1'));
      expect(ids, isNot(contains('mixed')));
    });

    test('one-off plays are too little to call a habit', () {
      final events = playsAt('morning1', 8, 1);
      final mix = build(tracks, events).timeMix(at: DateTime(2026, 10, 19, 8));
      expect(mix.map((r) => r.track.uniqueId), isNot(contains('morning1')));
    });

    test('unplayed tracks of an artist you only play in the morning are suggested after the habits', () {
      final events = [
        ...playsAt('morning1', 8, 4),
        ...playsAt('morning2', 9, 4),
      ];
      final ids = [for (final r in build(tracks, events).timeMix(at: DateTime(2026, 10, 19, 8))) r.track.uniqueId];

      expect(ids, contains('fresh'));
      expect(ids.indexOf('fresh'), greaterThan(ids.indexOf('morning1')));
    });

    test('something you just heard is not offered again', () {
      final now = DateTime(2026, 10, 19, 8, 30);
      final events = [
        ...playsAt('morning1', 8, 5),
        PlayEvent(
          trackId: 'morning1',
          at: now.subtract(const Duration(minutes: 30)).millisecondsSinceEpoch,
          listenedMs: 200000,
          durationMs: 200000,
          completed: true,
        ),
      ];
      final rec = Recommender(
        tracks: tracks,
        events: events,
        favorites: const {},
        now: now,
        random: Random(1),
      );
      expect(rec.timeMix(at: now).map((r) => r.track.uniqueId), isNot(contains('morning1')));
    });

    test('no history means no time mix', () {
      expect(build(tracks, []).timeMix(at: DateTime(2026, 10, 19, 8)), isEmpty);
    });
  });
}
