import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/sync_data.dart';

Track track(String id, {int at = 1000, String artist = 'A'}) => Track(
      fileId: 'f$id',
      uniqueId: id,
      title: 't$id',
      artist: artist,
      duration: 200,
      addedAt: at,
    );

void main() {
  test('merge is symmetric: both devices converge to the same state', () {
    final a = SyncData(
      tracks: [track('1'), track('2')],
      favorites: {'1': const Fav(true, 10)},
      playlists: {'p': Playlist(id: 'p', name: 'old', updatedAt: 5, trackIds: ['1'])},
    );
    final b = SyncData(
      tracks: [track('2'), track('3')],
      favorites: {'1': const Fav(false, 20), '3': const Fav(true, 1)},
      playlists: {'p': Playlist(id: 'p', name: 'new', updatedAt: 9, trackIds: ['2'])},
    );

    final ab = SyncData.merge(a, b);
    final ba = SyncData.merge(b, a);

    expect(ab.canonical(), ba.canonical());
    expect(ab.tracks.keys.toSet(), {'1', '2', '3'});
    expect(ab.favorites['1']!.on, isFalse, reason: 'later unlike wins');
    expect(ab.playlists['p']!.name, 'new');
  });

  test('merging identical data changes nothing (no endless uploads)', () {
    final a = SyncData(tracks: [track('1')], favorites: {'1': const Fav(true, 3)});
    final merged = SyncData.merge(a, SyncData.fromJson(a.toJson()));
    expect(merged.canonical(), a.canonical());
  });

  test('removed track stays removed on other devices', () {
    final other = SyncData(tracks: [track('1', at: 100), track('2')]);
    final mine = SyncData(tracks: [track('2')], removed: {'1': 500});

    final merged = SyncData.merge(other, mine);

    expect(merged.tracks.containsKey('1'), isFalse);
    expect(merged.tracks.containsKey('2'), isTrue);
  });

  test('re-uploading a removed track brings it back', () {
    final removed = SyncData(removed: {'1': 500});
    final reuploaded = SyncData(tracks: [track('1', at: 900)]);

    expect(SyncData.merge(removed, reuploaded).tracks.containsKey('1'), isTrue);
    expect(SyncData.merge(reuploaded, removed).tracks.containsKey('1'), isTrue);
  });

  test('reads the v1 index that only had a track list', () {
    final v1 = {
      'version': 1,
      'tracks': [
        {'file_id': 'f', 'unique_id': 'u', 'title': 't', 'artist': 'a', 'duration': 5}
      ],
    };
    final d = SyncData.fromJson(v1);
    expect(d.tracks['u']!.title, 't');
    expect(d.favorites, isEmpty);
    expect(d.playlists, isEmpty);
  });

  test('round trip through JSON keeps playlists intact', () {
    final d = SyncData(playlists: {
      'p': Playlist(
        id: 'p',
        name: 'Road',
        updatedAt: 7,
        trackIds: ['b', 'a'],
        offline: true,
      )
    });
    final back = SyncData.fromJson(d.toJson());
    expect(back.playlists['p']!.trackIds, ['b', 'a']);
    expect(back.playlists['p']!.offline, isTrue);
  });

  group('listening history', () {
    PlayEvent ev(String id, int at) => PlayEvent(
          trackId: id,
          at: at * 1000,
          listenedMs: 60000,
          durationMs: 200000,
          completed: true,
        );

    test('the longer log of a device wins, so appends are never lost', () {
      final shorter = SyncData(history: {'d1': DeviceHistory(0, [ev('a', 1)])});
      final longer = SyncData(history: {'d1': DeviceHistory(0, [ev('a', 1), ev('b', 2)])});

      expect(SyncData.merge(shorter, longer).history['d1']!.events.length, 2);
      expect(SyncData.merge(longer, shorter).history['d1']!.events.length, 2);
    });

    test('a higher epoch (a reset) beats any amount of older events', () {
      final old = SyncData(history: {'d1': DeviceHistory(0, [ev('a', 1), ev('b', 2), ev('c', 3)])});
      final reset = SyncData(history: {'d1': const DeviceHistory(1, [])});

      expect(SyncData.merge(old, reset).history['d1']!.events, isEmpty);
      expect(SyncData.merge(reset, old).history['d1']!.events, isEmpty);
    });

    test('different devices keep separate logs', () {
      final a = SyncData(history: {'d1': DeviceHistory(0, [ev('a', 1)])});
      final b = SyncData(history: {'d2': DeviceHistory(0, [ev('b', 2)])});

      expect(SyncData.merge(a, b).history.keys.toSet(), {'d1', 'd2'});
    });

    test('history survives a JSON round trip and the compact form is seconds-based', () {
      final data = SyncData(history: {'d1': DeviceHistory(2, [ev('a', 1700000000)])});
      final back = SyncData.fromJson(data.toJson());

      expect(back.history['d1']!.epoch, 2);
      expect(back.history['d1']!.events.single.trackId, 'a');
      expect(back.history['d1']!.events.single.at, 1700000000 * 1000);
      expect(data.toJson()['history'], isA<Map>());
    });

    test('an index written by an older version, without history, still loads', () {
      final d = SyncData.fromJson({'version': 2, 'tracks': []});
      expect(d.history, isEmpty);
    });

    test('history changes are visible to canonical comparison', () {
      final a = SyncData(history: {'d1': DeviceHistory(0, [ev('a', 1)])});
      final b = SyncData(history: {'d1': DeviceHistory(0, [ev('a', 1), ev('b', 2)])});
      expect(a.canonical(), isNot(b.canonical()));
      expect(a.withoutHistory('d1').canonical(), b.withoutHistory('d1').canonical());
    });
  });
}
