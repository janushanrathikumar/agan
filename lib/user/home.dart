import 'dart:async';
import 'dart:ui';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:restorant/user/menu.dart';
import 'package:restorant/user/checkout.dart';
import 'package:restorant/shared/table_registry.dart';
import 'package:restorant/shared/menu_offer.dart';
import 'package:restorant/shared/combo_includes.dart';
import 'package:restorant/platform_image/platform_image.dart';
import 'package:restorant/user/daily_meal_section.dart';
import 'package:restorant/user/opening_hours_card.dart';
import 'package:restorant/user/table_booking_page.dart';
import 'package:restorant/user/app_offer_dialog.dart';
import '../language.dart';
import 'package:restorant/shared/platform_support.dart';
import 'package:restorant/startup%20page/auth_dialog.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF112A18);
const kMuted = Color(0xFFA1B3A1);
const kWhite = Color(0xFFF7F7F2);
const kCardBg = Color(0xFF1A3822);
const kItemBg = Color(0xFF1E3A24);
const kDarkBar = Color(0xFF0C1E11);
const kDiscount = Color(0xFFE0483E);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userRole = 'customer';
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    _fetchUserRole();
    // A guest can browse this page and sign in afterwards through the popup,
    // so the role has to be read again rather than staying whatever it was
    // when the page was first built - otherwise a waiter who signs in here
    // keeps a customer's screen until they reload.
    _authSub = FirebaseAuth.instance.authStateChanges().listen(
      (_) => _fetchUserRole(),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted && _userRole != 'customer') {
        setState(() => _userRole = 'customer');
      }
      return;
    }

    // The same lookup the rest of the app uses, so a waiter cannot end up
    // with the manual entry on one screen and not on another.
    final role = await fetchUserRole(user.uid);
    if (!mounted || role == _userRole) return;
    setState(() => _userRole = role);
  }

  Future<void> _handleDineIn(BuildContext context) async {
    // Choosing a table writes to the visitor's own profile, so it needs an
    // account even though the page it sits on does not.
    if (!await requireLogin(
      context,
      reason: AppLanguage.getText('login_to_order'),
    )) {
      return;
    }
    if (!context.mounted) return;

    final selection = await showModalBottomSheet<TableSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TablePickerSheet(userRole: _userRole),
    );

    if (selection == null || !context.mounted) return;

    final tableNo = selection.table;

    // A chair QR code (or a recognised chair number) already identified the
    // seat — no need to ask for it again.
    String? chairNo = selection.hasChair ? selection.chair : null;
    if (chairNo == null) {
      chairNo = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ChairPickerDialog(userRole: _userRole),
      );
      if (chairNo == null || !context.mounted) return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(user.uid)
          .set({
            'delivery_method': 'Dine_In',
            'table_no': tableNo,
            'chair_no': chairNo,
            'timestamp': FieldValue.serverTimestamp(),
            // Merged so the uid/username/role the checkout flow stores on this
            // same document are not wiped.
          }, SetOptions(merge: true));
    }

    if (context.mounted) {
      final displayTable =
          '${AppLanguage.getText("Table")} $tableNo (${AppLanguage.getText("Chair")} $chairNo)';
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => MenuPage(tableNo: displayTable)),
      );
    }
  }

  Future<void> _handleTakeAway(BuildContext context) async {
    if (!await requireLogin(
      context,
      reason: AppLanguage.getText('login_to_order'),
    )) {
      return;
    }
    if (!context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(user.uid)
          .set({
            'delivery_method': 'Take_Away',
            'table_no': '',
            'chair_no': '',
            'timestamp': FieldValue.serverTimestamp(),
          });
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MenuPage(tableNo: 'Take-Away'),
      ), // Internal state representation
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _CartFab(
        onTap: (uid, tableNo) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutPage(uid: uid, tableNo: tableNo),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: _BigActionButton(
                        label: AppLanguage.getText('dine_in'),
                        icon: Icons.storefront_rounded,
                        isPrimary: true,
                        onTap: () => _handleDineIn(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _BigActionButton(
                        label: AppLanguage.getText('take_away'),
                        icon: Icons.takeout_dining_rounded,
                        isPrimary: false,
                        onTap: () => _handleTakeAway(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: _BigActionButton(
                  label: AppLanguage.getText('Book a table'),
                  icon: Icons.event_seat_rounded,
                  isPrimary: false,
                  onTap: () async {
                    if (!await requireLogin(
                      context,
                      reason: AppLanguage.getText('login_to_continue'),
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TableBookingPage(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Every active daily meal, grouped by its scheduled day.
              const DailyMealSection(),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLanguage.getText('Special Offers & Combos'),
                      style: const TextStyle(
                        color: kWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLanguage.getText(
                        "Today's best deals and combos for you",
                      ),
                      style: TextStyle(
                        color: kMuted.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _PromoCarousel(
                onDineIn: () => _handleDineIn(context),
                onTakeAway: () => _handleTakeAway(context),
              ),
              const SizedBox(height: 32),
              const OpeningHoursCard(),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

/// What the table picker hands back. [chair] is filled in when the seat was
/// identified from a chair QR code or a chair number, which lets the caller
/// skip asking for the chair a second time.
class TableSelection {
  const TableSelection(this.table, [this.chair = '']);

  final String table;
  final String chair;

  bool get hasChair => chair.trim().isNotEmpty;
}

class _TablePickerSheet extends StatefulWidget {
  final String userRole;
  const _TablePickerSheet({required this.userRole});

  @override
  State<_TablePickerSheet> createState() => _TablePickerSheetState();
}

class _TablePickerSheetState extends State<_TablePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _typeCtrl = TextEditingController();
  String? _scannedValue;

  /// Chair resolved alongside the table (from a chair QR code).
  String? _scannedChair;

  // Lookup for the number typed in the staff tab.
  ChairTextResult? _typeLookup;
  Timer? _typeDebounce;

  bool get isStaff => isStaffRole(widget.userRole);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: isStaff ? 2 : 1, vsync: this);
    _typeCtrl.addListener(_onTypedTextChanged);
  }

  @override
  void dispose() {
    _typeDebounce?.cancel();
    _typeCtrl.removeListener(_onTypedTextChanged);
    _tab.dispose();
    _typeCtrl.dispose();
    super.dispose();
  }

  void _confirm(String val, [String chair = '']) =>
      Navigator.pop(context, TableSelection(val.trim(), chair.trim()));

  /// Staff can type a chair number here instead of a table: chair numbers are
  /// unique across the restaurant, so one number identifies the table too.
  void _onTypedTextChanged() {
    _typeDebounce?.cancel();
    final text = _typeCtrl.text;

    if (text.trim().isEmpty) {
      if (_typeLookup != null) setState(() => _typeLookup = null);
      return;
    }

    _typeDebounce = Timer(const Duration(milliseconds: 350), () async {
      final result = await TableRegistry.resolveChairText(text);
      if (!mounted || _typeCtrl.text != text) return;
      setState(() => _typeLookup = result);
    });
  }

  Widget _buildTypeLookupNote() {
    final lookup = _typeLookup;
    if (lookup == null || lookup.rawText.isEmpty) {
      return const SizedBox.shrink();
    }

    final resolvedCleanly =
        lookup.resolved && !lookup.hasUnresolved && !lookup.spansMultipleTables;
    final color = resolvedCleanly ? Colors.greenAccent : Colors.orangeAccent;
    final message = resolvedCleanly
        ? (lookup.chair == null
              ? lookup.table!.name
              : '${lookup.table!.name} · '
                    '${AppLanguage.getText("Chair")} ${lookup.chair!.no}')
        : AppLanguage.getText('Used exactly as typed');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            resolvedCleanly ? Icons.check_circle : Icons.warning_amber_rounded,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: const BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: kMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              AppLanguage.getText('Select Table'),
              style: const TextStyle(
                color: kWhite,
                fontWeight: FontWeight.w800,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isStaff
                  ? AppLanguage.getText(
                      'Scan the table QR code or type table number manually',
                    )
                  : AppLanguage.getText('Scan the table QR code to proceed'),
              style: const TextStyle(color: kMuted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            if (isStaff) ...[
              Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: kWhite,
                  unselectedLabelColor: kMuted,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: [
                    Tab(text: AppLanguage.getText('Scan QR')),
                    Tab(text: AppLanguage.getText('Type No.')),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            SizedBox(
              height: 230,
              child: isStaff
                  ? TabBarView(
                      controller: _tab,
                      children: [_buildQrTab(), _buildTypeTab()],
                    )
                  : _buildQrTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrTab() {
    // The Windows till build has no camera scanner; the chair number can be
    // typed on the next tab instead.
    if (!supportsCameraScanner) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: Colors.white54),
              const SizedBox(height: 10),
              Text(
                AppLanguage.getText('qr_not_available'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    if (_scannedValue != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '${AppLanguage.getText("Table:")} $_scannedValue',
            style: const TextStyle(
              color: kWhite,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _confirm(_scannedValue!, _scannedChair ?? ''),
              child: Text(
                // A chair QR code already identified the seat, so there is
                // nothing left to ask for.
                _scannedChair != null
                    ? AppLanguage.getText('Go to Menu')
                    : AppLanguage.getText('Next (Select Chair)'),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: kWhite,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => setState(() {
              _scannedValue = null;
              _scannedChair = null;
            }),
            child: Text(
              AppLanguage.getText('Scan again'),
              style: const TextStyle(color: kMuted),
            ),
          ),
        ],
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: MobileScanner(
        onDetect: (capture) {
          final val = capture.barcodes.firstOrNull?.rawValue;
          if (val != null) _handleScannedCode(val);
        },
      ),
    );
  }

  /// A chair QR code carries a link to resolve; anything else stays a plain
  /// table name, so QR codes printed before this feature still work.
  Future<void> _handleScannedCode(String raw) async {
    final seat = await TableRegistry.resolveScan(raw);
    if (!mounted) return;

    setState(() {
      // Nothing matched: show what was actually scanned rather than pretending
      // a seat was found.
      _scannedValue = seat?.tableName ?? raw.trim();
      _scannedChair = seat?.chair == null ? null : seat!.chairNo;
    });
  }

  Widget _buildTypeTab() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _typeCtrl,
          keyboardType: TextInputType.text,
          style: const TextStyle(
            color: kWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: AppLanguage.getText('e.g. chair 7 or Table 5'),
            hintStyle: TextStyle(
              color: kMuted.withOpacity(0.5),
              fontWeight: FontWeight.normal,
            ),
            filled: true,
            fillColor: kBg,
            prefixIcon: const Icon(Icons.table_restaurant, color: kPrimary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: kPrimary, width: 2),
            ),
          ),
        ),
        _buildTypeLookupNote(),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: () {
              final val = _typeCtrl.text.trim();
              if (val.isEmpty) return;

              // A recognised chair number gives us the table and the seat, so
              // the chair step can be skipped. Anything else is passed through
              // as typed, exactly as before.
              final lookup = _typeLookup;
              if (lookup != null &&
                  lookup.rawText == val &&
                  lookup.resolved &&
                  !lookup.spansMultipleTables) {
                _confirm(lookup.table!.name, lookup.rawText);
                return;
              }
              _confirm(val);
            },
            child: Text(
              _typeLookup?.resolved == true
                  ? AppLanguage.getText('Go to Menu')
                  : AppLanguage.getText('Next (Select Chair)'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: kWhite,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChairPickerDialog extends StatefulWidget {
  final String userRole;
  const _ChairPickerDialog({required this.userRole});

  @override
  State<_ChairPickerDialog> createState() => _ChairPickerDialogState();
}

class _ChairPickerDialogState extends State<_ChairPickerDialog> {
  final _chairCtrl = TextEditingController();

  @override
  void dispose() {
    _chairCtrl.dispose();
    super.dispose();
  }

  void _confirm(String val) => Navigator.pop(context, val.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kCardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        AppLanguage.getText('Select Chair / Seat'),
        style: const TextStyle(color: kWhite, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              AppLanguage.getText(
                'Enter your chair number(s) below (e.g. 1, 2, 3)',
              ),
              style: const TextStyle(color: kMuted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _chairCtrl,
              keyboardType: TextInputType.text,
              style: const TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: AppLanguage.getText('e.g. 1, 2 or 1, 2, 3'),
                hintStyle: TextStyle(
                  color: kMuted.withOpacity(0.5),
                  fontWeight: FontWeight.normal,
                ),
                filled: true,
                fillColor: kBg,
                prefixIcon: const Icon(Icons.event_seat, color: kPrimary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: kPrimary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () {
                  final val = _chairCtrl.text.trim();
                  if (val.isNotEmpty) _confirm(val);
                },
                child: Text(
                  AppLanguage.getText('Go to Menu'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: kWhite,
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

class _CartFab extends StatelessWidget {
  final void Function(String uid, String? tableNo) onTap;
  const _CartFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chat')
          .doc(user.uid)
          .collection('items')
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];
        double total = 0;
        int count = 0;
        for (final d in docs) {
          final m = (d.data() as Map<String, dynamic>? ?? {});
          double itemPrice = (m['price'] as num?)?.toDouble() ?? 0.0;
          final List addons = m['additionalOptions'] ?? [];
          double addonsTotal = 0;
          for (var a in addons) {
            if (a is Map) {
              addonsTotal += (a['price'] as num?)?.toDouble() ?? 0.0;
            }
          }
          final qty = (m['qty'] as num?)?.toInt() ?? 1;
          total += (itemPrice + addonsTotal) * qty;
          count += qty;
        }
        if (total == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 65,
            width: double.infinity,
            child: FloatingActionButton.extended(
              elevation: 8,
              backgroundColor: kPrimary,
              foregroundColor: kWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              onPressed: () async {
                final delivDoc = await FirebaseFirestore.instance
                    .collection('food_delivery')
                    .doc(user.uid)
                    .get();
                final tableNo = delivDoc.exists
                    ? (delivDoc.data()?['delivery_method'] == 'Take_Away'
                          ? 'Take-Away' // internally handles take away
                          : delivDoc.data()?['table_no'] as String?)
                    : null;
                if (context.mounted) onTap(user.uid, tableNo);
              },
              label: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLanguage.getText('View Cart '),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'CHF ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PromoCarousel extends StatefulWidget {
  final VoidCallback onDineIn;
  final VoidCallback onTakeAway;
  const _PromoCarousel({required this.onDineIn, required this.onTakeAway});

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _ctrl = PageController(viewportFraction: 0.90);
  int _current = 0;

  // Created once: a new `.snapshots()` on every build re-subscribed each time
  // the page changed, so the carousel fell back to the loading spinner and
  // lost its place while the guest was swiping or tapping.
  final Stream<QuerySnapshot> _menuStream = FirebaseFirestore.instance
      .collection('menu_items')
      .snapshots();
  String? _deliveryUid;
  Stream<DocumentSnapshot>? _deliveryStream;

  Stream<DocumentSnapshot> _deliveryFor(String uid) {
    if (_deliveryUid != uid || _deliveryStream == null) {
      _deliveryUid = uid;
      _deliveryStream = FirebaseFirestore.instance
          .collection('food_delivery')
          .doc(uid)
          .snapshots();
    }
    return _deliveryStream!;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (!_ctrl.hasClients) return;
    _ctrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  Future<bool> _hasSelectedMethod(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('food_delivery')
        .doc(user.uid)
        .get();
    return doc.exists;
  }

  Future<void> _askMethod(
    BuildContext context,
    Map<String, dynamic> itemData,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MethodPickerSheet(
        onDineIn: () async {
          Navigator.pop(context);
          widget.onDineIn();
        },
        onTakeAway: () async {
          Navigator.pop(context);
          widget.onTakeAway();
        },
      ),
    );
  }

  Future<void> _openItemSheet(
    BuildContext context,
    Map<String, dynamic> itemData,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLanguage.getText('Please login first'))),
      );
      return;
    }
    final hasMethod = await _hasSelectedMethod(context);
    if (!hasMethod) {
      if (context.mounted) await _askMethod(context, itemData);
      return;
    }
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _PromoItemSheet(itemData: itemData),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildPromoStream(context, null);

    return StreamBuilder<DocumentSnapshot>(
      stream: _deliveryFor(user.uid),
      builder: (context, deliverySnap) {
        String? tableNo;
        if (deliverySnap.hasData && deliverySnap.data!.exists) {
          final d = deliverySnap.data!.data() as Map<String, dynamic>?;
          tableNo = d?['delivery_method'] == 'Take_Away'
              ? 'Take-Away'
              : d?['table_no'] as String?;
        }
        return _buildPromoStream(context, tableNo);
      },
    );
  }

  Widget _buildPromoStream(BuildContext context, String? tableNo) {
    return StreamBuilder<QuerySnapshot>(
      stream: _menuStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 280,
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _EmptyPromo();
        }

        var promoDocs = snapshot.data!.docs.where((d) {
          final data = (d.data() as Map<String, dynamic>?) ?? {};
          // Combos always show here, with or without an offer; other menus
          // only when they carry one.
          return data['status'] != 'off' &&
              (data['itemType'] == 'combo' ||
                  menuOfferLabel(data) != null ||
                  hasAppOffer(data) ||
                  data['isPromoActive'] == true);
        }).toList();
        if (tableNo == 'Take-Away') {
          promoDocs = promoDocs.where((d) {
            final data = (d.data() as Map<String, dynamic>?) ?? {};
            return data['canTakeAway'] != false;
          }).toList();
        }
        if (promoDocs.isEmpty) return _EmptyPromo();

        bool isCombo(QueryDocumentSnapshot d) =>
            ((d.data() as Map<String, dynamic>?)?['itemType'] ?? '')
                .toString()
                .toLowerCase() ==
            'combo';
        final comboDocs = promoDocs.where(isCombo).toList();
        final offerDocs = promoDocs.where((d) => !isCombo(d)).toList();
        // Combo cards show the photos of the menus inside them, read from the
        // live menu documents so a changed photo shows without re-saving.
        final liveMenus = {
          for (final d in snapshot.data!.docs)
            d.id: (d.data() as Map<String, dynamic>?) ?? <String, dynamic>{},
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offerDocs.isNotEmpty) _buildCarousel(context, offerDocs),
            if (offerDocs.isNotEmpty && comboDocs.isNotEmpty)
              const SizedBox(height: 20),
            for (final d in comboDocs)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: _ComboOfferCard(
                  data: d.data() as Map<String, dynamic>,
                  liveMenus: liveMenus,
                  onTap: () =>
                      _onPromoTap(context, d.data() as Map<String, dynamic>),
                ),
              ),
          ],
        );
      },
    );
  }

  Future<void> _onPromoTap(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    if (_isAppOnlyOffer(data) && !await showAppOnlyOfferDialog(context, data)) {
      return;
    }
    if (!context.mounted) return;
    if (!await requireLogin(
      context,
      reason: AppLanguage.getText('login_to_order'),
    )) {
      return;
    }
    if (!context.mounted) return;
    _openItemSheet(context, data);
  }

  Widget _buildCarousel(
    BuildContext context,
    List<QueryDocumentSnapshot> promoDocs,
  ) {
    final count = promoDocs.length;
    final current = _current.clamp(0, count - 1);

    return Column(
      children: [
        SizedBox(
          height: 290,
          child: Stack(
            children: [
              ScrollConfiguration(
                // Mouse and trackpad drags are off by default on web and
                // desktop, which left guests stuck on the first offer.
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                child: PageView.builder(
                  controller: _ctrl,
                  itemCount: count,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (context, index) {
                    final data =
                        promoDocs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? 'Special Offer';
                    final imageUrl = (data['imageUrl'] ?? '') as String;
                    final itemType = (data['itemType'] ?? '')
                        .toString()
                        .toLowerCase();
                    final bool isCombo = itemType == 'combo';
                    final double originalPrice = menuOriginalPrice(data);
                    final double offerPrice = _shownOfferPrice(data);
                    final offerLabel = _shownOfferLabel(data);
                    final isActive = _current == index;

                    return GestureDetector(
                      onTap: () async {
                        if (!isActive) {
                          _goTo(index);
                          return;
                        }
                        await _onPromoTap(context, data);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutCubic,
                        margin: EdgeInsets.only(
                          left: 8,
                          right: 8,
                          top: isActive ? 0 : 16,
                          bottom: isActive ? 10 : 26,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: kPrimary.withOpacity(0.35),
                                    blurRadius: 25,
                                    offset: const Offset(0, 10),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              imageUrl.isNotEmpty
                                  ? Image.network(imageUrl, fit: BoxFit.cover)
                                  : Container(
                                      color: kCardBg,
                                      child: const Icon(
                                        Icons.fastfood,
                                        color: kMuted,
                                        size: 80,
                                      ),
                                    ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    stops: const [0.0, 0.4, 0.8, 1.0],
                                    colors: [
                                      Colors.black.withOpacity(0.2),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.8),
                                      Colors.black.withOpacity(0.95),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 16,
                                left: 16,
                                child: Row(
                                  children: [
                                    if (isCombo)
                                      _Badge(
                                        label: AppLanguage.getText('Combos'),
                                        color: const Color(0xFFFF8C00),
                                        icon: Icons.fastfood_rounded,
                                      ),
                                    if (offerLabel != null) ...[
                                      if (isCombo) const SizedBox(width: 8),
                                      _Badge(
                                        label: offerLabel,
                                        color: kDiscount,
                                        icon: Icons.local_offer_rounded,
                                      ),
                                    ],
                                    if (hasAppOffer(data)) ...[
                                      const SizedBox(width: 8),
                                      _AppOfferBadge(data: data),
                                    ],
                                  ],
                                ),
                              ),
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: kPrimary.withOpacity(0.5),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Colors.white,
                                    size: 26,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 20,
                                left: 20,
                                right: 20,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black,
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'CHF ${offerPrice.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: kPrimary,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (originalPrice > offerPrice) ...[
                                          const SizedBox(width: 8),
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 2,
                                            ),
                                            child: Text(
                                              'CHF ${originalPrice.toStringAsFixed(2)}',
                                              style: TextStyle(
                                                color: kWhite.withOpacity(0.7),
                                                fontSize: 14,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    if (originalPrice > offerPrice) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: kDiscount,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          isCombo
                                              ? 'Combo offer • You save CHF ${(originalPrice - offerPrice).toStringAsFixed(2)}'
                                              : 'You save CHF ${(originalPrice - offerPrice).toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (count > 1) ...[
                if (current > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 16,
                    child: Center(
                      child: _CarouselArrow(
                        icon: Icons.chevron_left_rounded,
                        onTap: () => _goTo(current - 1),
                      ),
                    ),
                  ),
                if (current < count - 1)
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 16,
                    child: Center(
                      child: _CarouselArrow(
                        icon: Icons.chevron_right_rounded,
                        onTap: () => _goTo(current + 1),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            children: List.generate(
              count,
              (i) => GestureDetector(
                onTap: () => _goTo(i),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: current == i ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: current == i ? kPrimary : kMuted.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${current + 1} / $count',
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 13),
          ),
        ],
      ],
    );
  }
}

/// An offer the admin gave to app orders only. The website shows it too,
/// priced as in the app, but tapping it points the guest to the stores.
bool _isAppOnlyOffer(Map<String, dynamic> data) =>
    !appOffersApply && hasAppOffer(data);

double _shownOfferPrice(Map<String, dynamic> data) =>
    _isAppOnlyOffer(data) ? menuAppOfferPrice(data) : menuOfferPrice(data);

String? _shownOfferLabel(Map<String, dynamic> data) =>
    _isAppOnlyOffer(data) ? appOfferLabel(data) : menuOfferLabel(data);

class _AppOfferBadge extends StatelessWidget {
  final Map<String, dynamic> data;

  const _AppOfferBadge({required this.data});

  @override
  Widget build(BuildContext context) {
    return _Badge(
      label: AppLanguage.getText(
        _isAppOnlyOffer(data) ? 'app_offer_only_badge' : 'app_offer_badge',
      ),
      color: const Color(0xFF2F80ED),
      icon: Icons.phone_iphone_rounded,
    );
  }
}

/// A combo laid out as a full-width card, with a photo and name for every
/// menu inside it so guests see what they get before opening it.
class _ComboOfferCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, Map<String, dynamic>> liveMenus;
  final VoidCallback onTap;

  const _ComboOfferCard({
    required this.data,
    required this.liveMenus,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = (data['name'] as String?) ?? 'Combo';
    final double originalPrice = menuOriginalPrice(data);
    final double offerPrice = _shownOfferPrice(data);
    final offerLabel = _shownOfferLabel(data);
    final items = (data['comboItems'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((e) {
          final stored = Map<String, dynamic>.from(e);
          final live = liveMenus[stored['id']];
          final liveImage = live?['imageUrl'] as String?;
          return {
            ...stored,
            if (live?['name'] != null) 'name': live!['name'],
            if (liveImage != null && liveImage.isNotEmpty)
              'imageUrl': liveImage,
          };
        })
        .toList();

    return Material(
      color: kCardBg,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kPrimary.withOpacity(0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Badge(
                          label: AppLanguage.getText('Combos'),
                          color: const Color(0xFFFF8C00),
                          icon: Icons.fastfood_rounded,
                        ),
                        if (offerLabel != null)
                          _Badge(
                            label: offerLabel,
                            color: kDiscount,
                            icon: Icons.local_offer_rounded,
                          ),
                        if (hasAppOffer(data)) _AppOfferBadge(data: data),
                      ],
                    ),
                  ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 24),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 14),
              if (items.isNotEmpty) ...[
                Text(
                  '${AppLanguage.getText('This Combo Includes')} (${items.length})',
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                _ComboPhotoRow(items: items),
              ] else
                _ComboPhoto(
                  imageUrl: (data['imageUrl'] as String?) ?? '',
                  isDrink: false,
                  height: 160,
                ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'CHF ${offerPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: kPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (originalPrice > offerPrice) ...[
                    Text(
                      'CHF ${originalPrice.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: kWhite.withOpacity(0.6),
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kDiscount,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'You save CHF ${(originalPrice - offerPrice).toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The menus of a combo side by side, joined by "+". Up to four share the
/// card width; a longer combo scrolls sideways so no photo gets too small.
class _ComboPhotoRow extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const _ComboPhotoRow({required this.items});

  static const double _plusWidth = 22;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = items.length.clamp(1, 4);
        final tileWidth =
            (constraints.maxWidth - _plusWidth * (visible - 1)) / visible;
        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          if (i > 0) {
            children.add(
              const SizedBox(
                width: _plusWidth,
                child: Center(
                  child: Icon(Icons.add, color: kPrimary, size: 18),
                ),
              ),
            );
          }
          children.add(
            SizedBox(
              width: tileWidth,
              child: _ComboItemTile(item: items[i]),
            ),
          );
        }
        final row = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
        if (items.length <= 4) return row;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: row,
        );
      },
    );
  }
}

class _ComboItemTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ComboItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: _ComboPhoto(
            imageUrl: (item['imageUrl'] as String?) ?? '',
            isDrink: item['itemType'] == 'drink',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          (item['name'] as String?) ?? '',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: kWhite,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ComboPhoto extends StatelessWidget {
  final String imageUrl;
  final bool isDrink;
  final double? height;
  const _ComboPhoto({
    required this.imageUrl,
    required this.isDrink,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      color: Colors.black.withOpacity(0.25),
      alignment: Alignment.center,
      child: Icon(
        isDrink ? Icons.local_drink : Icons.restaurant,
        color: kMuted,
        size: 28,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: double.infinity,
        height: height,
        child: imageUrl.isEmpty
            ? fallback
            : buildUniversalImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fallback: fallback,
              ),
      ),
    );
  }
}

class _CarouselArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CarouselArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.55),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: kWhite, size: 30),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _BigActionButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isPrimary ? kPrimary : kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          if (isPrimary)
            BoxShadow(
              color: kPrimary.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          else
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
        ],
        border: isPrimary
            ? null
            : Border.all(color: kPrimary.withOpacity(0.2), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(icon, color: isPrimary ? kWhite : kPrimary, size: 36),
                const SizedBox(height: 12),
                Text(
                  label,
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MethodPickerSheet extends StatelessWidget {
  final VoidCallback onDineIn;
  final VoidCallback onTakeAway;
  const _MethodPickerSheet({required this.onDineIn, required this.onTakeAway});

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Container(
        decoration: const BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: kMuted.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Text(
              AppLanguage.getText('How would you like to order?'),
              style: const TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLanguage.getText('Please select before adding to cart'),
              style: TextStyle(color: kMuted.withOpacity(0.8), fontSize: 14),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _BigActionButton(
                    label: AppLanguage.getText('dine_in'),
                    icon: Icons.storefront_rounded,
                    isPrimary: true,
                    onTap: onDineIn,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _BigActionButton(
                    label: AppLanguage.getText('take_away'),
                    icon: Icons.takeout_dining_rounded,
                    isPrimary: false,
                    onTap: onTakeAway,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPromo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kPrimary.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.restaurant_menu_rounded,
              color: kPrimary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              AppLanguage.getText('Welcome to our Restaurant!'),
              style: const TextStyle(
                color: kWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLanguage.getText('Check out our menu for delicious meals.'),
              style: const TextStyle(color: kMuted, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PromoItemSheet extends StatefulWidget {
  final Map<String, dynamic> itemData;
  const _PromoItemSheet({required this.itemData});
  @override
  State<_PromoItemSheet> createState() => _PromoItemSheetState();
}

class _PromoItemSheetState extends State<_PromoItemSheet> {
  int _qty = 1;
  final TextEditingController _noteCtrl = TextEditingController();

  Map<String, dynamic>? _selectedSize;
  String? _selectedChoice;
  final List<Map<String, dynamic>> _selectedAddons = [];

  @override
  void initState() {
    super.initState();
    final List<dynamic> sizes = widget.itemData['sizes'] ?? [];
    if (sizes.isNotEmpty) {
      _selectedSize = sizes.first as Map<String, dynamic>;
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _basePrice {
    final hasSizes = widget.itemData['hasMultipleSizes'] == true;
    final sizePrice = hasSizes && _selectedSize != null
        ? ((_selectedSize!['price'] as num?)?.toDouble() ?? 0)
        : null;
    return menuOfferPrice(widget.itemData, sizePrice: sizePrice);
  }

  double get _totalPrice {
    double addons = 0;
    for (var a in _selectedAddons) {
      addons += (a['price'] as num?)?.toDouble() ?? 0.0;
    }
    return (_basePrice + addons) * _qty;
  }

  Future<void> _addToCart({bool goToCheckout = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final cartItem = {
      'name': widget.itemData['name'] ?? '',
      'price': _basePrice,
      'qty': _qty,
      'imageUrl': widget.itemData['imageUrl'] ?? '',
      'kind': widget.itemData['itemType'] ?? 'food',
      'size': _selectedSize != null ? _selectedSize!['name'] ?? '' : '',
      'note': _noteCtrl.text.trim(),
      'additionalOptions': _selectedAddons,
      'menuChoices': _selectedChoice != null ? {'Choice': _selectedChoice} : {},
      'createdAt': FieldValue.serverTimestamp(),
      if (comboOrderItems(widget.itemData).isNotEmpty)
        'comboItems': comboOrderItems(widget.itemData),
    };

    try {
      await FirebaseFirestore.instance
          .collection('chat')
          .doc(user.uid)
          .collection('items')
          .add(cartItem);
      if (!mounted) return;
      Navigator.pop(context);
      if (goToCheckout) {
        final delivDoc = await FirebaseFirestore.instance
            .collection('food_delivery')
            .doc(user.uid)
            .get();
        final method = delivDoc.data()?['delivery_method'] ?? '';
        final tableNo = method == 'Take_Away'
            ? 'Take-Away'
            : delivDoc.data()?['table_no'] as String?;
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CheckoutPage(uid: user.uid, tableNo: tableNo),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLanguage.getText('added_to_cart')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLanguage.getText("Error:")} $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.itemData['name'] ?? 'Item';
    final imageUrl = (widget.itemData['imageUrl'] ?? '') as String;

    final List<dynamic> sizes = widget.itemData['sizes'] ?? [];
    final bool hasMultipleSizes = widget.itemData['hasMultipleSizes'] ?? false;
    final List<dynamic> choices = widget.itemData['menuChoices'] ?? [];
    final List<dynamic> addons = widget.itemData['additionalOptions'] ?? [];
    final List<dynamic> comboItems = widget.itemData['comboItems'] ?? [];

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: kMuted.withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: imageUrl.isNotEmpty
                            ? Image.network(
                                imageUrl,
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 100,
                                height: 100,
                                color: kBg,
                                child: const Icon(
                                  Icons.fastfood,
                                  color: kMuted,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'CHF ${_basePrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: kPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.itemData['itemType'] == 'combo' &&
                      comboItems.isNotEmpty) ...[
                    ComboIncludes(
                      comboItems: comboItems,
                      savings: menuOriginalPrice(widget.itemData) > _basePrice
                          ? menuOriginalPrice(widget.itemData) - _basePrice
                          : null,
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (hasMultipleSizes && sizes.isNotEmpty) ...[
                    Text(
                      AppLanguage.getText('Select Portion / Size'),
                      style: const TextStyle(
                        color: kWhite,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: sizes.map((s) {
                          final sMap = s as Map<String, dynamic>;
                          final sName = sMap['name'] ?? '';
                          final sPrice =
                              (sMap['price'] as num?)?.toDouble() ?? 0.0;
                          return RadioListTile<Map<String, dynamic>>(
                            title: Text(
                              sName,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'CHF ${sPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: kMuted),
                            ),
                            activeColor: kPrimary,
                            value: sMap,
                            groupValue: _selectedSize,
                            onChanged: (val) =>
                                setState(() => _selectedSize = val),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text(
                    AppLanguage.getText('note_optional'),
                    style: const TextStyle(
                      color: kWhite,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: kWhite),
                    decoration: InputDecoration(
                      hintText: AppLanguage.getText('Any special requests...'),
                      hintStyle: const TextStyle(color: kMuted),
                      filled: true,
                      fillColor: kBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (choices.isNotEmpty) ...[
                    _SectionLabel(
                      AppLanguage.getText('Choose Option'),
                      required: true,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: choices.map((c) {
                          final cs = c.toString();
                          return RadioListTile<String>(
                            title: Text(
                              cs,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: kPrimary,
                            value: cs,
                            groupValue: _selectedChoice,
                            onChanged: (v) =>
                                setState(() => _selectedChoice = v),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (addons.isNotEmpty) ...[
                    _SectionLabel(
                      AppLanguage.getText('Add-ons'),
                      required: false,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: addons.map((addon) {
                          final aMap = addon as Map<String, dynamic>;
                          final aName = aMap['name'] ?? '';
                          final aPrice =
                              (aMap['price'] as num?)?.toDouble() ?? 0.0;
                          final isSel = _selectedAddons.contains(aMap);
                          return CheckboxListTile(
                            title: Text(
                              aName,
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '+CHF ${aPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: kMuted),
                            ),
                            activeColor: kPrimary,
                            checkColor: kWhite,
                            value: isSel,
                            onChanged: (val) => setState(() {
                              if (val == true) {
                                _selectedAddons.add(aMap);
                              } else {
                                _selectedAddons.remove(aMap);
                              }
                            }),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            decoration: BoxDecoration(
              color: kDarkBar,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(32),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        AppLanguage.getText('quantity'),
                        style: const TextStyle(
                          color: kMuted,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          _QtyBtn(
                            icon: Icons.remove,
                            onTap: () =>
                                setState(() => _qty = _qty > 1 ? _qty - 1 : 1),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              '$_qty',
                              style: const TextStyle(
                                color: kWhite,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          _QtyBtn(
                            icon: Icons.add,
                            onTap: () => setState(() => _qty++),
                          ),
                        ],
                      ),
                      Text(
                        'CHF ${_totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: kWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: kPrimary, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _addToCart(),
                            child: Text(
                              AppLanguage.getText('add_to_cart'),
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _addToCart(goToCheckout: true),
                            child: Text(
                              AppLanguage.getText('buy_now'),
                              style: const TextStyle(
                                color: kWhite,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _SectionLabel(this.text, {required this.required});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            color: kWhite,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: required
                ? kPrimary.withOpacity(0.2)
                : kMuted.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            required
                ? AppLanguage.getText('Required')
                : AppLanguage.getText('Optional'),
            style: TextStyle(
              color: required ? kPrimary : kMuted,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kItemBg,
          border: Border.all(color: kMuted.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: kWhite, size: 22),
      ),
    );
  }
}
