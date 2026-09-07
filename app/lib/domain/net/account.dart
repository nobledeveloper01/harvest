/// Who the farmer is to the server, and what they may do.
///
/// Pure, so the rules about signing in can be checked without a network: what
/// counts as a phone number here, what a tier permits, and when a token is old
/// enough to be worth refreshing.
library;

/// A Nigerian mobile number, as this app will send it.
///
/// The same normalisation the server does, on purpose. `accounts.phone` is
/// unique there, so two spellings of one number are two accounts — a farmer who
/// signed up as `0803…` and came back as `+234803…` would find their listings
/// gone. Doing it here as well means the app can tell somebody their number
/// looks wrong **before** spending an SMS on it, which is the largest line in
/// this product's operating cost.
String? normalisePhone(String input) {
  final digits = input.replaceAll(RegExp(r'[^\d]'), '');

  final String national;
  if (digits.length == 13 && digits.startsWith('234')) {
    national = digits.substring(3);
  } else if (digits.length == 11 && digits.startsWith('0')) {
    national = digits.substring(1);
  } else if (digits.length == 10) {
    national = digits;
  } else {
    return null;
  }

  if (!RegExp(r'^[789]\d{9}$').hasMatch(national)) return null;
  return '+234$national';
}

/// What the account may do, mirroring the server's tiers.
///
/// The app never decides this — it is read from the server and shown. FR-5.2:
/// *verification status MUST be visible on every buyer surface*, and a client
/// that inferred a tier would be a client that shows a badge nobody earned.
enum Tier {
  unverified('unverified'),
  verified('verified'),
  trusted('trusted'),
  suspended('suspended');

  const Tier(this.id);

  final String id;

  static Tier read(String? id) =>
      Tier.values.firstWhere((t) => t.id == id, orElse: () => Tier.unverified);

  /// Whether this account may send an enquiry.
  ///
  /// Shown, never enforced. The server decides, and the reason the app knows at
  /// all is that a button which fails after a farmer has typed a message is
  /// worse than one that explains itself first.
  bool get mayEnquire => this == Tier.verified || this == Tier.trusted;
}

/// The signed-in state, as the app holds it.
class Account {
  const Account({
    required this.id,
    required this.phone,
    required this.tier,
    required this.accessExpiresAt,
  });

  final String id;
  final String phone;
  final Tier tier;
  final DateTime accessExpiresAt;

  /// Whether the access token should be exchanged before it is used.
  ///
  /// A minute of margin, because the alternative is discovering the token
  /// expired *during* the request — and this app's connections are measured in
  /// tens of seconds, so a retry after a 401 may not get one.
  bool needsRefresh(DateTime now) =>
      !accessExpiresAt.subtract(const Duration(minutes: 1)).isAfter(now);
}
