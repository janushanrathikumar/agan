// lib/startup_page/signin_page.dart
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restorant/startup page/signupverify.dart';
import 'package:restorant/startup page/start_page.dart';
import '../language.dart';
import '../main.dart' show AppRoutes;

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class SignInPage extends StatefulWidget {
  static const route = AppRoutes.signIn;
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _emailOrPhone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _err;
  bool _obscure = true;

  String _selectedCountryCode = '+41';
  final List<Map<String, String>> _countryCodes = [
    {'code': '+41', 'flag': '🇨🇭'},
    {'code': '+94', 'flag': '🇱🇰'},
    {'code': '+49', 'flag': '🇩🇪'},
  ];

  Future<void> _loginUser() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    String input = _emailOrPhone.text.trim().replaceAll(RegExp(r'[\s\-]'), '');
    String loginEmail = input;

    try {
      if (!input.contains('@')) {
        final queryPhone = input.startsWith('+')
            ? input
            : '$_selectedCountryCode$input';
        final userQuery = await FirebaseFirestore.instance
            .collection('user')
            .where('phone', isEqualTo: queryPhone)
            .limit(1)
            .get();
        if (userQuery.docs.isEmpty) {
          throw Exception('No account found for this phone number.');
        }
        loginEmail = userQuery.docs.first.data()['email'] as String? ?? '';
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
        throw FirebaseAuthException(
          code: 'no-user',
          message: AppLanguage.getText('err_user_not_found'),
        );
      }

      final users = FirebaseFirestore.instance.collection('user');
      final snap = await users.doc(user.uid).get();
      final data = snap.data() ?? {};
      final verifiedField = data['verified'] == true;

      if (!verifiedField) {
        final phone = data['phone'] as String? ?? '';
        final userName = data['userName'] as String? ?? 'Guest';
        if (phone.isEmpty) {
          throw Exception(AppLanguage.getText('err_phone_not_found'));
        }

        final formattedPhone = phone.startsWith('+')
            ? phone
            : '$_selectedCountryCode$phone';

        if (kIsWeb) {
          ConfirmationResult confirmationResult = await FirebaseAuth.instance
              .signInWithPhoneNumber(formattedPhone);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => SignUpVerifyPage(
                verificationId: null,
                confirmationResult: confirmationResult,
                phoneNumber: formattedPhone,
                userName: userName,
                email: user.email ?? loginEmail,
                password: _password.text,
              ),
            ),
          );
        } else {
          await FirebaseAuth.instance.verifyPhoneNumber(
            phoneNumber: formattedPhone,
            verificationCompleted: (phoneAuthCredential) {},
            verificationFailed: (e) {
              if (!mounted) return;
              setState(() {
                _err = e.message;
                _busy = false;
              });
            },
            codeSent: (String verificationId, int? resendToken) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SignUpVerifyPage(
                    verificationId: verificationId,
                    confirmationResult: null,
                    phoneNumber: formattedPhone,
                    userName: userName,
                    email: user.email ?? loginEmail,
                    password: _password.text,
                  ),
                ),
              );
            },
            codeAutoRetrievalTimeout: (verificationId) {},
          );
        }
        return;
      }

      await users.doc(user.uid).set({
        'lastLogin': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final role =
          (data['role'] as String?)?.toLowerCase().trim() ?? 'customer';

      TextInput.finishAutofillContext();

      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        role == 'admin' ? AppRoutes.admin : AppRoutes.user,
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _err = _friendlyAuthError(e));
    } catch (e) {
      setState(() => _err = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
      default:
        return e.message ?? 'Sign in failed. Please try again.';
    }
  }

  void _navigateBackToStart() {
    Navigator.of(context).pushReplacementNamed(AppRoutes.start);
  }

  @override
  void dispose() {
    _emailOrPhone.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _buildCountryDropdown() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, right: 8.0),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCountryCode,
          dropdownColor: kBg,
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kMuted),
          items: _countryCodes.map((country) {
            return DropdownMenuItem(
              value: country['code'],
              child: Text(
                '${country['flag']} ${country['code']}',
                style: const TextStyle(color: kWhite, fontSize: 15),
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() => _selectedCountryCode = val);
            }
          },
        ),
      ),
    );
  }

  InputDecoration _dec(String label, {IconData? icon, Widget? prefixWidget}) =>
      InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kMuted),
        prefixIcon:
            prefixWidget ?? (icon != null ? Icon(icon, color: kMuted) : null),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        filled: true,
        fillColor: kWhite.withOpacity(0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
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

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _navigateBackToStart();
      },
      child: Scaffold(
        backgroundColor: kBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text(
            AppLanguage.getText('sign_in_title'),
            style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: kWhite,
              size: 22,
            ),
            onPressed: _navigateBackToStart,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 24.0,
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
                          child: AutofillGroup(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.restaurant_rounded,
                                  color: kPrimary,
                                  size: 32,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Restaurant Kleefeld',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: kWhite,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  AppLanguage.getText('welcome_back'),
                                  style: const TextStyle(
                                    color: kMuted,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                TextField(
                                  controller: _emailOrPhone,
                                  keyboardType: TextInputType.emailAddress,
                                  style: const TextStyle(color: kWhite),
                                  autofillHints: const [
                                    AutofillHints.email,
                                    AutofillHints.telephoneNumber,
                                  ],
                                  decoration: _dec(
                                    AppLanguage.getText('email_or_phone'),
                                    prefixWidget: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildCountryDropdown(),
                                        Container(
                                          height: 24,
                                          width: 1,
                                          color: kMuted.withOpacity(0.5),
                                          margin: const EdgeInsets.only(
                                            right: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  style: const TextStyle(color: kWhite),
                                  autofillHints: const [AutofillHints.password],
                                  decoration:
                                      _dec(
                                        AppLanguage.getText('password'),
                                        icon: Icons.lock_outline_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          onPressed: () => setState(
                                            () => _obscure = !_obscure,
                                          ),
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
                                    onPressed: _busy ? null : _loginUser,
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
                                            AppLanguage.getText(
                                              'sign_in_title',
                                            ),
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
                                  onPressed: () => Navigator.of(
                                    context,
                                  ).pushReplacementNamed(AppRoutes.signUp),
                                  child: Text(
                                    AppLanguage.getText('dont_have_account'),
                                    style: const TextStyle(
                                      color: kMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context)
                                      .pushReplacementNamed(
                                        AppRoutes.forgotPassword,
                                      ),
                                  child: Text(
                                    AppLanguage.getText('forgot_password'),
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
            ),
          ],
        ),
      ),
    );
  }
}
