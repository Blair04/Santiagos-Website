import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';
import 'package:flutter_application_1/main_screens/login_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aanbuqmorbhnepluuxjt.supabase.co', 
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhbmJ1cW1vcmJobmVwbHV1eGp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MzExMjEsImV4cCI6MjA5MDAwNzEyMX0.p6jzD6C_3EWrW6mzVeyw215GsoNjtBfoZeak8g5qa2I', 
  );

  final prefs = await SharedPreferences.getInstance();
  final bool isAdminLoggedIn = prefs.getBool('isAdminLoggedIn') ?? false;

  runApp(MyApp(isAdminLoggedIn: isAdminLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isAdminLoggedIn;
  const MyApp({super.key, required this.isAdminLoggedIn});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Santiago's Furniture",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: isAdminLoggedIn ? const MainResponsivePage() : const LoginScreen(), 
    );
  }
}