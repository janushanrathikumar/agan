// lib/kitchen/station_login.dart
//
// Login gate in front of the Kitchen and Bar boards.
//
// ⚠️ The credentials below are compiled into the app bundle, so anyone who
// inspects the JavaScript can read them. This gate only stops someone from
// casually opening a station board (e.g. by typing /kitchen in the browser);
// it is not real security. Move the check to Firebase Auth or a Firestore
// document if that is ever needed.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'station_orders.dart';

extension StationCredentials on OrderStation {
  String get username => this == OrderStation.kitchen ? 'kitchen' : 'bar';

  String get password =>
      this == OrderStation.kitchen ? 'kitchen123' : 'bar123';

  String get _sessionPrefKey => this == OrderStation.kitchen
      ? 'kitchen_session_active'
      : 'bar_session_active';
}

/// Remembers, per browser/device, that a station has been unlocked, so the
/// staff do not have to log in again after every page refresh.
class StationSession {
  static Future<bool> isSignedIn(OrderStation station) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(station._sessionPrefKey) ?? false;
  }

  static bool matches(OrderStation station, String user, String pass) {
    return user.trim().toLowerCase() == station.username &&
        pass == station.password;
  }

  static Future<void> signIn(OrderStation station) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(station._sessionPrefKey, true);
  }

  static Future<void> signOut(OrderStation station) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(station._sessionPrefKey);
  }
}

/// Shows the login form until the station is unlocked, then the order board.
class StationGate extends StatefulWidget {
  const StationGate({super.key, required this.station});

  final OrderStation station;

  @override
  State<StationGate> createState() => _StationGateState();
}

class _StationGateState extends State<StationGate> {
  bool _checking = true;
  bool _signedIn = false;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final signedIn = await StationSession.isSignedIn(widget.station);
    if (!mounted) return;
    setState(() {
      _signedIn = signedIn;
      _checking = false;
    });
  }

  Future<void> _handleSignOut() async {
    await StationSession.signOut(widget.station);
    if (!mounted) return;
    setState(() => _signedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: kStBg,
        body: Center(
          child: CircularProgressIndicator(color: widget.station.accent),
        ),
      );
    }

    if (!_signedIn) {
      return StationLoginPage(
        station: widget.station,
        onSignedIn: () => setState(() => _signedIn = true),
      );
    }

    return StationOrdersPage(
      station: widget.station,
      onSignOut: _handleSignOut,
    );
  }
}

class StationLoginPage extends StatefulWidget {
  const StationLoginPage({
    super.key,
    required this.station,
    required this.onSignedIn,
  });

  final OrderStation station;
  final VoidCallback onSignedIn;

  @override
  State<StationLoginPage> createState() => _StationLoginPageState();
}

class _StationLoginPageState extends State<StationLoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  OrderStation get _station => widget.station;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_busy) return;

    final user = _usernameCtrl.text;
    final pass = _passwordCtrl.text;

    if (!StationSession.matches(_station, user, pass)) {
      setState(() => _error = 'Wrong username or password.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    await StationSession.signIn(_station);
    if (!mounted) return;
    setState(() => _busy = false);
    widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kStBg,
      body: SafeArea(
        child: Stack(
          children: [
            if (Navigator.of(context).canPop())
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: kStWhite,
                    size: 22,
                  ),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Back',
                ),
              ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: kStCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kStItemBg, width: 1.5),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _station.accent.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _station.icon,
                              color: _station.accent,
                              size: 36,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          '${_station.title} Login',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kStWhite,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sign in to see the ${_station.title.toLowerCase()} orders.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: kStMuted,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _field(
                          controller: _usernameCtrl,
                          label: 'Username',
                          icon: Icons.person,
                        ),
                        const SizedBox(height: 16),
                        _field(
                          controller: _passwordCtrl,
                          label: 'Password',
                          icon: Icons.lock,
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: kStMuted,
                              size: 20,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(
                                Icons.error_outline,
                                color: Colors.redAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _station.accent,
                            foregroundColor: kStWhite,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _busy ? null : _login,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: kStWhite,
                                  ),
                                )
                              : const Text(
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: kStWhite),
      // Enter submits from either field, so the staff never need the mouse.
      onSubmitted: (_) => _login(),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kStMuted),
        prefixIcon: Icon(icon, color: kStMuted),
        suffixIcon: suffix,
        filled: true,
        fillColor: kStBg,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kStItemBg, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: _station.accent, width: 1.5),
        ),
      ),
    );
  }
}
