// lib/main_bar.dart
//
// Entrypoint for the standalone Kleefeld Bar app:
//   flutter build apk --debug --flavor bar     -t lib/main_bar.dart
import 'package:flutter/material.dart';

import 'package:restorant/kitchen/station_app.dart';
import 'package:restorant/kitchen/station_orders.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    StationApp(
      station: OrderStation.bar,
      initialization: initializeStationFirebase(),
    ),
  );
}
