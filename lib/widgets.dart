import 'package:flutter/material.dart';

import 'library_store.dart';
import 'models.dart';
import 'player_service.dart';

String fmtDuration(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// "3 ч 20 мин" / "45 мин" for listening totals.
String fmtSpent(int ms) {
  final minutes = ms ~/ 60000;
  if (minutes < 60) return '$minutes мин';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

/// There is no cover art in the channel, so derive a stable color from the
/// track and show its initial.
class Cover extends StatelessWidget {
  const Cover({super.key, required this.track, this.size = 44});

  final Track track;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hue = (track.uniqueId.hashCode.abs() % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.45, 0.35).toColor();
    final top = HSLColor.fromAHSL(1, (hue + 40) % 360, 0.5, 0.5).toColor();
    final text = track.title.trim().isEmpty ? '♪' : track.title.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, base],
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.9),
          fontSize: size * 0.42,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 8, 4),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          ?trailing,
        ],
      ),
    );
  }
}

enum TrackAction { playNext, queue, favorite, playlist, extra, remove }

/// One row of any track list. [onTap] decides what queue the tap starts.
class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.library,
    required this.player,
    required this.onTap,
    this.subtitle,
    this.extraLabel,
    this.onExtra,
  });

  final Track track;
  final LibraryStore library;
  final PlayerService player;
  final VoidCallback onTap;

  /// Replaces the default "artist · duration" line (e.g. a recommendation reason).
  final String? subtitle;

  /// One context-specific menu entry, e.g. "remove from this playlist".
  final String? extraLabel;
  final VoidCallback? onExtra;

  @override
  Widget build(BuildContext context) {
    final isCurrent = player.current?.uniqueId == track.uniqueId;
    final error = player.errors[track.uniqueId];
    final fav = library.isFavorite(track);

    Widget status;
    if (player.isDownloading(track)) {
      status = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (error != null) {
      status = Icon(Icons.error_outline, size: 18, color: Theme.of(context).colorScheme.error);
    } else if (player.isCached(track)) {
      status = const Icon(Icons.download_done, size: 18);
    } else {
      status = const Icon(Icons.cloud_outlined, size: 18);
    }

    return ListTile(
      selected: isCurrent,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          Cover(track: track),
          if (isCurrent && player.playing)
            const Icon(Icons.equalizer, color: Colors.white),
        ],
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        error ??
            subtitle ??
            [if (track.artist.isNotEmpty) track.artist, fmtDuration(track.duration)].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fav) const Icon(Icons.favorite, size: 16, color: Colors.pinkAccent),
          const SizedBox(width: 8),
          status,
          PopupMenuButton<Object>(
            tooltip: 'Действия',
            onSelected: (v) => _onAction(context, v),
            itemBuilder: (_) => [
              const PopupMenuItem(value: TrackAction.playNext, child: Text('Играть далее')),
              const PopupMenuItem(value: TrackAction.queue, child: Text('В очередь')),
              PopupMenuItem(
                value: TrackAction.favorite,
                child: Text(fav ? 'Убрать из избранного' : 'В избранное'),
              ),
              const PopupMenuItem(value: TrackAction.playlist, child: Text('В плейлист…')),
              if (extraLabel != null)
                PopupMenuItem(value: TrackAction.extra, child: Text(extraLabel!)),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: TrackAction.remove,
                child: Text('Удалить из библиотеки'),
              ),
            ],
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  Future<void> _onAction(BuildContext context, Object v) async {
    switch (v) {
      case TrackAction.playNext:
        player.playNext(track);
      case TrackAction.queue:
        player.addToQueue(track);
      case TrackAction.favorite:
        library.toggleFavorite(track);
      case TrackAction.playlist:
        await showAddToPlaylist(context, library, track);
      case TrackAction.extra:
        onExtra?.call();
      case TrackAction.remove:
        final ok = await confirm(
          context,
          title: 'Удалить трек?',
          text: '«${track.title}» исчезнет из библиотеки на всех устройствах и из канала.',
          action: 'Удалить',
        );
        if (ok) await library.removeTrack(track);
    }
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String text,
  required String action,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: Text(text),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return ok ?? false;
}

Future<String?> askText(BuildContext context, {required String title, String initial = ''}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true, onSubmitted: (v) => Navigator.pop(context, v)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        TextButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Готово')),
      ],
    ),
  );
}

Future<void> showAddToPlaylist(BuildContext context, LibraryStore library, Track track) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('Новый плейлист'),
            onTap: () async {
              Navigator.pop(sheet);
              final name = await askText(context, title: 'Название плейлиста');
              if (name != null) library.createPlaylist(name, trackIds: [track.uniqueId]);
            },
          ),
          for (final p in library.playlists)
            ListTile(
              leading: Icon(p.trackIds.contains(track.uniqueId)
                  ? Icons.check_circle
                  : Icons.queue_music),
              title: Text(p.name),
              subtitle: Text('${p.trackIds.length} треков'),
              onTap: () {
                library.addToPlaylist(p, track);
                Navigator.pop(sheet);
              },
            ),
        ],
      ),
    ),
  );
}
