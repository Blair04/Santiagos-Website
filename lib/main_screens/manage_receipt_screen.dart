import 'package:flutter/material.dart';

class ManageReceipt extends StatefulWidget {
  const ManageReceipt({super.key});

  @override
  State<ManageReceipt> createState() => _ManageReceiptState();
}

class _ManageReceiptState extends State<ManageReceipt> {
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
    );
  }
}