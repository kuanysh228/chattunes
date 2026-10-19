import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:image/image.dart' as img;

/// What we could read from an audio file's own tags.
class AudioTags {
  const AudioTags({this.title, this.artist, this.album, this.durationSeconds, this.coverJpeg});

  final String? title;
  final String? artist;
  final String? album;
  final int? durationSeconds;

  /// Embedded cover art, already shrunk to what Telegram accepts as a thumbnail.
  final Uint8List? coverJpeg;
}

/// Telegram thumbnails must be JPEG, at most 320 px on a side and 200 KB.
const thumbnailMaxSide = 320;
const thumbnailMaxBytes = 190 * 1024;

/// Reads tags and cover art off the main isolate: decoding a 5 MB cover would
/// freeze the UI. Never throws: a file without tags just yields empty tags.
Future<AudioTags> readAudioTags(File file) => Isolate.run(() => _readSync(file.path));

AudioTags _readSync(String path) {
  try {
    final meta = readMetadata(File(path), getImage: true);

    Uint8List? cover;
    if (meta.pictures.isNotEmpty) {
      final front = meta.pictures.firstWhere(
        (p) => p.pictureType == PictureType.coverFront,
        orElse: () => meta.pictures.first,
      );
      cover = makeThumbnail(front.bytes);
    }

    String? clean(String? s) {
      final t = s?.trim();
      return t == null || t.isEmpty ? null : t;
    }

    return AudioTags(
      title: clean(meta.title),
      artist: clean(meta.artist),
      album: clean(meta.album),
      durationSeconds: meta.duration?.inSeconds,
      coverJpeg: cover,
    );
  } catch (_) {
    return const AudioTags();
  }
}

/// Shrinks any decodable image to a Telegram-sized JPEG, or null if it is not
/// an image we can read.
Uint8List? makeThumbnail(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;

  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final scaled = longest <= thumbnailMaxSide
      ? decoded
      : img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? thumbnailMaxSide : null,
          height: decoded.height > decoded.width ? thumbnailMaxSide : null,
          interpolation: img.Interpolation.average,
        );

  // Drop quality until it fits; a 320 px image almost always does at the first try.
  for (final quality in [85, 70, 55, 40, 25]) {
    final jpg = Uint8List.fromList(img.encodeJpg(scaled, quality: quality));
    if (jpg.length <= thumbnailMaxBytes) return jpg;
  }
  return null;
}
