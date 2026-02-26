import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter_application_1/main_screens/manage_furniture.dart';
import 'package:flutter_application_1/main_screens/manage_receipt_screen.dart';
import 'package:flutter_application_1/main_screens/preorder_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Santiago\'s Furniture',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ManageReceipt(),
      routes: {
        ManageReceipt.routeName: (ctx) => ManageReceipt(),
        Preorder.routeName: (ctx) => Preorder(),
        ManageFurniture.routeName: (ctx) => ManageFurniture(),
      }  
    );
  }
}

