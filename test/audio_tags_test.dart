import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:telemusic/audio_tags.dart';

void main() {
  test('reads title, artist, album, duration and cover from an mp3', () async {
    final tags = await readAudioTags(File('test/fixtures/tagged.mp3'));
    expect(tags.title, 'Test Song');
    expect(tags.artist, 'Test Artist');
    expect(tags.album, 'Test Album');
    expect(tags.durationSeconds, inInclusiveRange(1, 3));
    expect(tags.coverJpeg, isNotNull);
  });

  test('reads tags and cover from a flac too', () async {
    final tags = await readAudioTags(File('test/fixtures/tagged.flac'));
    expect(tags.title, 'Flac Song');
    expect(tags.artist, 'Flac Artist');
    expect(tags.coverJpeg, isNotNull);
  });

  test('a file without tags gives empty tags instead of an error', () async {
    final tags = await readAudioTags(File('test/fixtures/plain.mp3'));
    expect(tags.title, isNull);
    expect(tags.artist, isNull);
    expect(tags.coverJpeg, isNull);
  });

  test('a file that is not audio gives empty tags instead of an error', () async {
    final tmp = File('${Directory.systemTemp.createTempSync('notaudio').path}/x.mp3')
      ..writeAsStringSync('this is not audio at all');
    addTearDown(() => tmp.parent.deleteSync(recursive: true));

    final tags = await readAudioTags(tmp);
    expect(tags.title, isNull);
    expect(tags.coverJpeg, isNull);
  });

  test('a missing file gives empty tags instead of an error', () async {
    final tags = await readAudioTags(File('test/fixtures/nope.mp3'));
    expect(tags.title, isNull);
  });

  group('thumbnails fit what Telegram accepts', () {
    test('a large cover is shrunk to 320 px and stays a valid JPEG', () async {
      final tags = await readAudioTags(File('test/fixtures/tagged.mp3'));
      final decoded = img.decodeJpg(tags.coverJpeg!)!;
      expect(decoded.width, lessThanOrEqualTo(thumbnailMaxSide));
      expect(decoded.height, lessThanOrEqualTo(thumbnailMaxSide));
      expect(tags.coverJpeg!.length, lessThanOrEqualTo(thumbnailMaxBytes));
    });

    test('proportions are kept for non-square art', () {
      final wide = img.Image(width: 1000, height: 500);
      final thumb = img.decodeJpg(makeThumbnail(img.encodePng(wide))!)!;
      expect(thumb.width, thumbnailMaxSide);
      expect(thumb.height, closeTo(thumbnailMaxSide / 2, 1));
    });

    test('a small image is not enlarged', () {
      final small = img.Image(width: 64, height: 64);
      final thumb = img.decodeJpg(makeThumbnail(img.encodePng(small))!)!;
      expect(thumb.width, 64);
    });

    test('noisy art is compressed until it fits the size limit', () {
      final noisy = img.Image(width: 320, height: 320);
      var seed = 1;
      for (final p in noisy) {
        seed = (seed * 1103515245 + 12345) & 0x7fffffff;
        p
          ..r = seed & 255
          ..g = (seed >> 8) & 255
          ..b = (seed >> 16) & 255;
      }
      final thumb = makeThumbnail(img.encodePng(noisy));
      expect(thumb, isNotNull);
      expect(thumb!.length, lessThanOrEqualTo(thumbnailMaxBytes));
    });

    test('bytes that are not an image give no thumbnail', () {
      expect(makeThumbnail(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}
