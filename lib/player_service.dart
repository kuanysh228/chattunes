import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import 'cache_manager.dart';
import 'library_store.dart';
import 'models.dart';
import 'recommender.dart';
import 'settings.dart';
import 'stats.dart';
import 'telegram_api.dart';

enum QueueRepeat { off, all, one }

/// Time spent on one track since it started, used to build a [PlayEvent].
class _Listen {
  _Listen(this.track) : startedAt = DateTime.now().millisecondsSinceEpoch;

  final Track track;
  final int startedAt;
  final Stopwatch watch = Stopwatch();
}

/// Queue, playback, caching and listening log in one place, because they all
/// react to the same events (track changed, skipped, finished).
class PlayerService extends ChangeNotifier {
  PlayerService(this.library, this.stats, this.settings)
      : cache = CacheManager(library.cacheDir) {
    _player.playerStateStream.listen(_onPlayerState);
    library.addListener(_scheduleOffline);
    settings.addListener(_scheduleOffline);
  }

  final LibraryStore library;
  final StatsStore stats;
  final AppSettings settings;
  final CacheManager cache;
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Future<File>> _inflight = {};
  final Map<String, String> errors = {};
  final Random _random = Random();

  List<Track> queue = [];
  List<Track> _original = [];
  int index = -1;
  bool shuffle = false;
  QueueRepeat repeat = QueueRepeat.off;
  bool loading = false;

  _Listen? _listen;
  int _token = 0;
  int _completedToken = -1;
  Timer? _offlineTimer;
  bool _offlineRunning = false;

  AudioPlayer get player => _player;
  bool get playing => _player.playing;
  Track? get current => index >= 0 && index < queue.length ? queue[index] : null;

  bool isCached(Track t) => library.cachedFile(t).existsSync();
  bool isDownloading(Track t) => _inflight.containsKey(t.uniqueId);

  // ---- downloading ----

  Future<File> _ensureCached(Track t) {
    final file = library.cachedFile(t);
    if (file.existsSync()) return Future.value(file);

    return _inflight.putIfAbsent(t.uniqueId, () async {
      notifyListeners();
      try {
        if ((t.size ?? 0) > TelegramApi.downloadLimit) {
          throw TelegramException('Файл больше 20 МБ, Bot API не отдаст его');
        }
        await library.api!.download(t.fileId, file);
        errors.remove(t.uniqueId);
        cache.evict(
          limitBytes: settings.cacheLimitBytes,
          protectedIds: protectedIds(),
        );
        return file;
      } catch (e) {
        errors[t.uniqueId] = '$e';
        rethrow;
      } finally {
        _inflight.remove(t.uniqueId);
        notifyListeners();
      }
    });
  }

  /// Tracks that must survive cache eviction: what is playing or about to,
  /// plus anything the user asked to keep offline.
  Set<String> protectedIds() {
    final ids = <String>{};
    final cur = current;
    if (cur != null) ids.add(cur.uniqueId);
    for (var k = 1; k <= settings.prefetchCount; k++) {
      if (index + k < queue.length) ids.add(queue[index + k].uniqueId);
    }
    ids.addAll(_offlineTargets().map((t) => t.uniqueId));
    return ids;
  }

  List<Track> _offlineTargets() {
    final out = <String, Track>{};
    if (settings.favoritesOffline) {
      for (final id in library.favoriteIds) {
        final t = library.trackById[id];
        if (t != null) out[id] = t;
      }
    }
    for (final p in library.playlists) {
      if (!p.offline) continue;
      for (final t in library.playlistTracks(p)) {
        out[t.uniqueId] = t;
      }
    }
    return out.values.toList();
  }

  void _scheduleOffline() {
    _offlineTimer?.cancel();
    _offlineTimer = Timer(const Duration(seconds: 3), ensureOffline);
  }

  /// Downloads favorites / offline playlists one at a time, in the background.
  Future<void> ensureOffline() async {
    if (_offlineRunning || library.api == null) return;
    _offlineRunning = true;
    try {
      for (final t in _offlineTargets()) {
        if (isCached(t) || errors.containsKey(t.uniqueId)) continue;
        try {
          await _ensureCached(t);
        } catch (_) {
          // Recorded in [errors]; one bad file must not stop the rest.
        }
      }
    } finally {
      _offlineRunning = false;
    }
  }

  void _prefetch() {
    if (index < 0 || repeat == QueueRepeat.one) return;
    _extendIfNeeded();
    for (var k = 1; k <= settings.prefetchCount; k++) {
      var i = index + k;
      if (i >= queue.length) {
        if (repeat != QueueRepeat.all || queue.isEmpty) break;
        i %= queue.length;
      }
      // Failures are recorded in [errors]; prefetch must never throw.
      _ensureCached(queue[i]).then((_) {}, onError: (_) {});
    }
  }

  // ---- queue ----

  /// Replaces the queue with [tracks] and starts at [start].
  Future<void> playContext(List<Track> tracks, int start, {bool? shuffleOn}) async {
    if (tracks.isEmpty) return;
    await _finishListen(completed: false);
    if (shuffleOn != null) shuffle = shuffleOn;
    _original = List.of(tracks);
    queue = List.of(tracks);
    index = start.clamp(0, tracks.length - 1);
    if (shuffle) _reshuffleRest();
    await _startCurrent();
  }

