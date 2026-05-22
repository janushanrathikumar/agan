// lib/startup_page/signupverify.dart
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:restorant/startup%20page/signin_page.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class SignUpVerifyPage extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String uid;
  final String userName;
  final String dummyEmail;

  const SignUpVerifyPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.uid,
    required this.userName,
    required this.dummyEmail,
  });

  @override
  State<SignUpVerifyPage> createState() => _SignUpVerifyPageState();
}

class _SignUpVerifyPageState extends State<SignUpVerifyPage> {
  final _otpController = TextEditingController();
  bool _busy = false;
  String? _msg;

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _msg = 'Enter a valid 6-digit OTP code');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      // 1. பயனர் உள்ளிட்ட OTP குறியீட்டை செக் செய்தல்
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        // மொபைல் எண்ணை பயனரின் கணக்குடன் லிங்க் செய்தல்
        await currentUser.linkWithCredential(credential);

        // 2. வெரிஃபிகேஷன் முடிந்தவுடன் Firestore-ல் பயனர் ப்ரோஃபைலை உருவாக்குதல்/அப்டேட் செய்தல்
        await FirebaseFirestore.instance.collection('user').doc(widget.uid).set(
          {
            'uid': widget.uid,
            'email': widget.dummyEmail,
            'phone': widget.phoneNumber,
            'userName': widget.userName,
            'role': 'customer',
            'verified': true, // வெரிஃபை ஆகிவிட்டது
            'createdAt': FieldValue.serverTimestamp(),
          },
        );

        // வெரிஃபை ஆனதும் சைன் அவுட் செய்து லாகின் பக்கத்திற்கு அனுப்புவோம்
        await FirebaseAuth.instance.signOut();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account Verified Successfully! Please Sign In.'),
          ),
        );

        Future.microtask(
          () => Navigator.pushReplacementNamed(context, SignInPage.route),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _msg = e.message);
    } catch (e) {
      setState(() => _msg = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
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
        title: const Text(
          'Verify Phone Number',
          style: TextStyle(color: kWhite),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background டிசைன்கள்...
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2A2928), Color(0xFF221F1E)],
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
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_android_rounded,
                          color: kPrimary,
                          size: 36,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Enter OTP Code',
                          style: TextStyle(
                            color: kWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'We sent a 6-digit code to\n${widget.phoneNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: kMuted),
                        ),
                        const SizedBox(height: 22),
                        // OTP Input Field
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kWhite,
                            fontSize: 22,
                            letterSpacing: 4,
                          ),
                          maxLength: 6,
                          decoration: InputDecoration(
                            counterText: "",
                            filled: true,
                            fillColor: kWhite.withOpacity(0.06),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                color: kWhite.withOpacity(0.12),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: kPrimary,
                                width: 1.4,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: kPrimary,
                            ),
                            onPressed: _busy ? null : _verifyOTP,
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
                                : const Text('Verify & Create Account'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_msg != null)
                          Text(
                            _msg!,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () => Navigator.pushReplacementNamed(
                            context,
                            SignInPage.route,
                          ),
                          child: const Text(
                            'Cancel & Back to Sign In',
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
