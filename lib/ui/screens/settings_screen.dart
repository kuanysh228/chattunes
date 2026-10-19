import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../../settings.dart';
import '../../stats.dart';
import '../components/components.dart';
import '../l10n.dart';
import '../theme/theme_controller.dart';
import 'themes_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.library,
    required this.player,
    required this.settings,
    required this.stats,
    required this.themes,
  });

  final LibraryStore library;
  final PlayerService player;
  final AppSettings settings;
  final StatsStore stats;
  final ThemeController themes;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _cacheSteps = [256, 512, 1024, 2048, 4096, 8192, 16384];

  String _languageName(BuildContext context, String code) =>
      code.isEmpty ? context.l10n.languageSystem : (languageNames[code] ?? code);

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final usedMb = widget.player.cache.sizeBytes() / (1024 * 1024);
    final step = _cacheSteps.indexOf(s.cacheLimitMb).clamp(0, _cacheSteps.length - 1);

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.settingsTitle)),
        body: ListView(
          children: [
            SectionTitle(context.l10n.appearance),
            ListenableBuilder(
              listenable: widget.themes,
              builder: (context, _) => ListTile(
                leading: const Icon(Icons.palette),
                title: Text(context.l10n.themeTitle),
                subtitle: Text(widget.themes.selected.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ThemesScreen(themes: widget.themes),
                )),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: Text(context.l10n.languageTitle),
              subtitle: Text(_languageName(context, s.languageCode)),
              trailing: PopupMenuButton<String>(
                tooltip: context.l10n.languageTitle,
                initialValue: s.languageCode,
                onSelected: s.setLanguage,
                itemBuilder: (_) => [
                  PopupMenuItem(value: '', child: Text(context.l10n.languageSystem)),
                  for (final locale in AppLocalizations.supportedLocales)
                    PopupMenuItem(
                      value: locale.languageCode,
                      child: Text(languageNames[locale.languageCode] ?? locale.languageCode),
                    ),
                ],
              ),
            ),
            SectionTitle(context.l10n.playbackSection),
            SwitchListTile(
              title: Text(context.l10n.autoplay),
              subtitle: Text(context.l10n.autoplaySub),
              value: s.autoplay,
              onChanged: s.setAutoplay,
            ),
            ListTile(
              title: Text(context.l10n.prefetch),
              subtitle: Text(context.l10n.prefetchSub(s.prefetchCount)),
            ),
            Slider(
              value: s.prefetchCount.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              label: '${s.prefetchCount}',
              onChanged: (v) => s.setPrefetch(v.round()),
            ),
            SectionTitle(context.l10n.cacheSection),
            ListTile(
              title: Text(context.l10n.cacheLimit),
              subtitle: Text(context.l10n.cacheUsage(
                (s.cacheLimitMb / 1024).toStringAsFixed(s.cacheLimitMb % 1024 == 0 ? 0 : 1),
                usedMb.round(),
              )),
            ),
            Slider(
              value: step.toDouble(),
              min: 0,
              max: (_cacheSteps.length - 1).toDouble(),
              divisions: _cacheSteps.length - 1,
              onChanged: (v) => s.setCacheLimitMb(_cacheSteps[v.round()]),
            ),
            SwitchListTile(
              title: Text(context.l10n.favoritesOffline),
              subtitle: Text(context.l10n.favoritesOfflineSub),
              value: s.favoritesOffline,
              onChanged: s.setFavoritesOffline,
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: Text(context.l10n.clearCache),
              subtitle: Text(context.l10n.clearCacheSub),
              onTap: () {
                widget.player.cache.clear(protectedIds: widget.player.protectedIds());
                setState(() {});
              },
            ),
            SectionTitle(context.l10n.dataSection),
            ListTile(
              leading: const Icon(Icons.history),
              title: Text(context.l10n.resetStats),
              subtitle: Text(context.l10n.resetStatsSub),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: context.l10n.resetStatsTitle,
                  text: context.l10n.resetStatsBody,
                  action: context.l10n.reset,
                );
                if (ok) await widget.library.resetHistory();
              },
            ),
            if (widget.player.systemMediaControls)
              ListTile(
                leading: const Icon(Icons.keyboard_command_key),
                title: Text(context.l10n.mediaKeysOn),
              ),
            ListTile(
              leading: Icon(widget.library.vault.isSecure ? Icons.lock : Icons.lock_open),
              title: Text(widget.library.vault.isSecure
                  ? context.l10n.tokenStoredSecurely
                  : context.l10n.tokenStoredPlain),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(context.l10n.disconnect),
              subtitle: Text(context.l10n.disconnectSub),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: context.l10n.disconnectTitle,
                  text: context.l10n.disconnectBody,
                  action: context.l10n.disconnect,
                );
                if (ok) {
                  await widget.library.disconnect();
                  if (context.mounted) Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
