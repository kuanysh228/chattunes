import 'dart:io';

/// Keeps the audio cache under a size limit by deleting least recently used files.
///
/// A file's modification time doubles as its last-played time: the player
/// touches it on every play, so no separate index is needed.
class CacheManager {
  CacheManager(this.dir);

  final Directory dir;

  Iterable<File> _files() => dir.existsSync()
      ? dir.listSync().whereType<File>().where((f) => !f.path.endsWith('.part'))
      : const [];

  int sizeBytes() => _files().fold(0, (s, f) => s + f.lengthSync());

  /// Deletes oldest files until the cache fits [limitBytes]. Files whose name
  /// is in [protectedIds] are never removed, even if that leaves it too big.
  /// Returns how many files were deleted.
  int evict({required int limitBytes, Set<String> protectedIds = const {}}) {
    final files = _files().toList();
    var total = files.fold<int>(0, (s, f) => s + f.lengthSync());
    if (total <= limitBytes) return 0;

    files.sort((a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()));
    var deleted = 0;
    for (final f in files) {
      if (total <= limitBytes) break;
      final id = f.uri.pathSegments.last;
      if (protectedIds.contains(id)) continue;
      final size = f.lengthSync();
      try {
        f.deleteSync();
        total -= size;
        deleted++;
      } on FileSystemException {
        // In use or already gone; try the next candidate.
      }
    }
    return deleted;
  }

  int clear({Set<String> protectedIds = const {}}) =>
      evict(limitBytes: 0, protectedIds: protectedIds);
}
