import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:harvest/data/net/account_store.dart';
import 'package:harvest/data/net/api.dart';

/*
  The token on the phone has to become a session, and somebody has to ask.

  `AccountStore.restore()` has documented itself as *called at launch and before
  anything that needs an account* since Phase 5, and until now **nothing called
  it** — not the launch path, not the sign-in gate, not one test. With
  `ForgetfulTokenStore` that was invisible: a method nobody calls and a store
  that keeps nothing look exactly like each other from the outside. It took a
  real store and a relaunch on a handset to see it, where `/sync/pull` came back
  401 and nothing tried a refresh.

  So these assert the seam itself. `app_test.dart` asserts that the launch path
  calls it; this asserts what it does when it is called, including the two
  refusals that must not be confused with each other.
*/
class _Server implements Api {
  _Server(this.answers);

  final Map<String, Answer> answers;
  final List<String> asked = [];

  @override
  String? bearer;

  @override
  String get baseUrl => '';

  @override
  Dio get http => throw UnimplementedError();

  @override
  Future<Answer> post(String path, Map<String, dynamic> body) async {
    asked.add(path);
    return answers[path] ?? const Answer(status: 0, body: {});
  }

  @override
  Future<Answer> get(String path, {Map<String, dynamic>? query}) async {
    asked.add(path);
    return answers[path] ?? const Answer(status: 0, body: {});
  }
}

class _Kept implements TokenStore {
  _Kept(this._held);
  String? _held;

  @override
  Future<String?> read() async => _held;

  @override
  Future<void> write(String? refresh) async => _held = refresh;
}

/// The shape `POST /auth/token/refresh` actually returns — `server/src/routes/auth.ts`.
const _session = Answer(status: 200, body: {
  'access': 'access-1',
  'refresh': 'refresh-2',
  'accountId': 'acct-1',
});

void main() {
  test('a kept token becomes a session', () async {
    final api = _Server({'/auth/token/refresh': _session});
    final accounts =
        AccountStore(api: api, tokens: _Kept('refresh-1'));

    expect(await accounts.restore(), isTrue);
    expect(accounts.account?.id, 'acct-1');
    expect(api.asked, contains('/auth/token/refresh'));
  });

  test('no token is not a request', () async {
    final api = _Server({});
    final accounts = AccountStore(api: api, tokens: _Kept(null));

    expect(await accounts.restore(), isFalse);
    expect(api.asked, isEmpty,
        reason: 'a farmer who has never signed in is not a network call');
  });

  test('no signal keeps the token; a refusal clears it', () async {
    // Two different facts, and only one of them should send a farmer back to
    // the sign-in screen. `status: 0` is the app's "never reached".
    final offline = _Kept('refresh-1');
    await AccountStore(api: _Server({}), tokens: offline).restore();
    expect(await offline.read(), 'refresh-1',
        reason: 'four days from a signal is not a sign-out');

    final refused = _Kept('refresh-1');
    await AccountStore(
      api: _Server({'/auth/token/refresh': const Answer(status: 401, body: {})}),
      tokens: refused,
    ).restore();
    expect(await refused.read(), isNull,
        reason: 'the server says this token is dead, so it is');
  });
}
