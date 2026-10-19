import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';
import '../l10n.dart';

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
        TextButton(
            onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.cancel)),
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
      content: TextField(
        controller: c,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, c.text), child: Text(context.l10n.done)),
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
            title: Text(context.l10n.newPlaylist),
            onTap: () async {
              Navigator.pop(sheet);
              final fallback = context.l10n.defaultPlaylistName;
              final name = await askText(context, title: context.l10n.playlistName);
              if (name != null) {
                library.createPlaylist(
                  name.trim().isEmpty ? fallback : name,
                  trackIds: [track.uniqueId],
                );
              }
            },
          ),
          for (final p in library.playlists)
            ListTile(
              leading: Icon(
                  p.trackIds.contains(track.uniqueId) ? Icons.check_circle : Icons.queue_music),
              title: Text(p.name),
              subtitle: Text(context.l10n.trackCount(p.trackIds.length)),
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
