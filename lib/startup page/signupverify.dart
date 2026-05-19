// lib/startup_page/signupverify.dart
import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:restorant/startup page/signin_page.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class SignUpVerifyPage extends StatefulWidget {
  const SignUpVerifyPage({super.key});
  @override
  State<SignUpVerifyPage> createState() => _SignUpVerifyPageState();
}

class _SignUpVerifyPageState extends State<SignUpVerifyPage> {
  bool _busy = false;
  String? _msg;
  int _cooldown = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _sendEmail(); // first send on entry
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _sendEmail() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await u.sendEmailVerification();
      setState(() => _msg = 'Verification email sent to ${u.email}.');
      _startCooldown();
    } catch (e) {
      setState(() => _msg = 'Failed to send email: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startCooldown() {
    _t?.cancel();
    setState(() => _cooldown = 60);
    _t = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _checkAndMark() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) return;
      if (u.emailVerified) {
        await FirebaseFirestore.instance.collection('user').doc(u.uid).set({
          'verified': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        Future.microtask(
          () => Navigator.pushReplacementNamed(context, SignInPage.route),
        );
      } else {
        setState(() => _msg = 'Not verified yet. Tap the link in your email.');
      }
    } catch (e) {
      setState(() => _msg = 'Check failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    final u = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Verify Account', style: TextStyle(color: kWhite)),
        iconTheme: const IconThemeData(color: kWhite),
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
                        const Icon(
                          Icons.mark_email_unread_outlined,
                          color: kPrimary,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Check your email',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          u?.email != null
                              ? 'We sent a verification link to\n${u!.email}'
                              : 'We sent a verification link to your email.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMuted),
                        ),
                        const SizedBox(height: 22),
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
                            onPressed: _busy ? null : _checkAndMark,
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
                                : const Text('I clicked the link'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: kWhite.withOpacity(0.22),
                                width: 1,
                              ),
                              foregroundColor: kWhite,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: (_busy || _cooldown > 0)
                                ? null
                                : _sendEmail,
                            child: Text(
                              _cooldown > 0
                                  ? 'Resend email ($_cooldown s)'
                                  : 'Resend email',
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_msg != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _msg!,
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Navigator.pushReplacementNamed(
                                  context,
                                  SignInPage.route,
                                ),
                          child: const Text(
                            'Back to Sign In',
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
