import 'package:flutter/material.dart';

import '../theme/layout_spec.dart';

class TabInfo {
  const TabInfo(this.icon, this.selectedIcon, this.title);

  final IconData icon;
  final IconData selectedIcon;
  final String title;
}

/// Icon and label of each main tab.
TabInfo tabInfo(AppTab tab) => switch (tab) {
      AppTab.library => const TabInfo(Icons.library_music_outlined, Icons.library_music, 'Библиотека'),
      AppTab.forYou => const TabInfo(Icons.auto_awesome_outlined, Icons.auto_awesome, 'Для вас'),
      AppTab.playlists => const TabInfo(Icons.queue_music_outlined, Icons.queue_music, 'Плейлисты'),
      AppTab.stats => const TabInfo(Icons.insights_outlined, Icons.insights, 'Статистика'),
    };
