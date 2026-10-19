import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'sync_data.dart';
import 'telegram_api.dart';

/// Owns tracks, favorites and playlists, and keeps them in sync with the
/// pinned index in the Telegram channel.
class LibraryStore extends ChangeNotifier {
  static const _pollInterval = Duration(seconds: 20);

  /// Edits are batched so toggling a few hearts is one upload, not several.
  static const _pushDelay = Duration(seconds: 4);

  late final SharedPreferences prefs;
  late final Directory dir;
  Timer? _pollTimer;
  Timer? _pushTimer;
  bool _syncing = false;

  TelegramApi? api;
  SyncData data = SyncData();
  int? _updateOffset;
  int? _indexMessageId;
  String? status;
  bool busy = false;

  List<Track>? _tracksCache;

  bool get configured => api != null;

  Directory get cacheDir => Directory('${dir.path}/audio');

  /// Oldest first; UI sorts further as needed.
  List<Track> get tracks => _tracksCache ??= data.sortedTracks;

  Map<String, Track> get trackById => data.tracks;

  Set<String> get favoriteIds => {
        for (final e in data.favorites.entries)
          if (e.value.on && data.tracks.containsKey(e.key)) e.key
      };

  List<Playlist> get playlists => [
        for (final p in data.playlists.values)
          if (!p.deleted) p
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  bool isFavorite(Track t) => data.favorites[t.uniqueId]?.on ?? false;

  Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    dir = await getApplicationSupportDirectory();
    await cacheDir.create(recursive: true);

    final token = prefs.getString('token');
    final chat = prefs.getString('chat');
    _updateOffset = prefs.getInt('offset');
    _indexMessageId = prefs.getInt('index_msg');
    await _loadLocal();

    if (token != null && chat != null) {
      api = TelegramApi(token, chat);
      _startPolling();
    }
  }

  File get _libraryFile => File('${dir.path}/library.json');

  Future<void> _loadLocal() async {
    if (!await _libraryFile.exists()) return;
    try {
      final json = jsonDecode(await _libraryFile.readAsString());
      data = json is List
          // Pre-playlist builds stored a bare list of tracks.
          ? SyncData(tracks: [for (final t in json) Track.fromJson(t as Map<String, dynamic>)])
          : SyncData.fromJson(json as Map<String, dynamic>);
    } catch (_) {
      data = SyncData();
    }
    _tracksCache = null;
  }

  Future<void> _saveLocal() => _libraryFile.writeAsString(data.canonical());

  /// Validates the credentials and, if they work, stores them.
  Future<void> connect(String token, String chat) async {
    final candidate = TelegramApi(token.trim(), chat.trim());
    await candidate.verifyAdmin();
    await prefs.setString('token', candidate.token);
    await prefs.setString('chat', candidate.chatId);
    api = candidate;
    notifyListeners();
    _startPolling();
  }

  Future<void> disconnect() async {
    _pollTimer?.cancel();
    _pushTimer?.cancel();
    api = null;
    data = SyncData();
    _tracksCache = null;
    _updateOffset = null;
    _indexMessageId = null;
    await prefs.remove('token');
    await prefs.remove('chat');
    await prefs.remove('offset');
    await prefs.remove('index_msg');
    if (await _libraryFile.exists()) await _libraryFile.delete();
    notifyListeners();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    refresh();
    _pollTimer = Timer.periodic(_pollInterval, (_) => refresh());
  }

  /// Applies a local edit: persist, tell the UI, and schedule an upload.
  void _changed() {
    _tracksCache = null;
    notifyListeners();
    unawaited(_saveLocal());
    _pushTimer?.cancel();
    _pushTimer = Timer(_pushDelay, refresh);
  }

