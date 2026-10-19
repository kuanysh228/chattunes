import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemusic/token_store.dart';

class FakeKeychain implements SecretBackend {
  final Map<String, String> values = {};
  bool broken = false;
  bool forgets = false;

  @override
  Future<String?> read(String key) async {
    if (broken) throw StateError('no secret service');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (broken) throw StateError('no secret service');
    if (!forgets) values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (broken) throw StateError('no secret service');
    values.remove(key);
  }
}

void main() {
  late FakeKeychain keychain;

  Future<TokenVault> vault([Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    return TokenVault(prefs: await SharedPreferences.getInstance(), keychain: keychain);
  }

  setUp(() => keychain = FakeKeychain());

  test('a saved token goes to the keychain and not to the settings file', () async {
    final v = await vault();
    await v.write('123:ABC');

    expect(await v.read(), '123:ABC');
    expect(v.isSecure, isTrue);
    expect(keychain.values.values, ['123:ABC']);
    expect(v.prefs.getString('token'), isNull);
  });

  test('an old plain-text token is moved into the keychain', () async {
    final v = await vault({'token': 'legacy:TOKEN'});

    expect(await v.read(), 'legacy:TOKEN');
    expect(v.isSecure, isTrue);
    expect(keychain.values.values, ['legacy:TOKEN']);
    expect(v.prefs.getString('token'), isNull, reason: 'the plain copy is removed after the move');
  });

  test('without a working keychain the token still works, stored plainly', () async {
    keychain.broken = true;
    final v = await vault();
    await v.write('123:ABC');

    expect(v.isSecure, isFalse);
    expect(await v.read(), '123:ABC');
    expect(v.prefs.getString('token'), '123:ABC');
  });

  test('a keychain that silently drops writes is not trusted', () async {
    keychain.forgets = true;
    final v = await vault();
    await v.write('123:ABC');

    expect(v.isSecure, isFalse);
    expect(await v.read(), '123:ABC');
  });

  test('a token stored plainly moves to the keychain once it appears', () async {
    keychain.broken = true;
    final v = await vault();
    await v.write('123:ABC');

    keychain.broken = false;
    expect(await v.read(), '123:ABC');
    expect(v.isSecure, isTrue);
    expect(v.prefs.getString('token'), isNull);
  });

  test('delete removes the token everywhere', () async {
    final v = await vault({'token': 'old'});
    await v.write('new');
    await v.delete();

    expect(await v.read(), isNull);
    expect(keychain.values, isEmpty);
    expect(v.prefs.getString('token'), isNull);
  });

  test('delete works when there is no keychain', () async {
    keychain.broken = true;
    final v = await vault();
    await v.write('x');
    await v.delete();
    expect(await v.read(), isNull);
  });

  test('nothing stored reads as null', () async {
    expect(await (await vault()).read(), isNull);
  });
}
