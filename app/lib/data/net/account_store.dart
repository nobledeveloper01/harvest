import 'dart:async';

import '../../domain/net/account.dart';
import 'api.dart';

/// Where the refresh token lives between launches.
///
/// A port, because the right answer is the platform's keychain and this app
/// cannot verify either platform's from here. `shared_preferences` is
/// deliberately **not** the default: on Android it is a plain XML file in the
/// app's data directory, and a refresh token there is ninety days of somebody
/// else's account for anybody who can read it.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String? refresh);
}

/// The stand-in, which announces itself by forgetting.
///
/// It keeps the token in memory for the life of the process and no longer, so a
/// farmer signs in again on every launch. That is a nuisance and it is the
/// honest one: a driver that quietly wrote the token somewhere insecure would
/// look exactly like a working keychain until somebody read the file.
class ForgetfulTokenStore implements TokenStore {
  String? _held;

  @override
  Future<String?> read() async => _held;

  @override
  Future<void> write(String? refresh) async => _held = refresh;
}

/// What happened when the app asked to sign in.
enum SignIn { sent, badNumber, tooOften, noSignal }

/// What happened when the app offered a code.
enum Verified { signedIn, wrongCode, noSignal }

/// Signing in, staying signed in, and knowing when neither is possible.
class AccountStore {
  AccountStore({required this.api, required this.tokens});

  final Api api;
  final TokenStore tokens;

  Account? _account;
  Account? get account => _account;

  final _changes = StreamController<Account?>.broadcast();
  Stream<Account?> get changes => _changes.stream;

  /// The number a code was sent to, so the second screen can say it back.
  String? pendingPhone;

  Future<SignIn> requestCode(String typed) async {
    final phone = normalisePhone(typed);
    // Checked here as well as on the server, because an SMS is the largest
    // line in this product's operating cost and a typo should not spend one.
    if (phone == null) return SignIn.badNumber;

    final answer = await api.post('/auth/otp/request', {'phone': phone});
    if (!answer.reached) return SignIn.noSignal;
    if (answer.status == 429) return SignIn.tooOften;
    if (answer.status >= 400) return SignIn.badNumber;

    pendingPhone = phone;
    return SignIn.sent;
  }

  Future<Verified> submitCode(String code, {DateTime? now}) async {
    final phone = pendingPhone;
    if (phone == null) return Verified.wrongCode;

    final answer = await api.post('/auth/otp/verify', {
      'phone': phone,
      'code': code,
    });
    if (!answer.reached) return Verified.noSignal;
    if (answer.status != 200) return Verified.wrongCode;

    await _hold(answer, phone, now ?? DateTime.now());
    return Verified.signedIn;
  }

  /// Exchanges the refresh token, if there is one and it still works.
  ///
  /// Called at launch and before anything that needs an account. Returns
  /// whether the app is signed in afterwards — never throws, because "we could
  /// not reach the server" and "you are signed out" are different facts and
  /// only one of them should send a farmer back to the sign-in screen.
  Future<bool> restore({DateTime? now}) async {
    final refresh = await tokens.read();
    if (refresh == null) return false;

    final answer = await api.post('/auth/token/refresh', {'refresh': refresh});
    if (!answer.reached) {
      /*
        No signal is not a sign-out.

        The token is kept and the app stays as it was. Clearing it here would
        mean a farmer four days from a network is asked for an SMS code they
        cannot receive, on a phone that is otherwise working perfectly.
      */
      return _account != null;
    }
    if (answer.status != 200) {
      await signOut();
      return false;
    }

    await _hold(answer, _account?.phone ?? '', now ?? DateTime.now());
    return true;
  }

  Future<void> signOut() async {
    final refresh = await tokens.read();
    if (refresh != null) {
      // Best effort. A logout the server never hears about is a token that
      // stays valid for ninety days, so it is worth asking; but a farmer who
      // taps sign out with no signal is signed out here regardless.
      unawaited(api.post('/auth/logout', {'refresh': refresh}));
    }
    await tokens.write(null);
    api.bearer = null;
    _account = null;
    _changes.add(null);
  }

  Future<void> _hold(Answer answer, String phone, DateTime now) async {
    api.bearer = answer.body['access'] as String?;
    await tokens.write(answer.body['refresh'] as String?);
    _account = Account(
      id: answer.body['accountId'] as String? ?? '',
      phone: phone,
      tier: Tier.read(answer.body['tier'] as String?),
      // Fifteen minutes is what the server mints. Held so the app can refresh
      // *before* a request rather than discovering it during one, on a
      // connection that may not survive a second attempt.
      accessExpiresAt: now.add(const Duration(minutes: 15)),
    );
    _changes.add(_account);
  }

  Future<void> dispose() => _changes.close();
}
