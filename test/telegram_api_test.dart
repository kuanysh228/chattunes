import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/sync_data.dart';
import 'package:telemusic/telegram_api.dart';

import 'support/fake_bot_api.dart';

void main() {
  late FakeBotApi fake;
  late TelegramApi api;

  setUp(() async {
    fake = FakeBotApi();
    await fake.start();
    api = TelegramApi('TOKEN', '@chan', host: fake.host);
  });

  tearDown(() => fake.stop());

  Track track(String id) => Track(
        fileId: 'f$id',
        uniqueId: id,
        title: 't$id',
        artist: 'A',
        duration: 10,
        addedAt: 1,
      );

  test('publishing an index pins it and reading it back gives the same data', () async {
    final data = SyncData(
      tracks: [track('1'), track('2')],
      favorites: {'1': const Fav(true, 5)},
      playlists: {'p': Playlist(id: 'p', name: 'Gym', updatedAt: 3, trackIds: ['2', '1'])},
    );

    final id = await api.publishIndex(data);
    final fetched = await api.fetchIndex();

    expect(fake.pinned, id);
    expect(fetched, isNotNull);
    expect(fetched!.messageId, id);
    expect(fetched.data!.canonical(), data.canonical());
  });

  test('republishing edits the pinned message in place', () async {
    final first = await api.publishIndex(SyncData(tracks: [track('1')]));
    fake.calls.clear();

    final second = await api.publishIndex(
      SyncData(tracks: [track('1'), track('2')]),
      previousMessageId: first,
    );

    expect(second, first, reason: 'same message, so no new pin notification');
    expect(fake.calls, ['editMessageMedia']);
    expect(fake.pinned, first);
    expect((await api.fetchIndex())!.data!.tracks.length, 2);
  });

  test('falls back to a fresh pinned post when the old one is gone', () async {
    final first = await api.publishIndex(SyncData(tracks: [track('1')]));
    fake.messages.remove(first);
    fake.pinned = null;

    final second = await api.publishIndex(
      SyncData(tracks: [track('1'), track('2')]),
      previousMessageId: first,
    );

    expect(second, isNot(first));
    expect(fake.pinned, second);
    expect((await api.fetchIndex())!.data!.tracks.length, 2);
  });

  test('a channel with no pinned index reports none', () async {
    expect(await api.fetchIndex(), isNull);
  });

  test('a pinned message that is not our index is ignored', () async {
    fake.postAudio('x', 'Some song');
    fake.pinned = 1;
    expect(await api.fetchIndex(), isNull);
  });

  test('polling returns new audio posts and advances the offset', () async {
    fake.postAudio('a', 'First');
    fake.postAudio('b', 'Second');

    final first = await api.pollTracks(null);
    expect(first.tracks.map((t) => t.uniqueId), ['a', 'b']);
    expect(first.tracks.first.addedAt, 1700000000 * 1000);
    expect(first.nextOffset, 102);

    final again = await api.pollTracks(first.nextOffset);
    expect(again.tracks, isEmpty);
  });

  test('polling also reads posts from a group, not only a channel', () async {
    fake.postAudio('g', 'In group', inGroup: true);
    fake.postAudio('c', 'In channel');

    final r = await api.pollTracks(null);

    expect(r.tracks.map((t) => t.uniqueId), ['g', 'c']);
  });

  test('polling ignores the pinned index document and other chats', () async {
    await api.publishIndex(SyncData(tracks: [track('1')]));
    fake.updates.add({
      'update_id': fake.nextUpdate++,
      'channel_post': {
        'message_id': 99,
        'date': 1,
        'chat': {'id': -555},
        'audio': {'file_id': 'x', 'file_unique_id': 'other', 'duration': 1},
      },
    });
    final r = await api.pollTracks(null);
    expect(r.tracks, isEmpty);
    expect(r.nextOffset, isNotNull, reason: 'foreign updates must still be consumed');
  });

  test('download streams the file and leaves no .part behind', () async {
    fake.postAudio('a', 'Song');
    final dir = Directory.systemTemp.createTempSync('dl_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    final target = File('${dir.path}/a');
    await api.download('file-a', target);

    expect(utf8.decode(target.readAsBytesSync()), 'audio-a');
    expect(File('${target.path}.part').existsSync(), isFalse);
  });

  test('a failed download leaves nothing that looks like a cached file', () async {
    final dir = Directory.systemTemp.createTempSync('dl_test');
    addTearDown(() => dir.deleteSync(recursive: true));

    final target = File('${dir.path}/missing');
    await expectLater(api.download('nope', target), throwsA(isA<TelegramException>()));
    expect(target.existsSync(), isFalse);
  });

  test('verifyAdmin accepts an administrator', () async {
    await api.verifyAdmin();
    expect(fake.calls, containsAll(['getMe', 'getChatMember']));
  });
}
