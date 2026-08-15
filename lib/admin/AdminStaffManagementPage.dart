import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../language.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class AdminStaffManagementPage extends StatefulWidget {
  static const route = '/admin-staff';
  const AdminStaffManagementPage({super.key});

  @override
  State<AdminStaffManagementPage> createState() =>
      _AdminStaffManagementPageState();
}

class _AdminStaffManagementPageState extends State<AdminStaffManagementPage> {
  final _firestore = FirebaseFirestore.instance;

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

  void _showAddStaffDialog() {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    String selectedRole = 'cashier';
    bool isDialogBusy = false;
    String? dialogErr;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF194D25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: kWhite.withOpacity(0.2)),
              ),
              title: const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: kPrimary),
                  SizedBox(width: 10),
                  Text(
                    'Add Staff Account',
                    style: TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: kWhite),
                      decoration: _dec(
                        'Full Name',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: kWhite),
                      decoration: _dec('Email', icon: Icons.mail_outline),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: kWhite),
                      decoration: _dec(
                        'Phone Number',
                        icon: Icons.phone_android_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      style: const TextStyle(color: kWhite),
                      decoration: _dec(
                        'Password',
                        icon: Icons.lock_outline_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      dropdownColor: const Color(0xFF0C1E11),
                      style: const TextStyle(color: kWhite),
                      decoration: _dec(
                        'Select Role',
                        icon: Icons.badge_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'cashier',
                          child: Text('Cashier'),
                        ),
                        DropdownMenuItem(
                          value: 'waiter',
                          child: Text('Waiter'),
                        ),
                        //   DropdownMenuItem(value: 'admin', child: Text('Admin')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedRole = val);
                        }
                      },
                    ),
                    if (dialogErr != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        dialogErr!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isDialogBusy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: kMuted)),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kWhite,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: isDialogBusy
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          final email = emailController.text.trim();
                          var phone = phoneController.text.trim();
                          final password = passwordController.text.trim();

                          if (name.isEmpty ||
                              email.isEmpty ||
                              password.isEmpty) {
                            setDialogState(
                              () => dialogErr =
                                  'Please fill all required fields.',
                            );
                            return;
                          }

                          if (phone.isNotEmpty && !phone.startsWith('+')) {
                            phone = '+$phone';
                          }

                          setDialogState(() {
                            isDialogBusy = true;
                            dialogErr = null;
                          });

                          try {
                            // Secondary app initialization keeps current admin session active
                            FirebaseApp secondaryApp =
                                await Firebase.initializeApp(
                                  name: 'SecondaryApp',
                                  options: Firebase.app().options,
                                );

                            UserCredential creds =
                                await FirebaseAuth.instanceFor(
                                  app: secondaryApp,
                                ).createUserWithEmailAndPassword(
                                  email: email,
                                  password: password,
                                );

                            final uid = creds.user!.uid;
                            await creds.user!.updateDisplayName(name);

                            // Save user to 'user' collection matching existing app model
                            await _firestore.collection('user').doc(uid).set({
                              'uid': uid,
                              'userName': name,
                              'email': email,
                              'phone': phone,
                              'role': selectedRole,
                              'verified': true,
                              'createdAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            await secondaryApp.delete();

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Created $selectedRole account for $name!',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              dialogErr = e.toString();
                              isDialogBusy = false;
                            });
                          }
                        },
                  child: isDialogBusy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kWhite,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteStaff(String uid) async {
    try {
      await _firestore.collection('user').doc(uid).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User record deleted from database.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Staff Management',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: kWhite,
            size: 22,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        onPressed: _showAddStaffDialog,
        icon: const Icon(Icons.person_add_rounded, color: kWhite),
        label: const Text(
          'Add Staff',
          style: TextStyle(color: kWhite, fontWeight: FontWeight.bold),
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
          StreamBuilder<QuerySnapshot>(
            stream: _firestore
                .collection('user')
                .where('role', whereIn: ['cashier', 'waiter', 'admin'])
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: kPrimary),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No staff accounts found.',
                    style: TextStyle(color: kMuted, fontSize: 16),
                  ),
                );
              }

              final staffMembers = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: staffMembers.length,
                itemBuilder: (context, index) {
                  final data =
                      staffMembers[index].data() as Map<String, dynamic>;
                  final name = data['userName'] ?? 'No Name';
                  final email = data['email'] ?? '';
                  final phone = data['phone'] ?? '';
                  final role = (data['role'] ?? 'staff')
                      .toString()
                      .toUpperCase();

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          decoration: BoxDecoration(
                            color: kWhite.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kWhite.withOpacity(0.15)),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: kPrimary,
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                style: const TextStyle(
                                  color: kWhite,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '$email\n$phone • Role: $role',
                              style: const TextStyle(
                                color: kMuted,
                                height: 1.3,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.redAccent,
                              ),
                              onPressed: () =>
                                  _deleteStaff(staffMembers[index].id),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
