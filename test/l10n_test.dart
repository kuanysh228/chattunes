import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/library_store.dart';
import 'package:telemusic/recommender.dart';
import 'package:telemusic/telegram_api.dart';
import 'package:telemusic/ui/l10n.dart';

Map<String, dynamic> arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> messageKeys(Map<String, dynamic> m) =>
    m.keys.where((k) => !k.startsWith('@')).toSet();

/// `{name}` placeholders used by a message, ignoring ICU plural/select syntax.
Set<String> placeholders(String message) {
  final names = <String>{};
  // Plural arguments: {count, plural, ...}
  for (final m in RegExp(r'\{(\w+),\s*(?:plural|select)').allMatches(message)) {
    names.add(m.group(1)!);
  }
  // Simple arguments: {name}
  for (final m in RegExp(r'\{(\w+)\}').allMatches(message)) {
    names.add(m.group(1)!);
  }
  return names;
}

void main() {
  group('translation files', () {
    final en = arb('en');
    final languages = [
      for (final f in Directory('lib/l10n').listSync().whereType<File>())
        if (RegExp(r'app_(\w+)\.arb$').hasMatch(f.path) && !f.path.endsWith('app_en.arb'))
          RegExp(r'app_(\w+)\.arb$').firstMatch(f.path)!.group(1)!
    ];

    test('there is at least one translation besides English', () {
      expect(languages, contains('ru'));
    });

    test('every language in the picker has a translation file and vice versa', () {
      expect({'en', ...languages}, languageNames.keys.toSet());
    });

    for (final lang in languages) {
      group(lang, () {
        final tr = arb(lang);

        test('has every English string and no extras', () {
          expect(messageKeys(tr), messageKeys(en));
        });

        test('uses the same placeholders as the English text', () {
          for (final key in messageKeys(en)) {
            expect(placeholders(tr[key] as String), placeholders(en[key] as String),
                reason: 'placeholders differ in "$key"');
          }
        });

        test('has no empty strings', () {
          for (final key in messageKeys(en)) {
            expect((tr[key] as String).trim(), isNotEmpty, reason: key);
          }
        });

        test('is actually translated, not copied English', () {
          // Brand and symbol-only strings may legitimately match.
          const same = {'appName', 'ok', 'playsTimes'};
          for (final key in messageKeys(en)) {
            if (same.contains(key) || en[key] != tr[key]) continue;
            expect(RegExp(r'[A-Za-z]{3,}').hasMatch(en[key] as String), isFalse,
                reason: '"$key" is identical to English');
          }
        });
      });
    }

    test('English strings contain no Cyrillic (a sign of a swapped file)', () {
      final cyrillic = RegExp(r'[А-Яа-яЁё]');
      for (final key in messageKeys(en)) {
        expect(cyrillic.hasMatch(en[key] as String), isFalse, reason: key);
      }
    });
  });

  test('no user-visible Russian is hardcoded in the code', () {
    // Text belongs in lib/l10n/*.arb. Only language names (shown in their own
    // language) and generated files may contain Cyrillic.
    final cyrillic = RegExp(r'[А-Яа-яЁё]');
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      if (f.path.contains('lib/l10n/')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (cyrillic.hasMatch(line) && !line.contains("'ru': 'Русский'")) {
          offenders.add('${f.path}:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: 'move these strings into the ARB files:\n${offenders.join('\n')}');
  });

  group('plurals', () {
    test('Russian picks the right word form', () async {
      final l = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(l.trackCount(1), '1 трек');
      expect(l.trackCount(2), '2 трека');
      expect(l.trackCount(5), '5 треков');
      expect(l.trackCount(11), '11 треков');
      expect(l.trackCount(21), '21 трек');
      expect(l.trackCount(22), '22 трека');
      expect(l.trackCount(0), 'Нет треков');
    });

    test('English handles one and many', () async {
      final l = await AppLocalizations.delegate.load(const Locale('en'));
      expect(l.trackCount(1), '1 track');
      expect(l.trackCount(3), '3 tracks');
      expect(l.trackCount(0), 'No tracks');
      expect(l.reasonNotPlayedDays(1), 'not played for 1 day');
      expect(l.reasonNotPlayedDays(30), 'not played for 30 days');
    });

    test('Russian day counts decline correctly', () async {
      final l = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(l.reasonNotPlayedDays(1), 'не слушали 1 день');
      expect(l.reasonNotPlayedDays(3), 'не слушали 3 дня');
      expect(l.reasonNotPlayedDays(21), 'не слушали 21 день');
      expect(l.reasonNotPlayedDays(30), 'не слушали 30 дней');
    });
  });

  group('text built from logic values', () {
    late AppLocalizations en;
    late AppLocalizations ru;

    setUpAll(() async {
      en = await AppLocalizations.delegate.load(const Locale('en'));
      ru = await AppLocalizations.delegate.load(const Locale('ru'));
    });

    test('every recommendation reason has a translation in both languages', () {
      for (final kind in RecReasonKind.values) {
        final r = RecReason(kind, days: 5, artist: 'Band');
        expect(reasonText(en, r), isNotEmpty);
        expect(reasonText(ru, r), isNotEmpty);
        expect(reasonText(en, r), isNot(reasonText(ru, r)));
      }
      expect(reasonText(en, const RecReason(RecReasonKind.newFromArtist, artist: 'Marlow')),
          'new from Marlow');
      expect(reasonText(ru, const RecReason(RecReasonKind.newFromArtist, artist: 'Marlow')),
          'новое у «Marlow»');
    });

    test('Telegram errors we raise are translated, Telegram\'s own are kept', () {
      for (final kind in TelegramErrorKind.values) {
        final e = TelegramException('raw $kind', kind: kind, code: 404);
        if (kind == TelegramErrorKind.api) {
          expect(errorText(en, e), 'raw $kind');
          expect(errorText(ru, e), 'raw $kind');
        } else {
          expect(errorText(en, e), isNot(startsWith('raw')));
          expect(errorText(ru, e), isNot(errorText(en, e)));
        }
      }
      expect(errorText(en, TelegramException('x', kind: TelegramErrorKind.downloadFailed, code: 404)),
          'Download failed (404)');
    });

    test('upload progress and connection status read naturally', () {
      expect(statusText(en, const LibraryStatus.uploading(2, 5, 'a.mp3')), 'Uploading 2/5: a.mp3');
      expect(statusText(ru, const LibraryStatus.uploading(2, 5, 'a.mp3')), 'Загрузка 2/5: a.mp3');
      expect(statusText(en, const LibraryStatus.noConnection()), 'No connection');
    });

    test('listening totals use the language\'s units', () {
      expect(fmtSpent(en, 45 * 60000), '45 min');
      expect(fmtSpent(en, 200 * 60000), '3 h 20 min');
      expect(fmtSpent(ru, 120 * 60000), '2 ч');
      expect(fmtSpent(ru, 200 * 60000), '3 ч 20 мин');
    });
  });
}
