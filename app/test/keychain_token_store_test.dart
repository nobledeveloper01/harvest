import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/net/keychain_token_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

/*
  The driver, against a fake secure store.

  `flutter_secure_storage` talks to the platform over a method channel, so the
  channel is what a test can stand in for — and what it asserts is the three
  things this class decides: which key, that clearing deletes rather than writes
  the word "null", and that a reinstall does not inherit the last install's
  account.

  What it cannot assert is that the platform's store is actually secure, or that
  a token survives being killed. That is R14's other half and it needs a
  handset.
*/
const _channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, String> secure;
  late List<String> calls;

  setUp(() {
    secure = {};
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call.method);
      final args = (call.arguments as Map).cast<String, Object?>();
      final key = args['key'] as String?;
      switch (call.method) {
        case 'read':
          return secure[key];
        case 'write':
          secure[key!] = args['value'] as String;
          return null;
        case 'delete':
          secure.remove(key);
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  test('a token written on one launch is there on the next', () async {
    SharedPreferences.setMockInitialValues({});

    await KeychainTokenStore().write('refresh-abc');
    // A second instance is the next launch: nothing is held in memory.
    expect(await KeychainTokenStore().read(), 'refresh-abc');
    expect(secure[KeychainTokenStore.key], 'refresh-abc');
  });

  test('signing out deletes it rather than writing the word null', () async {
    SharedPreferences.setMockInitialValues({});
    final store = KeychainTokenStore();

    await store.write('refresh-abc');
    await store.write(null);

    expect(secure, isEmpty);
    expect(calls, contains('delete'));
    expect(secure.values, isNot(contains('null')),
        reason: 'a stored "null" comes back as a token the server never issued');
  });

  test('a reinstall does not inherit the last install\'s account', () async {
    /*
      The iOS Keychain survives uninstalling the app; Android's encrypted
      preferences do not. So on one platform a farmer who deletes Harvest and
      sells the phone leaves a working refresh token for whoever installs it
      next. `shared_preferences` is cleared by an uninstall on both, so its
      absence is what says "this install has not run before".
    */
    secure[KeychainTokenStore.key] = 'left-behind-by-the-last-owner';
    SharedPreferences.setMockInitialValues({});

    expect(await KeychainTokenStore().read(), isNull);
    expect(secure, isEmpty);
  });

  test('and an ordinary launch keeps the token it was left', () async {
    secure[KeychainTokenStore.key] = 'refresh-abc';
    // The flag the first run wrote, which an uninstall would have removed.
    SharedPreferences.setMockInitialValues({'auth.install.seen': true});

    expect(await KeychainTokenStore().read(), 'refresh-abc');
  });
}
