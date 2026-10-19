import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Somewhere a secret can be kept. The real one is the system keychain.
abstract interface class SecretBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// The operating system's keychain: libsecret on Linux (GNOME Keyring, KWallet),
/// the Keychain on macOS, and so on.
class KeychainBackend implements SecretBackend {
  KeychainBackend([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Keeps the bot token in the system keychain when there is one.
///
/// Not every machine has a keychain running (a bare window manager, a
/// container), and a player that cannot remember its login is useless, so if
/// the keychain fails the token falls back to the app's settings file. [isSecure]
/// says which one is in use, and the Settings screen shows it.
class TokenVault {
  TokenVault({required this.prefs, SecretBackend? keychain}) : _keychain = keychain ?? KeychainBackend();

  static const _key = 'bot_token';

  /// Where tokens were stored before the keychain was used, and the fallback.
  static const _legacyPrefKey = 'token';

  final SharedPreferences prefs;
  final SecretBackend _keychain;

  /// True when the token currently lives in the keychain.
  bool isSecure = false;

  Future<String?> read() async {
    try {
      final fromKeychain = await _keychain.read(_key);
      if (fromKeychain != null && fromKeychain.isNotEmpty) {
        isSecure = true;
        return fromKeychain;
      }
    } catch (_) {
      // No keychain here: fall through to the settings file.
    }

    final plain = prefs.getString(_legacyPrefKey);
    if (plain == null) return null;
    // Move an old plain-text token into the keychain the first time we can.
    await write(plain);
    return plain;
  }

  Future<void> write(String token) async {
    try {
      await _keychain.write(_key, token);
      // Only trust the keychain once we can read the value back.
      if (await _keychain.read(_key) == token) {
        await prefs.remove(_legacyPrefKey);
        isSecure = true;
        return;
      }
    } catch (_) {
      // Fall back below.
    }
    isSecure = false;
    await prefs.setString(_legacyPrefKey, token);
  }

  Future<void> delete() async {
    try {
      await _keychain.delete(_key);
    } catch (_) {
      // Nothing to clean up if there is no keychain.
    }
    await prefs.remove(_legacyPrefKey);
    isSecure = false;
  }
}
