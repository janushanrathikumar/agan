// lib/user/home_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:restorant/user/menu.dart';
import '../language.dart';

const kPrimary = Color(0xFFE49024);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  // ── Dine In: show picker sheet, then go to menu ─────────────────────────
  Future<void> _handleDineIn(BuildContext context) async {
    final tableNo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TablePickerSheet(),
    );
    if (tableNo != null && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MenuPage(tableNo: tableNo)),
      );
    }
  }

  // ── Take Away: go to menu with 'Take-Away' ──────────────────────────────
  Future<void> _handleTakeAway(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(user.uid)
          .set({
            'delivery_method': 'Take_Away',
            'table_no': 'no',
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MenuPage(tableNo: 'Take-Away')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Image.asset('assets/logo.jpeg', height: 45),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shortcuts
              Row(
                children: [
                  Expanded(
                    child: _TopCard(
                      label: AppLanguage.getText('rewards'),
                      icon: Icons.loyalty,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TopCard(
                      label: AppLanguage.getText('balance'),
                      icon: Icons.account_balance_wallet,
                      onTap: () {},
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TopCard(
                      label: AppLanguage.getText('qr_scanner'),
                      icon: Icons.qr_code_scanner,
                      onTap: () => _handleDineIn(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Promo banner
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: kWhite.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('Promo Banner', style: TextStyle(color: kMuted)),
                ),
              ),
              const SizedBox(height: 24),

              // Main actions
              Row(
                children: [
                  Expanded(
                    child: _BigActionButton(
                      label: AppLanguage.getText('dine_in'),
                      icon: Icons.restaurant,
                      onTap: () => _handleDineIn(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BigActionButton(
                      label: AppLanguage.getText('take_away'),
                      icon: Icons.shopping_bag,
                      onTap: () => _handleTakeAway(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Table Picker Sheet (Scan QR / Type / Take-Away) ─────────────────────────
class _TablePickerSheet extends StatefulWidget {
  const _TablePickerSheet();
  @override
  State<_TablePickerSheet> createState() => _TablePickerSheetState();
}

class _TablePickerSheetState extends State<_TablePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _typeCtrl = TextEditingController();
  String? _scannedValue;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this); // Scan | Type
  }

  @override
  void dispose() {
    _tab.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _confirm(String val) {
    Navigator.pop(context, val.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF194D25),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Text(
            'Dine-In: Enter Table',
            style: TextStyle(
              color: kWhite,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Scan the QR code on your table or type the number',
            style: TextStyle(color: kMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Tabs
          TabBar(
            controller: _tab,
            indicatorColor: kPrimary,
            labelColor: kPrimary,
            unselectedLabelColor: kMuted,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan QR'),
              Tab(icon: Icon(Icons.edit_outlined), text: 'Type No.'),
            ],
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 230,
            child: TabBarView(
              controller: _tab,
              children: [_buildQrTab(), _buildTypeTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrTab() {
    if (_scannedValue != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 52),
          const SizedBox(height: 12),
          Text(
            'Table: $_scannedValue',
            style: const TextStyle(
              color: kWhite,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            onPressed: () => _confirm(_scannedValue!),
            child: const Text(
              'Go to Menu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _scannedValue = null),
            child: const Text('Scan again', style: TextStyle(color: kMuted)),
          ),
        ],
      );
    }

    // Web fallback
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: MobileScanner(
        onDetect: (capture) {
          final val = capture.barcodes.firstOrNull?.rawValue;
          if (val != null && mounted) {
            setState(() => _scannedValue = val);
          }
        },
      ),
    );
  }

  Widget _buildTypeTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _typeCtrl,
          keyboardType: TextInputType.text,
          style: const TextStyle(color: kWhite, fontSize: 18),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: 'e.g.  T5  or  12',
            hintStyle: const TextStyle(color: kMuted),
            filled: true,
            fillColor: kBg,
            prefixIcon: const Icon(Icons.table_restaurant, color: kPrimary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: kMuted.withOpacity(0.3)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () {
              final val = _typeCtrl.text.trim();
              if (val.isNotEmpty) _confirm(val);
            },
            child: const Text(
              'Go to Menu',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Helper widgets ───────────────────────────────────────────────────────────
class _TopCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _TopCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kWhite.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, size: 28, color: kPrimary),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: kWhite,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kPrimary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: kWhite, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
