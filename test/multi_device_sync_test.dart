import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemusic/library_store.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/stats.dart';
import 'package:telemusic/token_store.dart';

import 'support/fake_bot_api.dart';

/// In-memory stand-in for the system keychain.
class MemoryKeychain implements SecretBackend {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Two "devices" (two LibraryStores with separate storage) talking to one
/// fake Telegram chat. These are the real sync paths: upload, polling, the
/// pinned index, favorites, playlists and removals.
void main() {
  late FakeBotApi fake;
  final dirs = <Directory>[];
  final stores = <LibraryStore>[];

  Future<LibraryStore> device() async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('device');
    dirs.add(dir);
    final prefs = await SharedPreferences.getInstance();
    final store = LibraryStore(
      apiHost: fake.host,
      autoSync: false,
      initialVault: TokenVault(prefs: prefs, keychain: MemoryKeychain()),
    );
    await store.initForTest(prefs: prefs, dir: dir);
    final stats = StatsStore();
    await stats.init(dir, deviceId: store.deviceId);
    await store.attachStats(stats);
    await store.connect('TOKEN', '@chan');
    stores.add(store);
    return store;
  }

  setUp(() async {
    fake = FakeBotApi();
    await fake.start();
  });

  tearDown(() async {
    for (final s in stores) {
      s.dispose();
    }
    stores.clear();
    for (final d in dirs) {
      if (d.existsSync()) d.deleteSync(recursive: true);
    }
    dirs.clear();
    await fake.stop();
  });

  File fixture(String name) => File('test/fixtures/$name');

  test('an upload on one device shows up on another, with tags and cover', () async {
    final a = await device();
    await a.uploadFiles([fixture('tagged.mp3')]);
    await a.refresh();

    expect(a.tracks.single.title, 'Test Song');
    expect(a.tracks.single.artist, 'Test Artist');
    expect(a.tracks.single.duration, inInclusiveRange(1, 3));
    expect(a.tracks.single.thumbId, isNotNull, reason: 'the cover was sent as a thumbnail');
    expect(a.coverFor(a.tracks.single), isNotNull, reason: 'the uploader keeps its own copy');

    final b = await device();
    await b.refresh();
    await b.syncCovers();

    expect(b.tracks.map((t) => t.title), ['Test Song']);
    final cover = b.coverFor(b.tracks.single);
    expect(cover, isNotNull, reason: 'the other device downloads the cover thumbnail');
    expect(cover!.lengthSync(), greaterThan(100));
  });

  test('a file without tags falls back to the file name', () async {
    final a = await device();
    final tmp = fixture('plain.mp3').copySync('${dirs.first.path}/Some Band - Some Song.mp3');
    await a.uploadFiles([tmp]);

    expect(a.tracks.single.title, 'Some Song');
    expect(a.tracks.single.artist, 'Some Band');
  });

  test('favorites, playlists and removals travel through the pinned index', () async {
    final a = await device();
    await a.uploadFiles([fixture('tagged.mp3'), fixture('plain.mp3')]);
    final song = a.tracks.firstWhere((t) => t.title == 'Test Song');
    final other = a.tracks.firstWhere((t) => t.title != 'Test Song');

    a.toggleFavorite(song);
    final list = a.createPlaylist('Road', trackIds: [song.uniqueId, other.uniqueId]);
    a.setPlaylistOffline(list, true);
    await a.refresh();

    final b = await device();
    await b.refresh();
    expect(b.favoriteIds, {song.uniqueId});
    expect(b.playlists.single.name, 'Road');
    expect(b.playlists.single.offline, isTrue);
    expect(b.playlistTracks(b.playlists.single).map((t) => t.uniqueId), [song.uniqueId, other.uniqueId]);

    await b.removeTrack(b.tracks.firstWhere((t) => t.uniqueId == other.uniqueId));
    await b.refresh();
    await a.refresh();

    expect(a.tracks.map((t) => t.uniqueId), [song.uniqueId], reason: 'removal reaches the first device');
    expect(a.playlistTracks(a.playlists.single).map((t) => t.uniqueId), [song.uniqueId]);
  });

  test('edits made on both devices at once converge without losing either', () async {
    final a = await device();
    await a.uploadFiles([fixture('tagged.mp3'), fixture('plain.mp3')]);
    await a.refresh();
    final b = await device();
    await b.refresh();

    final first = a.tracks.first;
    final second = a.tracks.last;
    a.toggleFavorite(first);
    b.toggleFavorite(second);
    b.createPlaylist('From B');
    a.createPlaylist('From A');

    await a.refresh();
    await b.refresh();
    await a.refresh();

    for (final d in [a, b]) {
      expect(d.favoriteIds, {first.uniqueId, second.uniqueId});
      expect(d.playlists.map((p) => p.name).toSet(), {'From A', 'From B'});
    }
    // Each device keeps its own listening log elsewhere; the shared data must agree.
    String shared(LibraryStore x) =>
        x.data.withoutHistory(a.deviceId).withoutHistory(b.deviceId).canonical();
    expect(shared(a), shared(b));
  });

  test('a track posted into the chat by hand is picked up by polling', () async {
    final a = await device();
    fake.postAudio('manual1', 'Posted By Hand');
    await a.refresh();

    expect(a.tracks.map((t) => t.title), ['Posted By Hand']);

    final b = await device();
    await b.refresh();
    expect(b.tracks.map((t) => t.title), ['Posted By Hand'],
        reason: 'the other device reads it from the index, even though polling already consumed the update');
  });

