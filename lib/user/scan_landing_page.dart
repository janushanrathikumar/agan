// lib/user/scan_landing_page.dart
//
// Landing page for a chair QR code:
//
//   /scan?t=<tableId>&c=<chairId>   the seat's own ids, which survive renumbering
//   /scan?n=<chairNumber>           the number printed on the chair
//
// A guest points their phone camera at the sticker on their chair, and this
// page selects that table and seat for them before handing over to the menu.
//
// The numbered form exists so a sticker can be printed for a chair before the
// admin has added it to a table: it starts working the moment a chair with
// that number exists.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:restorant/app_bar.dart';
import 'package:restorant/language.dart';
import 'package:restorant/main.dart';
import 'package:restorant/shared/table_registry.dart';

const _kBg = Color(0xFF112A18);
const _kSpinner = Color(0xFFE49024);

/// A scan that arrived before the guest was signed in, kept until they are.
class PendingScan {
  static const _tableKey = 'pending_scan_table';
  static const _chairKey = 'pending_scan_chair';
  static const _chairNoKey = 'pending_scan_chair_no';

  static Future<void> save({
    String? tableId,
    String? chairId,
    int? chairNo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tableKey);
    await prefs.remove(_chairKey);
    await prefs.remove(_chairNoKey);

    if (chairNo != null) {
      await prefs.setInt(_chairNoKey, chairNo);
      return;
    }
    if (tableId == null || tableId.isEmpty) return;
    await prefs.setString(_tableKey, tableId);
    if (chairId != null && chairId.isNotEmpty) {
      await prefs.setString(_chairKey, chairId);
    }
  }

  /// Reads and clears the pending scan, so it is applied exactly once.
  static Future<({String? tableId, String? chairId, int? chairNo})?>
  take() async {
    final prefs = await SharedPreferences.getInstance();
    final tableId = prefs.getString(_tableKey);
    final chairId = prefs.getString(_chairKey);
    final chairNo = prefs.getInt(_chairNoKey);
    if ((tableId == null || tableId.isEmpty) && chairNo == null) return null;
    await prefs.remove(_tableKey);
    await prefs.remove(_chairKey);
    await prefs.remove(_chairNoKey);
    return (tableId: tableId, chairId: chairId, chairNo: chairNo);
  }
}

/// Writes a resolved seat to the guest's current selection.
///
/// Merges, because `food_delivery/{uid}` also carries uid/username/role that
/// the checkout flow puts there.
Future<void> applySeatSelection(String uid, SeatSelection seat) {
  return FirebaseFirestore.instance.collection('food_delivery').doc(uid).set({
    'delivery_method': 'Dine_In',
    'table_no': seat.tableName,
    'chair_no': seat.chairNo,
    'timestamp': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

class ScanLandingPage extends StatefulWidget {
  const ScanLandingPage({
    super.key,
    this.tableId,
    this.chairId,
    this.chairNo,
  });

  final String? tableId;
  final String? chairId;

  /// The number printed on the chair, for `/scan?n=<number>`.
  final int? chairNo;

  @override
  State<ScanLandingPage> createState() => _ScanLandingPageState();
}

class _ScanLandingPageState extends State<ScanLandingPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    // Firebase is guaranteed ready here: MyApp's builder gates the whole
    // navigator on initialisation.
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScan());
  }

  Future<void> _handleScan() async {
    final tableId = widget.tableId;
    final chairNo = widget.chairNo;
    if (chairNo == null && (tableId == null || tableId.isEmpty)) {
      _fail(AppLanguage.getText('This QR code is not valid.'));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Remember the seat and resolve it after sign-in — reading the table
      // before authentication would depend on public read access.
      await PendingScan.save(
        tableId: tableId,
        chairId: widget.chairId,
        chairNo: chairNo,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(AppRoutes.start);
      return;
    }

    try {
      final seat = chairNo != null
          ? await TableRegistry.resolveByChairNumber(chairNo)
          : await TableRegistry.resolveByIds(tableId!, widget.chairId);
      if (seat == null) {
        _fail(
          chairNo != null
              ? '${AppLanguage.getText('This chair is not set up yet.')} '
                    '($chairNo)'
              : AppLanguage.getText('This table is no longer available.'),
        );
        return;
      }

      await applySeatSelection(user.uid, seat);
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell(initialIndex: 1)),
        (route) => false,
      );
    } catch (e) {
      _fail('${AppLanguage.getText('Could not open this table.')} $e');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kSpinner)),
      );
    }

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  color: _kSpinner,
                  size: 56,
                ),
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kSpinner,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(220, 48),
                  ),
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil(AppRoutes.start, (r) => false),
                  child: Text(AppLanguage.getText('Continue')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
