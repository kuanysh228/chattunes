import 'dart:collection';
import 'dart:convert';

import 'models.dart';

/// Everything that is shared between devices through the pinned channel index.
///
/// Merging is last-writer-wins per entity, so two devices that edited offline
/// converge without a server deciding anything.
class SyncData {
  SyncData({
    Iterable<Track> tracks = const [],
    Map<String, int>? removed,
    Map<String, Fav>? favorites,
    Map<String, Playlist>? playlists,
    Map<String, DeviceHistory>? history,
  })  : tracks = {for (final t in tracks) t.uniqueId: t},
        removed = removed ?? {},
        favorites = favorites ?? {},
        playlists = playlists ?? {},
        history = history ?? {};

  final Map<String, Track> tracks;

  /// uniqueId -> when the track was removed. A later re-upload wins over it.
  final Map<String, int> removed;
  final Map<String, Fav> favorites;
  final Map<String, Playlist> playlists;

  /// Listening logs by device id.
  final Map<String, DeviceHistory> history;

  /// Devices with nothing to say (no events, never reset) are left out of the file.
  Map<String, DeviceHistory> get _sharedHistory => {
        for (final e in history.entries)
          if (e.value.events.isNotEmpty || e.value.epoch > 0) e.key: e.value,
      };

  List<Track> get sortedTracks => tracks.values.toList()
    ..sort((a, b) {
      final c = a.addedAt.compareTo(b.addedAt);
      return c != 0 ? c : a.uniqueId.compareTo(b.uniqueId);
    });

  static SyncData merge(SyncData a, SyncData b) {
    final removed = {...a.removed};
    b.removed.forEach((id, at) {
      final mine = removed[id];
      if (mine == null || at > mine) removed[id] = at;
    });

    final tracks = <String, Track>{};
    for (final t in [...a.tracks.values, ...b.tracks.values]) {
      final prev = tracks[t.uniqueId];
      if (prev == null || t.addedAt > prev.addedAt) tracks[t.uniqueId] = t;
    }
    tracks.removeWhere((id, t) {
      final at = removed[id];
      return at != null && t.addedAt <= at;
    });

    final favorites = {...a.favorites};
    b.favorites.forEach((id, f) {
      final mine = favorites[id];
      if (mine == null || f.at > mine.at) favorites[id] = f;
    });

    final playlists = {...a.playlists};
    b.playlists.forEach((id, p) {
      final mine = playlists[id];
      if (mine == null || p.updatedAt > mine.updatedAt) playlists[id] = p;
    });

    final history = {...a.history};
    b.history.forEach((id, h) {
      final mine = history[id];
      if (mine == null ||
          h.epoch > mine.epoch ||
          (h.epoch == mine.epoch && h.events.length > mine.events.length)) {
        history[id] = h;
      }
    });

    return SyncData(
      tracks: tracks.values,
      removed: removed,
      favorites: favorites,
      playlists: playlists,
      history: history,
    );
  }

  /// A copy with [deviceId]'s history set to [h]. Everything else is shared.
  SyncData withHistory(String deviceId, DeviceHistory h) => SyncData(
        tracks: tracks.values,
        removed: removed,
        favorites: favorites,
        playlists: playlists,
        history: {...history, deviceId: h},
      );

  /// A copy without [deviceId]'s history.
  SyncData withoutHistory(String deviceId) => SyncData(
        tracks: tracks.values,
        removed: removed,
        favorites: favorites,
        playlists: playlists,
        history: {...history}..remove(deviceId),
      );

  Map<String, dynamic> toJson() => {
        'version': 2,
        'tracks': [for (final t in sortedTracks) t.toJson()],
        'removed': SplayTreeMap<String, int>.of(removed),
        'favorites': SplayTreeMap<String, dynamic>.of(
            {for (final e in favorites.entries) e.key: e.value.toJson()}),
        'playlists': SplayTreeMap<String, dynamic>.of(
            {for (final e in playlists.entries) e.key: e.value.toJson()}),
        if (_sharedHistory.isNotEmpty)
          'history': SplayTreeMap<String, dynamic>.of(
              {for (final e in _sharedHistory.entries) e.key: e.value.toJson()}),
      };

  /// Deterministic encoding: equal data always produces equal strings.
  String canonical() => jsonEncode(toJson());

  /// Accepts the current format and the v1 index (a bare `tracks` list).
  factory SyncData.fromJson(Map<String, dynamic> j) {
    return SyncData(
      tracks: [
        for (final t in (j['tracks'] as List? ?? []))
          Track.fromJson(t as Map<String, dynamic>)
      ],
      removed: {
        for (final e in ((j['removed'] as Map?) ?? {}).entries)
          e.key as String: (e.value as num).toInt()
      },
      favorites: {
        for (final e in ((j['favorites'] as Map?) ?? {}).entries)
          e.key as String: Fav.fromJson(e.value as Map<String, dynamic>)
      },
      playlists: {
        for (final e in ((j['playlists'] as Map?) ?? {}).entries)
          e.key as String: Playlist.fromJson(e.value as Map<String, dynamic>)
      },
      history: {
        for (final e in ((j['history'] as Map?) ?? {}).entries)
          e.key as String: DeviceHistory.fromJson(e.value as Map<String, dynamic>)
      },
    );
  }
}
