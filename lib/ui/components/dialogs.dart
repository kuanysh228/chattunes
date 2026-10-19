import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../models.dart';

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
      content: TextField(
        controller: c,
        autofocus: true,
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
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
              leading: Icon(
                  p.trackIds.contains(track.uniqueId) ? Icons.check_circle : Icons.queue_music),
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
