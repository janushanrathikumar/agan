import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- Theme Palette ---
const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF2A2928);
const kCardBg = Color(0xFF383735); // Slightly lighter for cards
const kItemBg = Color(0xFF2F2E2D);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);
const kSuccess = Color(0xFF558B2F); // Soft green for profit

class SalesDashboard extends StatelessWidget {
  const SalesDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg, // Ensure background matches theme
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final orders = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          // Process Data
          final metrics = _calculateMetrics(orders, now);
          final topSellers = _calculateTopSellers(orders);
          final peakHours = _calculatePeakHours(orders);
          final weeklyTrend = _calculateWeeklyTrend(orders, now);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Dashboard Overview',
                  style: TextStyle(
                    color: kWhite,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track your sales and performance',
                  style: TextStyle(
                    color: kMuted.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Key Metrics Grid
                _KeyMetricsRow(metrics: metrics),

                const SizedBox(height: 32),

                // Weekly Trend Chart
                const _SectionHeader(
                  title: 'Weekly Sales Trend',
                  icon: Icons.insights,
                ),
                const SizedBox(height: 16),
                _SalesTrendReport(weeklyTrend: weeklyTrend),

                const SizedBox(height: 32),

                // Grid for Peak Hours and Top Sellers
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      // Desktop/Tablet layout: Row
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(
                                  title: 'Top 5 Busiest Hours',
                                  icon: Icons.access_time_filled,
                                ),
                                const SizedBox(height: 16),
                                _PeakHoursReport(peakHours: peakHours),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader(
                                  title: 'Top Selling Items',
                                  icon: Icons.star_rounded,
                                ),
                                const SizedBox(height: 16),
                                _TopSellersList(topSellers: topSellers),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      // Mobile layout: Column
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _SectionHeader(
                            title: 'Top 5 Busiest Hours',
                            icon: Icons.access_time_filled,
                          ),
                          const SizedBox(height: 16),
                          _PeakHoursReport(peakHours: peakHours),
                          const SizedBox(height: 32),
                          const _SectionHeader(
                            title: 'Top Selling Items',
                            icon: Icons.star_rounded,
                          ),
                          const SizedBox(height: 16),
                          _TopSellersList(topSellers: topSellers),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- Logic Functions ---

  int _getDayKey(DateTime date) {
    return date.difference(DateTime.utc(1970)).inDays;
  }

  Map<String, double> _calculateMetrics(
    List<QueryDocumentSnapshot> orders,
    DateTime now,
  ) {
    double dailyRevenue = 0;
    double weeklyRevenue = 0;
    double monthlyRevenue = 0;
    double totalProfit = 0;
    const profitMargin = 0.30;

    final startOfDay = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      if (timestamp != null) {
        totalProfit += total * profitMargin;
        if (timestamp.isAfter(startOfDay) ||
            timestamp.isAtSameMomentAs(startOfDay))
          dailyRevenue += total;
        if (timestamp.isAfter(startOfWeek) ||
            timestamp.isAtSameMomentAs(startOfWeek))
          weeklyRevenue += total;
        if (timestamp.isAfter(startOfMonth) ||
            timestamp.isAtSameMomentAs(startOfMonth))
          monthlyRevenue += total;
      }
    }

    return {
      'daily': dailyRevenue,
      'weekly': weeklyRevenue,
      'monthly': monthlyRevenue,
      'profit': totalProfit,
    };
  }

  List<Map<String, dynamic>> _calculateTopSellers(
    List<QueryDocumentSnapshot> orders,
  ) {
    final itemCounts = <String, int>{};
    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final items = (data['items'] as List<dynamic>?) ?? [];
      for (final item in items) {
        if (item is Map<String, dynamic>) {
          final name = item['name'] as String? ?? 'Unknown Item';
          final qty = (item['qty'] as num?)?.toInt() ?? 0;
          itemCounts[name] = (itemCounts[name] ?? 0) + qty;
        }
      }
    }
    final sortedItems = itemCounts.entries
        .map((e) => {'name': e.key, 'qty': e.value})
        .toList();
    sortedItems.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));
    return sortedItems.take(5).toList();
  }

  // Modified to return Top 5 hours instead of all 24
  List<Map<String, dynamic>> _calculatePeakHours(
    List<QueryDocumentSnapshot> orders,
  ) {
    final hourlyCounts = <int, int>{};
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
      if (timestamp != null && timestamp.isAfter(sevenDaysAgo)) {
        final hour = timestamp.hour;
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
    }

    final sortedHours = hourlyCounts.entries
        .map((e) => {'hour': e.key, 'count': e.value})
        .toList();
    sortedHours.sort(
      (a, b) => (b['count'] as int).compareTo(a['count'] as int),
    );

    // Only return the top 5 busiest hours to keep the UI clean
    return sortedHours.take(5).toList();
  }

  List<Map<String, dynamic>> _calculateWeeklyTrend(
    List<QueryDocumentSnapshot> orders,
    DateTime now,
  ) {
    final dailyRevenueMap = <int, double>{};
    final trendList = <Map<String, dynamic>>[];
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      if (timestamp != null && timestamp.isAfter(sevenDaysAgo)) {
        final dayKey = _getDayKey(timestamp);
        dailyRevenueMap[dayKey] = (dailyRevenueMap[dayKey] ?? 0.0) + total;
      }
    }

    final dayFormatter = DateFormat('E');
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayKey = _getDayKey(day);
      trendList.add({
        'day': i == 0 ? 'Today' : dayFormatter.format(day),
        'revenue': dailyRevenueMap[dayKey] ?? 0.0,
      });
    }
    return trendList;
  }
}

