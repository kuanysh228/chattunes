import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../player_service.dart';
import '../../settings.dart';
import '../../stats.dart';
import '../components/components.dart';
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

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    final usedMb = widget.player.cache.sizeBytes() / (1024 * 1024);
    final step = _cacheSteps.indexOf(s.cacheLimitMb).clamp(0, _cacheSteps.length - 1);

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Настройки')),
        body: ListView(
          children: [
            const SectionTitle('Внешний вид'),
            ListenableBuilder(
              listenable: widget.themes,
              builder: (context, _) => ListTile(
                leading: const Icon(Icons.palette),
                title: const Text('Тема'),
                subtitle: Text(widget.themes.selected.title),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ThemesScreen(themes: widget.themes),
                )),
              ),
            ),
            const SectionTitle('Воспроизведение'),
            SwitchListTile(
              title: const Text('Автопродолжение'),
              subtitle: const Text('Когда очередь кончается, добавлять рекомендованные треки'),
              value: s.autoplay,
              onChanged: s.setAutoplay,
            ),
            ListTile(
              title: const Text('Предзагрузка'),
              subtitle: Text('Заранее качать следующих треков: ${s.prefetchCount}'),
            ),
            Slider(
              value: s.prefetchCount.toDouble(),
              min: 0,
              max: 5,
              divisions: 5,
              label: '${s.prefetchCount}',
              onChanged: (v) => s.setPrefetch(v.round()),
            ),
            const SectionTitle('Кэш'),
            ListTile(
              title: const Text('Лимит кэша'),
              subtitle: Text(
                '${(s.cacheLimitMb / 1024).toStringAsFixed(s.cacheLimitMb % 1024 == 0 ? 0 : 1)} ГБ'
                ' · занято ${usedMb.round()} МБ',
              ),
            ),
            Slider(
              value: step.toDouble(),
              min: 0,
              max: (_cacheSteps.length - 1).toDouble(),
              divisions: _cacheSteps.length - 1,
              onChanged: (v) => s.setCacheLimitMb(_cacheSteps[v.round()]),
            ),
            SwitchListTile(
              title: const Text('Избранное всегда офлайн'),
              subtitle: const Text('Скачивать и не удалять избранные треки из кэша'),
              value: s.favoritesOffline,
              onChanged: s.setFavoritesOffline,
            ),
            ListTile(
              leading: const Icon(Icons.cleaning_services),
              title: const Text('Очистить кэш'),
              subtitle: const Text('Офлайн-треки и текущая очередь останутся'),
              onTap: () {
                widget.player.cache.clear(protectedIds: widget.player.protectedIds());
                setState(() {});
              },
            ),
            const SectionTitle('Данные'),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Сбросить статистику'),
              subtitle: const Text('Удалит историю прослушиваний на этом устройстве'),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: 'Сбросить статистику?',
                  text: 'Рекомендации тоже начнутся с нуля.',
                  action: 'Сбросить',
                );
                if (ok) await widget.stats.clear();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Отключить канал'),
              subtitle: const Text('Библиотека в канале останется'),
              onTap: () async {
                final ok = await confirm(
                  context,
                  title: 'Отключить канал?',
                  text: 'Локальный список будет очищен. В канале всё останется.',
                  action: 'Отключить',
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
