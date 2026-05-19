import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart'; // Required for date formatting
import 'package:restorant/startup%20page/balance_user_register.dart';

// Palette (for consistent styling)
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  // Helper to build a styled profile info row
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2F2E2D), // Slightly lighter dark background
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: kPrimary, size: 24),
            const SizedBox(width: 15),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: kMuted, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: const TextStyle(
                    color: kWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to format birthday data from Firestore
  String _formatBirthday(dynamic birthdayData) {
    if (birthdayData == null) return 'N/A';

    DateTime? date;
    if (birthdayData is Timestamp) {
      date = birthdayData.toDate();
    } else if (birthdayData is String) {
      date = DateTime.tryParse(birthdayData);
    }

    return date != null ? DateFormat('MMM d, yyyy').format(date) : 'N/A';
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Handle unauthenticated state
      return const Center(
        child: Text(
          'Please sign in to view your profile.',
          style: TextStyle(color: kWhite, fontSize: 18),
        ),
      );
    }

    final userDocRef = FirebaseFirestore.instance
        .collection('user')
        .doc(user.uid);

    return StreamBuilder<DocumentSnapshot>(
      stream: userDocRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: kPrimary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading profile: ${snapshot.error}',
              style: const TextStyle(color: Colors.redAccent),
            ),
          );
        }

        // Extract data, using fallbacks from FirebaseAuth if Firestore doc is missing
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};

        final userName =
            (data['userName'] as String?) ?? user.displayName ?? '';
        final email = (data['email'] as String?) ?? user.email ?? '';
        final mobile = (data['mobile'] as String?) ?? '';
        final address = (data['address'] as String?) ?? '';
        final gender = (data['gender'] as String?)?.toUpperCase() ?? 'N/A';
        final birthday = _formatBirthday(data['birthday']);

        return Scaffold(
          backgroundColor: kBg,
          appBar: AppBar(
            backgroundColor: kBg,
            foregroundColor: kWhite,
            title: const Text(
              'My Profile',
              style: TextStyle(fontWeight: FontWeight.w700, color: kWhite),
            ),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (Name and Avatar Placeholder)
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: kPrimary.withOpacity(0.2),
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 40,
                            color: kPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        userName.isNotEmpty ? userName : 'User Profile',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),

                // Profile Information Rows
                _buildInfoRow(Icons.mail_outline, 'Email Address', email),
                _buildInfoRow(Icons.phone_outlined, 'Mobile Number', mobile),
                _buildInfoRow(Icons.location_on_outlined, 'Address', address),
                _buildInfoRow(Icons.person_outline, 'Gender', gender),
                _buildInfoRow(Icons.cake_outlined, 'Birthday', birthday),

                const SizedBox(height: 24),

                // Edit Profile Button (This navigates to the registration page for editing)
                FilledButton.icon(
                  onPressed: () {
                    // FIX: Using MaterialPageRoute instead of a broken named route.
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const BalanceUserRegisterPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit_outlined, size: 24),
                  label: const Text(
                    'Edit Profile Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: kWhite,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Log out button
                TextButton.icon(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    // Implement navigation to your sign-in screen here
                  },
                  icon: const Icon(Icons.logout, color: kMuted),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: kMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
