import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});
  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  bool _busy = false;
  String? _msg;
  String? _emailArg;
  String? _nameArg;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _emailArg = args['email'] as String?;
      _nameArg  = args['name'] as String?;
    }
  }

  Future<void> _openEmailApp() async {
    final uri = Uri.parse('mailto:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _resend() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        setState(() { _msg = 'Verification email sent again.'; });
      } else {
        setState(() { _msg = 'Already verified.'; });
      }
    } catch (e) {
      setState(() { _msg = 'Failed to send: $e'; });
    } finally {
      setState(() { _busy = false; });
    }
  }

  Future<void> _refreshStatus() async {
    setState(() { _busy = true; _msg = null; });
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      final fresh = FirebaseAuth.instance.currentUser;

      if (fresh != null && fresh.emailVerified) {
        // If name was passed during signup and not saved, ensure it’s on the profile.
        if ((_nameArg?.isNotEmpty ?? false) && (fresh.displayName == null || fresh.displayName!.isEmpty)) {
          await fresh.updateDisplayName(_nameArg!.trim());
          await fresh.reload();
        }

        if (!mounted) return;
        // Go straight to Home and clear back stack
        Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false);
        return;
      } else {
        setState(() { _msg = 'Not verified yet. Check your inbox/spam.'; });
      }
    } catch (e) {
      setState(() { _msg = 'Check failed: $e'; });
    } finally {
      setState(() { _busy = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailArg ?? FirebaseAuth.instance.currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sent to: $email'),
            const SizedBox(height: 12),
            const Text('Open the verification link in your email. Then tap Refresh.'),
            const SizedBox(height: 24),
            if (_msg != null) Text(_msg!, style: const TextStyle(color: Colors.blue)),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(onPressed: _busy ? null : _openEmailApp, child: const Text('Open email app')),
                const SizedBox(width: 12),
                ElevatedButton(onPressed: _busy ? null : _refreshStatus, child: const Text('Refresh status')),
              ],
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _busy ? null : _resend, child: const Text('Resend email')),
          ],
        ),
      ),
    );
  }
}
