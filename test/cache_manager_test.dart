import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/cache_manager.dart';

void main() {
  late Directory dir;
  late CacheManager cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('cache_test');
    cache = CacheManager(dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  File put(String name, int bytes, DateTime modified) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(List.filled(bytes, 1));
    f.setLastModifiedSync(modified);
    return f;
  }

  test('drops the least recently used files first', () {
    final base = DateTime(2026, 1, 1);
    put('old', 100, base);
    put('mid', 100, base.add(const Duration(days: 1)));
    put('new', 100, base.add(const Duration(days: 2)));

    final deleted = cache.evict(limitBytes: 150);

    expect(deleted, 2);
    expect(File('${dir.path}/new').existsSync(), isTrue);
    expect(File('${dir.path}/old').existsSync(), isFalse);
    expect(File('${dir.path}/mid').existsSync(), isFalse);
  });

  test('never deletes protected files, even over the limit', () {
    final base = DateTime(2026, 1, 1);
    put('keep', 100, base);
    put('drop', 100, base.add(const Duration(days: 1)));

    cache.evict(limitBytes: 0, protectedIds: {'keep'});

    expect(File('${dir.path}/keep').existsSync(), isTrue);
    expect(File('${dir.path}/drop').existsSync(), isFalse);
  });

  test('does nothing while under the limit', () {
    put('a', 100, DateTime(2026, 1, 1));
    expect(cache.evict(limitBytes: 1000), 0);
  });

  test('ignores half-downloaded .part files', () {
    put('a', 100, DateTime(2026, 1, 1));
    put('b.part', 5000, DateTime(2026, 1, 1));

    expect(cache.sizeBytes(), 100);
    cache.evict(limitBytes: 0);
    expect(File('${dir.path}/b.part').existsSync(), isTrue);
  });
}
