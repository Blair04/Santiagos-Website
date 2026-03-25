import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aanbuqmorbhnepluuxjt.supabase.co', // Replace with your Supabase URL
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhbmJ1cW1vcmJobmVwbHV1eGp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MzExMjEsImV4cCI6MjA5MDAwNzEyMX0.p6jzD6C_3EWrW6mzVeyw215GsoNjtBfoZeak8g5qa2I', //
  );
  runApp(const MyApp());
}
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Santiago\'s Furniture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true
      ),
      home: const MainResponsivePage(),
    );
  }
}

