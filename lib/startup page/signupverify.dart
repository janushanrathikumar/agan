// lib/startup_page/signupverify.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:restorant/startup%20page/signup_page.dart';
import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class SignUpVerifyPage extends StatefulWidget {
  final String? verificationId;
  final ConfirmationResult? confirmationResult;

  final String phoneNumber;
  final String userName;
  final String password;

  const SignUpVerifyPage({
    super.key,
    required this.verificationId,
    required this.confirmationResult,
    required this.phoneNumber,
    required this.userName,
    required this.password,
  });

  @override
  State<SignUpVerifyPage> createState() => _SignUpVerifyPageState();
}

class _SignUpVerifyPageState extends State<SignUpVerifyPage> {
  final _otpController = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length < 6) {
      setState(() => _err = 'Please enter a valid 6-digit OTP.');
      return;
    }

    setState(() {
      _busy = true;
      _err = null;
    });

    try {
      if (kIsWeb) {
        if (widget.confirmationResult == null) {
          throw Exception("Confirmation setup failed.");
        }
        UserCredential userCredential = await widget.confirmationResult!
            .confirm(otp);

        await finalizeSignupWeb(
          user: userCredential.user!,
          phone: widget.phoneNumber,
          name: widget.userName,
          password: widget.password,
        );
      } else {
        if (widget.verificationId == null) {
          throw Exception("Verification ID is missing.");
        }
        PhoneAuthCredential credential = PhoneAuthProvider.credential(
          verificationId: widget.verificationId!,
          smsCode: otp,
        );

        await finalizeSignupMobile(
          phoneCredential: credential,
          phone: widget.phoneNumber,
          name: widget.userName,
          password: widget.password,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please sign in.'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pushReplacementNamed(context, '/signin');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _err = e.message ?? 'Invalid OTP code. Please try again.';
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _err = e.toString().replaceAll('Exception: ', '');
        _busy = false;
      });
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kWhite),
          onPressed: () => Navigator.pushReplacementNamed(context, '/signup'),
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
                colors: [Color(0xFF194D25), Color(0xFF0C1E11)],
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                            const Icon(
                              Icons.message_rounded,
                              color: kPrimary,
                              size: 40,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Verify your number',
                              style: TextStyle(
                                color: kWhite,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter the 6-digit code we sent to\n${widget.phoneNumber}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kMuted,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 32),
                            TextField(
                              controller: _otpController,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 24,
                                letterSpacing: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              decoration: InputDecoration(
                                counterText: "",
                                filled: true,
                                fillColor: kWhite.withOpacity(0.06),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: kWhite.withOpacity(0.15),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(
                                    color: kPrimary,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                            if (_err != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                _err!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                            const SizedBox(height: 32),
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
                                ),
                                onPressed: _busy ? null : _verifyOTP,
                                child: _busy
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: kWhite,
                                        ),
                                      )
                                    : const Text(
                                        'Verify & Complete Signup',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
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
