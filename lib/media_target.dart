import 'dart:io';

import 'package:flutter/foundation.dart';

import 'models.dart';

enum QueueRepeat { off, all, one }

/// What the operating system's media controls (media keys, the shell's player
/// widget, `playerctl`) need from the player. Keeping it an interface lets the
/// system integration be tested with a fake player.
abstract interface class MediaTarget implements Listenable {
  Track? get current;

  /// Cover image of [track], if one is downloaded.
  File? coverFor(Track track);

  bool get playing;
  bool get shuffle;
  QueueRepeat get repeat;
  bool get canGoNext;
  bool get canGoPrevious;

  Duration get position;
  Duration? get duration;

  /// Fires when the position jumps because the user sought, not on normal playback.
  Stream<Duration> get seeks;

  Future<void> play();
  Future<void> pause();
  Future<void> toggle();
  Future<void> stop();
  Future<void> next();
  Future<void> previous();
  Future<void> seek(Duration position);
  void setShuffle(bool on);
  void setRepeat(QueueRepeat mode);
}
