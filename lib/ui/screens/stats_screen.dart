import 'package:flutter/material.dart';

import '../../library_store.dart';
import '../../stats.dart';
import '../components/components.dart';
import '../l10n.dart';
import '../theme/app_tokens.dart';

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
      return Center(child: Text(context.l10n.statsEmpty));
    }

    final topTracks = view.topTracks(5);
    final topArtists = view.topArtists(5);

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: EdgeInsets.all(context.tokens.pad),
          child: SegmentedButton<_Range>(
            segments: [
              ButtonSegment(value: _Range.week, label: Text(context.l10n.range7)),
              ButtonSegment(value: _Range.month, label: Text(context.l10n.range30)),
              ButtonSegment(value: _Range.all, label: Text(context.l10n.rangeAll)),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.tokens.pad),
          child: Wrap(
            spacing: context.tokens.gap + 4,
            runSpacing: context.tokens.gap + 4,
            children: [
              StatCard(label: context.l10n.statListened, value: fmtSpent(context.l10n, view.totalMs)),
              StatCard(label: context.l10n.statPlays, value: '${view.plays}'),
              StatCard(label: context.l10n.statStreak, value: '$streak'),
              StatCard(
                label: context.l10n.statSkips,
                value: '${(view.skipRate * 100).round()}%',
              ),
            ],
          ),
        ),
        SectionTitle(_range == _Range.week
            ? context.l10n.minutesPerDay
            : context.l10n.minutesPerDay30),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.tokens.pad),
          child: SizedBox(
            height: 120,
            child: BarChart(
              unit: context.l10n.unitMinutes,
              values: StatsView(widget.stats.events, widget.library.trackById)
                  .minutesPerDay(days),
              color: context.tokens.chartPrimary,
              labelOf: (i) {
                final d = DateTime.now().subtract(Duration(days: days - 1 - i));
                return '${d.day}';
              },
              labelEvery: days > 7 ? 5 : 1,
            ),
          ),
        ),
        SectionTitle(context.l10n.whenYouListen),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.tokens.pad),
          child: SizedBox(
            height: 100,
            child: BarChart(
              unit: context.l10n.unitMinutes,
              values: view.minutesByHour(),
              color: context.tokens.chartSecondary,
              labelOf: (i) => '$i',
              labelEvery: 3,
            ),
          ),
        ),
        if (topTracks.isNotEmpty) ...[
          SectionTitle(context.l10n.topTracks),
          for (var i = 0; i < topTracks.length; i++)
            ListTile(
              leading: Cover(track: topTracks[i].track),
              title: Text(topTracks[i].track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(topTracks[i].track.artist),
              trailing: Text(context.l10n.playsTimes(topTracks[i].plays)),
            ),
        ],
        if (topArtists.isNotEmpty) ...[
          SectionTitle(context.l10n.topArtists),
          for (var i = 0; i < topArtists.length; i++)
            ListTile(
              leading: CircleAvatar(child: Text('${i + 1}')),
              title: Text(topArtists[i].name),
              subtitle: Text(fmtSpent(context.l10n, topArtists[i].listenedMs)),
              trailing: Text(context.l10n.playsTimes(topArtists[i].plays)),
            ),
        ],
      ],
    );
  }
}
