// lib/main_kitchen.dart
//
// Entrypoint for the standalone Kleefeld Kitchen app:
//   flutter build apk --debug --flavor kitchen -t lib/main_kitchen.dart
import 'package:flutter/material.dart';

import 'package:restorant/kitchen/station_app.dart';
import 'package:restorant/kitchen/station_orders.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    StationApp(
      station: OrderStation.kitchen,
      initialization: initializeStationFirebase(),
    ),
  );
}
