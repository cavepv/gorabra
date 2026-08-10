import 'package:flutter/material.dart';

import 'screens/planner_screen.dart';
import 'services/location_lookup.dart';

void main() {
  runApp(const GorabraApp());
}

class GorabraApp extends StatelessWidget {
  final Future<UserPosition?> Function()? positionFetcher;

  const GorabraApp({super.key, this.positionFetcher});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hittepå',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: PlannerScreen(positionFetcher: positionFetcher),
    );
  }
}
