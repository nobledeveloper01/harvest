import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_store.dart';

/// The refresh token, in the platform's own secure store.
///
/// R14. `ForgetfulTokenStore` kept it in memory and announced itself by
/// forgetting, so every restart signed the farmer out and the whole marketplace
/// — inbox, enquiries, deals — was unreachable on the second launch. The
/// placeholder was honest and the feature behind it was not usable.
///
/// **Not `shared_preferences`.** On Android that is a plain XML file in the
/// app's data directory, and a refresh token there is ninety days of somebody
/// else's account for anybody who can read it. This is EncryptedSharedPreferences
/// on Android — a key held in the hardware-backed Keystore — and the Keychain
/// on iOS.
class KeychainTokenStore implements TokenStore {
  KeychainTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              // Without this, Android 9.2.x falls back to plain
              // SharedPreferences with a locally-derived key — which is the
              // thing this class exists not to be.
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                /*
                  `first_unlock_this_device`, and both halves matter.

                  *first unlock* rather than *unlocked*: the token has to be
                  readable when the app is woken by a spoilage alert with the
                  phone in a pocket, which is most of the time it is woken.

                  *this device* rather than plain: it keeps the token out of
                  iCloud and iTunes backups, so a restore onto a second handset
                  does not carry somebody's account with it.
                */
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  final FlutterSecureStorage _storage;

  /// Where the token lives inside the secure store.
  static const key = 'auth.refresh';

  /// Set the first time this **install** runs, in a store that uninstalling
  /// clears. See [_forgetIfReinstalled].
  static const _installed = 'auth.install.seen';

  bool _checked = false;

  @override
  Future<String?> read() async {
    await _forgetIfReinstalled();
    return _storage.read(key: key);
  }

  @override
  Future<void> write(String? refresh) async {
    await _forgetIfReinstalled();
    // Deleted rather than written as the string "null", which is what
    // `write(value: null)` does on some of this plugin's platforms and which
    // would come back as a token the server has never heard of.
    if (refresh == null) {
      await _storage.delete(key: key);
    } else {
      await _storage.write(key: key, value: refresh);
    }
  }

  /*
    A reinstall must not inherit the last owner's account.

    The iOS Keychain **survives uninstalling the app** — deliberately, and it
    surprises everybody. Android's EncryptedSharedPreferences does not. So on
    one platform a farmer who sells their phone after deleting the app leaves a
    working refresh token behind for whoever installs Harvest next, and on the
    other they do not.

    `shared_preferences` is cleared by an uninstall on both, so a flag there is
    a reliable answer to *has this install run before*. If it is missing and the
    secure store is not, the store belongs to an install that is gone.

    Once per process: this is on the path of every token read.
  */
  Future<void> _forgetIfReinstalled() async {
    if (_checked) return;
    _checked = true;
    final settings = await SharedPreferences.getInstance();
    if (settings.getBool(_installed) ?? false) return;
    await _storage.delete(key: key);
    await settings.setBool(_installed, true);
  }
}
