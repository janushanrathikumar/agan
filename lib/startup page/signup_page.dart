// lib/startup_page/signup_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/startup%20page/signupverify.dart';
import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

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

  // --- NEW: Language Toggle Method ---
  void _toggleLanguage() {
    setState(() {
      AppLanguage.currentLanguage = (AppLanguage.currentLanguage == 'de')
          ? 'en'
          : 'de';
    });
  }

  // ── 100% Original Logic Retained ──
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

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
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
                content: Text(
                  'Account verified automatically! Please sign in.',
                ),
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

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  // ── Neat Input Decoration ──
  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kMuted),
    prefixIcon: icon != null ? Icon(icon, color: kMuted) : null,
    filled: true,
    fillColor: kWhite.withOpacity(0.06),
    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kWhite.withOpacity(0.15), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          AppLanguage.getText('sign_up_title'),
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kWhite,
            size: 22,
          ),
          onPressed: () => Navigator.pushReplacementNamed(context, '/signin'),
        ),
        //   // --- NEW: Language Toggle Button Added Here ---
        //   actions: [
        //     Padding(
        //       padding: const EdgeInsets.only(right: 16.0),
        //       child: Center(
        //         child: Container(
        //           decoration: BoxDecoration(
        //             color: kWhite.withOpacity(0.1),
        //             borderRadius: BorderRadius.circular(20),
        //             border: Border.all(color: kWhite.withOpacity(0.2)),
        //           ),
        //           child: InkWell(
        //             borderRadius: BorderRadius.circular(20),
        //             onTap: _toggleLanguage,
        //             child: Padding(
        //               padding: const EdgeInsets.symmetric(
        //                 horizontal: 14,
        //                 vertical: 7,
        //               ),
        //               child: Row(
        //                 children: [
        //                   const Icon(Icons.language, color: kWhite, size: 16),
        //                   const SizedBox(width: 6),
        //                   Text(
        //                     AppLanguage.getText('lang_toggle'),
        //                     style: const TextStyle(
        //                       color: kWhite,
        //                       fontWeight: FontWeight.bold,
        //                       fontSize: 13,
        //                     ),
        //                   ),
        //                 ],
        //               ),
        //             ),
        //           ),
        //         ),
        //       ),
        //     ),
        //   ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isWide ? 460 : 400),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: kWhite.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: kWhite.withOpacity(0.2)),
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
                                  size: 30,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  AppLanguage.getText('create_account'),
                                  style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            TextField(
                              controller: _name,
                              style: const TextStyle(color: kWhite),
                              decoration: _dec(
                                AppLanguage.getText('full_name'),
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: kWhite),
                              decoration: _dec(
                                'Email',
                                icon: Icons.mail_outline,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(color: kWhite),
                              decoration: _dec(
                                AppLanguage.getText('phone_hint'),
                                icon: Icons.phone_android_rounded,
                              ),
                            ),
                            const SizedBox(height: 16),
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
                            const SizedBox(height: 28),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: kPrimary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 2,
                                ),
                                onPressed: _busy ? null : _registerWithPhone,
                                child: _busy
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: kWhite,
                                        ),
                                      )
                                    : Text(
                                        AppLanguage.getText('get_otp'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/signin',
                              ),
                              child: Text(
                                AppLanguage.getText('already_have_account'),
                                style: const TextStyle(
                                  color: kMuted,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
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

// ── 100% Original Helper Logic Retained ──
Future<void> finalizeSignup({
  required PhoneAuthCredential phoneCredential,
  required String phone,
  required String name,
  required String email,
  required String password,
}) async {
  final phoneSignIn = await FirebaseAuth.instance.signInWithCredential(
    phoneCredential,
  );
  final user = phoneSignIn.user;
  if (user == null) {
    throw Exception('Could not create account. Please try again.');
  }

  await user.updateDisplayName(name);

  final emailCredential = EmailAuthProvider.credential(
    email: email,
    password: password,
  );
  try {
    await user.linkWithCredential(emailCredential);
  } on FirebaseAuthException catch (e) {
    if (e.code == 'provider-already-linked') {
    } else if (e.code == 'email-already-in-use') {
      throw Exception(
        'This email is already used by another account. Please sign in or use a different email.',
      );
    } else {
      rethrow;
    }
  }

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
