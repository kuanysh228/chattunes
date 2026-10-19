class Track {
  Track({
    required this.fileId,
    required this.uniqueId,
    required this.title,
    required this.artist,
    required this.duration,
    required this.addedAt,
    this.size,
    this.messageId,
    this.thumbId,
  });

  /// Bot-specific id, valid for getFile as long as the bot lives.
  final String fileId;

  /// Stable across bots, used to dedupe between channel posts and the index.
  final String uniqueId;
  final String title;
  final String artist;
  final int duration;

  /// Milliseconds since epoch. Also decides whether a track survives a removal.
  final int addedAt;
  final int? size;
  final int? messageId;

  /// Cover thumbnail Telegram stored with the audio, if any.
  final String? thumbId;

  String get label => artist.isEmpty ? title : '$artist — $title';

  /// Case-insensitive grouping key; empty artists share one bucket.
  String get artistKey => artist.trim().isEmpty ? '' : artist.trim().toLowerCase();

  Map<String, dynamic> toJson() => {
        'file_id': fileId,
        'unique_id': uniqueId,
        'title': title,
        'artist': artist,
        'duration': duration,
        'added_at': addedAt,
        if (size != null) 'size': size,
        if (messageId != null) 'message_id': messageId,
        if (thumbId != null) 'thumb_id': thumbId,
      };

  factory Track.fromJson(Map<String, dynamic> j) => Track(
        fileId: j['file_id'] as String,
        uniqueId: j['unique_id'] as String,
        title: j['title'] as String? ?? '',
        artist: j['artist'] as String? ?? '',
        duration: (j['duration'] as num?)?.toInt() ?? 0,
        addedAt: (j['added_at'] as num?)?.toInt() ?? 0,
        size: (j['size'] as num?)?.toInt(),
        messageId: (j['message_id'] as num?)?.toInt(),
        thumbId: j['thumb_id'] as String?,
      );

  /// Builds a track from a Bot API `audio` or `document` object.
  factory Track.fromMedia(Map<String, dynamic> m, {int? messageId, int? addedAt}) {
    final fileName = (m['file_name'] as String?) ?? '';
    final base = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
    return Track(
      fileId: m['file_id'] as String,
      uniqueId: m['file_unique_id'] as String,
      title: (m['title'] as String?) ?? base,
      artist: (m['performer'] as String?) ?? '',
      duration: (m['duration'] as num?)?.toInt() ?? 0,
      addedAt: addedAt ?? DateTime.now().millisecondsSinceEpoch,
      size: (m['file_size'] as num?)?.toInt(),
      messageId: messageId,
      thumbId: ((m['thumbnail'] ?? m['thumb']) as Map<String, dynamic>?)?['file_id'] as String?,
    );
  }
}

/// A like/unlike with the time it happened, so devices can agree on the latest.
class Fav {
  const Fav(this.on, this.at);

  final bool on;
  final int at;

  Map<String, dynamic> toJson() => {'on': on, 'at': at};

  factory Fav.fromJson(Map<String, dynamic> j) =>
      Fav(j['on'] as bool? ?? false, (j['at'] as num?)?.toInt() ?? 0);
}

class Playlist {
  Playlist({
    required this.id,
    required this.name,
    required this.updatedAt,
    List<String>? trackIds,
    this.deleted = false,
    this.offline = false,
  }) : trackIds = trackIds ?? [];

  final String id;
  String name;
  List<String> trackIds;
  int updatedAt;
  bool deleted;

  /// Keep every track of this playlist downloaded.
  bool offline;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'track_ids': trackIds,
        'updated_at': updatedAt,
        'deleted': deleted,
        'offline': offline,
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        trackIds: [for (final t in (j['track_ids'] as List? ?? [])) t as String],
        updatedAt: (j['updated_at'] as num?)?.toInt() ?? 0,
        deleted: j['deleted'] as bool? ?? false,
        offline: j['offline'] as bool? ?? false,
      );
}

/// One listening session of one track. Stored locally, never synced.
class PlayEvent {
  const PlayEvent({
    required this.trackId,
    required this.at,
    required this.listenedMs,
    required this.durationMs,
    required this.completed,
  });

  final String trackId;

  /// When listening started, ms since epoch.
  final int at;
  final int listenedMs;
  final int durationMs;
  final bool completed;

  /// Same rule streaming services use: 30 seconds or half the track.
  bool get counted {
    final threshold = durationMs > 0 ? (durationMs * 0.5).clamp(0, 30000) : 30000;
    return completed || listenedMs >= threshold;
  }

  bool get skipped => !completed && listenedMs < 10000;

  Map<String, dynamic> toJson() => {
        'id': trackId,
        'at': at,
        'ms': listenedMs,
        'dur': durationMs,
        'done': completed,
      };

  /// Compact form for the shared index: `[trackId, startSec, listenedSec,
  /// durationSec, completed]`. Seconds are plenty for stats and keep a year of
  /// listening to a few hundred KB.
  List<Object> toCompact() => [
        trackId,
        at ~/ 1000,
        (listenedMs / 1000).round(),
        (durationMs / 1000).round(),
        completed ? 1 : 0,
      ];

  factory PlayEvent.fromCompact(List<dynamic> c) => PlayEvent(
        trackId: c[0] as String,
        at: (c[1] as num).toInt() * 1000,
        listenedMs: (c[2] as num).toInt() * 1000,
        durationMs: (c[3] as num).toInt() * 1000,
        completed: c[4] == 1,
      );

  factory PlayEvent.fromJson(Map<String, dynamic> j) => PlayEvent(
        trackId: j['id'] as String,
        at: (j['at'] as num).toInt(),
        listenedMs: (j['ms'] as num).toInt(),
        durationMs: (j['dur'] as num?)?.toInt() ?? 0,
        completed: j['done'] as bool? ?? false,
      );
}

/// One device's listening log as shared through the index. Only its own device
/// ever appends to it, so devices never conflict over it.
///
/// [epoch] goes up when stats are reset; a higher epoch wins over any amount of
/// older events, so a reset on one device is not undone by another.
class DeviceHistory {
  const DeviceHistory(this.epoch, this.events);

  final int epoch;
  final List<PlayEvent> events;

  Map<String, dynamic> toJson() => {
        'epoch': epoch,
        'events': [for (final e in events) e.toCompact()],
      };

  factory DeviceHistory.fromJson(Map<String, dynamic> j) => DeviceHistory(
        (j['epoch'] as num?)?.toInt() ?? 0,
        [
          for (final e in (j['events'] as List? ?? []))
            PlayEvent.fromCompact(e as List<dynamic>)
        ],
      );
}
