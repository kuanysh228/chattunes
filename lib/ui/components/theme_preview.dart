import 'package:flutter/material.dart';

import '../theme/layout_spec.dart';
import '../theme/theme_spec.dart';

/// A small card showing a theme: a wireframe of where its regions sit, and
/// its main colors. Built from the spec alone, so it works for any theme file.
class ThemePreview extends StatelessWidget {
  const ThemePreview({super.key, required this.spec, this.width = 150, this.height = 110});

  final ThemeSpec spec;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = spec.colorScheme;
    final tokens = spec.tokens;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(tokens.radius.clamp(2, 16)),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Expanded(child: _node(spec.layout.shellFor(0), scheme, Axis.vertical)),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final c in [scheme.primary, scheme.secondary, scheme.tertiary, tokens.favorite])
                Expanded(
                  child: Container(
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: c,
                      borderRadius: BorderRadius.circular(tokens.radius.clamp(0, 4)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _node(ShellNode node, ColorScheme scheme, Axis parent) {
    switch (node) {
      case ShellLeaf(:final region):
        final color = switch (region) {
          ShellRegion.header => scheme.secondaryContainer,
          ShellRegion.content => scheme.surfaceContainerHigh,
          ShellRegion.navigation => scheme.primaryContainer,
          ShellRegion.player => scheme.primary,
        };
        final box = Container(
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        );
        // Content stretches; the others take a thin slice like in the real app.
        if (region == ShellRegion.content) return Expanded(child: box);
        return SizedBox(
          width: parent == Axis.horizontal ? 12 : null,
          height: parent == Axis.vertical ? 9 : null,
          child: box,
        );
      case ShellBox(:final axis, :final children):
        final a = axis == ShellAxis.row ? Axis.horizontal : Axis.vertical;
        // Nested boxes share the space; leaves size themselves (content stretches).
        final kids = [
          for (final c in children)
            c is ShellBox ? Expanded(child: _node(c, scheme, a)) : _node(c, scheme, a),
        ];
        return Flex(direction: a, children: kids);
    }
  }
}
