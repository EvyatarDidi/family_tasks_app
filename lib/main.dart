import 'package:flutter/material.dart';

void main() {
  runApp(const FamilyTaskManager());
}

class FamilyTaskManager extends StatelessWidget {
  const FamilyTaskManager({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Tasks',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('משימות משפחת הדי'),
        centerTitle: true,
      ),
      body: const Center(
        child: Text(
          'כאן יופיעו המשימות של צופיה, אביתר והילדים',
          style: TextStyle(fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}