// --- UI Components ---

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: kPrimary, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: kWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _KeyMetricsRow extends StatelessWidget {
  final Map<String, double> metrics;
  const _KeyMetricsRow({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 1000
            ? 4
            : constraints.maxWidth > 600
            ? 2
            : 1;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: crossAxisCount == 1 ? 2.8 : 2.0,
          children: [
            _MetricCard(
              title: 'Today\'s Revenue',
              value: metrics['daily']!,
              icon: Icons.payments_rounded,
              color: kPrimary,
            ),
            _MetricCard(
              title: 'Weekly Sales',
              value: metrics['weekly']!,
              icon: Icons.calendar_view_week_rounded,
              color: Colors.blueAccent,
            ),
            _MetricCard(
              title: 'Monthly Sales',
              value: metrics['monthly']!,
              icon: Icons.calendar_month_rounded,
              color: Colors.orangeAccent,
            ),
            _MetricCard(
              title: 'Total Profit (Est.)',
              value: metrics['profit']!,
              icon: Icons.trending_up_rounded,
              color: kSuccess,
            ),
          ],
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final double value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // 🟢 Currency changed from RM (Malaysian Ringgit) to CHF (Swiss Franc)
    // to match the rest of the app (see menu.dart / checkout.dart).
    final currencyFormatter = NumberFormat.currency(
      symbol: 'CHF ',
      decimalDigits: 2,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormatter.format(value),
              style: const TextStyle(
                color: kWhite,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTrendReport extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyTrend;
  const _SalesTrendReport({required this.weeklyTrend});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = weeklyTrend.fold(0.0, (max, item) {
      final revenue = (item['revenue'] as double);
      return revenue > max ? revenue : max;
    });

    // 🟢 Currency changed from RM to CHF
    final currencyFormatter = NumberFormat.currency(
      symbol: 'CHF ',
      decimalDigits: 0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      height: 300,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kItemBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Peak: ${currencyFormatter.format(maxRevenue)}',
                style: const TextStyle(
                  color: kMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyTrend.map((item) {
                final day = item['day'] as String;
                final revenue = item['revenue'] as double;
                final isToday = day == 'Today';
                final normalizedHeight = maxRevenue == 0
                    ? 0.0
                    : revenue / maxRevenue;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          revenue > 0 ? currencyFormatter.format(revenue) : '',
                          style: TextStyle(
                            color: isToday ? kPrimary : kMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: normalizedHeight,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 800),
                                curve: Curves.easeOutQuart,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isToday
                                        ? [kPrimary.withOpacity(0.8), kPrimary]
                                        : [kItemBg.withOpacity(0.8), kItemBg],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          day,
                          style: TextStyle(
                            color: isToday ? kWhite : kMuted,
                            fontSize: 12,
                            fontWeight: isToday
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeakHoursReport extends StatelessWidget {
  final List<Map<String, dynamic>> peakHours;
  const _PeakHoursReport({required this.peakHours});

  @override
  Widget build(BuildContext context) {
    if (peakHours.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No recent order data',
          style: TextStyle(color: kMuted),
        ),
      );
    }

    final maxOrders = peakHours.first['count'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: peakHours.map((entry) {
          final hour = entry['hour'] as int;
          final count = entry['count'] as int;
          final normalizedValue = maxOrders == 0 ? 0.0 : count / maxOrders;
          final timeLabel = DateFormat('h a').format(DateTime(0, 0, 0, hour));

          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    timeLabel,
                    style: const TextStyle(
                      color: kWhite,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        height: 16,
                        decoration: BoxDecoration(
                          color: kItemBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: normalizedValue,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOut,
                          height: 16,
                          decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 30,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TopSellersList extends StatelessWidget {
  final List<Map<String, dynamic>> topSellers;
  const _TopSellersList({required this.topSellers});

  @override
  Widget build(BuildContext context) {
    if (topSellers.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'No sales data yet.',
          style: TextStyle(color: kMuted),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: topSellers.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final name = item['name'] as String;
          final qty = item['qty'] as int;

          final isFirst = index == 0;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isFirst ? kPrimary : kItemBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: isFirst ? kWhite : kMuted,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            title: Text(
              name,
              style: TextStyle(
                color: kWhite,
                fontWeight: isFirst ? FontWeight.bold : FontWeight.w500,
                fontSize: 15,
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$qty sold',
                style: const TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
