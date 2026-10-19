import 'package:flutter/material.dart';

/// Minimal bar chart: one bar per value, scaled to the largest.
class BarChart extends StatelessWidget {
  const BarChart({
    super.key,
    required this.values,
    required this.color,
    required this.labelOf,
    required this.labelEvery,
    required this.unit,
  });

  final List<double> values;
  final Color color;
  final String Function(int) labelOf;
  final int labelEvery;
  final String unit;

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
              message: '${values[i].round()} $unit',
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
