// lib/startup_page/balance_user_register.dart
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:restorant/app_bar.dart'; // for AppShell

// Palette
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class BalanceUserRegisterPage extends StatefulWidget {
  const BalanceUserRegisterPage({super.key});

  @override
  State<BalanceUserRegisterPage> createState() =>
      _BalanceUserRegisterPageState();
}

class _BalanceUserRegisterPageState extends State<BalanceUserRegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _address = TextEditingController();

  String? _gender; // 'male' | 'female' | 'other'
  DateTime? _birthday;

  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return;

    // Auth defaults
    _name.text = (u.displayName ?? '').trim();
    _email.text = (u.email ?? '').trim();

    // Firestore overrides if present
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user')
          .doc(u.uid)
          .get();
      final data = doc.data();
      if (data != null) {
        if ((data['userName'] as String?)?.trim().isNotEmpty ?? false) {
          _name.text = (data['userName'] as String).trim();
        }
        if ((data['email'] as String?)?.trim().isNotEmpty ?? false) {
          _email.text = (data['email'] as String).trim();
        }
        _mobile.text = (data['mobile'] as String?) ?? '';
        _address.text = (data['address'] as String?) ?? '';
        _gender = (data['gender'] as String?)?.toLowerCase();
        final b = data['birthday'];
        if (b is Timestamp) _birthday = b.toDate();
        if (b is String && b.isNotEmpty) _birthday = DateTime.tryParse(b);
        setState(() {});
      }
    } catch (_) {}
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
      borderSide: BorderSide(color: kWhite.withOpacity(0.12)),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: kPrimary, width: 1.4),
    ),
  );

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final initial = _birthday ?? DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 100, 1, 1);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kPrimary,
              surface: kBg,
              onSurface: kWhite,
              onPrimary: kWhite,
            ),
            dialogBackgroundColor: kBg,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  Future<void> _saveAndContinue() async {
    if (!_form.currentState!.validate()) return;
    if (_gender == null) {
      setState(() => _msg = 'Select gender.');
      return;
    }
    if (_birthday == null) {
      setState(() => _msg = 'Select birthday.');
      return;
    }

    setState(() {
      _busy = true;
      _msg = null;
    });

    try {
      final u = FirebaseAuth.instance.currentUser;
      if (u == null) throw Exception('Not signed in');

      // keep Auth displayName in sync
      if (_name.text.trim().isNotEmpty &&
          _name.text.trim() != (u.displayName ?? '').trim()) {
        await u.updateDisplayName(_name.text.trim());
      }

      await FirebaseFirestore.instance.collection('user').doc(u.uid).set({
        'uid': u.uid,
        'email': _email.text.trim(),
        'userName': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'address': _address.text.trim(),
        'gender': _gender,
        'birthday': Timestamp.fromDate(_birthday!),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      // go to app shell
      Future.microtask(() {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AppShell()),
        );
      });
    } catch (e) {
      setState(() => _msg = 'Save failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _mobile.dispose();
    _address.dispose();
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
          'Complete your profile',
          style: TextStyle(color: kWhite),
        ),
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
              constraints: BoxConstraints(maxWidth: isWide ? 620 : 480),
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
                    child: Form(
                      key: _form,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Tell us about you',
                            style: TextStyle(
                              color: kWhite,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Name
                          TextFormField(
                            controller: _name,
                            style: const TextStyle(color: kWhite),
                            cursorColor: kPrimary,
                            decoration: _dec(
                              'Name',
                              icon: Icons.badge_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter your name'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Email (read-only)
                          TextFormField(
                            controller: _email,
                            readOnly: true,
                            style: const TextStyle(color: kWhite),
                            decoration: _dec(
                              'Email',
                              icon: Icons.mail_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Mobile
                          TextFormField(
                            controller: _mobile,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(color: kWhite),
                            cursorColor: kPrimary,
                            decoration: _dec(
                              'Mobile number',
                              icon: Icons.phone_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter mobile number'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Address
                          TextFormField(
                            controller: _address,
                            maxLines: 2,
                            style: const TextStyle(color: kWhite),
                            cursorColor: kPrimary,
                            decoration: _dec(
                              'Address',
                              icon: Icons.location_on_outlined,
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Enter address'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Gender
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Gender',
                              style: const TextStyle(color: kMuted),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 12,
                            children: [
                              _genderChip('male', 'Male'),
                              _genderChip('female', 'Female'),
                              _genderChip('other', 'Other'),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Birthday
                          InkWell(
                            onTap: _pickBirthday,
                            child: InputDecorator(
                              decoration: _dec(
                                'Birthday',
                                icon: Icons.cake_outlined,
                              ),
                              child: Text(
                                _birthday == null
                                    ? 'Select date'
                                    : '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: _birthday == null ? kMuted : kWhite,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 14),
                          if (_msg != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _msg!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),

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
                              onPressed: _busy ? null : _saveAndContinue,
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
                                  : const Text('Continue'),
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
        ],
      ),
    );
  }

  Widget _genderChip(String value, String label) {
    final selected = _gender == value;
    return ChoiceChip(
      selected: selected,
      onSelected: (v) => setState(() => _gender = value),
      label: Text(label),
      labelStyle: TextStyle(color: selected ? kWhite : kMuted),
      selectedColor: kPrimary,
      backgroundColor: kWhite.withOpacity(0.06),
      side: BorderSide(color: selected ? kPrimary : kWhite.withOpacity(0.12)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
