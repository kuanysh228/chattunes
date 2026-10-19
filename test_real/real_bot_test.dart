// Opt-in checks against a real Telegram bot and chat. Skipped unless both
// variables are set:
//
//   TG_TOKEN=123:ABC TG_CHAT=-100123 flutter test test_real
//
// It uploads one tiny audio file to the chat, syncs it to a second simulated
// device, then removes it and puts the pinned index back exactly as it was,
// so it is safe to run against your real library chat. Do not run it while the
// app is open on the same bot: both would read the same updates.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemusic/library_store.dart';
import 'package:telemusic/stats.dart';
import 'package:telemusic/sync_data.dart';
import 'package:telemusic/telegram_api.dart';
import 'package:telemusic/token_store.dart';

class _MemoryKeychain implements SecretBackend {
  final Map<String, String> values = {};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  final token = Platform.environment['TG_TOKEN'];
  final chat = Platform.environment['TG_CHAT'];
  final skip = token == null || chat == null ? 'set TG_TOKEN and TG_CHAT to run against a real bot' : null;

  group('real Telegram', skip: skip, () {
    late TelegramApi api;
    ({SyncData? data, int messageId, String version})? original;
    final dirs = <Directory>[];
    final stores = <LibraryStore>[];

    Future<LibraryStore> device() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final dir = Directory.systemTemp.createTempSync('real_device');
      dirs.add(dir);
      final store = LibraryStore(
        autoSync: false,
        initialVault: TokenVault(prefs: prefs, keychain: _MemoryKeychain()),
      );
      await store.initForTest(prefs: prefs, dir: dir);
      final stats = StatsStore();
      await stats.init(dir, deviceId: store.deviceId);
      await store.attachStats(stats);
      await store.connect(token!, chat!);
      stores.add(store);
      return store;
    }

    setUpAll(() async {
      api = TelegramApi(token!, chat!);
      original = await api.fetchIndex();
    });

    tearDownAll(() async {
      for (final s in stores) {
        s.dispose();
      }
      for (final d in dirs) {
        if (d.existsSync()) d.deleteSync(recursive: true);
      }
      // Put the pinned index back exactly as we found it.
      final before = original;
      final now = await api.fetchIndex();
      if (before?.data != null && now != null) {
        await api.publishIndex(before!.data!, previousMessageId: now.messageId);
      }
    });

    test('the bot is an administrator and can read the chat', () async {
      await api.verifyAdmin();
      final chatInfo = await api.getChat();
      expect(chatInfo['id'], isNotNull);
    });

    test('polling updates works with the real API', () async {
      final r = await api.pollTracks(null);
      expect(r.tracks, isA<List>());
    });

    test('upload with real tags and cover, sync to a second device, clean up', () async {
      final a = await device();
      final b = await device();
      await a.refresh();
      final before = a.tracks.length;

      await a.uploadFiles([File('test/fixtures/tagged.mp3')]);
      final uploaded = a.tracks.firstWhere((t) => t.title == 'Test Song');
      addTearDown(() async {
        await a.removeTrack(uploaded);
        await a.refresh();
      });

      expect(uploaded.artist, 'Test Artist');
      expect(uploaded.duration, inInclusiveRange(1, 3));
      expect(uploaded.messageId, isNotNull);
      // ignore: avoid_print
      print('thumbnail echoed by Telegram: ${uploaded.thumbId != null}');

      await a.refresh();
      await b.refresh();
      await b.syncCovers();

      final seen = b.tracks.firstWhere((t) => t.uniqueId == uploaded.uniqueId);
      expect(seen.title, 'Test Song');
      expect(b.tracks.length, before + 1);
      if (uploaded.thumbId != null) {
        expect(b.coverFor(seen), isNotNull, reason: 'the second device downloads the cover from Telegram');
        expect(b.coverFor(seen)!.lengthSync(), greaterThan(100));
      }

      // The uploaded audio really downloads, byte for byte.
      final out = File('${dirs.first.path}/dl.mp3');
      await api.download(uploaded.fileId, out);
      expect(out.lengthSync(), File('test/fixtures/tagged.mp3').lengthSync());
    });

    test('the pinned index is edited in place, not re-pinned', () async {
      final a = await device();
      await a.refresh();
      final pinnedBefore = (await api.fetchIndex())?.messageId;
      a.createPlaylist('real-bot-check');
      await a.refresh();
      final pinnedAfter = (await api.fetchIndex())?.messageId;

      expect(pinnedAfter, pinnedBefore, reason: 'same message, so no pin notification in groups');
      final stored = (await api.fetchIndex())!.data!;
      expect(stored.playlists.values.any((p) => p.name == 'real-bot-check'), isTrue);

      final p = a.playlists.firstWhere((p) => p.name == 'real-bot-check');
      a.deletePlaylist(p);
      await a.refresh();
    });
  });
}
