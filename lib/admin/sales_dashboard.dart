import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Re-using the unified palette
const kPrimary = Color(0xFFA26334);
const kBg = Color(0xFF2A2928);
const kMuted = Color(0xFFB7B7B6);
const kWhite = Color(0xFFFFFFFF);

/// Dashboard component that streams and displays real-time sales metrics.
class SalesDashboard extends StatelessWidget {
  const SalesDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Stream all orders for real-time calculation
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimary));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.red)),
          );
        }

        final orders = snapshot.data?.docs ?? [];
        final now = DateTime.now();

        // 1. Calculate Core Metrics
        final metrics = _calculateMetrics(orders, now);
        final topSellers = _calculateTopSellers(orders);

        // 2. Calculate Analytics Data
        final peakHours = _calculatePeakHours(orders);
        final weeklyTrend = _calculateWeeklyTrend(orders, now);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revenue Overview',
                  style: TextStyle(
                      color: kPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              // Key Metrics Cards
              _KeyMetricsRow(metrics: metrics),

              const SizedBox(height: 32),

              // Smart Reports & Forecasting - Weekly Trend
              const Text('Weekly Sales Trend',
                  style: TextStyle(
                      color: kPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _SalesTrendReport(weeklyTrend: weeklyTrend),

              const SizedBox(height: 32),

              // Customer Analytics - Peak Hours
              const Text('Peak Order Hours',
                  style: TextStyle(
                      color: kPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _PeakHoursReport(peakHours: peakHours),

              const SizedBox(height: 32),

              // Top Selling Items
              const Text('Top Selling Items',
                  style: TextStyle(
                      color: kPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),

              _TopSellersList(topSellers: topSellers),
            ],
          ),
        );
      },
    );
  }

  // --- Data Processing Functions (Original) ---

  /// Helper to create a unique integer key for a specific day.
  /// Fixes the issue where DateTime.dayOfYear is not defined.
  int _getDayKey(DateTime date) {
    // Uses the number of days since the epoch (1970-01-01) for a unique integer day key.
    // This correctly handles leap years and year boundaries.
    return date.difference(DateTime.utc(1970)).inDays;
  }

  Map<String, double> _calculateMetrics(
      List<QueryDocumentSnapshot> orders, DateTime now) {
    double dailyRevenue = 0;
    double weeklyRevenue = 0;
    double monthlyRevenue = 0;
    double totalProfit = 0;
    const profitMargin = 0.30; // Mock 30% profit margin

    // Define time boundaries
    final startOfDay = DateTime(now.year, now.month, now.day);
    // Dart's weekday starts with 1=Monday, so subtract (1-1=0) for Monday, (7-1=6) for Sunday
    final startOfWeek = startOfDay.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      if (timestamp != null) {
        // Calculate Profit
        totalProfit += total * profitMargin;

        // Daily
        if (timestamp.isAfter(startOfDay) ||
            timestamp.isAtSameMomentAs(startOfDay)) {
          dailyRevenue += total;
        }
        // Weekly
        if (timestamp.isAfter(startOfWeek) ||
            timestamp.isAtSameMomentAs(startOfWeek)) {
          weeklyRevenue += total;
        }
        // Monthly
        if (timestamp.isAfter(startOfMonth) ||
            timestamp.isAtSameMomentAs(startOfMonth)) {
          monthlyRevenue += total;
        }
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
      List<QueryDocumentSnapshot> orders) {
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

    // Convert map to a list of maps and sort by quantity
    final sortedItems =
        itemCounts.entries.map((e) => {'name': e.key, 'qty': e.value}).toList();

    // Sort descending
    sortedItems.sort((a, b) => (b['qty'] as int).compareTo(a['qty'] as int));

    // Return top 5
    return sortedItems.take(5).toList();
  }

  // --- New Data Processing Functions (Analytics) ---

  /// Returns a map of <hour_of_day (0-23), number_of_orders>
  Map<int, int> _calculatePeakHours(List<QueryDocumentSnapshot> orders) {
    final hourlyCounts = <int, int>{};
    for (var i = 0; i < 24; i++) {
      hourlyCounts[i] = 0;
    }

    // Filter to only orders within the last 7 days for current trend relevance
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      if (timestamp != null && timestamp.isAfter(sevenDaysAgo)) {
        final hour = timestamp.hour; // 0 to 23
        hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
      }
    }

    return hourlyCounts;
  }

  /// Returns a list of <DayName, daily_revenue> for the last 7 days.
  List<Map<String, dynamic>> _calculateWeeklyTrend(
      List<QueryDocumentSnapshot> orders, DateTime now) {
    // FIX: Using int as the key for the map to store daily revenue
    final dailyRevenueMap = <int, double>{};
    final trendList = <Map<String, dynamic>>[];
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    // 1. Aggregate revenue by day key
    for (final doc in orders) {
      final data = doc.data() as Map<String, dynamic>;
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate();

      if (timestamp != null && timestamp.isAfter(sevenDaysAgo)) {
        // FIX: Use the new helper function to get a unique integer day key
        final dayKey = _getDayKey(timestamp);
        dailyRevenueMap[dayKey] = (dailyRevenueMap[dayKey] ?? 0.0) + total;
      }
    }

    // 2. Build the final 7-day trend list
    final dayFormatter = DateFormat('E'); // E = Mon, Tue, etc.

    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      // FIX: Use the new helper function to get a unique integer day key
      final dayKey = _getDayKey(day);
      final dayName = i == 0 ? 'Today' : dayFormatter.format(day);

      trendList.add({
        'day': dayName,
        'revenue': dailyRevenueMap[dayKey] ?? 0.0,
      });
    }

    return trendList;
  }
}

