import 'package:flutter/material.dart';

import '../theme/layout_spec.dart';
import '../l10n.dart';
import 'tab_info.dart';

/// Switches between the main tabs. A bar when placed in a column, a rail when
/// placed in a row: the theme decides by where it puts `navigation` in
/// `layout.shell`.
class AppNavigation extends StatelessWidget {
  const AppNavigation({
    super.key,
    required this.axis,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.labels,
  });

  final Axis axis;
  final List<AppTab> tabs;
  final AppTab selected;
  final ValueChanged<AppTab> onSelect;
  final NavigationLabels labels;

  @override
  Widget build(BuildContext context) {
    final index = tabs.indexOf(selected).clamp(0, tabs.length - 1);
    void onTap(int i) => onSelect(tabs[i]);

    if (axis == Axis.horizontal) {
      return NavigationBar(
        selectedIndex: index,
        onDestinationSelected: onTap,
        labelBehavior: switch (labels) {
          NavigationLabels.always => NavigationDestinationLabelBehavior.alwaysShow,
          NavigationLabels.selected => NavigationDestinationLabelBehavior.onlyShowSelected,
          NavigationLabels.never => NavigationDestinationLabelBehavior.alwaysHide,
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(tabInfo(t).icon),
              selectedIcon: Icon(tabInfo(t).selectedIcon),
              label: tabTitle(context.l10n, t),
              tooltip: tabTitle(context.l10n, t),
            ),
        ],
      );
    }

    return NavigationRail(
      selectedIndex: index,
      onDestinationSelected: onTap,
      labelType: switch (labels) {
        NavigationLabels.always => NavigationRailLabelType.all,
        NavigationLabels.selected => NavigationRailLabelType.selected,
        NavigationLabels.never => NavigationRailLabelType.none,
      },
      destinations: [
        for (final t in tabs)
          NavigationRailDestination(
            icon: Icon(tabInfo(t).icon),
            selectedIcon: Icon(tabInfo(t).selectedIcon),
            label: Text(tabTitle(context.l10n, t)),
          ),
      ],
    );
  }
}
