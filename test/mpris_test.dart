import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemusic/media_target.dart';
import 'package:telemusic/models.dart';
import 'package:telemusic/mpris.dart';

class FakePlayer extends ChangeNotifier implements MediaTarget {
  Track? _current;
  bool _playing = false;
  QueueRepeat _repeat = QueueRepeat.off;
  bool _shuffle = false;
  final List<String> calls = [];
  Duration lastSeek = Duration.zero;
  File? cover;
  final _seeks = StreamController<Duration>.broadcast();

  void load(Track? t, {bool playing = false}) {
    _current = t;
    _playing = playing;
    notifyListeners();
  }

  @override
  Track? get current => _current;
  @override
  File? coverFor(Track track) => cover;
  @override
  bool get playing => _playing;
  @override
  bool get shuffle => _shuffle;
  @override
  QueueRepeat get repeat => _repeat;
  @override
  bool get canGoNext => true;
  bool previousAllowed = true;
  @override
  bool get canGoPrevious => previousAllowed;
  @override
  Duration get position => const Duration(seconds: 12);
  @override
  Duration? get duration => const Duration(seconds: 200);
  @override
  Stream<Duration> get seeks => _seeks.stream;

  @override
  Future<void> play() async {
    calls.add('play');
    _playing = true;
    notifyListeners();
  }

