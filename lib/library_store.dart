import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio_tags.dart';
import 'models.dart';
import 'stats.dart';
import 'sync_data.dart';
import 'telegram_api.dart';
import 'token_store.dart';

enum StatusKind { noConnection, uploading, error }

/// Something the user should know about the sync, kept as data so the UI can
/// translate it.
class LibraryStatus {
  const LibraryStatus.noConnection() : this._(StatusKind.noConnection);
  const LibraryStatus.uploading(int current, int total, String name)
      : this._(StatusKind.uploading, current: current, total: total, name: name);
  const LibraryStatus.error(Object error) : this._(StatusKind.error, error: error);

  const LibraryStatus._(this.kind, {this.current, this.total, this.name, this.error});

  final StatusKind kind;
  final int? current;
  final int? total;
  final String? name;
  final Object? error;
}

/// Owns tracks, favorites and playlists, and keeps them in sync with the
/// pinned index in the Telegram channel.
class LibraryStore extends ChangeNotifier {
  /// [apiHost] and [autoSync] exist for tests: a fake Bot API server, and
  /// calling [refresh] by hand instead of on a timer.
  LibraryStore({this.apiHost, this.autoSync = true, this.initialVault});

  final String? apiHost;
  final bool autoSync;
  final TokenVault? initialVault;

  /// Where the bot token is kept. Built on first use, once [prefs] exists.
  late final TokenVault vault = initialVault ?? TokenVault(prefs: prefs);

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

  /// Listening logs are shared too, but they only grow, so uploading them on
  /// every few plays would be wasteful. Alone, they are pushed this rarely.
  static const historyPushInterval = Duration(minutes: 30);

  StatsStore? stats;
  String? _deviceId;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  bool _forceHistoryPush = false;

  /// Names this device's listening log in the shared index.
  String get deviceId {
    var id = _deviceId ?? prefs.getString('device_id');
    if (id == null) {
      final r = Random.secure();
      id = List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join();
      unawaited(prefs.setString('device_id', id));
    }
    return _deviceId = id;
  }

  /// Connects the listening log, so it is synced with the rest of the library.
  Future<void> attachStats(StatsStore s) async {
    stats = s;
    s.deviceId = deviceId;
    await s.applyRemote(data.history);
  }

  /// The index as last downloaded, and the version of that file, so an unchanged
  /// index is not downloaded again on every poll.
  SyncData? _remoteData;
  String? _remoteCanonical;
  String? _remoteCanonicalNoOwn;
  String? _remoteVersion;
  LibraryStatus? status;
  bool busy = false;

  List<Track>? _tracksCache;

  /// Tracks whose cover image is on disk.
  final Set<String> _coverIds = {};

  bool get configured => api != null;

  Directory get cacheDir => Directory('${dir.path}/audio');

  Directory get coversDir => Directory('${dir.path}/covers');

  File _coverFile(String uniqueId) => File('${coversDir.path}/$uniqueId.jpg');

  /// The cover image of [t], or null if it has none (or it is not downloaded yet).
  File? coverFor(Track t) => _coverIds.contains(t.uniqueId) ? _coverFile(t.uniqueId) : null;

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
    await _loadCovers();

    final token = await vault.read();
    final chat = prefs.getString('chat');
    _updateOffset = prefs.getInt('offset');
    _indexMessageId = prefs.getInt('index_msg');
    await _loadLocal();

