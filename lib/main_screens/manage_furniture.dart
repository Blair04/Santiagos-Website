import 'package:flutter/material.dart';
class ManageFurniture extends StatefulWidget {
  const ManageFurniture({super.key});

  static String get routeName => '/manage-furniture';

  @override
  State<ManageFurniture> createState() => _ManageFurnitureState();
}

class _ManageFurnitureState extends State<ManageFurniture> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(249, 246, 241, 1.0),
    );
  }
}