  @override
  Future<void> pause() async {
    calls.add('pause');
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> toggle() async {
    calls.add('toggle');
    _playing = !_playing;
    notifyListeners();
  }

  @override
  Future<void> stop() async => calls.add('stop');
  @override
  Future<void> next() async => calls.add('next');
  @override
  Future<void> previous() async => calls.add('previous');
  @override
  Future<void> seek(Duration position) async {
    calls.add('seek');
    lastSeek = position;
  }

  @override
  void setShuffle(bool on) {
    _shuffle = on;
    notifyListeners();
  }

  @override
  void setRepeat(QueueRepeat mode) {
    _repeat = mode;
    notifyListeners();
  }
}

Future<String> playerctl(String name, List<String> args) async {
  final r = await Process.run('playerctl', ['-p', name, ...args]);
  return (r.stdout as String).trim();
}

/// Polls until [check] passes; the bus round trip is asynchronous.
Future<void> eventually(Future<bool> Function() check, {String? reason}) async {
  final end = DateTime.now().add(const Duration(seconds: 5));
  while (DateTime.now().isBefore(end)) {
    if (await check()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail(reason ?? 'condition not met in time');
}

final track = Track(
  fileId: 'f',
  uniqueId: 'AgAD-xyz_9',
  title: 'Test Song',
  artist: 'Test Artist',
  duration: 200,
  addedAt: 0,
);

bool get _canRun {
  if (!Platform.isLinux || Platform.environment['DBUS_SESSION_BUS_ADDRESS'] == null) return false;
  return Process.runSync('which', ['playerctl']).exitCode == 0;
}

void main() {
  final skip = _canRun ? null : 'needs a D-Bus session bus and playerctl';

  group('MPRIS on the real session bus', skip: skip, () {
    late FakePlayer player;
    late MprisService service;
    late String name;

    setUp(() async {
      player = FakePlayer();
      name = 'chattunes_test_$pid';
      service = MprisService(player, name: name);
      expect(await service.start(), isTrue);
    });

    tearDown(() async {
      await service.stop();
      player.dispose();
    });

    test('shows up as a player, stopped while nothing is loaded', () async {
      final r = await Process.run('playerctl', ['-l']);
      expect(r.stdout as String, contains(name));
      expect(await playerctl(name, ['status']), 'Stopped');
    });

    test('publishes the current track as metadata', () async {
      player.load(track);

      await eventually(() async => await playerctl(name, ['metadata', 'title']) == 'Test Song');
      expect(await playerctl(name, ['metadata', 'artist']), 'Test Artist');
      expect(await playerctl(name, ['metadata', 'mpris:length']), '200000000');
      // playerctl prints object paths in quotes.
      expect(await playerctl(name, ['metadata', 'mpris:trackid']), "'/org/chattunes/track/AgAD_xyz_9'",
          reason: 'ids are made valid as D-Bus path elements');
      expect(await playerctl(name, ['status']), 'Paused');
    });

    test('exposes the cover as a file URL', () async {
      final tmp = File('${Directory.systemTemp.createTempSync('art').path}/c.jpg')..writeAsBytesSync([1]);
      addTearDown(() => tmp.parent.deleteSync(recursive: true));
      player.cover = tmp;
      player.load(track);

      await eventually(() async => (await playerctl(name, ['metadata', 'mpris:artUrl'])).startsWith('file://'));
      expect(await playerctl(name, ['metadata', 'mpris:artUrl']), tmp.uri.toString());
    });

    test('media keys control the player', () async {
      player.load(track);
      await eventually(() async => await playerctl(name, ['status']) == 'Paused');

      await playerctl(name, ['play-pause']);
      await eventually(() async => await playerctl(name, ['status']) == 'Playing');
      expect(player.calls, contains('toggle'));

      await playerctl(name, ['pause']);
      await playerctl(name, ['play']);
      await playerctl(name, ['next']);
      await playerctl(name, ['previous']);
      await playerctl(name, ['stop']);
      await eventually(() async => player.calls.contains('stop'));
      expect(player.calls, containsAllInOrder(['pause', 'play', 'next', 'previous', 'stop']));
    });

    test('previous is withheld while the player says it cannot go back', () async {
      player.previousAllowed = false;
      player.load(track);
      await eventually(() async => await playerctl(name, ['status']) == 'Paused');

      await playerctl(name, ['previous']);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(player.calls, isNot(contains('previous')));

      player.previousAllowed = true;
      player.load(track, playing: true);
      await eventually(() async => await playerctl(name, ['status']) == 'Playing');
      await playerctl(name, ['previous']);
      await eventually(() async => player.calls.contains('previous'));
    });

    test('seeking from the desktop reaches the player', () async {
      player.load(track, playing: true);
      await eventually(() async => await playerctl(name, ['status']) == 'Playing');

      await playerctl(name, ['position', '45']);
      await eventually(() async => player.calls.contains('seek'));
      expect(player.lastSeek, const Duration(seconds: 45));

      expect(double.parse(await playerctl(name, ['position'])), closeTo(12, 0.01),
          reason: 'position is read live from the player');
    });

    test('shuffle and repeat can be set from outside and are reflected back', () async {
      player.load(track);
      await playerctl(name, ['shuffle', 'On']);
      await eventually(() async => player.shuffle);
      expect(await playerctl(name, ['shuffle']), 'On');

      await playerctl(name, ['loop', 'Playlist']);
      await eventually(() async => player.repeat == QueueRepeat.all);
      await playerctl(name, ['loop', 'Track']);
      await eventually(() async => player.repeat == QueueRepeat.one);
      expect(await playerctl(name, ['loop']), 'Track');
      await playerctl(name, ['loop', 'None']);
      await eventually(() async => player.repeat == QueueRepeat.off);
    });

    test('desktop widgets are told about changes without polling', () async {
      player.load(track);
      await eventually(() async => await playerctl(name, ['status']) == 'Paused');

      final follow = await Process.start('playerctl', ['-p', name, '-F', 'status']);
      addTearDown(follow.kill);
      final lines = <String>[];
      follow.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(lines.add);

      await eventually(() async => lines.isNotEmpty, reason: 'initial status line');
      player.load(track, playing: true);
      await eventually(() async => lines.contains('Playing'), reason: 'PropertiesChanged signal');
    });

    test('a second instance with the same name does not steal the bus name', () async {
      final other = MprisService(FakePlayer(), name: name);
      expect(await other.start(), isFalse);
      expect(await playerctl(name, ['status']), 'Stopped');
    });

    test('the name is released when the service stops', () async {
      await service.stop();
      await eventually(() async => !((await Process.run('playerctl', ['-l'])).stdout as String).contains(name));
    });
  });
}
