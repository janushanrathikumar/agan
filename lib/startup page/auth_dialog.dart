// lib/startup page/auth_dialog.dart
//
// Sign in and sign up as one popup.
//
// A guest may browse the start page, the home page and the menu without an
// account; the popup only appears at the moment an action actually needs one,
// and the caller resumes that action when it reports success. Sign up keeps
// the SMS step inside the same popup, so nothing here ever leaves the page the
// guest was on.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../language.dart';
import '../main.dart' show AppRoutes, homeRouteForRole;
import 'signup_page.dart' show finalizeSignupMobile, finalizeSignupWeb;

const _kPrimary = Color(0xFFB59410);
const _kBg = Color(0xFF112A18);
const _kMuted = Color(0xFFA1B3A1);
const _kWhite = Color(0xFFF7F7F2);

enum AuthMode { signIn, signUp }

/// Whether a real account is signed in.
///
/// The menu signs a visitor in anonymously to hold a cart, so `currentUser`
/// alone is not the question — an anonymous session is still a guest.
bool isSignedIn() {
  final user = FirebaseAuth.instance.currentUser;
  return user != null && !user.isAnonymous;
}

/// Opens the sign in / sign up popup.
///
/// Returns true once a real account is signed in, false if the visitor closed
/// it. [reason] is shown at the top, to say which action is waiting.
Future<bool> showAuthDialog(
  BuildContext context, {
  AuthMode mode = AuthMode.signIn,
  String? reason,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.75),
    builder: (_) => _AuthDialog(initialMode: mode, reason: reason),
  );
  return result == true;
}

/// The gate in front of everything that needs an account.
///
/// Returns true straight away when somebody is already signed in; otherwise it
/// shows the popup and reports whether they signed in. Callers must run their
/// action only when this returns true.
Future<bool> requireLogin(
  BuildContext context, {
  AuthMode mode = AuthMode.signIn,
  String? reason,
}) async {
  if (isSignedIn()) return true;
  return showAuthDialog(context, mode: mode, reason: reason);
}

/// What the SMS step still needs once the code is confirmed.
class _PendingSignup {
  const _PendingSignup({
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
  });

  final String name;
  final String email;
  final String phone;
  final String password;
}

class _AuthDialog extends StatefulWidget {
  const _AuthDialog({required this.initialMode, this.reason});

  final AuthMode initialMode;
  final String? reason;

  @override
  State<_AuthDialog> createState() => _AuthDialogState();
}

class _AuthDialogState extends State<_AuthDialog> {
  late AuthMode _mode = widget.initialMode;
  bool _awaitingCode = false;

  final _identifier = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _err;

  String _country = '+41';
  static const _countries = [
    {'code': '+41', 'flag': '🇨🇭'},
    {'code': '+94', 'flag': '🇱🇰'},
    {'code': '+49', 'flag': '🇩🇪'},
  ];

  static final _emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$');
  static final _phoneRegex = RegExp(r'^\+?[1-9]\d{6,14}$');

  // The SMS step carries these over from whichever form started it.
  _PendingSignup? _pending;
  ConfirmationResult? _confirmation;
  String? _verificationId;

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ helpers

  String _withCountry(String raw) {
    final digits = raw.trim().replaceAll(RegExp(r'[\s\-]'), '');
    if (digits.startsWith('+')) return digits;
    return '$_country$digits';
  }

