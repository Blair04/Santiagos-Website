import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main_screens/responsive_side_menu.dart';
import 'package:flutter_application_1/main_screens/login_screen.dart';
import 'package:flutter_application_1/main_screens/forgot_password_screen.dart';

late final SharedPreferences prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://aanbuqmorbhnepluuxjt.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhbmJ1cW1vcmJobmVwbHV1eGp0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ0MzExMjEsImV4cCI6MjA5MDAwNzEyMX0.p6jzD6C_3EWrW6mzVeyw215GsoNjtBfoZeak8g5qa2I',
  );

  prefs = await SharedPreferences.getInstance();

  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/home/dashboard',

  // Runs on every navigation, so it always reads the latest login state
  redirect: (context, state) {
    final bool loggedIn = prefs.getBool('isAdminLoggedIn') ?? false;
    final String path = state.matchedLocation;

    // pages anyone can open without logging in
    const publicPages = ['/login', '/forgot-password'];
    final bool isPublic = publicPages.contains(path);

    if (!loggedIn && !isPublic) return '/login';
    if (loggedIn && path == '/login') return '/home/dashboard';
    if (path == '/home') return '/home/dashboard';
    return null;
  },

  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/home/:tab',
      // Fixed key: the page keeps its state when only the tab changes
      pageBuilder: (context, state) => NoTransitionPage(
        key: const ValueKey('home'),
        child: MainResponsivePage(
          tab: state.pathParameters['tab'] ?? 'dashboard',
        ),
      ),
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: "Santiago's Furniture",
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}