import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/smart_playlists.dart';

final now = DateTime(2026, 10, 19, 12);
int ms(DateTime d) => d.millisecondsSinceEpoch;

Track track(String id, {required int addedDaysAgo}) => Track(
      fileId: id,
      uniqueId: id,
      title: id,
      artist: 'A',
      duration: 200,
      addedAt: ms(now.subtract(Duration(days: addedDaysAgo))),
    );

PlayEvent play(String id, {int daysAgo = 1, bool skip = false}) => PlayEvent(
      trackId: id,
      at: ms(now.subtract(Duration(days: daysAgo))),
      listenedMs: skip ? 2000 : 200000,
      durationMs: 200000,
      completed: !skip,
    );

SmartPlaylists build(List<Track> tracks, List<PlayEvent> events, {Set<String> favorites = const {}}) =>
    SmartPlaylists(tracks: tracks, events: events, favorites: favorites, now: now);

List<String> ids(List<Track> l) => [for (final t in l) t.uniqueId];

void main() {
  final tracks = [
    track('old', addedDaysAgo: 200),
    track('mid', addedDaysAgo: 40),
    track('new', addedDaysAgo: 2),
    track('newer', addedDaysAgo: 1),
  ];

  test('recently added: the last two weeks, newest first', () {
    final list = build(tracks, []).tracksFor(SmartPlaylist.recentlyAdded);
    expect(ids(list), ['newer', 'new']);
  });

  test('top of the month ranks by plays and ignores older listening', () {
    final events = [
      for (var i = 0; i < 5; i++) play('mid', daysAgo: 2 + i),
      for (var i = 0; i < 2; i++) play('new', daysAgo: 3 + i),
      for (var i = 0; i < 20; i++) play('old', daysAgo: 60 + i), // too long ago
    ];
    expect(ids(build(tracks, events).tracksFor(SmartPlaylist.topMonth)), ['mid', 'new']);
  });

  test('never played lists what has no counted play, newest first', () {
    final events = [play('mid'), play('old', skip: true)]; // a skip is not a play
    expect(ids(build(tracks, events).tracksFor(SmartPlaylist.neverPlayed)), ['newer', 'new', 'old']);
  });

  test('loved puts favorites first, but heavy rotation counts too', () {
    final events = [for (var i = 0; i < 4; i++) play('mid', daysAgo: 1 + i)];
    final list = build(tracks, events, favorites: {'new'}).tracksFor(SmartPlaylist.loved);
    expect(ids(list), ['new', 'mid']);
  });

  test('a track needs enough evidence before it counts as loved', () {
    final list = build(tracks, [play('mid')]).tracksFor(SmartPlaylist.loved);
    expect(list, isEmpty);
  });

  test('often skipped needs repeated plays and mostly skips', () {
    final events = [
      play('mid', skip: true), play('mid', skip: true), play('mid', skip: true), play('mid'),
      play('new', skip: true), // only once: not enough to judge
      play('old', skip: true), play('old', skip: true), play('old'), play('old'), play('old'),
    ];
    expect(ids(build(tracks, events).tracksFor(SmartPlaylist.skipped)), ['mid']);
  });

  test('lists are capped', () {
    final many = [for (var i = 0; i < 300; i++) track('t$i', addedDaysAgo: 1)];
    expect(build(many, []).tracksFor(SmartPlaylist.recentlyAdded).length, SmartPlaylists.maxTracks);
  });

  test('empty lists are left out so the screen shows only useful ones', () {
    final shown = build(tracks, []).nonEmpty().keys.toSet();
    expect(shown, {SmartPlaylist.recentlyAdded, SmartPlaylist.neverPlayed});
  });

  test('tracks that were removed from the library do not appear', () {
    final events = [for (var i = 0; i < 6; i++) play('gone', daysAgo: 1 + i)];
    final lists = build(tracks, events);
    expect(ids(lists.tracksFor(SmartPlaylist.topMonth)), isEmpty);
    expect(ids(lists.tracksFor(SmartPlaylist.loved)), isEmpty);
  });
}
