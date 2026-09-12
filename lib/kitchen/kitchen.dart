// lib/kitchen/kitchen.dart
import 'package:flutter/material.dart';

import 'station_login.dart';
import 'station_orders.dart';

/// Kitchen screen: behind a staff login, shows only the food (and combo) lines
/// of every live order and prints them as kitchen tickets.
class KitchenPage extends StatelessWidget {
  const KitchenPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const StationGate(station: OrderStation.kitchen);
  }
}