  /// Keeps the current track first and shuffles everything after it.
  void _reshuffleRest() {
    final cur = current;
    if (cur == null) return;
    final rest = [
      for (final t in _original)
        if (t.uniqueId != cur.uniqueId) t
    ]..shuffle(_random);
    queue = [cur, ...rest];
    index = 0;
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    final cur = current;
    if (cur != null) {
      if (shuffle) {
        _reshuffleRest();
      } else {
        queue = List.of(_original);
        index = max(0, queue.indexWhere((t) => t.uniqueId == cur.uniqueId));
      }
      _prefetch();
    }
    notifyListeners();
  }

  void cycleRepeat() {
    repeat = QueueRepeat.values[(repeat.index + 1) % QueueRepeat.values.length];
    notifyListeners();
  }

  void playNext(Track t) {
    if (current == null) {
      playContext([t], 0);
      return;
    }
    queue.insert(index + 1, t);
    _original.add(t);
    _prefetch();
    notifyListeners();
  }

  void addToQueue(Track t) {
    if (current == null) {
      playContext([t], 0);
      return;
    }
    queue.add(t);
    _original.add(t);
    notifyListeners();
  }

  void removeFromQueue(int i) {
    if (i == index || i < 0 || i >= queue.length) return;
    queue.removeAt(i);
    if (i < index) index--;
    notifyListeners();
  }

  void reorderQueue(int from, int to) {
    final cur = current;
    queue.insert(to, queue.removeAt(from));
    if (cur != null) index = queue.indexOf(cur);
    notifyListeners();
  }

  Future<void> jumpTo(int i) async {
    if (i < 0 || i >= queue.length || i == index) return;
    await _finishListen(completed: false);
    index = i;
    await _startCurrent();
  }

  /// Appends recommended tracks when the queue is about to run dry.
  void _extendIfNeeded() {
    if (!settings.autoplay || repeat != QueueRepeat.off) return;
    final cur = current;
    if (cur == null || index + 1 < queue.length) return;

    final rec = Recommender(
      tracks: library.tracks,
      events: stats.events,
      favorites: library.favoriteIds,
    );
    final inQueue = {for (final t in queue) t.uniqueId};
    final more = rec.radio(cur, limit: 10, exclude: inQueue);
    if (more.isEmpty) return;
    queue.addAll(more.map((r) => r.track));
    notifyListeners();
  }

  // ---- playback ----

  Future<void> _startCurrent() async {
    final t = current;
    if (t == null) return;
    final token = ++_token;
    loading = true;
    notifyListeners();
    try {
      final file = await _ensureCached(t);
      // The user may have picked another track while this one downloaded.
      if (token != _token) return;
      try {
        // Touch for LRU eviction; harmless if the filesystem refuses.
        file.setLastModifiedSync(DateTime.now());
      } on FileSystemException {
        // Not essential.
      }
      await _player.setFilePath(file.path);
      if (token != _token) return;
      loading = false;
      _listen = _Listen(t);
      notifyListeners();
      unawaited(_player.play());
      _syncWatch();
      _prefetch();
    } catch (_) {
      if (token == _token) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void _onPlayerState(PlayerState s) {
    _syncWatch();
    if (s.processingState == ProcessingState.completed && _completedToken != _token) {
      // The stream can emit "completed" repeatedly; advance once per track.
      _completedToken = _token;
      unawaited(_onCompleted());
    }
    notifyListeners();
  }

  void _syncWatch() {
    final w = _listen?.watch;
    if (w == null) return;
    if (_player.playing && !w.isRunning) w.start();
    if (!_player.playing && w.isRunning) w.stop();
  }

  Future<void> _onCompleted() async {
    await _finishListen(completed: true);
    if (repeat == QueueRepeat.one) {
      await _player.seek(Duration.zero);
      _listen = _Listen(current!);
      _completedToken = -1;
      unawaited(_player.play());
      _syncWatch();
      return;
    }
    await _advance();
  }

  /// Moves to the next queue item (or wraps / extends / stops at the end).
  Future<void> _advance() async {
    if (index + 1 >= queue.length) {
      if (repeat == QueueRepeat.all && queue.isNotEmpty) {
        index = 0;
        await _startCurrent();
        return;
      }
      _extendIfNeeded();
    }
    if (index + 1 < queue.length) {
      index++;
      await _startCurrent();
    } else {
      notifyListeners();
    }
  }

  Future<void> next() async {
    await _finishListen(completed: false);
    await _advance();
  }

  Future<void> previous() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    if (index > 0) {
      await _finishListen(completed: false);
      index--;
      await _startCurrent();
    }
  }

  Future<void> toggle() async {
    if (current == null) {
      final all = library.tracks.reversed.toList();
      if (all.isNotEmpty) await playContext(all, 0);
      return;
    }
    _player.playing ? await _player.pause() : await _player.play();
    notifyListeners();
  }

  Future<void> seek(Duration d) => _player.seek(d);

  Future<void> _finishListen({required bool completed}) async {
    final l = _listen;
    _listen = null;
    if (l == null) return;
    l.watch.stop();
    final ms = l.watch.elapsedMilliseconds;
    // Sub-second blips are accidental taps, not listening.
    if (ms < 1000 && !completed) return;
    await stats.record(PlayEvent(
      trackId: l.track.uniqueId,
      at: l.startedAt,
      listenedMs: ms,
      durationMs: l.track.duration * 1000,
      completed: completed,
    ));
  }

  @override
  void dispose() {
    _offlineTimer?.cancel();
    library.removeListener(_scheduleOffline);
    settings.removeListener(_scheduleOffline);
    unawaited(_finishListen(completed: false));
    _player.dispose();
    super.dispose();
  }
}
