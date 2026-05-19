import 'package:flutter/material.dart';
import 'package:restorant/app_bar.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFFB7B7B6);

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _saved = false;

  Future<void> _saveCode(String code) async {
    if (_saved) return;
    _saved = true;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(user.uid)
        .set({
      'delivery_method': 'Dine_In',
      'table_no': code,
      'timestamp': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Table saved: $code'), backgroundColor: kPrimary),
    );

    // Navigate directly to AppShell and open Menu tab (index 1)
    Navigator.popUntil(context, (route) => route.isFirst);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AppShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: kWhite,
        title: const Text('Scan Table QR'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              for (final b in barcodes) {
                final code = b.rawValue ?? '';
                if (code.isNotEmpty) _saveCode(code);
              }
            },
            controller: MobileScannerController(
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: kPrimary, width: 4),
              borderRadius: BorderRadius.circular(16),
            ),
            width: MediaQuery.of(context).size.width * 0.7,
            height: MediaQuery.of(context).size.width * 0.7,
          ),
          const Positioned(
            bottom: 40,
            child: Text(
              'Align QR code within the frame',
              style: TextStyle(color: kMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
