// lib/admin/sales_dashboard.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const kPrimary = Color(0xFFB59410);
const kBg = Color(0xFF1E1E1E);
const kCardBg = Color(0xFF2A2A2A);
const kWhite = Color(0xFFFFFFFF);
const kMuted = Color(0xFF9E9E9E);
const kGreen = Color(0xFF4CAF50);
const kRed = Color(0xFFE53935);

class SalesDashboard extends StatelessWidget {
  const SalesDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('orders').snapshots(),
      builder: (context, snapshot) {
        // 1. Loading State
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(50.0),
              child: CircularProgressIndicator(color: kPrimary),
            ),
          );
        }

        // 2. Error State
        if (snapshot.hasError) {
          return Center(
            child: Text(
              "Error loading data: ${snapshot.error}",
              style: const TextStyle(color: kRed),
            ),
          );
        }

        // 3. Calculate Real-time Metrics from Firestore
        final docs = snapshot.data?.docs ?? [];

        int totalOrdersCount = docs.length;
        int totalDeliveredCount = 0;
        int totalCanceledCount = 0;
        double totalRevenue = 0.0;

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          final num orderTotal = data['total'] ?? 0;

          if (status == 'delivered') {
            totalDeliveredCount++;
          } else if (status == 'canceled') {
            totalCanceledCount++;
          }

          totalRevenue += orderTotal.toDouble();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Welcome Text ──
              const Text(
                "Dashboard Overview",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Here's what's happening with your restaurant today.",
                style: TextStyle(color: kMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // ── Responsive Stats Grid (Dynamic Data) ──
              LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount = constraints.maxWidth < 600 ? 2 : 4;
                  return GridView.count(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: constraints.maxWidth < 600 ? 1.4 : 1.8,
                    children: [
                      _buildStatCard(
                        title: "Total Orders",
                        value: "$totalOrdersCount",
                        trend: "Live Database",
                        icon: Icons.shopping_basket_rounded,
                        iconColor: Colors.orangeAccent,
                        isPositive: true,
                      ),
                      _buildStatCard(
                        title: "Total Delivered",
                        value: "$totalDeliveredCount",
                        trend: "Successful",
                        icon: Icons.delivery_dining_rounded,
                        iconColor: Colors.blueAccent,
                        isPositive: true,
                      ),
                      _buildStatCard(
                        title: "Total Canceled",
                        value: "$totalCanceledCount",
                        trend: "Canceled Orders",
                        icon: Icons.cancel_presentation_rounded,
                        iconColor: kRed,
                        isPositive: false,
                      ),
                      _buildStatCard(
                        title: "Total Revenue",
                        value: "CHF ${totalRevenue.toStringAsFixed(2)}",
                        trend: "Total Earnings",
                        icon: Icons.account_balance_wallet_rounded,
                        iconColor: kPrimary,
                        isPositive: true,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Charts Section (Mock UI) ──
              LayoutBuilder(
                builder: (context, constraints) {
                  bool isMobile = constraints.maxWidth < 800;
                  return Flex(
                    direction: isMobile ? Axis.vertical : Axis.horizontal,
                    children: [
                      Expanded(
                        flex: isMobile ? 0 : 2,
                        child: _buildChartPlaceholder(
                          "Daily Revenue",
                          "CHF ${totalRevenue.toStringAsFixed(2)}",
                          "Updated Live",
                        ),
                      ),
                      if (!isMobile) const SizedBox(width: 16),
                      if (isMobile) const SizedBox(height: 16),
                      Expanded(
                        flex: isMobile ? 0 : 1,
                        child: _buildChartPlaceholder(
                          "Total Database Orders",
                          "$totalOrdersCount",
                          "In System",
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // ── Recent Activity (Live from Firestore) ──
              const Text(
                "Recent Activity",
                style: TextStyle(
                  color: kWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildActivityList(docs),
            ],
          ),
        );
      },
    );
  }

  // ── Stat Card UI ──
  Widget _buildStatCard({
    required String title,
    required String value,
    required String trend,
    required IconData icon,
    required Color iconColor,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              Icon(Icons.more_vert, color: kMuted.withOpacity(0.5)),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: kWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: kMuted, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                color: isPositive ? kGreen : kRed,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                trend,
                style: TextStyle(
                  color: isPositive ? kGreen : kRed,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chart Placeholder UI ──
  Widget _buildChartPlaceholder(
    String title,
    String mainValue,
    String subTitle,
  ) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.menu, color: kMuted, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                mainValue,
                style: const TextStyle(
                  color: kWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                subTitle,
                style: const TextStyle(
                  color: kGreen,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          Center(
            child: Icon(
              Icons.bar_chart_rounded,
              color: kPrimary.withOpacity(0.2),
              size: 100,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  // ── Recent Activity List (Dynamic from DB) ──
  Widget _buildActivityList(List<QueryDocumentSnapshot> docs) {
    if (docs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            "No recent activity found.",
            style: TextStyle(color: kMuted),
          ),
        ),
      );
    }

    // Recent 5 orders காட்டுவதற்கு
    final recentDocs = docs.take(5).toList();

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kWhite.withOpacity(0.05)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: recentDocs.length,
        separatorBuilder: (context, index) =>
            Divider(color: kWhite.withOpacity(0.05), height: 1),
        itemBuilder: (context, index) {
          final data = recentDocs[index].data() as Map<String, dynamic>;
          final orderId = data['order_id'] ?? recentDocs[index].id;
          final status = data['status'] ?? 'Unknown';
          final Timestamp? timestamp = data['timestamp'] as Timestamp?;

          String timeStr = "Recent";
          if (timestamp != null) {
            final dt = timestamp.toDate();
            timeStr =
                "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
          }

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: kWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            title: Text(
              "Order #$orderId - Status: $status",
              style: const TextStyle(color: kWhite, fontSize: 14),
            ),
            subtitle: Text(
              "Delivery Type: ${data['delivery_method'] ?? 'N/A'}",
              style: const TextStyle(color: kMuted, fontSize: 12),
            ),
            trailing: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: kPrimary,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }
}
