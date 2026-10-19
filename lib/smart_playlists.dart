import 'models.dart';

/// Playlists that fill themselves from how the library is used. They are
/// computed on demand and never stored, so they are always up to date.
enum SmartPlaylist { topMonth, recentlyAdded, neverPlayed, loved, skipped }

class SmartPlaylists {
  SmartPlaylists({
    required this.tracks,
    required this.events,
    required this.favorites,
    DateTime? now,
  }) : _now = (now ?? DateTime.now()).millisecondsSinceEpoch;

  final List<Track> tracks;
  final Set<String> favorites;
  final List<PlayEvent> events;
  final int _now;

  static const _day = 86400000;

  /// Never more than this many tracks in one list.
  static const maxTracks = 100;

  late final Map<String, int> _plays = _countPlays();

  Map<String, int> _countPlays({int? since}) {
    final out = <String, int>{};
    for (final e in events) {
      if (e.counted && (since == null || e.at >= since)) {
        out[e.trackId] = (out[e.trackId] ?? 0) + 1;
      }
    }
    return out;
  }

  List<Track> tracksFor(SmartPlaylist kind) {
    final List<Track> list = switch (kind) {
      SmartPlaylist.topMonth => _topMonth(),
      SmartPlaylist.recentlyAdded => _recentlyAdded(),
      SmartPlaylist.neverPlayed => _neverPlayed(),
      SmartPlaylist.loved => _loved(),
      SmartPlaylist.skipped => _skipped(),
    };
    return list.take(maxTracks).toList();
  }

  /// Lists worth showing: the empty ones are left out.
  Map<SmartPlaylist, List<Track>> nonEmpty() => {
        for (final k in SmartPlaylist.values)
          if (tracksFor(k).isNotEmpty) k: tracksFor(k),
      };

  List<Track> _topMonth() {
    final month = _countPlays(since: _now - 30 * _day);
    final list = [
      for (final t in tracks)
        if ((month[t.uniqueId] ?? 0) > 0) t
    ]..sort((a, b) => month[b.uniqueId]!.compareTo(month[a.uniqueId]!));
    return list;
  }

  List<Track> _recentlyAdded() => [
        for (final t in tracks)
          if (t.addedAt >= _now - 14 * _day) t
      ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  List<Track> _neverPlayed() => [
        for (final t in tracks)
          if ((_plays[t.uniqueId] ?? 0) == 0) t
      ]..sort((a, b) => b.addedAt.compareTo(a.addedAt));

  /// Favorites count as much as five plays, so liked tracks lead but heavy
  /// rotation can still make the list.
  List<Track> _loved() {
    double score(Track t) => (_plays[t.uniqueId] ?? 0) + (favorites.contains(t.uniqueId) ? 5 : 0);
    final list = [
      for (final t in tracks)
        if (score(t) >= 3) t
    ]..sort((a, b) => score(b).compareTo(score(a)));
    return list;
  }

  /// Tracks that are mostly abandoned within seconds, with enough plays to be sure.
  List<Track> _skipped() {
    final seen = <String, int>{};
    final skips = <String, int>{};
    for (final e in events) {
      seen[e.trackId] = (seen[e.trackId] ?? 0) + 1;
      if (e.skipped) skips[e.trackId] = (skips[e.trackId] ?? 0) + 1;
    }
    final list = [
      for (final t in tracks)
        if ((seen[t.uniqueId] ?? 0) >= 3 && (skips[t.uniqueId] ?? 0) / seen[t.uniqueId]! >= 0.5) t
    ]..sort((a, b) => skips[b.uniqueId]!.compareTo(skips[a.uniqueId]!));
    return list;
  }
}
