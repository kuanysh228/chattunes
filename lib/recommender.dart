import 'dart:math';

import 'models.dart';

class Rec {
  const Rec(this.track, this.score, this.reason);

  final Track track;
  final double score;
  final String reason;
}

/// Content-free recommender: it only knows what the user played, skipped and
/// liked. No audio features and no network, so it works on a private library.
class Recommender {
  Recommender({
    required this.tracks,
    required List<PlayEvent> events,
    required this.favorites,
    DateTime? now,
    Random? random,
  })  : _now = (now ?? DateTime.now()).millisecondsSinceEpoch,
        _random = random ?? Random() {
    _learn(events);
  }

  /// Half-life of a listen's influence.
  static const _halfLifeDays = 30.0;

  final List<Track> tracks;
  final Set<String> favorites;
  final int _now;
  final Random _random;

  final Map<String, double> _trackWeight = {};
  final Map<String, double> _artistWeight = {};
  final Map<String, int> _lastPlayed = {};
  final Map<String, int> _playCount = {};
  final Map<String, List<int>> _trackHours = {};
  final Map<String, List<int>> _artistHours = {};
  final Map<String, Map<String, int>> _next = {};
  double _maxTrack = 0;
  double _maxArtist = 0;
  int _countedTotal = 0;
  late final Map<String, Track> _byId = {for (final t in tracks) t.uniqueId: t};

  int get countedPlays => _countedTotal;

  /// Not enough history to personalise; callers should fall back to "new".
  bool get coldStart => _countedTotal < 5;

  void _learn(List<PlayEvent> events) {
    final sorted = [...events]..sort((a, b) => a.at.compareTo(b.at));
    PlayEvent? prev;

    for (final e in sorted) {
      final t = _byId[e.trackId];
      if (t == null) continue;

      final ageDays = max(0, _now - e.at) / 86400000;
      final decay = pow(0.5, ageDays / _halfLifeDays).toDouble();
      final double w = e.counted
          ? (e.completed ? 1.5 : 1.0)
          : (e.skipped ? -0.7 : 0.1);

      _trackWeight[t.uniqueId] = (_trackWeight[t.uniqueId] ?? 0) + w * decay;
      if (t.artistKey.isNotEmpty) {
        _artistWeight[t.artistKey] = (_artistWeight[t.artistKey] ?? 0) + w * decay;
      }

      if (e.counted) {
        _countedTotal++;
        _playCount[t.uniqueId] = (_playCount[t.uniqueId] ?? 0) + 1;
        _lastPlayed[t.uniqueId] = max(_lastPlayed[t.uniqueId] ?? 0, e.at);
        final hour = DateTime.fromMillisecondsSinceEpoch(e.at).hour;
        (_trackHours[t.uniqueId] ??= List.filled(24, 0))[hour]++;
        if (t.artistKey.isNotEmpty) {
          (_artistHours[t.artistKey] ??= List.filled(24, 0))[hour]++;
        }

        // Two counted plays within half an hour belong to one listening session.
        final p = prev;
        if (p != null && p.trackId != e.trackId) {
          final gap = e.at - (p.at + p.listenedMs);
          if (gap < 30 * 60 * 1000) {
            final row = _next[p.trackId] ??= {};
            row[e.trackId] = (row[e.trackId] ?? 0) + 1;
          }
        }
        prev = e;
      }
    }

    _maxTrack = _trackWeight.values.fold(0.0, max);
    _maxArtist = _artistWeight.values.fold(0.0, max);
  }

  double _norm(double v, double maxV) => maxV <= 0 ? 0 : (v.clamp(0, maxV)) / maxV;

  double _hourAffinity(Track t) {
    final hour = DateTime.fromMillisecondsSinceEpoch(_now).hour;
    double share(List<int>? h) {
      if (h == null) return 0;
      final total = h.fold(0, (a, b) => a + b);
      if (total == 0) return 0;
      final near = h[hour] + h[(hour + 23) % 24] + h[(hour + 1) % 24];
      return near / total;
    }

    return max(share(_trackHours[t.uniqueId]), share(_artistHours[t.artistKey]));
  }

  double _hoursSincePlayed(Track t) {
    final last = _lastPlayed[t.uniqueId];
    return last == null ? double.infinity : (_now - last) / 3600000;
  }

