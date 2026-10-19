import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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
  int nextEdit = 1;
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
      case 'sendAudio':
        final id = nextMessage++;
        final parts = _parseMultipart(req.headers.contentType!, bytes);
        final audio = parts.files['audio']!;
        final fileId = 'audio-$id';
        files[fileId] = audio.bytes;
        final thumbPart = parts.files['cover'];
        final thumbId = thumbPart == null ? null : 'thumb-$id';
        if (thumbId != null) files[thumbId] = thumbPart!.bytes;
        final msg = {
          'message_id': id,
          'date': 1700000000 + id,
          'chat': {'id': -1001},
          'audio': {
            'file_id': fileId,
            'file_unique_id': 'u-$fileId',
            'file_name': audio.name,
            'title': parts.fields['title'],
            'performer': parts.fields['performer'],
            'duration': int.tryParse(parts.fields['duration'] ?? '') ?? 0,
            'file_size': audio.bytes.length,
            if (thumbId != null)
              'thumbnail': {'file_id': thumbId, 'file_unique_id': 'u-$thumbId', 'width': 90, 'height': 90},
          },
        };
        messages[id] = msg;
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
        files[fileId] = fields.files.values.first.bytes;
        (msg['document'] as Map)['file_id'] = fileId;
        msg['edit_date'] = 1700000000 + nextEdit++;
        fileNames[fileId] = fields.files.values.first.name;
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
      _parseMultipart(ct, body).files['document']!;

  ({Map<String, String> fields, Map<String, ({String name, Uint8List bytes})> files}) _parseMultipart(
      ContentType ct, List<int> body) {
    final boundary = '--${ct.parameters['boundary']}';
    final fields = <String, String>{};
    final files = <String, ({String name, Uint8List bytes})>{};
    for (final part in latin1.decode(body).split(boundary)) {
      final head = RegExp(r'name="([^"]+)"').firstMatch(part);
      if (head == null) continue;
      final start = part.indexOf('\r\n\r\n') + 4;
      final end = part.lastIndexOf('\r\n');
      final value = part.substring(start, end);
      final fname = RegExp(r'filename="([^"]+)"').firstMatch(part);
      if (fname != null) {
        files[head.group(1)!] = (name: fname.group(1)!, bytes: Uint8List.fromList(latin1.encode(value)));
      } else {
        fields[head.group(1)!] = value;
      }
    }
    return (fields: fields, files: files);
  }
}
