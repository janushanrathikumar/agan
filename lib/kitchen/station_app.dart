// lib/kitchen/station_app.dart
//
// The app shell for the standalone station builds (Kleefeld Kitchen and
// Kleefeld Bar). One implementation, parameterised by [OrderStation] — the
// same way the boards themselves are.
//
// Unlike lib/main.dart this has no route table and no AuthGate: a station
// tablet only ever needs its own board, so the app opens straight onto
// StationGate and there is nowhere else to navigate to.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'package:restorant/firebase_options.dart';
import 'package:restorant/shared/startup_views.dart';

import 'station_login.dart';
import 'station_orders.dart';

/// Brings up the primary Firebase project, which holds the `orders` collection
/// the boards stream from.
///
/// The `SecondaryDb` project that lib/main.dart also initialises is skipped on
/// purpose: only checkout/payment writes there, the boards never read it, and
/// on Android it points at an unrelated project.
Future<void> initializeStationFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (error, stackTrace) {
    debugPrint('Station Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    rethrow;
  }
}

class StationApp extends StatelessWidget {
  const StationApp({
    required this.station,
    required this.initialization,
    super.key,
  });

  final OrderStation station;
  final Future<void> initialization;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kleefeld ${station.title}',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: station.accent,
        scaffoldBackgroundColor: kStBg,
      ),
      home: StationGate(station: station),
      // Firebase must be ready before StationGate opens its Firestore stream.
      builder: (context, child) {
        return FutureBuilder<void>(
          future: initialization,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return StartupErrorView(error: snapshot.error!);
            }
            if (snapshot.connectionState != ConnectionState.done) {
              return const SplashView();
            }
            return child ?? const SplashView();
          },
        );
      },
    );
  }
}