  /// Returns the score together with the factor that contributed most.
  (double, String) _score(Track t, Track? seed) {
    final artistN = _norm(_artistWeight[t.artistKey] ?? 0, _maxArtist);
    final trackN = _norm(_trackWeight[t.uniqueId] ?? 0, _maxTrack);
    final fav = favorites.contains(t.uniqueId) ? 1.0 : 0.0;
    final hourN = _hourAffinity(t);

    var trans = 0.0;
    if (seed != null) {
      final row = _next[seed.uniqueId];
      final maxRow = row == null || row.isEmpty ? 0 : row.values.reduce(max);
      if (maxRow > 0) trans = (row![t.uniqueId] ?? 0) / maxRow;
    }

    final parts = <String, double>{
      'любимый исполнитель': 0.35 * artistN,
      'часто слушаете': 0.25 * trackN,
      'в избранном': 0.20 * fav,
      'часто играет после этого трека': 0.45 * trans,
      'под это время суток': 0.10 * hourN,
    };

    var score = parts.values.fold(0.0, (a, b) => a + b);

    final hours = _hoursSincePlayed(t);
    if (hours < 6) {
      score -= 0.6;
    } else if (hours < 24) {
      score -= 0.25;
    } else if (hours > 14 * 24 && trackN > 0.3) {
      score += 0.1;
    }

    var reason = parts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    var reasonText = reason.value > 0.02 ? reason.key : 'новое в вашей библиотеке';

    // Never played, but the artist is liked: worth surfacing.
    if (!_playCount.containsKey(t.uniqueId) && artistN > 0.3) {
      score += 0.15;
      if (parts['часто играет после этого трека']! < 0.05) {
        reasonText = 'похоже на то, что вы любите';
      }
    }

    score += _random.nextDouble() * 0.05;
    return (score, reasonText);
  }

  /// Greedy re-rank: a small penalty per already-picked track of the same
  /// artist keeps a mix from becoming one band for an hour.
  List<Rec> _diversify(List<Rec> ranked, int limit) {
    final picked = <Rec>[];
    final perArtist = <String, int>{};
    final pool = [...ranked];
    while (picked.length < limit && pool.isNotEmpty) {
      var bestIdx = 0;
      var bestVal = double.negativeInfinity;
      for (var i = 0; i < pool.length; i++) {
        final r = pool[i];
        final v = r.score - 0.15 * (perArtist[r.track.artistKey] ?? 0);
        if (v > bestVal) {
          bestVal = v;
          bestIdx = i;
        }
      }
      final r = pool.removeAt(bestIdx);
      picked.add(r);
      perArtist[r.track.artistKey] = (perArtist[r.track.artistKey] ?? 0) + 1;
    }
    return picked;
  }

  List<Rec> _rank(Iterable<Track> candidates, Track? seed) {
    final out = [
      for (final t in candidates)
        if (t.uniqueId != seed?.uniqueId)
          () {
            final (s, why) = _score(t, seed);
            return Rec(t, s, why);
          }()
    ]..sort((a, b) => b.score.compareTo(a.score));
    return out;
  }

  /// The main "for you" list.
  List<Rec> mix({int limit = 30, Track? seed}) {
    if (coldStart) {
      final fresh = [...tracks]..sort((a, b) => b.addedAt.compareTo(a.addedAt));
      return [
        for (final t in fresh.take(limit))
          Rec(t, 0, favorites.contains(t.uniqueId) ? 'в избранном' : 'новое в вашей библиотеке')
      ];
    }
    return _diversify(_rank(tracks, seed), limit);
  }

  /// Autoplay continuation after [seed]; skips anything in [exclude].
  List<Rec> radio(Track seed, {int limit = 10, Set<String> exclude = const {}}) {
    final candidates = tracks.where(
      (t) => !exclude.contains(t.uniqueId) && _hoursSincePlayed(t) > 1,
    );
    final ranked = _rank(candidates, seed);
    // Without history the ranking is noise; prefer the seed's own artist.
    if (coldStart) {
      ranked.sort((a, b) {
        final sa = a.track.artistKey == seed.artistKey ? 1 : 0;
        final sb = b.track.artistKey == seed.artistKey ? 1 : 0;
        return sb != sa ? sb.compareTo(sa) : b.score.compareTo(a.score);
      });
      return ranked.take(limit).toList();
    }
    return _diversify(ranked, limit);
  }

  /// Tracks you loved once and haven't heard for a while.
  List<Rec> forgotten({int limit = 15, int minDays = 21}) {
    final out = <Rec>[];
    for (final t in tracks) {
      final plays = _playCount[t.uniqueId] ?? 0;
      final liked = favorites.contains(t.uniqueId);
      if (plays < 3 && !(liked && plays > 0)) continue;
      final last = _lastPlayed[t.uniqueId];
      if (last == null) continue;
      final days = (_now - last) / 86400000;
      if (days < minDays) continue;
      // Loved more and longer ago ranks higher.
      out.add(Rec(t, plays * log(days + 1), 'не слушали ${days.round()} дн.'));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.take(limit).toList();
  }

  /// Unplayed tracks by artists the user already plays a lot.
  List<Rec> newFromFavoriteArtists({int limit = 15}) {
    final out = <Rec>[];
    for (final t in tracks) {
      if (_playCount.containsKey(t.uniqueId)) continue;
      final a = _norm(_artistWeight[t.artistKey] ?? 0, _maxArtist);
      if (a < 0.3) continue;
      out.add(Rec(t, a, 'новое у «${t.artist}»'));
    }
    out.sort((a, b) => b.score.compareTo(a.score));
    return out.take(limit).toList();
  }
}
