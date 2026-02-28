import 'package:flutter/material.dart';

class Preorder extends StatefulWidget {
  const Preorder({super.key});

  static String get routeName => '/preorder';

  @override
  State<Preorder> createState() => _PreorderState();
}

class _PreorderState extends State<Preorder> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(249, 246, 241, 1.0),
    );
  }
}