// --- Widget Helpers for UI (Original) ---

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
          childAspectRatio: crossAxisCount == 1 ? 2.5 : 1.8,
          children: [
            _MetricCard(
              title: 'Today\'s Revenue',
              value: metrics['daily']!,
              icon: Icons.attach_money,
              color: kPrimary,
            ),
            _MetricCard(
              title: 'Weekly Sales',
              value: metrics['weekly']!,
              icon: Icons.calendar_view_week,
              color: kMuted,
            ),
            _MetricCard(
              title: 'Monthly Sales',
              value: metrics['monthly']!,
              icon: Icons.calendar_today,
              color: kMuted,
            ),
            _MetricCard(
              title: 'Total Profit (Est.)',
              value: metrics['profit']!,
              icon: Icons.trending_up,
              color: const Color(0xFF63A234), // Green for profit
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
    final currencyFormatter =
        NumberFormat.currency(symbol: 'RM ', decimalDigits: 2);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: kMuted,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              currencyFormatter.format(value),
              style: const TextStyle(
                color: kWhite,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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
      return const Center(
          child: Text('No sales data yet.', style: TextStyle(color: kMuted)));
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: topSellers.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final name = item['name'] as String;
          final qty = item['qty'] as int;

          final isFirst = index == 0;
          final isLast = index == topSellers.length - 1;

          return Padding(
            padding: EdgeInsets.only(top: isFirst ? 12.0 : 0),
            child: Column(
              children: [
                ListTile(
                  leading: Text('#${index + 1}',
                      style: TextStyle(
                        color: isFirst ? kPrimary : kMuted,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      )),
                  title: Text(name,
                      style: const TextStyle(
                          color: kWhite, fontWeight: FontWeight.w600)),
                  trailing: Text('$qty Sold',
                      style: TextStyle(
                          color: kWhite,
                          fontWeight:
                              isFirst ? FontWeight.bold : FontWeight.normal)),
                ),
                if (!isLast)
                  const Divider(
                      color: Color(0xFF3A3938),
                      height: 1,
                      indent: 16,
                      endIndent: 16),
                if (isLast) const SizedBox(height: 12),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// --- New Analytics Widgets (Smart Reports & Forecasting / Customer Analytics) ---

/// Displays a simple bar chart representing the hourly frequency of orders.
class _PeakHoursReport extends StatelessWidget {
  final Map<int, int> peakHours;
  const _PeakHoursReport({required this.peakHours});

  @override
  Widget build(BuildContext context) {
    final maxOrders = peakHours.values.fold(0, (a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Hour',
                  style: TextStyle(color: kMuted, fontWeight: FontWeight.bold)),
              Text('${maxOrders} Orders',
                  style: const TextStyle(
                      color: kMuted, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          ...peakHours.entries.map((entry) {
            final hour = entry.key;
            final count = entry.value;
            final normalizedValue = maxOrders == 0 ? 0.0 : count / maxOrders;
            final timeLabel = DateFormat('ha')
                .format(DateTime(0, 0, 0, hour)); // e.g., 9AM, 1PM

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(timeLabel,
                        style: const TextStyle(color: kWhite, fontSize: 12)),
                  ),
                  Expanded(
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A3938),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: normalizedValue,
                        child: Container(
                          decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(count > 0 ? '$count' : '',
                                style: const TextStyle(
                                    color: kWhite,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

/// Displays the sales trend over the last 7 days.
class _SalesTrendReport extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyTrend;
  const _SalesTrendReport({required this.weeklyTrend});

  @override
  Widget build(BuildContext context) {
    final maxRevenue = weeklyTrend.fold(0.0, (max, item) {
      final revenue = (item['revenue'] as double);
      return revenue > max ? revenue : max;
    });

    final currencyFormatter =
        NumberFormat.currency(symbol: 'RM ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2E2D),
        borderRadius: BorderRadius.circular(12),
      ),
      height: 250,
      child: Column(
        children: [
          // Top Label (Max Revenue)
          Align(
            alignment: Alignment.centerRight,
            child: Text('Max: ${currencyFormatter.format(maxRevenue)}',
                style: const TextStyle(color: kMuted, fontSize: 12)),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: weeklyTrend.map((item) {
                final day = item['day'] as String;
                final revenue = item['revenue'] as double;
                final normalizedHeight =
                    maxRevenue == 0 ? 0.0 : revenue / maxRevenue;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Tooltip (Value)
                        Text(
                            revenue > 0
                                ? currencyFormatter.format(revenue)
                                : '',
                            style: TextStyle(
                                color: kWhite,
                                fontSize: 10,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        // Bar
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: normalizedHeight,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: kPrimary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Day Label
                        Text(day,
                            style: TextStyle(
                                color: kMuted,
                                fontSize: 12,
                                fontWeight: day == 'Today'
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
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
