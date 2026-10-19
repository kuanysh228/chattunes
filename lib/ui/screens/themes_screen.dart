import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/components.dart';
import '../l10n.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';
import '../theme/theme_spec.dart';

/// Pick, import, share and preview themes.
class ThemesScreen extends StatelessWidget {
  const ThemesScreen({super.key, required this.themes});

  final ThemeController themes;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themes,
      builder: (context, _) {
        final t = context.tokens;
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.themeTitle),
            actions: [
              IconButton(
                tooltip: context.l10n.reloadFiles,
                icon: const Icon(Icons.refresh),
                onPressed: themes.reload,
              ),
              PopupMenuButton<String>(
                tooltip: context.l10n.moreTooltip,
                onSelected: (v) => _menu(context, v),
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'file', child: Text(context.l10n.importFile)),
                  PopupMenuItem(value: 'paste', child: Text(context.l10n.pasteClipboard)),
                  PopupMenuItem(value: 'copy', child: Text(context.l10n.copyCurrentTheme)),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: EdgeInsets.only(bottom: t.pad * 2),
            children: [
              _FolderHint(path: themes.dir.path),
              SectionTitle(context.l10n.builtInThemes),
              _Grid(themes: themes, entries: themes.builtins),
              SectionTitle(context.l10n.myThemes),
              if (themes.userThemes.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: t.pad),
                  child: Text(context.l10n.noUserThemes),
                )
              else
                _Grid(themes: themes, entries: themes.userThemes),
            ],
          ),
        );
      },
    );
  }

  Future<void> _menu(BuildContext context, String action) async {
    try {
      switch (action) {
        case 'file':
          final picked = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['json'],
          );
          if (picked.isEmpty || picked.first.path == null) return;
          final text = await File(picked.first.path!).readAsString();
          await themes.import(text);
        case 'paste':
          final data = await Clipboard.getData(Clipboard.kTextPlain);
          final text = data?.text;
          if (text == null || text.trim().isEmpty) {
            if (context.mounted) _snack(context, context.l10n.clipboardEmpty);
            return;
          }
          await themes.import(text);
        case 'copy':
          await Clipboard.setData(ClipboardData(text: themes.exportSelected()));
          if (context.mounted) _snack(context, context.l10n.themeCopied);
      }
    } on ThemeFormatException catch (e) {
      if (context.mounted) await _showErrors(context, e.errors);
    }
  }

  void _snack(BuildContext context, String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

Future<void> _showErrors(BuildContext context, List<String> errors) => showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.themeRejected),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [for (final e in errors) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text('• $e'))],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(context.l10n.ok))],
      ),
    );

class _FolderHint extends StatelessWidget {
  const _FolderHint({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: EdgeInsets.all(t.pad),
      padding: EdgeInsets.all(t.pad - 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(t.radius),
      ),
      child: Row(
        children: [
          const Icon(Icons.folder_open),
          SizedBox(width: t.gap + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.themeFolderHint),
                SelectableText(path, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.copyPath,
            icon: const Icon(Icons.copy),
            onPressed: () => Clipboard.setData(ClipboardData(text: path)),
          ),
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.themes, required this.entries});

  final ThemeController themes;
  final List<ThemeEntry> entries;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.pad),
      child: Wrap(
        spacing: t.gap + 4,
        runSpacing: t.gap + 4,
        children: [for (final e in entries) _ThemeCard(themes: themes, entry: e)],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.themes, required this.entry});

  final ThemeController themes;
  final ThemeEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final scheme = Theme.of(context).colorScheme;
    final spec = entry.spec;
    final selected = entry.id == themes.selected.id;

    return SizedBox(
      width: 190,
      child: Material(
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radius),
          side: BorderSide(
            color: selected ? scheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radius),
          onTap: entry.usable ? () => themes.select(entry) : null,
          child: Padding(
            padding: EdgeInsets.all(t.gap + 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (spec != null)
                  ThemePreview(spec: spec, width: 170, height: 110)
                else
                  SizedBox(
                    height: 110,
                    child: Center(child: Icon(Icons.error_outline, color: scheme.error, size: 36)),
                  ),
                SizedBox(height: t.gap),
                Row(
                  children: [
                    Expanded(
                      child: Text(entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall),
                    ),
                    if (selected) Icon(Icons.check_circle, size: 18, color: scheme.primary),
                    if (!entry.builtin)
                      InkWell(
                        onTap: () => _delete(context),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.delete_outline, size: 18),
                        ),
                      ),
                  ],
                ),
                if (spec != null && spec.author.isNotEmpty)
                  Text(spec.author, style: Theme.of(context).textTheme.bodySmall),
                if (spec != null && spec.description.isNotEmpty)
                  Text(spec.description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall),
                if (entry.error != null)
                  Text(entry.error!, style: TextStyle(color: scheme.error, fontSize: 12)),
                if (spec != null)
                  for (final w in spec.warnings)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('⚠ $w',
                          style: TextStyle(color: scheme.tertiary, fontSize: 11)),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirm(
      context,
      title: context.l10n.deleteThemeTitle,
      text: context.l10n.deleteThemeBody(entry.title),
      action: context.l10n.delete,
    );
    if (ok) await themes.delete(entry);
  }
}