  test('syncing with nothing changed does not upload the index again', () async {
    final a = await device();
    await a.uploadFiles([fixture('plain.mp3')]);
    await a.refresh();
    fake.calls.clear();

    await a.refresh();
    await a.refresh();

    expect(fake.calls.where((c) => c == 'editMessageMedia' || c == 'sendDocument'), isEmpty);
  });

  test('an unchanged index is not downloaded again on every poll', () async {
    final a = await device();
    await a.uploadFiles([fixture('plain.mp3')]);
    await a.refresh();
    await a.refresh(); // learns the new file id after our own upload
    fake.calls.clear();

    await a.refresh();
    await a.refresh();
    await a.refresh();

    expect(fake.calls.where((c) => c == 'getFile'), isEmpty,
        reason: 'only getChat is needed to see the index has not changed');
    expect(fake.calls.where((c) => c == 'getChat'), isNotEmpty);

    // A change from elsewhere is still noticed.
    final b = await device();
    await b.refresh();
    b.createPlaylist('New');
    await b.refresh();
    await a.refresh();
    expect(a.playlists.map((p) => p.name), ['New']);
  });

  test('an upload without network surfaces a status instead of crashing', () async {
    final a = await device();
    await fake.stop();
    await a.refresh();

    expect(a.status, isNotNull);
    expect(a.tracks, isEmpty);
    fake = FakeBotApi()..server = await HttpServer.bind('127.0.0.1', 0);
    fake.server.listen((r) => r.response.close());
  });

  group('listening history', () {
    PlayEvent heard(String id, int at, {int ms = 200000}) => PlayEvent(
          trackId: id,
          at: at,
          listenedMs: ms,
          durationMs: 200000,
          completed: true,
        );

    test('what one device listened to shows up in the stats of the other', () async {
      final a = await device();
      final b = await device();
      await a.stats!.record(heard('u1', 1760000000000));
      await a.stats!.record(heard('u2', 1760000100000));
      await b.stats!.record(heard('u3', 1760000200000));

      await a.refresh(forceHistory: true);
      await b.refresh(forceHistory: true);
      await a.refresh();

      expect(b.stats!.events.map((e) => e.trackId).toSet(), {'u1', 'u2', 'u3'});
      expect(a.stats!.events.map((e) => e.trackId).toSet(), {'u1', 'u2', 'u3'});
      expect(a.stats!.ownEvents.length, 2, reason: 'each device still owns only its own log');
      expect(b.stats!.ownEvents.length, 1);
    });

    test('plays alone do not upload the index on every sync', () async {
      final a = await device();
      await a.uploadFiles([fixture('plain.mp3')]);
      await a.refresh();
      await a.refresh();
      fake.calls.clear();

      await a.stats!.record(heard('u1', 1760000000000));
      await a.refresh();
      await a.refresh();

      expect(fake.calls.where((c) => c == 'editMessageMedia' || c == 'sendDocument'), isEmpty);

      await a.refresh(forceHistory: true);
      expect(fake.calls.where((c) => c == 'editMessageMedia'), hasLength(1),
          reason: 'going to the background pushes the pending plays');
    });

    test('a real change carries the pending plays along', () async {
      final a = await device();
      await a.uploadFiles([fixture('plain.mp3')]);
      await a.refresh();
      await a.stats!.record(heard('u1', 1760000000000));
      a.createPlaylist('New');
      await a.refresh();

      final b = await device();
      await b.refresh();
      expect(b.stats!.events.map((e) => e.trackId), ['u1']);
    });

    test('resetting stats clears every device and nothing comes back', () async {
      final a = await device();
      final b = await device();
      await a.stats!.record(heard('old-a', 1760000000000));
      await b.stats!.record(heard('old-b', 1760000100000));
      await a.refresh(forceHistory: true);
      await b.refresh(forceHistory: true);
      await a.refresh();
      expect(a.stats!.events.length, 2);

      await a.resetHistory();
      await a.refresh();
      await b.refresh();

      expect(a.stats!.events, isEmpty);
      expect(b.stats!.events, isEmpty, reason: 'the other device drops its old log too');
      expect(b.stats!.epoch, greaterThan(0));

      // Syncing again must not resurrect anything.
      await a.refresh(forceHistory: true);
      await b.refresh(forceHistory: true);
      await a.refresh();
      expect(a.stats!.events, isEmpty);
      expect(b.stats!.events, isEmpty);

      // New listening after the reset is shared normally.
      await b.stats!.record(heard('new-b', 1760000500000));
      await b.refresh(forceHistory: true);
      await a.refresh();
      expect(a.stats!.events.map((e) => e.trackId), ['new-b']);
    });

    test('an index with a year of listening stays small', () {
      final events = [
        for (var i = 0; i < 7300; i++) heard('AgADBAADrqwxG0abcDE${i % 400}', 1760000000000 + i * 3600000),
      ];
      final json = DeviceHistory(0, events).toJson().toString();
      // ~20 plays a day for a year; each event is a short array, not an object.
      expect(json.length, lessThan(600 * 1024));
    });
  });
}
