// import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import 'package:restorant/admin/admin_app_bar.dart';

// class SignInPage extends StatefulWidget {
//   static const route = '/signin';
//   const SignInPage({super.key});
//   @override
//   State<SignInPage> createState() => _SignInPageState();
// }

// class _SignInPageState extends State<SignInPage> {
//   final _form = GlobalKey<FormState>();
//   final _email = TextEditingController();
//   final _pass = TextEditingController();
//   bool _busy = false;

//   Future<void> _submit() async {
//     if (!_form.currentState!.validate()) return;
//     setState(() => _busy = true);
//     try {
//       final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
//         email: _email.text.trim(),
//         password: _pass.text,
//       );

//       if (!mounted) return;

//       // Check for admin email
//       if (cred.user?.email?.toLowerCase() == 'admin@gmail.com') {
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(builder: (_) => const AdminAppBar()),
//         );
//       } else {
//         Navigator.pop(context); // go back to normal AppShell
//       }
//     } on FirebaseAuthException catch (e) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(e.message ?? 'Sign in failed')),
//       );
//     } finally {
//       if (mounted) setState(() => _busy = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text('Sign in')),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Form(
//           key: _form,
//           child: Column(
//             children: [
//               TextFormField(
//                 controller: _email,
//                 decoration: const InputDecoration(labelText: 'Email'),
//                 keyboardType: TextInputType.emailAddress,
//                 validator: (v) =>
//                     (v == null || !v.contains('@')) ? 'Enter email' : null,
//               ),
//               TextFormField(
//                 controller: _pass,
//                 decoration: const InputDecoration(labelText: 'Password'),
//                 obscureText: true,
//                 validator: (v) =>
//                     (v == null || v.length < 6) ? 'Min 6 chars' : null,
//               ),
//               const SizedBox(height: 16),
//               FilledButton(
//                 onPressed: _busy ? null : _submit,
//                 child: _busy
//                     ? const SizedBox(
//                         width: 18,
//                         height: 18,
//                         child: CircularProgressIndicator(strokeWidth: 2))
//                     : const Text('Sign in'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
