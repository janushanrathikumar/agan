// lib/startup_page/signin_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/admin/adminhome.dart';
import 'package:restorant/app_bar.dart';

import 'package:restorant/startup page/signupverify.dart';
import 'package:restorant/startup%20page/balance_user_register.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class SignInPage extends StatefulWidget {
  static const route = '/signin';
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _obscure = true;

  // In the _SignInPageState class, inside _loginEmail() function:
  Future<void> _loginEmail() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );
      var user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'no-user', message: 'User not found');
      }

      // get Firestore profile
      final users = FirebaseFirestore.instance.collection('user');
      final snap = await users.doc(user.uid).get();
      final data = snap.data() ?? {};

      // sync with Auth if needed
      await user.reload();
      user = FirebaseAuth.instance.currentUser;

      bool verifiedField = data['verified'] == true;
      final verifiedAuth = user?.emailVerified == true;

      if (!verifiedField && verifiedAuth) {
        // update Firestore since email is verified
        await users.doc(user!.uid).set({
          'verified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        verifiedField = true;
      }

      if (!verifiedField) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(
          () =>
              _err = 'Account not verified. Open the link sent to your email.',
        );
        Future.microtask(
          () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const SignUpVerifyPage()),
          ),
        );
        return;
      }

      // upsert last login
      await users.doc(user!.uid).set({
        'uid': user.uid,
        'email': user.email,
        'userName': user.displayName,
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final role = (data['role'] as String?)?.toLowerCase() ?? 'customer';

      if (!mounted) return;
      Future.microtask(() {
        // Clear navigation stack and go to the correct home screen
        Navigator.of(context).popUntil((route) => route.isFirst);
        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminHome()),
          );
        } else if (role == 'kitchen') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AppShell()),
          );
        }
      });
    } on FirebaseAuthException catch (e) {
      setState(() => _err = e.message);
    } catch (e) {
      setState(() => _err = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: kMuted),
    prefixIcon: icon != null ? Icon(icon, color: kMuted) : null,
    filled: true,
    fillColor: kWhite.withOpacity(0.06),
    hintStyle: const TextStyle(color: kMuted),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: kWhite.withOpacity(0.12), width: 1),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: kPrimary, width: 1.4),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: Colors.redAccent, width: 1.4),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: Colors.redAccent, width: 1.4),
    ),
  );

  @override
  void dispose() {
    _email.dispose();
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
        title: const Text('Sign In', style: TextStyle(color: kWhite)),
        iconTheme: const IconThemeData(color: kWhite),
        // இங்க பேக் பட்டன் (Back Button) சேர்க்கப்பட்டுள்ளது
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kWhite),
          onPressed: () => Navigator.of(context).pop(),
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
                colors: [Color(0xFF2A2928), Color(0xFF221F1E)],
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimary.withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kMuted.withOpacity(0.12),
              ),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 520 : 420),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: EdgeInsets.all(isWide ? 28 : 22),
                    decoration: BoxDecoration(
                      color: kWhite.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kWhite.withOpacity(0.10)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.35),
                          blurRadius: 24,
                          offset: const Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.coffee_rounded,
                              color: kPrimary,
                              size: 28,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Welcome back',
                              style: TextStyle(
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to continue',
                          style: TextStyle(color: kMuted, fontSize: 14),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(color: kWhite),
                          cursorColor: kPrimary,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          decoration: _dec('Email', icon: Icons.mail_outline),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _password,
                          obscureText: _obscure,
                          style: const TextStyle(color: kWhite),
                          cursorColor: kPrimary,
                          autofillHints: const [AutofillHints.password],
                          decoration:
                              _dec(
                                'Password',
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
                              foregroundColor: kWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _busy ? null : _loginEmail,
                            child: _busy
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        kWhite,
                                      ),
                                    ),
                                  )
                                : const Text('Sign In'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: kWhite.withOpacity(0.12),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                'or',
                                style: TextStyle(color: kMuted),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: kWhite.withOpacity(0.12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            '/signup',
                          ),
                          child: const Text(
                            "Don't have an account? Sign up",
                            style: TextStyle(color: kMuted),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignUpVerifyPage(),
                            ),
                          ),
                          child: const Text(
                            "Have a link? Verify now",
                            style: TextStyle(color: kMuted),
                          ),
                        ),
                      ],
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
