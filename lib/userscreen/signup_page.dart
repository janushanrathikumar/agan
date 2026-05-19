// lib/startup_page/signup_page.dart
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/startup%20page/signupverify.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class SignUpPage extends StatefulWidget {
  static const route = '/signup';
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _obscure = true;

  Future<void> _registerEmail() async {
    // Basic validation
    if (_name.text.trim().isEmpty) {
      setState(() => _err = 'Please enter your name');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      // 1. Create user in Firebase Auth
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text.trim(),
      );

      final user = cred.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-null',
          message: 'Registration failed',
        );
      }

      // 2. Update display name in Firebase Auth
      await user.updateDisplayName(_name.text.trim());

      // 3. Send email verification
      await user.sendEmailVerification();

      // 4. Create user profile in Firestore
      final users = FirebaseFirestore.instance.collection('user');
      await users.doc(user.uid).set({
        'uid': user.uid,
        'email': user.email,
        'userName': _name.text.trim(),
        'role': 'customer', // Default role
        'verified': false, // Set to false initially
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sign out immediately so they must verify and log in
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Go to Verification Page
      Future.microtask(
        () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SignUpVerifyPage()),
        ),
      );
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
    _name.dispose();
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
        title: const Text('Sign Up', style: TextStyle(color: kWhite)),
        iconTheme: const IconThemeData(color: kWhite),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kWhite),
          onPressed: () {
            // Sign in பக்கத்திற்கு திரும்பச் செல்லுதல்
            Navigator.pushReplacementNamed(context, '/signin');
          },
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
            child: SingleChildScrollView(
              // மொபைல் கீபோர்டு வரும்போது screen overflow ஆகாமல் தடுக்க
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
                                  'Create Account',
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
                              'Sign up to get started',
                              style: TextStyle(color: kMuted, fontSize: 14),
                            ),
                            const SizedBox(height: 24),
                            // Name Field
                            TextField(
                              controller: _name,
                              keyboardType: TextInputType.name,
                              style: const TextStyle(color: kWhite),
                              cursorColor: kPrimary,
                              autofillHints: const [AutofillHints.name],
                              decoration: _dec(
                                'Full Name',
                                icon: Icons.person_outline_rounded,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Email Field
                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: kWhite),
                              cursorColor: kPrimary,
                              autofillHints: const [AutofillHints.email],
                              decoration: _dec(
                                'Email',
                                icon: Icons.mail_outline,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Password Field
                            TextField(
                              controller: _password,
                              obscureText: _obscure,
                              style: const TextStyle(color: kWhite),
                              cursorColor: kPrimary,
                              autofillHints: const [AutofillHints.newPassword],
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
                            // Sign Up Button
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
                                onPressed: _busy ? null : _registerEmail,
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
                                    : const Text('Sign Up'),
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
                            // Already have an account Button
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(
                                context,
                                '/signin',
                              ),
                              child: const Text(
                                "Already have an account? Sign in",
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
            ),
          ),
        ],
      ),
    );
  }
}