  /// Merges the remote index and new channel posts into local data, then
  /// uploads if the result differs from what the channel holds.
  ///
  /// Several devices may share one bot. getUpdates is called with timeout=0,
  /// so they never hold competing long polls; whichever device sees a post
  /// first publishes it through the index and the others pick it up there.
  Future<void> refresh() async {
    final api = this.api;
    if (api == null) return;
    if (_syncing) {
      // An edit arrived mid-sync; run again once this pass finishes.
      _pushTimer?.cancel();
      _pushTimer = Timer(const Duration(seconds: 1), refresh);
      return;
    }
    _syncing = true;
    try {
      final remote = await api.fetchIndex();
      final polled = await api.pollTracks(_updateOffset);

      if (polled.nextOffset != null && polled.nextOffset != _updateOffset) {
        _updateOffset = polled.nextOffset;
        await prefs.setInt('offset', _updateOffset!);
      }

      var merged = data;
      if (remote != null) {
        _indexMessageId = remote.messageId;
        merged = SyncData.merge(merged, remote.data);
      }
      if (polled.tracks.isNotEmpty) {
        merged = SyncData.merge(merged, SyncData(tracks: polled.tracks));
      }

      final before = data.canonical();
      data = merged;
      final after = merged.canonical();
      if (after != before) {
        _tracksCache = null;
        await _saveLocal();
      }

      final remoteCanonical = remote?.data.canonical();
      final channelEmpty = remote == null && data.tracks.isEmpty && data.playlists.isEmpty;
      if (!channelEmpty && after != remoteCanonical) {
        await _pushIndex();
      }

        status = null;
      notifyListeners();
    } on TelegramException catch (e) {
      status = e.message;
      notifyListeners();
    } on SocketException {
      status = 'Нет соединения';
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushIndex() async {
    final id = await api!.publishIndex(data, previousMessageId: _indexMessageId);
    _indexMessageId = id;
    await prefs.setInt('index_msg', id);
  }

  // ---- tracks ----

  /// Lets the user pick audio files and uploads them to the channel.
  Future<void> pickAndUpload() async {
    final api = this.api;
    if (api == null) return;
    final picked = await FilePicker.pickFiles(type: FileType.audio);
    if (picked.isEmpty) return;

    busy = true;
    notifyListeners();
    try {
      var n = 0;
      for (final f in picked) {
        final path = f.path;
        if (path == null) continue;
        n++;
        status = 'Загрузка $n/${picked.length}: ${f.name}';
        notifyListeners();

        final parts = _guessTags(f.name);
        final track = await api.sendAudio(
          File(path),
          title: parts.title,
          performer: parts.artist,
        );
        // We already hold the bytes; seed the cache so first play is instant.
        await File(path).copy('${cacheDir.path}/${track.uniqueId}');
        data = SyncData.merge(data, SyncData(tracks: [track]));
        _changed();
      }
      status = null;
    } on TelegramException catch (e) {
      status = e.message;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// "Artist - Title.mp3" -> (Artist, Title); otherwise the file name is the title.
  ({String artist, String title}) _guessTags(String fileName) {
    final base = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final m = RegExp(r'^(.+?)\s+[-–—]\s+(.+)$').firstMatch(base);
    if (m == null) return (artist: '', title: base);
    return (artist: m.group(1)!, title: m.group(2)!);
  }

  /// Removes a track from the library on every device and from the channel.
  Future<void> removeTrack(Track t) async {
    data.tracks.remove(t.uniqueId);
    data.removed[t.uniqueId] = DateTime.now().millisecondsSinceEpoch;
    final f = cachedFile(t);
    if (f.existsSync()) f.deleteSync();
    _changed();
    final id = t.messageId;
    if (id != null) await api?.deleteMessage(id);
  }

  File cachedFile(Track t) => File('${cacheDir.path}/${t.uniqueId}');

  // ---- favorites ----

  void toggleFavorite(Track t) {
    data.favorites[t.uniqueId] =
        Fav(!isFavorite(t), DateTime.now().millisecondsSinceEpoch);
    _changed();
  }

  // ---- playlists ----

  Playlist createPlaylist(String name, {List<String> trackIds = const []}) {
    final now = DateTime.now();
    final p = Playlist(
      id: now.microsecondsSinceEpoch.toRadixString(36),
      name: name.trim().isEmpty ? 'Плейлист' : name.trim(),
      trackIds: [...trackIds],
      updatedAt: now.millisecondsSinceEpoch,
    );
    data.playlists[p.id] = p;
    _changed();
    return p;
  }

  void _edit(Playlist p, void Function() change) {
    change();
    p.updatedAt = DateTime.now().millisecondsSinceEpoch;
    _changed();
  }

  void renamePlaylist(Playlist p, String name) {
    if (name.trim().isEmpty) return;
    _edit(p, () => p.name = name.trim());
  }

  void deletePlaylist(Playlist p) => _edit(p, () => p.deleted = true);

  void setPlaylistOffline(Playlist p, bool offline) =>
      _edit(p, () => p.offline = offline);

  void addToPlaylist(Playlist p, Track t) {
    if (p.trackIds.contains(t.uniqueId)) return;
    _edit(p, () => p.trackIds = [...p.trackIds, t.uniqueId]);
  }

  void removeFromPlaylist(Playlist p, Track t) =>
      _edit(p, () => p.trackIds = [...p.trackIds]..remove(t.uniqueId));

  void reorderPlaylist(Playlist p, int from, int to) {
    final ids = [...p.trackIds];
    ids.insert(to, ids.removeAt(from));
    _edit(p, () => p.trackIds = ids);
  }

  /// Tracks of a playlist in order, skipping ones that were removed.
  List<Track> playlistTracks(Playlist p) => [
        for (final id in p.trackIds)
          if (data.tracks[id] != null) data.tracks[id]!
      ];

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pushTimer?.cancel();
    super.dispose();
  }
}
