import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/net/account_store.dart';
import '../../data/speech/speaker.dart';
import '../../domain/net/account.dart';
import '../../domain/speech/phrase.dart';
import '../lots/keypad.dart';

/// Signing in, on the same pad the rest of the app uses.
///
/// The first screen in this product that asks a farmer for something rather
/// than telling them something, and the only one an account is needed for.
/// Everything the app is actually for — logging, the window, the alerts, the
/// calculator — works with no account at all and keeps working. This exists
/// because putting a lot in front of a stranger needs the stranger to be able
/// to reach you.
///
/// **The same keypad as the quantity and price screens.** A phone number is a
/// number; a second layout for typing one would be a second layout for a thumb
/// to learn, on a screen somebody reaches once.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    required this.accounts,
    required this.speaker,
    required this.language,
    required this.onSignedIn,
    required this.onBack,
    super.key,
  });

  final AccountStore accounts;
  final Speaker speaker;
  final Speech language;
  final VoidCallback onSignedIn;
  final VoidCallback onBack;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  var _typed = '';
  var _askingForCode = false;
  var _busy = false;
  String? _trouble;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _say(Phrase.yourNumber));
  }

  void _say(Phrase phrase) => widget.speaker.say(phrase, widget.language);

  void _press(String key) {
    if (_busy) return;
    setState(() {
      _trouble = null;
      if (key == '⌫') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
      } else if (_typed.length < (_askingForCode ? 6 : 14)) {
        _typed += key;
      }
    });
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    final outcome = await widget.accounts.requestCode(_typed);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (outcome) {
        case SignIn.sent:
          _askingForCode = true;
          _typed = '';
          _trouble = null;
        case SignIn.badNumber:
          _trouble = 'That is not a Nigerian mobile number.';
        case SignIn.tooOften:
          _trouble = 'Too many codes asked for. Wait a few minutes.';
        case SignIn.noSignal:
          _trouble = 'No network. Try again when you have signal.';
      }
    });
    if (outcome == SignIn.sent) _say(Phrase.codeSent);
  }

  Future<void> _check() async {
    setState(() => _busy = true);
    final outcome = await widget.accounts.submitCode(_typed);
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (outcome) {
        case Verified.signedIn:
          _trouble = null;
        case Verified.wrongCode:
          /*
            The code is spent, so the sentence says what to do next.

            Three wrong guesses spend it on the server whatever the app does,
            and a farmer told only "wrong" has no idea whether to retype, wait,
            or start again — while the thing they would have to do is ask for
            another one.
          */
          _typed = '';
          _trouble = 'That code is not right. Ask for another one.';
        case Verified.noSignal:
          _trouble = 'No network. Try again when you have signal.';
      }
    });
    if (outcome == Verified.signedIn) {
      _say(Phrase.signedIn);
      widget.onSignedIn();
    } else if (outcome == Verified.wrongCode) {
      _say(Phrase.wrongCode);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final freshness = Theme.of(context).extension<Freshness>()!;

    final ready = _askingForCode
        ? _typed.length == 6
        : normalisePhone(_typed) != null;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: Gap.l,
        title: BackButtonRow(onBack: widget.onBack, child: const SizedBox()),
      ),
      body: PageCanvas(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SectionQuestion(
                        icon: _askingForCode
                            ? Icons.sms_outlined
                            : Icons.phone_iphone_rounded,
                        text: _askingForCode
                            ? 'Type the code'
                            : 'What is your number?',
                      ),
                      const SizedBox(height: Gap.xs),
                      Text(
                        _askingForCode
                            ? 'Sent to ${widget.accounts.pendingPhone ?? ''}.'
                            : 'Only to reach you about a lot. Never shown to '
                                'anybody until you both agree.',
                        style: text.bodyMedium,
                      ),
                      const SizedBox(height: Gap.m),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Gap.l,
                          vertical: Gap.m,
                        ),
                        decoration: BoxDecoration(
                          color: freshness.raised,
                          borderRadius: Radii.card,
                          border: Border.all(color: freshness.outline),
                        ),
                        child: Semantics(
                          liveRegion: true,
                          /*
                            A sentence, not the digits alone.

                            The bare value collides with the keypad — a screen
                            reader, and a test, then find two things labelled
                            "0" and cannot tell the box from the key. It is also
                            the better announcement: "0" read aloud on its own
                            tells somebody nothing about what it is.
                          */
                          label: _typed.isEmpty
                              ? 'nothing typed yet'
                              : 'you typed $_typed',
                          child: ExcludeSemantics(
                            child: Text(
                              _typed.isEmpty
                                  ? (_askingForCode ? '– – – – – –' : '0…')
                                  : _typed,
                              style: text.displaySmall?.copyWith(
                                fontSize: 32,
                                color: _typed.isEmpty
                                    ? scheme.onSurfaceVariant
                                    : scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_trouble case final trouble?) ...[
                        const SizedBox(height: Gap.m),
                        Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 20, color: freshness.critical),
                            const SizedBox(width: Gap.s),
                            Expanded(
                              child: Text(
                                trouble,
                                style: text.bodyMedium
                                    ?.copyWith(color: freshness.critical),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              // Pinned, like every other pad in this app: the keys must not
              // move between digits. `DESIGN.md`, found by using it.
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.l, 0, Gap.l, Gap.m),
                child: Column(
                  children: [
                    Keypad(onPress: _press, withPoint: false),
                    const SizedBox(height: Gap.m),
                    PrimaryButton(
                      label: _askingForCode ? 'Sign in' : 'Send me a code',
                      icon: _askingForCode
                          ? Icons.check_rounded
                          : Icons.sms_outlined,
                      onPressed: ready && !_busy
                          ? (_askingForCode ? _check : _send)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
