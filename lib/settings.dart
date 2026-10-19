import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs)
      : prefetchCount = _prefs.getInt('prefetch') ?? 2,
        cacheLimitMb = _prefs.getInt('cache_mb') ?? 2048,
        autoplay = _prefs.getBool('autoplay') ?? true,
        favoritesOffline = _prefs.getBool('fav_offline') ?? false;

  final SharedPreferences _prefs;

  /// How many upcoming queue items to download ahead.
  int prefetchCount;
  int cacheLimitMb;

  /// When the queue runs out, keep going with recommended tracks.
  bool autoplay;

  /// Keep every favorite downloaded.
  bool favoritesOffline;

  int get cacheLimitBytes => cacheLimitMb * 1024 * 1024;

  Future<void> setPrefetch(int v) async {
    prefetchCount = v;
    notifyListeners();
    await _prefs.setInt('prefetch', v);
  }

  Future<void> setCacheLimitMb(int v) async {
    cacheLimitMb = v;
    notifyListeners();
    await _prefs.setInt('cache_mb', v);
  }

  Future<void> setAutoplay(bool v) async {
    autoplay = v;
    notifyListeners();
    await _prefs.setBool('autoplay', v);
  }

  Future<void> setFavoritesOffline(bool v) async {
    favoritesOffline = v;
    notifyListeners();
    await _prefs.setBool('fav_offline', v);
  }
}
