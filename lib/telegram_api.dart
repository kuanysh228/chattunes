import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'sync_data.dart';

enum TelegramErrorKind { api, notAdmin, fileUnavailable, fileTooBig, downloadFailed }

/// A failed Telegram call. [kind] lets the UI show a translated message;
/// [message] is an English fallback and, for [TelegramErrorKind.api], the
/// description Telegram itself returned.
class TelegramException implements Exception {
  TelegramException(this.message, {this.kind = TelegramErrorKind.api, this.code});

  final String message;
  final TelegramErrorKind kind;

  /// HTTP status for [TelegramErrorKind.downloadFailed].
  final int? code;

  @override
  String toString() => message;
}

/// Thin wrapper over the parts of the Bot API the player needs.
class TelegramApi {
  TelegramApi(this.token, this.chatId, {this.host = 'https://api.telegram.org'});

  final String token;
  final String chatId;

  /// Overridable so tests can talk to a local fake server.
  final String host;
  static const indexFileName = 'telemusic_library.json';

  /// Bot API refuses to serve files larger than this through getFile.
  static const downloadLimit = 20 * 1024 * 1024;

  Uri _method(String name) => Uri.parse('$host/bot$token/$name');

  Future<dynamic> _call(String name, [Map<String, dynamic>? params]) async {
    final res = await http.post(
      _method(name),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(params ?? {}),
    );
    return _unwrap(res.body);
  }