    if (token != null && chat != null) {
      api = _newApi(token, chat);
      _startPolling();
    }
  }

  /// Sets up storage without platform plugins, so UI tests can build a
  /// library from sample data. Never connects to Telegram.
  @visibleForTesting
  Future<void> initForTest({required SharedPreferences prefs, required Directory dir}) async {
    this.prefs = prefs;
    this.dir = dir;
    await cacheDir.create(recursive: true);
    await _loadCovers();
  }

  Future<void> _loadCovers() async {
    await coversDir.create(recursive: true);
    _coverIds
      ..clear()
      ..addAll([
        for (final f in coversDir.listSync().whereType<File>())
          if (f.path.endsWith('.jpg')) f.uri.pathSegments.last.replaceFirst('.jpg', ''),
      ]);
  }

  Future<void>? _coversTask;

  /// Downloads the small cover thumbnails of tracks that have one. They are a
  /// few KB each, so this simply fetches every missing one in the background.
  /// Calling it while a run is in progress waits for that run instead of
  /// starting another.
  Future<void> syncCovers() {
    if (api == null) return Future.value();
    return _coversTask ??= _downloadCovers().whenComplete(() => _coversTask = null);
  }

  Future<void> _downloadCovers() async {
    final api = this.api;
    if (api == null) return;
    for (final t in tracks) {
      final id = t.thumbId;
      if (id == null || _coverIds.contains(t.uniqueId)) continue;
      try {
        await api.download(id, _coverFile(t.uniqueId));
        _coverIds.add(t.uniqueId);
        notifyListeners();
      } on SocketException {
        return; // offline: try again on the next sync
      } catch (_) {
        // A cover is decoration. Whatever went wrong, it must never break sync;
        // this one is retried next time.
      }
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
    final candidate = _newApi(token.trim(), chat.trim());
    await candidate.verifyAdmin();
    await vault.write(candidate.token);
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
    _remoteData = null;
    _remoteCanonical = null;
    _remoteVersion = null;
    _remoteCanonicalNoOwn = null;
    _coverIds.clear();
    if (coversDir.existsSync()) coversDir.deleteSync(recursive: true);
    await coversDir.create(recursive: true);
    await vault.delete();
    await prefs.remove('chat');
    await prefs.remove('offset');
    await prefs.remove('index_msg');
    if (await _libraryFile.exists()) await _libraryFile.delete();
    notifyListeners();
  }

  TelegramApi _newApi(String token, String chat) =>
      apiHost == null ? TelegramApi(token, chat) : TelegramApi(token, chat, host: apiHost!);

  void _startPolling() {
    if (!autoSync) return;
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
  Future<void> refresh({bool forceHistory = false}) async {
    final api = this.api;
    if (api == null) return;
    if (_syncing) {
      // An edit arrived mid-sync; run again once this pass finishes.
      _forceHistoryPush |= forceHistory;
      _pushTimer?.cancel();
      _pushTimer = Timer(const Duration(seconds: 1), refresh);
      return;
    }
    _syncing = true;
    final force = forceHistory || _forceHistoryPush;
    _forceHistoryPush = false;
    try {
      final remote = await api.fetchIndex(knownVersion: _remoteVersion);
      final polled = await api.pollTracks(_updateOffset);

      if (polled.nextOffset != null && polled.nextOffset != _updateOffset) {
        _updateOffset = polled.nextOffset;
        await prefs.setInt('offset', _updateOffset!);
      }

      final me = deviceId;
      final s = stats;
      // Our own log lives in the stats store, not in [data]; bring it along for the merge.
      var merged = s == null ? data : data.withHistory(me, s.ownHistory);

      if (remote == null) {
        _remoteData = null;
        _remoteCanonical = null;
        _remoteCanonicalNoOwn = null;
        _remoteVersion = null;
      } else {
        _indexMessageId = remote.messageId;
        _remoteVersion = remote.version;
        // A null `data` means the file is unchanged since we last downloaded it.
        if (remote.data != null) {
          _remoteData = remote.data;
          _remoteCanonical = remote.data!.canonical();
          _remoteCanonicalNoOwn = remote.data!.withoutHistory(me).canonical();
        }
        if (_remoteData != null) merged = SyncData.merge(merged, _remoteData!);
      }
      if (polled.tracks.isNotEmpty) {
        merged = SyncData.merge(merged, SyncData(tracks: polled.tracks));
      }

      if (s != null) {
        // Another device may have reset stats; take that, and the others' logs.
        await s.applyRemote(merged.history);
        merged = merged.withHistory(me, s.ownHistory);
      }

      final before = data.canonical();
      data = s == null ? merged : merged.withoutHistory(me);
      if (data.canonical() != before) {
        _tracksCache = null;
        await _saveLocal();
      }

      final nothingToShare = data.tracks.isEmpty &&
          data.playlists.isEmpty &&
          merged.history.values.every((h) => h.events.isEmpty && h.epoch == 0);
      final channelEmpty = remote == null && nothingToShare;
      if (!channelEmpty && merged.canonical() != _remoteCanonical) {
        // If only our own listening log grew, it can wait for the next real
        // change, a long enough interval, or the app going to the background.
        final onlyOwnHistory = _remoteCanonicalNoOwn != null &&
            data.canonical() == _remoteCanonicalNoOwn;
        final due = DateTime.now().difference(_lastPush) >= historyPushInterval;
        if (!onlyOwnHistory || force || due) {
          await _pushIndex(merged);
        }
      }

      status = null;
      notifyListeners();
      unawaited(syncCovers());
    } on TelegramException catch (e) {
      status = LibraryStatus.error(e);
      notifyListeners();
    } on SocketException {
      status = const LibraryStatus.noConnection();
      notifyListeners();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pushIndex(SyncData snapshot) async {
    final id = await api!.publishIndex(snapshot, previousMessageId: _indexMessageId);
    _indexMessageId = id;
    _lastPush = DateTime.now();
    // The pinned file just changed; fetch it afresh next time.
    _remoteData = null;
    _remoteCanonical = null;
    _remoteCanonicalNoOwn = null;
    _remoteVersion = null;
    await prefs.setInt('index_msg', id);
  }

  /// Wipes listening history on every device. Pushed at once, so another
  /// device cannot bring the old history back.
  Future<void> resetHistory() async {
    final s = stats;
    if (s == null) return;
    final epoch = s.nextEpoch(data.history.values);
    await s.reset(epoch);
    for (final id in data.history.keys.toList()) {
      data.history[id] = DeviceHistory(epoch, const []);
    }
    _forceHistoryPush = true;
    _changed();
  }

  // ---- tracks ----

  /// Lets the user pick audio files and uploads them to the channel.
  Future<void> pickAndUpload() async {
    if (api == null) return;
    final picked = await FilePicker.pickFiles(type: FileType.audio);
    await uploadFiles([
      for (final f in picked)
        if (f.path != null) File(f.path!),
    ]);
  }

  /// Uploads local audio files. Title, artist and cover art come from the
  /// file's own tags; the file name is only a fallback.
  Future<void> uploadFiles(List<File> files) async {
    final api = this.api;
    if (api == null || files.isEmpty) return;

    busy = true;
    notifyListeners();
    try {
      for (var i = 0; i < files.length; i++) {
        final file = files[i];
        final name = file.uri.pathSegments.last;
        status = LibraryStatus.uploading(i + 1, files.length, name);
        notifyListeners();

        final tags = await readAudioTags(file);
        final guessed = _guessTags(name);
        final track = await api.sendAudio(
          file,
          title: tags.title ?? guessed.title,
          performer: tags.artist ?? guessed.artist,
          duration: tags.durationSeconds,
          thumbnail: tags.coverJpeg,
        );

        // We already hold the bytes; seed the caches so first play and the
        // cover are instant, with no download.
        await file.copy('${cacheDir.path}/${track.uniqueId}');
        final cover = tags.coverJpeg;
        if (cover != null) {
          await _coverFile(track.uniqueId).writeAsBytes(cover);
          _coverIds.add(track.uniqueId);
        }
        data = SyncData.merge(data, SyncData(tracks: [track]));
        _changed();
      }
      status = null;
    } on TelegramException catch (e) {
      status = LibraryStatus.error(e);
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
    if (_coverIds.remove(t.uniqueId)) _coverFile(t.uniqueId).deleteSync();
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
      name: name.trim().isEmpty ? 'Playlist' : name.trim(),
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
