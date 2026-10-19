import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/sync_data.dart';
import 'package:telemusic/telegram_api.dart';

/// A tiny in-memory stand-in for the parts of the Bot API the app uses.
/// It mirrors documented behaviour (pinned_message in getChat, file_path
/// from getFile, updates consumed by offset) so sync logic can be exercised.
class FakeBotApi {
  late HttpServer server;
  final files = <String, Uint8List>{}; // file_id -> bytes
  final fileNames = <String, String>{};
  final messages = <int, Map<String, dynamic>>{};
  final updates = <Map<String, dynamic>>[];
  int? pinned;
  int nextMessage = 1;
  int nextUpdate = 100;
  final calls = <String>[];

  String get host => 'http://127.0.0.1:${server.port}';

  Future<void> start() async {
    server = await HttpServer.bind('127.0.0.1', 0);
    server.listen(_handle);
  }

  Future<void> stop() => server.close(force: true);

  /// Simulates someone posting a track in the channel.
  void postAudio(String uniqueId, String title,
      {String performer = 'Band', bool inGroup = false}) {
    final id = nextMessage++;
    final fileId = 'file-$uniqueId';
    files[fileId] = Uint8List.fromList(utf8.encode('audio-$uniqueId'));
    final msg = {
      'message_id': id,
      'date': 1700000000,
      'chat': {'id': -1001},
      'audio': {
        'file_id': fileId,
        'file_unique_id': uniqueId,
        'title': title,
        'performer': performer,
        'duration': 180,
        'file_size': 20,
      },
    };
    messages[id] = msg;
    updates.add({'update_id': nextUpdate++, inGroup ? 'message' : 'channel_post': msg});
  }

  Future<void> _handle(HttpRequest req) async {
    final path = req.uri.path;
    final bytes = await req.fold<List<int>>([], (a, b) => a..addAll(b));

    if (path.startsWith('/file/bot')) {
      final fileId = path.split('/').last;
      final data = files[fileId];
      if (data == null) {
        req.response.statusCode = 404;
      } else {
        req.response.add(data);
      }
      await req.response.close();
      return;
    }

    final method = path.split('/').last;
    calls.add(method);
    Object result;
    switch (method) {
      case 'getMe':
        result = {'id': 7, 'is_bot': true};
      case 'getChatMember':
        result = {'status': 'administrator'};
      case 'getChat':
        result = {
          'id': -1001,
          if (pinned != null) 'pinned_message': messages[pinned],
        };
      case 'getUpdates':
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final offset = body['offset'] as int? ?? 0;
        updates.removeWhere((u) => (u['update_id'] as int) < offset);
        result = List.of(updates);
      case 'sendDocument':
        final id = nextMessage++;
        final doc = _parseMultipartDocument(req.headers.contentType!, bytes);
        final fileId = 'doc-$id';
        files[fileId] = doc.bytes;
        fileNames[fileId] = doc.name;
        final msg = {
          'message_id': id,
          'date': 1700000000,
          'chat': {'id': -1001},
          'document': {
            'file_id': fileId,
            'file_unique_id': 'u-$fileId',
            'file_name': doc.name,
            'mime_type': 'application/json',
          },
        };
        messages[id] = msg;
        // The bot's own posts are not delivered as updates, like the real API.
        result = msg;
      case 'editMessageMedia':
        final fields = _parseMultipart(req.headers.contentType!, bytes);
        final id = int.parse(fields.fields['message_id']!);
        final msg = messages[id];
        if (msg == null) {
          req.response.statusCode = 400;
          req.response.write(jsonEncode(
              {'ok': false, 'description': 'Bad Request: message to edit not found'}));
          await req.response.close();
          return;
        }
        final fileId = 'doc-$id-v${calls.length}';
        files[fileId] = fields.file!.bytes;
        (msg['document'] as Map)['file_id'] = fileId;
        fileNames[fileId] = fields.file!.name;
        result = msg;
      case 'pinChatMessage':
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        pinned = body['message_id'] as int;
        result = true;
      case 'deleteMessage':
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final id = body['message_id'] as int;
        messages.remove(id);
        if (pinned == id) pinned = null;
        result = true;
      case 'getFile':
        final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
        final fileId = body['file_id'] as String;
        result = {'file_id': fileId, 'file_path': fileId};
      default:
        req.response.statusCode = 404;
        req.response.write(jsonEncode({'ok': false, 'description': 'unknown $method'}));
        await req.response.close();
        return;
    }
    req.response.headers.contentType = ContentType.json;
    req.response.write(jsonEncode({'ok': true, 'result': result}));
    await req.response.close();
  }

  ({String name, Uint8List bytes}) _parseMultipartDocument(ContentType ct, List<int> body) =>
      _parseMultipart(ct, body).file!;

  ({Map<String, String> fields, ({String name, Uint8List bytes})? file}) _parseMultipart(
      ContentType ct, List<int> body) {
    final boundary = '--${ct.parameters['boundary']}';
    final fields = <String, String>{};
    ({String name, Uint8List bytes})? file;
    for (final part in latin1.decode(body).split(boundary)) {
      final head = RegExp(r'name="([^"]+)"').firstMatch(part);
      if (head == null) continue;
      final start = part.indexOf('\r\n\r\n') + 4;
      final end = part.lastIndexOf('\r\n');
      final value = part.substring(start, end);
      final fname = RegExp(r'filename="([^"]+)"').firstMatch(part);
      if (fname != null) {
        file = (name: fname.group(1)!, bytes: Uint8List.fromList(latin1.encode(value)));
      } else {
        fields[head.group(1)!] = value;
      }
    }
    return (fields: fields, file: file);
  }
}

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
    expect(fetched.data.canonical(), data.canonical());
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
    expect((await api.fetchIndex())!.data.tracks.length, 2);
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
    expect((await api.fetchIndex())!.data.tracks.length, 2);
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