  void _fail(Object error) {
    if (!mounted) return;
    final message = error is FirebaseAuthException
        ? _friendlyAuthError(error)
        : error.toString().replaceAll('Exception: ', '');
    setState(() {
      _err = message;
      _busy = false;
    });
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Incorrect phone/email or password.';
      case 'invalid-email':
        return 'The email or phone format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'That code is not correct. Please check your SMS.';
      default:
        return e.message ?? 'Sign in failed. Please try again.';
    }
  }

  /// Closes the popup with success. Staff whose home is not the customer app
  /// are sent to their own board instead of being left on the menu.
  void _finish(String role) {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    navigator.pop(true);

    final home = homeRouteForRole(role);
    if (home != AppRoutes.user) {
      navigator.pushNamedAndRemoveUntil(home, (_) => false);
    }
  }

  // ------------------------------------------------------------------ sign in

  Future<void> _submitSignIn() async {
    setState(() {
      _busy = true;
      _err = null;
    });

    // Spaces and dashes are stripped so a phone number typed as 079 123-45-67
    // still matches, but an email address must be left exactly as typed - a
    // dash is a perfectly normal character in one.
    final typed = _identifier.text.trim();
    final input = typed.contains('@')
        ? typed
        : typed.replaceAll(RegExp(r'[\s\-]'), '');
    var loginEmail = input;

    try {
      if (!input.contains('@')) {
        final match = await FirebaseFirestore.instance
            .collection('user')
            .where('phone', isEqualTo: _withCountry(input))
            .limit(1)
            .get();
        if (match.docs.isEmpty) {
          throw Exception('No account found for this phone number.');
        }
        loginEmail = match.docs.first.data()['email'] as String? ?? '';
        if (loginEmail.isEmpty) {
          throw Exception('No email registered for this account.');
        }
      }

      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail,
        password: _password.text.trim(),
      );
      final user = cred.user;
      if (user == null) {
        throw Exception(AppLanguage.getText('err_user_not_found'));
      }

      final users = FirebaseFirestore.instance.collection('user');
      final snap = await users.doc(user.uid).get();
      final data = snap.data() ?? {};

      // An account whose SMS code was never confirmed finishes that step here,
      // in the same popup, rather than on a separate page.
      if (data['verified'] != true) {
        final phone = data['phone'] as String? ?? '';
        if (phone.isEmpty) {
          throw Exception(AppLanguage.getText('err_phone_not_found'));
        }
        await _startPhoneVerification(
          _PendingSignup(
            name: data['userName'] as String? ?? 'Guest',
            email: user.email ?? loginEmail,
            phone: phone.startsWith('+') ? phone : '$_country$phone',
            password: _password.text.trim(),
          ),
        );
        return;
      }

      await users.doc(user.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      TextInput.finishAutofillContext();
      _finish((data['role'] as String?)?.toLowerCase().trim() ?? 'customer');
    } catch (error) {
      _fail(error);
    }
  }

  // ------------------------------------------------------------------ sign up

  Future<void> _submitSignUp() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    final phone = _withCountry(_phone.text);

    if (name.isEmpty) {
      setState(() => _err = AppLanguage.getText('err_enter_name'));
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      setState(() => _err = 'Please enter a valid email address.');
      return;
    }
    if (!_phoneRegex.hasMatch(phone)) {
      setState(() => _err = 'Please enter a valid phone number.');
      return;
    }
    if (password.length < 6) {
      setState(() => _err = AppLanguage.getText('err_password_len'));
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      final users = FirebaseFirestore.instance.collection('user');

      final byPhone = await users
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (byPhone.docs.isNotEmpty &&
          byPhone.docs.first.data()['verified'] == true) {
        throw Exception(
          'This phone number is already registered. Please sign in instead.',
        );
      }

      final byEmail = await users
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (byEmail.docs.isNotEmpty &&
          byEmail.docs.first.data()['verified'] == true) {
        throw Exception(
          'This email is already registered. Please sign in instead.',
        );
      }

      await _startPhoneVerification(
        _PendingSignup(
          name: name,
          email: email,
          phone: phone,
          password: password,
        ),
      );
    } catch (error) {
      _fail(error);
    }
  }

  // --------------------------------------------------------------- SMS step

  Future<void> _startPhoneVerification(_PendingSignup pending) async {
    _pending = pending;

    if (kIsWeb) {
      final confirmation = await FirebaseAuth.instance.signInWithPhoneNumber(
        pending.phone,
      );
      if (!mounted) return;
      setState(() {
        _confirmation = confirmation;
        _awaitingCode = true;
        _busy = false;
        _err = null;
      });
      return;
    }

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: pending.phone,
      verificationCompleted: (_) {},
      verificationFailed: _fail,
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _awaitingCode = true;
          _busy = false;
          _err = null;
        });
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> _submitCode() async {
    final pending = _pending;
    final code = _code.text.trim();
    if (pending == null) return;
    if (code.length < 6) {
      setState(() => _err = 'Please enter the 6 digit code.');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      if (kIsWeb) {
        final cred = await _confirmation!.confirm(code);
        final user = cred.user;
        if (user == null) throw Exception('Verification failed.');
        await finalizeSignupWeb(
          user: user,
          phone: pending.phone,
          name: pending.name,
          email: pending.email,
          password: pending.password,
        );
      } else {
        await finalizeSignupMobile(
          phoneCredential: PhoneAuthProvider.credential(
            verificationId: _verificationId!,
            smsCode: code,
          ),
          phone: pending.phone,
          name: pending.name,
          email: pending.email,
          password: pending.password,
        );
      }

      // finalizeSignup* signs out on purpose, so sign the finished account
      // straight back in: the guest asked for an action, not for a login form.
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: pending.email,
        password: pending.password,
      );
      final uid = cred.user?.uid;
      var role = 'customer';
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('user')
            .doc(uid)
            .get();
        role = (snap.data()?['role'] as String?)?.toLowerCase().trim() ?? role;
      }
      _finish(role);
    } catch (error) {
      _fail(error);
    }
  }

  // ----------------------------------------------------------------- widgets

  InputDecoration _dec(String label, {IconData? icon, Widget? prefix}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: _kMuted),
        prefixIcon: prefix ?? (icon != null ? Icon(icon, color: _kMuted) : null),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: _kWhite.withOpacity(0.06),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: _kWhite.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      );

  Widget _countryPrefix() => Padding(
    padding: const EdgeInsets.only(left: 12, right: 8),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: _country,
        dropdownColor: _kBg,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _kMuted),
        items: _countries
            .map(
              (c) => DropdownMenuItem(
                value: c['code'],
                child: Text(
                  '${c['flag']} ${c['code']}',
                  style: const TextStyle(color: _kWhite, fontSize: 14),
                ),
              ),
            )
            .toList(),
        onChanged: (v) => setState(() => _country = v ?? _country),
      ),
    ),
  );

  Widget _passwordField() => TextField(
    controller: _password,
    obscureText: _obscure,
    style: const TextStyle(color: _kWhite),
    autofillHints: const [AutofillHints.password],
    decoration: _dec(
      AppLanguage.getText('password'),
      icon: Icons.lock_outline_rounded,
    ).copyWith(
      suffixIcon: IconButton(
        onPressed: () => setState(() => _obscure = !_obscure),
        icon: Icon(
          _obscure ? Icons.visibility : Icons.visibility_off,
          color: _kMuted,
        ),
      ),
    ),
  );

  List<Widget> _signInFields() => [
    TextField(
      controller: _identifier,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: _kWhite),
      autofillHints: const [
        AutofillHints.email,
        AutofillHints.telephoneNumber,
      ],
      decoration: _dec(
        AppLanguage.getText('email_or_phone'),
        prefix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countryPrefix(),
            Container(
              height: 22,
              width: 1,
              margin: const EdgeInsets.only(right: 10),
              color: _kMuted.withOpacity(0.5),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    _passwordField(),
  ];

  List<Widget> _signUpFields() => [
    TextField(
      controller: _name,
      style: const TextStyle(color: _kWhite),
      decoration: _dec(
        AppLanguage.getText('full_name'),
        icon: Icons.person_outline_rounded,
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _email,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(color: _kWhite),
      decoration: _dec(
        AppLanguage.getText('email_label'),
        icon: Icons.mail_outline_rounded,
      ),
    ),
    const SizedBox(height: 12),
    TextField(
      controller: _phone,
      keyboardType: TextInputType.phone,
      style: const TextStyle(color: _kWhite),
      decoration: _dec(
        AppLanguage.getText('phone_hint'),
        prefix: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _countryPrefix(),
            Container(
              height: 22,
              width: 1,
              margin: const EdgeInsets.only(right: 10),
              color: _kMuted.withOpacity(0.5),
            ),
          ],
        ),
      ),
    ),
    const SizedBox(height: 12),
    _passwordField(),
  ];

  List<Widget> _codeFields() => [
    Text(
      '${AppLanguage.getText('otp_sent_to')} ${_pending?.phone ?? ''}',
      textAlign: TextAlign.center,
      style: const TextStyle(color: _kMuted, fontSize: 13),
    ),
    const SizedBox(height: 14),
    TextField(
      controller: _code,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      style: const TextStyle(
        color: _kWhite,
        fontSize: 22,
        letterSpacing: 8,
        fontWeight: FontWeight.bold,
      ),
      decoration: _dec(AppLanguage.getText('otp_code')).copyWith(
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
      ),
    ),
  ];

  String get _primaryLabel {
    if (_awaitingCode) return AppLanguage.getText('verify_code');
    return _mode == AuthMode.signIn
        ? AppLanguage.getText('sign_in_title')
        : AppLanguage.getText('get_otp');
  }

  VoidCallback? get _primaryAction {
    if (_busy) return null;
    if (_awaitingCode) return _submitCode;
    return _mode == AuthMode.signIn ? _submitSignIn : _submitSignUp;
  }

  @override
  Widget build(BuildContext context) {
    final title = _awaitingCode
        ? AppLanguage.getText('verify_code')
        : _mode == AuthMode.signIn
        ? AppLanguage.getText('sign_in_title')
        : AppLanguage.getText('sign_up_title');

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _kWhite.withOpacity(0.18)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      tooltip: AppLanguage.getText('cancel'),
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close_rounded, color: _kMuted),
                    ),
                  ),
                  const Icon(
                    Icons.restaurant_rounded,
                    color: _kPrimary,
                    size: 30,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _kWhite,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.reason != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.reason!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _kMuted, fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ...(_awaitingCode
                      ? _codeFields()
                      : _mode == AuthMode.signIn
                      ? _signInFields()
                      : _signUpFields()),
                  if (_err != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _err!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _primaryAction,
                      child: _busy
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: _kWhite,
                              ),
                            )
                          : Text(
                              _primaryLabel,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (!_awaitingCode) ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _mode = _mode == AuthMode.signIn
                                  ? AuthMode.signUp
                                  : AuthMode.signIn;
                              _err = null;
                            }),
                      child: Text(
                        _mode == AuthMode.signIn
                            ? AppLanguage.getText('dont_have_account')
                            : AppLanguage.getText('already_have_account'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _kMuted, fontSize: 13),
                      ),
                    ),
                    if (_mode == AuthMode.signIn)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () {
                                Navigator.of(context).pop(false);
                                Navigator.of(
                                  context,
                                ).pushNamed(AppRoutes.forgotPassword);
                              },
                        child: Text(
                          AppLanguage.getText('forgot_password'),
                          style: const TextStyle(color: _kMuted, fontSize: 13),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
