import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemusic/ui/theme/theme_controller.dart';
import 'package:telemusic/ui/theme/theme_spec.dart';

String theme(String name, {String seed = '#FF7043'}) =>
    jsonEncode({'name': name, 'colors': {'seed': seed}});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  Future<ThemeController> make([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final c = ThemeController(prefs: await SharedPreferences.getInstance(), dir: dir);
    await c.load();
    return c;
  }

  setUp(() => dir = Directory.systemTemp.createTempSync('themes_test')..deleteSync());
  tearDown(() {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  test('ships built-in themes and starts on the default one', () async {
    final c = await make();
    expect(c.builtins.length, greaterThanOrEqualTo(5));
    expect(c.builtins.every((e) => e.usable), isTrue);
    expect(c.selected.id, ThemeController.defaultId);
    expect(c.builtins.first.id, ThemeController.defaultId, reason: 'default is listed first');
  });

  test('remembers the chosen theme across launches', () async {
    final c = await make();
    final amoled = c.builtins.firstWhere((e) => e.id == 'builtin/amoled');
    await c.select(amoled);

    final next = ThemeController(prefs: c.prefs, dir: dir);
    await next.load();
    expect(next.selected.id, 'builtin/amoled');
  });

  test('a saved theme that no longer exists falls back to the default', () async {
    final c = await make({'theme': 'user/deleted-long-ago'});
    expect(c.selected.id, ThemeController.defaultId);
  });

  test('importing saves the file, selects it and applies its colors', () async {
    final c = await make();
    final entry = await c.import(theme('Sunrise'));

    expect(entry.builtin, isFalse);
    expect(File('${dir.path}/sunrise.json').existsSync(), isTrue);
    expect(c.selected.id, entry.id);
    expect(c.userThemes.map((e) => e.title), ['Sunrise']);
    expect(c.themeData.colorScheme.primary, c.selected.spec!.colorScheme.primary);
  });

  test('importing a bad theme throws and writes nothing', () async {
    final c = await make();
    await expectLater(c.import('{"colors": {"seed": "nope"}}'), throwsA(isA<ThemeFormatException>()));
    expect(dir.listSync().whereType<File>(), isEmpty);
    expect(c.selected.id, ThemeController.defaultId);
  });

  test('two themes with the same name do not overwrite each other', () async {
    final c = await make();
    await c.import(theme('Same', seed: '#111111'));
    await c.import(theme('Same', seed: '#EEEEEE'));
    expect(c.userThemes.length, 2);
    expect(dir.listSync().length, 2);
  });

  test('a broken file is listed with its error and does not break the others', () async {
    await dir.create(recursive: true);
    File('${dir.path}/good.json').writeAsStringSync(theme('Good'));
    File('${dir.path}/bad.json').writeAsStringSync('{"name": "Bad", "shape": {"radius": 500}}');
    File('${dir.path}/notes.txt').writeAsStringSync('ignored');

    final c = await make();
    final bad = c.userThemes.firstWhere((e) => e.id == 'user/bad');
    expect(bad.usable, isFalse);
    expect(bad.error, contains('shape.radius'));
    expect(c.userThemes.firstWhere((e) => e.id == 'user/good').usable, isTrue);
    expect(c.userThemes.length, 2);

    await c.select(bad);
    expect(c.selected.id, ThemeController.defaultId, reason: 'unusable themes cannot be selected');
  });

  test('editing a theme file and reloading restyles the app', () async {
    final c = await make();
    final entry = await c.import(theme('Live', seed: '#FF0000'));
    final before = c.themeData.colorScheme.primary;

    entry.file!.writeAsStringSync(theme('Live', seed: '#0000FF'));
    await c.reload();

    expect(c.selected.id, entry.id);
    expect(c.themeData.colorScheme.primary, isNot(before));
  });

  test('breaking the selected theme file falls back instead of crashing', () async {
    final c = await make();
    final entry = await c.import(theme('Fragile'));

    entry.file!.writeAsStringSync('{ oops');
    await c.reload();

    expect(c.selected.id, ThemeController.defaultId);
    expect(c.userThemes.single.error, isNotNull);
  });

  test('deleting the selected theme returns to the default', () async {
    final c = await make();
    final entry = await c.import(theme('Temp'));
    await c.delete(entry);

    expect(entry.file!.existsSync(), isFalse);
    expect(c.userThemes, isEmpty);
    expect(c.selected.id, ThemeController.defaultId);
  });

  test('built-in themes cannot be deleted', () async {
    final c = await make();
    final before = c.builtins.length;
    await c.delete(c.builtins.first);
    expect(c.builtins.length, before);
  });

  test('exported JSON can be imported again as the same look', () async {
    final c = await make();
    final amoled = c.builtins.firstWhere((e) => e.id == 'builtin/amoled');
    await c.select(amoled);

    final copy = await c.import(c.exportSelected().replaceFirst('AMOLED Black', 'AMOLED Copy'));
    expect(copy.spec!.colorScheme, amoled.spec!.colorScheme);
    expect(copy.spec!.layout.toJson(), amoled.spec!.layout.toJson());
  });
}
