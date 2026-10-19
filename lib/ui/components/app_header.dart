import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

/// Screen title with the sync and settings buttons. A strip in a column, a
/// narrow icon column when a theme places it inside a row.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.axis,
    required this.title,
    required this.busy,
    required this.onSync,
    required this.onSettings,
  });

  final Axis axis;
  final String title;
  final bool busy;
  final VoidCallback onSync;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final surface = Theme.of(context).colorScheme.surface;

    final sync = IconButton(
      tooltip: 'Синхронизировать',
      icon: const Icon(Icons.sync),
      onPressed: onSync,
    );
    final settings = IconButton(
      tooltip: 'Настройки',
      icon: const Icon(Icons.settings),
      onPressed: onSettings,
    );

    if (axis == Axis.vertical) {
      return Material(
        color: surface,
        child: SizedBox(
          width: 56,
          child: Column(
            children: [
              SizedBox(height: t.gap),
              sync,
              settings,
              if (busy) const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: EdgeInsets.only(left: t.pad, right: t.gap / 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  sync,
                  settings,
                ],
              ),
            ),
          ),
          if (busy) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }
}
