import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_spec.dart';

/// One selectable theme: either a working [spec], or the [error] explaining
/// why a user's file could not be loaded.
class ThemeEntry {
  ThemeEntry({required this.id, required this.builtin, this.spec, this.error, this.file});

  final String id;
  final bool builtin;
  final ThemeSpec? spec;
  final String? error;
  final File? file;

  String get title => spec?.name ?? file?.uri.pathSegments.last ?? id;
  bool get usable => spec != null;
}

/// Loads built-in themes (bundled `themes/*.json`) and user themes (JSON files
/// dropped into [dir]), remembers the choice, and keeps the app's [ThemeData].
///
/// User themes are watched, so saving the file while the app runs restyles it
/// immediately. That is the whole theme-authoring loop.
class ThemeController extends ChangeNotifier {
  ThemeController({required this.prefs, required this.dir, AssetBundle? bundle})
      : _bundle = bundle ?? rootBundle;

  static const defaultId = 'builtin/chattunes-dark';
  static const _prefKey = 'theme';
  static const _assetPrefix = 'themes/';

  final SharedPreferences prefs;

  /// Where user themes live.
  final Directory dir;
  final AssetBundle _bundle;

  List<ThemeEntry> entries = [];
  late ThemeEntry selected;
  late ThemeData themeData;

  StreamSubscription<FileSystemEvent>? _watch;
  Timer? _debounce;

  List<ThemeEntry> get builtins => entries.where((e) => e.builtin).toList();
  List<ThemeEntry> get userThemes => entries.where((e) => !e.builtin).toList();

  Future<void> load() async {
    await dir.create(recursive: true);
    final found = <ThemeEntry>[
      ...await _loadBuiltins(),
      ..._loadUserThemes(),
    ];
    entries = found;
    _applySelection(prefs.getString(_prefKey));
  }

  Future<List<ThemeEntry>> _loadBuiltins() async {
    final manifest = await AssetManifest.loadFromAssetBundle(_bundle);
    final paths = manifest
        .listAssets()
        .where((p) => p.startsWith(_assetPrefix) && p.endsWith('.json'))
        .toList()
      ..sort();

    final out = <ThemeEntry>[];
    for (final path in paths) {
      final stem = _stem(path);
      try {
        final spec = ThemeSpec.parse(await _bundle.loadString(path));
        out.add(ThemeEntry(id: 'builtin/$stem', builtin: true, spec: spec));
      } on ThemeFormatException catch (e) {
        // A broken bundled theme is a bug in the app, not something to hide.
        out.add(ThemeEntry(id: 'builtin/$stem', builtin: true, error: e.toString()));
      }
    }
    // Default first, the rest by name.
    out.sort((a, b) {
      if (a.id == defaultId) return -1;
      if (b.id == defaultId) return 1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return out;
  }

  List<ThemeEntry> _loadUserThemes() {
    if (!dir.existsSync()) return [];
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    return [
      for (final f in files)
        () {
          final id = 'user/${_stem(f.path)}';
          try {
            return ThemeEntry(id: id, builtin: false, file: f, spec: ThemeSpec.parse(f.readAsStringSync()));
          } on ThemeFormatException catch (e) {
            return ThemeEntry(id: id, builtin: false, file: f, error: e.toString());
          } on FileSystemException catch (e) {
            return ThemeEntry(id: id, builtin: false, file: f, error: e.message);
          }
        }()
    ];
  }

  static String _stem(String path) {
    final name = path.split('/').last;
    return name.replaceFirst(RegExp(r'\.json$'), '');
  }

  void _applySelection(String? wanted) {
    final usable = entries.where((e) => e.usable).toList();
    selected = usable.firstWhere(
      (e) => e.id == wanted,
      orElse: () => usable.firstWhere(
        (e) => e.id == defaultId,
        // Nothing bundled at all would be a broken build; keep the app alive anyway.
        orElse: () => usable.isNotEmpty
            ? usable.first
            : ThemeEntry(id: defaultId, builtin: true, spec: ThemeSpec(name: 'Fallback')),
      ),
    );
    themeData = selected.spec!.toThemeData();
    notifyListeners();
  }

  Future<void> select(ThemeEntry entry) async {
    if (!entry.usable) return;
    await prefs.setString(_prefKey, entry.id);
    _applySelection(entry.id);
  }

  /// Re-reads user themes, e.g. after editing a file by hand.
  Future<void> reload() async {
    final keep = selected.id;
    entries = [...builtins, ..._loadUserThemes()];
    _applySelection(keep);
  }

  /// Validates [text] and saves it as a user theme. Throws
  /// [ThemeFormatException] if the theme is not usable; nothing is written then.
  Future<ThemeEntry> import(String text) async {
    final spec = ThemeSpec.parse(text);
    await dir.create(recursive: true);

    final base = _slug(spec.name);
    var file = File('${dir.path}/$base.json');
    for (var n = 2; file.existsSync(); n++) {
      file = File('${dir.path}/$base-$n.json');
    }
    await file.writeAsString(text);

    await reload();
    final entry = entries.firstWhere((e) => e.file?.path == file.path);
    await select(entry);
    return entry;
  }

  Future<void> delete(ThemeEntry entry) async {
    final file = entry.file;
    if (entry.builtin || file == null) return;
    if (file.existsSync()) await file.delete();
    final wasSelected = entry.id == selected.id;
    await reload();
    if (wasSelected) await prefs.remove(_prefKey);
    if (wasSelected) _applySelection(null);
  }

  /// The selected theme as a shareable JSON document.
  String exportSelected() => selected.spec!.toPrettyJson();

  /// Restyle live when files in [dir] change.
  void startWatching() {
    if (_watch != null) return;
    try {
      _watch = dir.watch().listen((_) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 300), reload);
      });
    } on FileSystemException {
      // Not every platform can watch; the manual Reload button still works.
    }
  }

  static String _slug(String name) {
    final s = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return s.isEmpty ? 'theme' : s;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _watch?.cancel();
    super.dispose();
  }
}