  dynamic _unwrap(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['ok'] != true) {
      throw TelegramException(json['description'] as String? ?? 'Telegram error');
    }
    return json['result'];
  }

  Future<Map<String, dynamic>> getMe() async =>
      (await _call('getMe')) as Map<String, dynamic>;

  Future<Map<String, dynamic>> getChat() async =>
      (await _call('getChat', {'chat_id': chatId})) as Map<String, dynamic>;

  /// Checks that the bot can post, pin and delete in the channel.
  Future<void> verifyAdmin() async {
    final me = await getMe();
    final member = await _call('getChatMember', {
      'chat_id': chatId,
      'user_id': me['id'],
    }) as Map<String, dynamic>;
    if (member['status'] != 'administrator' && member['status'] != 'creator') {
      throw TelegramException('The bot must be an administrator of the chat',
          kind: TelegramErrorKind.notAdmin);
    }
  }

  /// Returns channel posts that carry audio. Advances [offset] past everything seen.
  Future<({List<Track> tracks, int? nextOffset})> pollTracks(int? offset) async {
    final result = await _call('getUpdates', {
      'offset': ?offset,
      'timeout': 0,
      // Channels deliver posts as channel_post, groups and supergroups as message.
      'allowed_updates': ['channel_post', 'message'],
    }) as List;

    final tracks = <Track>[];
    int? next = offset;
    for (final u in result) {
      final update = u as Map<String, dynamic>;
      next = (update['update_id'] as int) + 1;
      final post = (update['channel_post'] ?? update['message']) as Map<String, dynamic>?;
      if (post == null || '${(post['chat'] as Map)['id']}' != await _resolvedChatId()) {
        continue;
      }
      final audio = post['audio'] as Map<String, dynamic>?;
      final doc = post['document'] as Map<String, dynamic>?;
      final messageId = post['message_id'] as int;
      final postedAt = (post['date'] as int) * 1000;
      if (audio != null) {
        tracks.add(Track.fromMedia(audio, messageId: messageId, addedAt: postedAt));
      } else if (doc != null &&
          ((doc['mime_type'] as String?) ?? '').startsWith('audio/')) {
        tracks.add(Track.fromMedia(doc, messageId: messageId, addedAt: postedAt));
      }
    }
    return (tracks: tracks, nextOffset: next);
  }

  String? _numericId;

  Future<String> _resolvedChatId() async {
    return _numericId ??= '${(await getChat())['id']}';
  }

  /// Uploads a local audio file to the channel and returns the stored track.
  Future<Track> sendAudio(
    File file, {
    String? title,
    String? performer,
    int? duration,
    Uint8List? thumbnail,
  }) async {
    final req = http.MultipartRequest('POST', _method('sendAudio'))
      ..fields['chat_id'] = chatId
      ..fields['disable_notification'] = 'true'
      ..files.add(await http.MultipartFile.fromPath('audio', file.path));
    if (duration != null && duration > 0) req.fields['duration'] = '$duration';
    if (thumbnail != null) {
      // Telegram wants a thumbnail as a separate upload, referenced by name.
      req.fields['thumbnail'] = 'attach://cover';
      req.files.add(http.MultipartFile.fromBytes('cover', thumbnail, filename: 'cover.jpg'));
    }
    if (title != null && title.isNotEmpty) req.fields['title'] = title;
    if (performer != null && performer.isNotEmpty) req.fields['performer'] = performer;
    final res = await http.Response.fromStream(await req.send());
    final msg = _unwrap(res.body) as Map<String, dynamic>;
    final audio = (msg['audio'] ?? msg['document']) as Map<String, dynamic>;
    return Track.fromMedia(audio, messageId: msg['message_id'] as int);
  }

  /// Removes a channel post. Silent if it is already gone, because the
  /// library entry is what matters.
  Future<void> deleteMessage(int messageId) async {
    try {
      await _call('deleteMessage', {'chat_id': chatId, 'message_id': messageId});
    } on TelegramException {
      // Nothing useful to do; the track is removed from the index regardless.
    }
  }

  /// Resolves a file_id to a downloadable URL.
  Future<Uri> fileUrl(String fileId) async {
    final file = await _call('getFile', {'file_id': fileId}) as Map<String, dynamic>;
    final path = file['file_path'] as String?;
    if (path == null) throw TelegramException('File unavailable', kind: TelegramErrorKind.fileUnavailable);
    return Uri.parse('$host/file/bot$token/$path');
  }

  /// Streams a file to [target]. Writes to a temp name first so a half-downloaded
  /// file is never mistaken for a cached one.
  Future<void> download(String fileId, File target) async {
    final url = await fileUrl(fileId);
    final client = http.Client();
    try {
      final res = await client.send(http.Request('GET', url));
      if (res.statusCode != 200) {
        throw TelegramException('Download failed (${res.statusCode})',
            kind: TelegramErrorKind.downloadFailed, code: res.statusCode);
      }
      final tmp = File('${target.path}.part');
      final sink = tmp.openWrite();
      try {
        await res.stream.pipe(sink);
      } catch (_) {
        await sink.close();
        if (await tmp.exists()) await tmp.delete();
        rethrow;
      }
      await tmp.rename(target.path);
    } finally {
      client.close();
    }
  }

  // ---- library index, stored as a pinned JSON document in the channel ----

  /// Reads the pinned index. Returns null if the channel has none yet.
  ///
  /// Every edit of the pinned message changes at least one of its file id,
  /// file unique id and edit time. If their combination still equals
  /// [knownVersion], the download is skipped and `data` is null, which means
  /// "same as last time".
  Future<({SyncData? data, int messageId, String version})?> fetchIndex({
    String? knownVersion,
  }) async {
    final chat = await getChat();
    final pinned = chat['pinned_message'] as Map<String, dynamic>?;
    final doc = pinned?['document'] as Map<String, dynamic>?;
    if (pinned == null || doc == null || doc['file_name'] != indexFileName) {
      return null;
    }
    final messageId = pinned['message_id'] as int;
    final version = '${doc['file_id']}|${doc['file_unique_id']}|'
        '${pinned['edit_date'] ?? pinned['date']}';
    if (version == knownVersion) {
      return (data: null, messageId: messageId, version: version);
    }
    final url = await fileUrl(doc['file_id'] as String);
    final res = await http.get(url);
    if (res.statusCode != 200) return null;
    return (
      data: SyncData.fromJson(
          jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>),
      messageId: messageId,
      version: version,
    );
  }

  /// Publishes the index. The pinned message is edited in place when possible:
  /// re-pinning would leave a "pinned a message" service post in groups on
  /// every sync. Falls back to send + pin + delete if the old one is gone.
  Future<int> publishIndex(SyncData data, {int? previousMessageId}) async {
    final bytes = utf8.encode(data.canonical());

    if (previousMessageId != null && await _editIndex(previousMessageId, bytes)) {
      return previousMessageId;
    }

    final req = http.MultipartRequest('POST', _method('sendDocument'))
      ..fields['chat_id'] = chatId
      ..fields['disable_notification'] = 'true'
      ..files.add(http.MultipartFile.fromBytes('document', bytes,
          filename: indexFileName));
    final res = await http.Response.fromStream(await req.send());
    final msg = _unwrap(res.body) as Map<String, dynamic>;
    final id = msg['message_id'] as int;

    await _call('pinChatMessage', {
      'chat_id': chatId,
      'message_id': id,
      'disable_notification': true,
    });
    if (previousMessageId != null && previousMessageId != id) {
      await deleteMessage(previousMessageId);
    }
    return id;
  }

  /// Swaps the document inside an existing message. False if Telegram refuses
  /// (message deleted, not ours, or content identical).
  Future<bool> _editIndex(int messageId, List<int> bytes) async {
    final req = http.MultipartRequest('POST', _method('editMessageMedia'))
      ..fields['chat_id'] = chatId
      ..fields['message_id'] = '$messageId'
      ..fields['media'] = jsonEncode({'type': 'document', 'media': 'attach://index'})
      ..files.add(http.MultipartFile.fromBytes('index', bytes, filename: indexFileName));
    final res = await http.Response.fromStream(await req.send());
    try {
      _unwrap(res.body);
      return true;
    } on TelegramException {
      return false;
    }
  }
}
