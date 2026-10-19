import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';

import 'media_target.dart';

const _rootInterface = 'org.mpris.MediaPlayer2';
const _playerInterface = 'org.mpris.MediaPlayer2.Player';
const _noTrack = '/org/mpris/MediaPlayer2/TrackList/NoTrack';

/// Publishes the player on the session bus as an MPRIS player, which is what
/// makes media keys, the desktop's player widget, Bluetooth headset buttons
/// and `playerctl` work with it.
class MprisService {
  MprisService(this.target, {this.name = 'chattunes'});

  final MediaTarget target;

  /// Bus name suffix: the player appears as `org.mpris.MediaPlayer2.<name>`.
  final String name;

  DBusClient? _client;
  _MprisObject? _object;
  StreamSubscription<Duration>? _seekSub;
  Map<String, String> _last = {};

  bool get running => _client != null;

  /// Connects and starts mirroring the player. Returns false, without
  /// throwing, when there is no session bus (other platforms, containers).
  Future<bool> start() async {
    if (_client != null) return true;
    if (!Platform.isLinux) return false;
    try {
      final client = DBusClient.session();
      final reply = await client.requestName(
        'org.mpris.MediaPlayer2.$name',
        flags: {DBusRequestNameFlag.doNotQueue},
      );
      if (reply == DBusRequestNameReply.exists || reply == DBusRequestNameReply.inQueue) {
        await client.close();
        return false;
      }
      final object = _MprisObject(target);
      await client.registerObject(object);

      _client = client;
      _object = object;
      _last = _snapshot();
      target.addListener(_onChanged);
      _seekSub = target.seeks.listen(
        (p) => object.emitSignal(_playerInterface, 'Seeked', [DBusInt64(p.inMicroseconds)]),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    target.removeListener(_onChanged);
    await _seekSub?.cancel();
    _seekSub = null;
    final client = _client;
    _client = null;
    _object = null;
    await client?.close();
  }

  Map<String, String> _snapshot() =>
      {for (final e in _object?.playerProperties().entries ?? const <MapEntry<String, DBusValue>>[]) e.key: '${e.value}'};

  /// Tells listeners only about what actually changed, as the spec asks.
  void _onChanged() {
    final object = _object;
    if (object == null) return;
    final props = object.playerProperties();
    final now = {for (final e in props.entries) e.key: '${e.value}'};
    final changed = <String, DBusValue>{
      for (final e in props.entries)
        if (_last[e.key] != now[e.key]) e.key: e.value,
    };
    _last = now;
    if (changed.isNotEmpty) {
      object.emitPropertiesChanged(_playerInterface, changedProperties: changed);
    }
  }
}

class _MprisObject extends DBusObject {
  _MprisObject(this.target) : super(DBusObjectPath('/org/mpris/MediaPlayer2'));

  final MediaTarget target;

  // ---- properties ----

  Map<String, DBusValue> rootProperties() => {
        'CanQuit': DBusBoolean(false),
        'CanRaise': DBusBoolean(false),
        'HasTrackList': DBusBoolean(false),
        'Identity': DBusString('ChatTunes'),
        'SupportedUriSchemes': DBusArray.string(const []),
        'SupportedMimeTypes': DBusArray.string(const []),
      };

  Map<String, DBusValue> playerProperties() {
    final hasTrack = target.current != null;
    return {
      'PlaybackStatus': DBusString(!hasTrack ? 'Stopped' : (target.playing ? 'Playing' : 'Paused')),
      'LoopStatus': DBusString(switch (target.repeat) {
        QueueRepeat.off => 'None',
        QueueRepeat.one => 'Track',
        QueueRepeat.all => 'Playlist',
      }),
      'Rate': DBusDouble(1.0),
      'MinimumRate': DBusDouble(1.0),
      'MaximumRate': DBusDouble(1.0),
      'Shuffle': DBusBoolean(target.shuffle),
      'Metadata': _metadata(),
      'Volume': DBusDouble(1.0),
      'CanGoNext': DBusBoolean(hasTrack && target.canGoNext),
      'CanGoPrevious': DBusBoolean(hasTrack && target.canGoPrevious),
      'CanPlay': DBusBoolean(hasTrack),
      'CanPause': DBusBoolean(hasTrack),
      'CanSeek': DBusBoolean(hasTrack),
      'CanControl': DBusBoolean(true),
    };
  }

  DBusValue _metadata() {
    final t = target.current;
    if (t == null) {
      return DBusDict.stringVariant({'mpris:trackid': DBusObjectPath(_noTrack)});
    }
    final cover = target.coverFor(t);
    final durationMs = (target.duration?.inMilliseconds ?? 0) > 0
        ? target.duration!.inMilliseconds
        : t.duration * 1000;
    return DBusDict.stringVariant({
      'mpris:trackid': DBusObjectPath(trackPath(t.uniqueId)),
      'mpris:length': DBusInt64(durationMs * 1000),
      if (cover != null) 'mpris:artUrl': DBusString(cover.uri.toString()),
      'xesam:title': DBusString(t.title),
      if (t.artist.isNotEmpty) 'xesam:artist': DBusArray.string([t.artist]),
    });
  }

  /// D-Bus object paths allow only letters, digits and underscores.
  static String trackPath(String uniqueId) =>
      '/org/chattunes/track/${uniqueId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}';

  // ---- introspection ----

  static DBusIntrospectProperty _prop(String name, String sig,
          [DBusPropertyAccess access = DBusPropertyAccess.read]) =>
      DBusIntrospectProperty(name, DBusSignature(sig), access: access);

  @override
  List<DBusIntrospectInterface> introspect() => [
        DBusIntrospectInterface(_rootInterface, methods: [
          DBusIntrospectMethod('Raise'),
          DBusIntrospectMethod('Quit'),
        ], properties: [
          _prop('CanQuit', 'b'),
          _prop('CanRaise', 'b'),
          _prop('HasTrackList', 'b'),
          _prop('Identity', 's'),
          _prop('SupportedUriSchemes', 'as'),
          _prop('SupportedMimeTypes', 'as'),
        ]),
        DBusIntrospectInterface(_playerInterface, methods: [
          DBusIntrospectMethod('Next'),
          DBusIntrospectMethod('Previous'),
          DBusIntrospectMethod('Pause'),
          DBusIntrospectMethod('PlayPause'),
          DBusIntrospectMethod('Stop'),
          DBusIntrospectMethod('Play'),
          DBusIntrospectMethod('Seek', args: [
            DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Offset'),
          ]),
          DBusIntrospectMethod('SetPosition', args: [
            DBusIntrospectArgument(DBusSignature('o'), DBusArgumentDirection.in_, name: 'TrackId'),
            DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.in_, name: 'Position'),
          ]),
          DBusIntrospectMethod('OpenUri', args: [
            DBusIntrospectArgument(DBusSignature('s'), DBusArgumentDirection.in_, name: 'Uri'),
          ]),
        ], signals: [
          DBusIntrospectSignal('Seeked', args: [
            DBusIntrospectArgument(DBusSignature('x'), DBusArgumentDirection.out, name: 'Position'),
          ]),
        ], properties: [
          _prop('PlaybackStatus', 's'),
          _prop('LoopStatus', 's', DBusPropertyAccess.readwrite),
          _prop('Rate', 'd'),
          _prop('Shuffle', 'b', DBusPropertyAccess.readwrite),
          _prop('Metadata', 'a{sv}'),
          _prop('Volume', 'd'),
          _prop('Position', 'x'),
          _prop('MinimumRate', 'd'),
          _prop('MaximumRate', 'd'),
          _prop('CanGoNext', 'b'),
          _prop('CanGoPrevious', 'b'),
          _prop('CanPlay', 'b'),
          _prop('CanPause', 'b'),
          _prop('CanSeek', 'b'),
          _prop('CanControl', 'b'),
        ]),
      ];

  // ---- calls ----

  @override
  Future<DBusMethodResponse> handleMethodCall(DBusMethodCall call) async {
    if (call.interface == _rootInterface) {
      return switch (call.name) {
        'Raise' || 'Quit' => DBusMethodSuccessResponse(),
        _ => DBusMethodErrorResponse.unknownMethod(),
      };
    }
    if (call.interface != _playerInterface) return DBusMethodErrorResponse.unknownInterface();

    switch (call.name) {
      case 'Play':
        await target.play();
      case 'Pause':
        await target.pause();
      case 'PlayPause':
        await target.toggle();
      case 'Stop':
        await target.stop();
      case 'Next':
        await target.next();
      case 'Previous':
        await target.previous();
      case 'Seek':
        final offset = (call.values[0] as DBusInt64).value;
        final to = target.position + Duration(microseconds: offset);
        await target.seek(to < Duration.zero ? Duration.zero : to);
      case 'SetPosition':
        final id = (call.values[0] as DBusObjectPath).value;
        final pos = (call.values[1] as DBusInt64).value;
        final t = target.current;
        // Per spec, ignore a position meant for a track that is no longer current.
        if (t != null && id == trackPath(t.uniqueId) && pos >= 0) {
          await target.seek(Duration(microseconds: pos));
        }
      case 'OpenUri':
        break;
      default:
        return DBusMethodErrorResponse.unknownMethod();
    }
    return DBusMethodSuccessResponse();
  }

  @override
  Future<DBusMethodResponse> getProperty(String interface, String name) async {
    final value = _allFor(interface)[name];
    if (value == null) return DBusMethodErrorResponse.unknownProperty();
    return DBusGetPropertyResponse(value);
  }

  @override
  Future<DBusMethodResponse> getAllProperties(String interface) async =>
      DBusGetAllPropertiesResponse(_allFor(interface));

  Map<String, DBusValue> _allFor(String interface) {
    if (interface == _rootInterface) return rootProperties();
    if (interface == _playerInterface) {
      return {
        ...playerProperties(),
        'Position': DBusInt64(target.position.inMicroseconds),
      };
    }
    return {};
  }

  @override
  Future<DBusMethodResponse> setProperty(String interface, String name, DBusValue value) async {
    if (interface != _playerInterface) return DBusMethodErrorResponse.unknownProperty();
    switch (name) {
      case 'Shuffle':
        target.setShuffle((value as DBusBoolean).value);
      case 'LoopStatus':
        target.setRepeat(switch ((value as DBusString).value) {
          'Track' => QueueRepeat.one,
          'Playlist' => QueueRepeat.all,
          _ => QueueRepeat.off,
        });
      case 'Volume':
        break; // Volume belongs to the system mixer; accepted and ignored.
      default:
        return DBusMethodErrorResponse.propertyReadOnly();
    }
    return DBusMethodSuccessResponse();
  }
}
