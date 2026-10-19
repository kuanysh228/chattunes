import 'package:flutter/material.dart';

import '../../player_service.dart';
import '../l10n.dart';
import 'cover.dart';
import 'section_title.dart';

void showQueueSheet(BuildContext context, PlayerService player) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (context, scroll) => ListenableBuilder(
        listenable: player,
        builder: (context, _) => Column(
          children: [
            SectionTitle(context.l10n.queueTitle),
            Expanded(
              child: ReorderableListView.builder(
                scrollController: scroll,
                buildDefaultDragHandles: false,
                itemCount: player.queue.length,
                onReorderItem: player.reorderQueue,
                itemBuilder: (_, i) {
                  final t = player.queue[i];
                  final isCurrent = i == player.index;
                  return ReorderableDragStartListener(
                    key: ValueKey('$i-${t.uniqueId}'),
                    index: i,
                    child: ListTile(
                      selected: isCurrent,
                      leading: Cover(track: t, size: 36),
                      title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(t.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: isCurrent
                          ? const Icon(Icons.graphic_eq)
                          : IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () => player.removeFromQueue(i),
                            ),
                      onTap: () => player.jumpTo(i),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
