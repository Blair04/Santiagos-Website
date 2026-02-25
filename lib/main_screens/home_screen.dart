import 'package:flutter/material.dart';
import './navigation.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(249, 246, 241, 1.0),

      appBar: AppBar(
        backgroundColor: Color.fromRGBO(215, 199, 187, 1.0),
        title: const Text(
          "Santiago's furniture"
        )
      ),

      drawer: Navigation(),
    );
  }
}