// lib/startup_page/signup_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/startup%20page/signupverify.dart';
import '../language.dart'; // Language file இணைக்கப்பட்டுள்ளது

// லோகோ நிறங்கள்
const kPrimary = Color(0xFFE49024); // Orange
const kBg = Color(0xFF112A18); // Dark Green
const kMuted = Color(0xFFA1B3A1); // Muted Green
const kWhite = Color(0xFFF7F7F2); // Cream White

class SignUpPage extends StatefulWidget {
  static const route = '/signup';
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _obscure = true;

  final _emailRegex = RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$');

  Future<void> _registerWithPhone() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    var phone = _phone.text.trim();
    final password = _password.text.trim();

    if (name.isEmpty) {
      setState(() => _err = AppLanguage.getText('err_enter_name'));
      return;
    }
    if (email.isEmpty || !_emailRegex.hasMatch(email)) {
      setState(() => _err = 'Please enter a valid email address.');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _err = AppLanguage.getText('err_enter_phone'));
      return;
    }
    // Auto-prefix '+' so the user doesn't have to type it themselves.
    if (!phone.startsWith('+')) {
      phone = '+$phone';
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
      // Friendly pre-check: block only if a FULLY VERIFIED account already
      // exists with this phone or email. We deliberately don't create any
      // Firebase Auth account yet, so there's nothing to clean up if the
      // user abandons this screen.
      final phoneMatch = await FirebaseFirestore.instance
          .collection('user')
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();
      if (phoneMatch.docs.isNotEmpty &&
          phoneMatch.docs.first.data()['verified'] == true) {
        throw Exception(
          'This phone number is already registered. Please sign in instead.',
        );
      }

      final emailMatch = await FirebaseFirestore.instance
          .collection('user')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (emailMatch.docs.isNotEmpty &&
          emailMatch.docs.first.data()['verified'] == true) {
        throw Exception(
          'This email is already registered. Please sign in instead.',
        );
      }

      // Send the OTP. No Firebase Auth user exists yet — the account is
      // only created once the code is verified, on the next screen.
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        // Android only: fires automatically if SMS auto-retrieval succeeds
        // before the user types the code manually. We still finish account
        // creation here so the user isn't left stuck on this screen.
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            await finalizeSignup(
              phoneCredential: credential,
              phone: phone,
              name: name,
              email: email,
              password: password,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account verified automatically! Please sign in.'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacementNamed(context, '/signin');
          } catch (e) {
            if (!mounted) return;
            setState(() {
              _err = e.toString();
              _busy = false;
            });
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _err = e.message;
            _busy = false;
          });
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() => _busy = false);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SignUpVerifyPage(
                verificationId: verificationId,
                phoneNumber: phone,
                userName: name,
                email: email,
                password: password,
              ),
            ),
          );
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _err = e.message;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _err = e.toString();
        _busy = false;
      });
    }
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kMuted),
    prefixIcon: icon != null ? Icon(icon, color: kMuted) : null,
    filled: true,
    fillColor: kWhite.withOpacity(0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kWhite.withOpacity(0.15), width: 1),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: kPrimary, width: 1.5),
    ),
  );

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          AppLanguage.getText('sign_up_title'),
          style: const TextStyle(color: kWhite),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kWhite),
          onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF194D25),
                  Color(0xFF0C1E11),
                ], // Logo Dark Green Gradient
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 520 : 420),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: EdgeInsets.all(isWide ? 28 : 22),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: kWhite.withOpacity(0.15)),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.restaurant_rounded,
                                  color: kPrimary,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLanguage.getText('create_account'),
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: _name,
                              style: const TextStyle(color: kWhite),
                              decoration: _dec(
                                AppLanguage.getText('full_name'),
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: kWhite),
                              decoration: _dec(
                                'Email',
                                icon: Icons.mail_outline,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: kWhite),
                              decoration: _dec(
                                AppLanguage.getText('phone_hint'),
                                icon: Icons.phone_android_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _password,
                              obscureText: _obscure,
                              style: const TextStyle(color: kWhite),
                              decoration:
                                  _dec(
                                    AppLanguage.getText('password'),
                                    icon: Icons.lock_outline_rounded,
                                  ).copyWith(
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: kMuted,
                                      ),
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 8),
                            if (_err != null)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  _err!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                onPressed: _busy ? null : _registerWithPhone,
                                child: _busy
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                kWhite,
                                              ),
                                        ),
                                      )
                                    : Text(
                                        AppLanguage.getText('get_otp'),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/signin',
                              ),
                              child: Text(
                                AppLanguage.getText('already_have_account'),
                                style: const TextStyle(color: kMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared finalization logic used both by the auto-retrieved OTP path here
/// and the manual OTP entry in SignUpVerifyPage.
///
/// Signs in with the phone credential (creating the Firebase user, since
/// none exists yet at this point), links an email/password credential using
/// the user's REAL email so they can also log in with email+password later,
/// then writes the verified Firestore user document.
Future<void> finalizeSignup({
  required PhoneAuthCredential phoneCredential,
  required String phone,
  required String name,
  required String email,
  required String password,
}) async {
  // 1. Sign in with the phone credential. Since this phone has never been
  //    used before, Firebase creates a brand-new user here.
  final phoneSignIn = await FirebaseAuth.instance.signInWithCredential(
    phoneCredential,
  );
  final user = phoneSignIn.user;
  if (user == null) {
    throw Exception('Could not create account. Please try again.');
  }

  await user.updateDisplayName(name);

  // 2. Link the real email + password so the user can log in with either
  //    phone or email afterward.
  final emailCredential = EmailAuthProvider.credential(
    email: email,
    password: password,
  );
  try {
    await user.linkWithCredential(emailCredential);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'provider-already-linked') {
      // Already linked from a previous attempt — fine, continue.
    } else if (e.code == 'email-already-in-use') {
      throw Exception(
        'This email is already used by another account. Please sign in or use a different email.',
      );
    } else {
      rethrow;
    }
  }

  // 3. Write the verified Firestore user document.
  await FirebaseFirestore.instance.collection('user').doc(user.uid).set({
    'uid': user.uid,
    'email': email,
    'phone': phone,
    'userName': name,
    'role': 'customer',
    'verified': true,
    'createdAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await FirebaseAuth.instance.signOut();
}