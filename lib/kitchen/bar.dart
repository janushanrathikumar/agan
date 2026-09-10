// lib/kitchen/bar.dart
import 'package:flutter/material.dart';

import 'station_login.dart';
import 'station_orders.dart';

/// Bar screen: behind a staff login, shows only the drink lines of every live
/// order and prints them as bar tickets.
class BarPage extends StatelessWidget {
  const BarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StationGate(station: OrderStation.bar);
  }
}
