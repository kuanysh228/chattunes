import 'package:flutter/material.dart';

import '../library_store.dart';
import '../stats.dart';
import '../widgets.dart';

enum _Range { week, month, all }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.library, required this.stats});

  final LibraryStore library;
  final StatsStore stats;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  _Range _range = _Range.week;

  @override
  Widget build(BuildContext context) {
    final window = switch (_range) {
      _Range.week => const Duration(days: 7),
      _Range.month => const Duration(days: 30),
      _Range.all => null,
    };
    final view = StatsView(widget.stats.events, widget.library.trackById, window: window);
    // Streak looks at the whole history, whatever range is shown.
    final streak = StatsView(widget.stats.events, widget.library.trackById).streakDays;
    final days = switch (_range) {
      _Range.week => 7,
      _Range.month => 30,
      _Range.all => 30,
    };

    if (widget.stats.events.isEmpty) {
      return const Center(child: Text('Статистика появится после первых прослушиваний'));
    }

    final topTracks = view.topTracks(5);
    final topArtists = view.topArtists(5);
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SegmentedButton<_Range>(
            segments: const [
              ButtonSegment(value: _Range.week, label: Text('7 дней')),
              ButtonSegment(value: _Range.month, label: Text('30 дней')),
              ButtonSegment(value: _Range.all, label: Text('Всё время')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _StatCard(label: 'Слушали', value: fmtSpent(view.totalMs)),
              _StatCard(label: 'Прослушиваний', value: '${view.plays}'),
              _StatCard(label: 'Серия дней', value: '$streak'),
              _StatCard(
                label: 'Пропусков',
                value: '${(view.skipRate * 100).round()}%',
              ),
            ],
          ),
        ),
        SectionTitle(_range == _Range.week ? 'Минуты по дням' : 'Минуты по дням (30 дней)'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 120,
            child: _Bars(
              values: StatsView(widget.stats.events, widget.library.trackById)
                  .minutesPerDay(days),
              color: scheme.primary,
              labelOf: (i) {
                final d = DateTime.now().subtract(Duration(days: days - 1 - i));
                return '${d.day}';
              },
              labelEvery: days > 7 ? 5 : 1,
            ),
          ),
        ),
        const SectionTitle('Когда вы слушаете'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 100,
            child: _Bars(
              values: view.minutesByHour(),
              color: scheme.tertiary,
              labelOf: (i) => '$i',
              labelEvery: 3,
            ),
          ),
        ),
        if (topTracks.isNotEmpty) ...[
          const SectionTitle('Топ треков'),
          for (var i = 0; i < topTracks.length; i++)
            ListTile(
              leading: Cover(track: topTracks[i].track),
              title: Text(topTracks[i].track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(topTracks[i].track.artist),
              trailing: Text('${topTracks[i].plays} ×'),
            ),
        ],
        if (topArtists.isNotEmpty) ...[
          const SectionTitle('Топ исполнителей'),
          for (var i = 0; i < topArtists.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(topArtists[i].name),
              subtitle: Text(fmtSpent(topArtists[i].listenedMs)),
              trailing: Text('${topArtists[i].plays} ×'),
            ),
        ],
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(label, style: t.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars({
    required this.values,
    required this.color,
    required this.labelOf,
    required this.labelEvery,
  });

  final List<double> values;
  final Color color;
  final String Function(int) labelOf;
  final int labelEvery;

  @override
  Widget build(BuildContext context) {
    final peak = values.fold(0.0, (a, b) => a > b ? a : b);
    final labelStyle = Theme.of(context).textTheme.labelSmall;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Tooltip(
              message: '${values[i].round()} мин',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: peak <= 0 ? 0.02 : (values[i] / peak).clamp(0.02, 1.0),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: values[i] <= 0 ? color.withValues(alpha: 0.2) : color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 14,
                    child: i % labelEvery == 0
                        ? Text(labelOf(i), style: labelStyle, maxLines: 1, softWrap: false)
                        : null,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
