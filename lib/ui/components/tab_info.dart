import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/layout_spec.dart';

class TabInfo {
  const TabInfo(this.icon, this.selectedIcon);

  final IconData icon;
  final IconData selectedIcon;
}

/// Icons of each main tab.
TabInfo tabInfo(AppTab tab) => switch (tab) {
      AppTab.library => const TabInfo(Icons.library_music_outlined, Icons.library_music),
      AppTab.forYou => const TabInfo(Icons.auto_awesome_outlined, Icons.auto_awesome),
      AppTab.playlists => const TabInfo(Icons.queue_music_outlined, Icons.queue_music),
      AppTab.stats => const TabInfo(Icons.insights_outlined, Icons.insights),
    };

/// The translated label of a tab.
String tabTitle(AppLocalizations l, AppTab tab) => switch (tab) {
      AppTab.library => l.tabLibrary,
      AppTab.forYou => l.tabForYou,
      AppTab.playlists => l.tabPlaylists,
      AppTab.stats => l.tabStats,
    };
