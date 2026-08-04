import 'package:flutter/material.dart';

import 'screens/planner_screen.dart';

void main() {
  runApp(const GorabraApp());
}

class GorabraApp extends StatelessWidget {
  const GorabraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Görabra',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const PlannerScreen(),
    );
  }
}
