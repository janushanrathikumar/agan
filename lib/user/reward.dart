import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

// --- Re-using the unified palette ---
const kPrimary = Color(0xFFA26334); // coffee brown
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

class RewardPage extends StatefulWidget {
  const RewardPage({super.key});
  @override
  State<RewardPage> createState() => _RewardPageState();
}

class _RewardPageState extends State<RewardPage> {
  User? _user;
  late final CollectionReference _rewardsRef;

  // --- Initial State Data ---
  int _totalCoins = 0;
  int _currentStreak = 0;
  DateTime? _lastCheckIn;
  bool _canCollect = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initFirebaseAndFetchData();
  }

  // Helper to get the reward amount based on the streak
  int _getReward(int streak) {
    if (streak == 1 || streak == 2) return 20;
    return 30;
  }

  // Helper function to initialize Firebase/Auth and fetch reward data
  Future<void> _initFirebaseAndFetchData() async {
    // 1. Ensure user is authenticated (using existing anonymous sign-in pattern)
    final auth = FirebaseAuth.instance;
    User? user = auth.currentUser;
    if (user == null) {
      final cred = await auth.signInAnonymously();
      user = cred.user;
    }

    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    _user = user;
    _rewardsRef = FirebaseFirestore.instance.collection('rewards');

    // 2. Fetch initial data
    await _fetchRewardsData();
  }

  Future<void> _fetchRewardsData() async {
    if (_user == null) return;

    try {
      final docSnap = await _rewardsRef.doc(_user!.uid).get();

      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;

        // Load persistent data
        _totalCoins = (data['totalCoins'] as num?)?.toInt() ?? 0;
        _currentStreak = (data['currentStreak'] as num?)?.toInt() ?? 0;
        final timestamp = data['lastCheckInDate'] as Timestamp?;
        _lastCheckIn = timestamp?.toDate();
      }

      _updateCollectionStatus();
    } catch (e) {
      // Log error for debugging
      print('Error fetching rewards: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load rewards data.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Logic to determine if the user can collect today.
  void _updateCollectionStatus() {
    if (_lastCheckIn == null) {
      // First time ever checking in
      _canCollect = true;
    } else {
      final now = DateTime.now();
      final lastCheckInDay =
          DateTime(_lastCheckIn!.year, _lastCheckIn!.month, _lastCheckIn!.day);
      final today = DateTime(now.year, now.month, now.day);

      // Can collect if last check-in was NOT today
      _canCollect = today.isAfter(lastCheckInDay);
    }
  }

  // --- Main Reward Logic ---
  Future<void> _checkAndCollectReward() async {
    if (_user == null || !_canCollect) return;

    setState(() => _isLoading = true);

    int newStreak;
    int coinsCollected;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastCheckIn == null) {
      // 1. First time ever
      newStreak = 1;
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      final lastCheckInDay =
          DateTime(_lastCheckIn!.year, _lastCheckIn!.month, _lastCheckIn!.day);

      if (lastCheckInDay.isAtSameMomentAs(yesterday)) {
        // 2. Continuing the streak
        newStreak = _currentStreak + 1;
      } else {
        // 3. Streak broken (missed day)
        newStreak = 1;
      }
    }

    coinsCollected = _getReward(newStreak);

    final newTotalCoins = _totalCoins + coinsCollected;

    try {
      await _rewardsRef.doc(_user!.uid).set({
        'totalCoins': newTotalCoins,
        'currentStreak': newStreak,
        'lastCheckInDate':
            Timestamp.fromDate(now), // Use full timestamp for accurate record
      });

      // Update local state after successful write
      _totalCoins = newTotalCoins;
      _currentStreak = newStreak;
      _lastCheckIn = now;
      _canCollect = false; // Cannot collect again until tomorrow

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Success! Collected $coinsCollected coins. Streak: $_currentStreak days.'),
            backgroundColor: kPrimary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    // --- UI Implementation ---
    return Scaffold(
      backgroundColor: kBg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Total Coins Display
            _CoinBalanceCard(totalCoins: _totalCoins),
            const SizedBox(height: 20),

            // 2. Current Streak Card
            _StreakCard(
                currentStreak: _currentStreak, lastCheckIn: _lastCheckIn),
            const SizedBox(height: 20),

            // 3. Reward Schedule
            const Text('Daily Reward Calendar',
                style: TextStyle(
                    color: kWhite, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _RewardSchedule(currentStreak: _currentStreak),
            const SizedBox(height: 30),

            // 4. Collect Button
            AnimatedOpacity(
              opacity: _canCollect ? 1.0 : 0.6,
              duration: const Duration(milliseconds: 300),
              child: FilledButton.icon(
                onPressed: _canCollect ? _checkAndCollectReward : null,
                icon: const Icon(Icons.star, size: 28),
                label: Text(
                  _canCollect
                      ? 'COLLECT TODAY\'S REWARD (${_getReward(_currentStreak + 1)} COINS)'
                      : 'REWARD ALREADY COLLECTED TODAY',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _canCollect ? kPrimary : kMuted.withOpacity(0.5),
                  foregroundColor: kWhite,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Custom Widgets ---

class _CoinBalanceCard extends StatelessWidget {
  final int totalCoins;
  const _CoinBalanceCard({required this.totalCoins});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on, color: kPrimary, size: 40),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your Coin Balance',
                  style: TextStyle(color: kMuted, fontSize: 14)),
              Text('$totalCoins Coins',
                  style: const TextStyle(
                      color: kWhite,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int currentStreak;
  final DateTime? lastCheckIn;
  const _StreakCard({required this.currentStreak, this.lastCheckIn});

  String _formatLastCheckIn(DateTime? date) {
    if (date == null) return 'Never checked in.';
    final today = DateTime.now();
    final lastCheckInDay = DateTime(date.year, date.month, date.day);
    final yesterday = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 1));

    if (lastCheckInDay
        .isAtSameMomentAs(DateTime(today.year, today.month, today.day))) {
      return 'Last collected: Today at ${DateFormat('jm').format(date)}';
    } else if (lastCheckInDay.isAtSameMomentAs(yesterday)) {
      return 'Last collected: Yesterday';
    } else {
      return 'Last collected: ${DateFormat('MMM d, y').format(date)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Current Streak',
              style: TextStyle(color: kMuted, fontSize: 14)),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(Icons.local_fire_department,
                  color: kPrimary, size: 30),
              const SizedBox(width: 10),
              Text('$currentStreak Days',
                  style: const TextStyle(
                      color: kWhite,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(height: 25, color: kMuted),
          Text(_formatLastCheckIn(lastCheckIn),
              style: const TextStyle(color: kMuted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RewardSchedule extends StatelessWidget {
  final int currentStreak;
  const _RewardSchedule({required this.currentStreak});

  int _getReward(int day) {
    if (day == 1 || day == 2) return 20;
    return 30;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _RewardItem(
            day: 1,
            reward: _getReward(1),
            isCurrent: currentStreak == 0, // Highlight day 1 if streak is reset
            isCompleted: currentStreak >= 1,
            label: 'Start New Streak',
          ),
          _RewardItem(
            day: 2,
            reward: _getReward(2),
            isCurrent: currentStreak == 1,
            isCompleted: currentStreak >= 2,
          ),
          _RewardItem(
            day: 3,
            reward: _getReward(3),
            isCurrent: currentStreak == 2,
            isCompleted: currentStreak >= 3,
          ),
          _RewardItem(
            day: 4,
            reward: _getReward(4),
            isCurrent: currentStreak == 3,
            isCompleted: currentStreak >= 4,
            label: 'Day 4+',
          ),
        ],
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final int day;
  final int reward;
  final bool isCurrent;
  final bool isCompleted;
  final String? label;

  const _RewardItem({
    required this.day,
    required this.reward,
    required this.isCurrent,
    required this.isCompleted,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    Color color = isCompleted
        ? const Color(0xFF63A234)
        : (isCurrent ? kPrimary : kMuted.withOpacity(0.3));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: isCompleted
                ? const Icon(Icons.check, color: kWhite, size: 20)
                : Text(day.toString(),
                    style: const TextStyle(
                        color: kWhite, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label ?? 'Day $day',
              style: TextStyle(
                color: kWhite,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on, color: kPrimary, size: 16),
                const SizedBox(width: 4),
                Text('$reward Coins',
                    style:
                        TextStyle(color: kWhite, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
