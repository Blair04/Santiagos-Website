import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_1/main_screens/dashboard_screen.dart';
import 'package:flutter_application_1/main_screens/manage_receipt_screen.dart';
import 'package:flutter_application_1/main_screens/products_sales_screen.dart';
import 'package:flutter_application_1/main_screens/manage_furniture.dart';
import 'package:flutter_application_1/main_screens/login_screen.dart';
import 'package:flutter_application_1/main_screens/manage_category_screen.dart';
import 'package:flutter_application_1/main_screens/manage_profile_screen.dart';
import 'package:flutter_application_1/main_screens/session_listener.dart';

class MainResponsivePage extends StatefulWidget {
  const MainResponsivePage({super.key});

  @override
  State<MainResponsivePage> createState() => _MainResponsivePageState();
}

class _MainResponsivePageState extends State<MainResponsivePage> {
  static const String _localAvatarKey = 'adminProfileAvatarBase64';

  int _selectedIndex = 0;
  Uint8List? _profileAvatarBytes;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(
        onViewProducts: () {
          if (mounted) setState(() => _selectedIndex = 2);
        },
      ),
      ManageReceipt(),
      ManageFurniture(),
      ManageCategoryScreen(),
      ProductsSalesScreen(),
      ManageProfileScreen(onProfileUpdated: _loadProfileAvatar),
    ];
    _loadProfileAvatar();
  }

  Future<void> _loadProfileAvatar() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_localAvatarKey);
    Uint8List? bytes;
    if (encoded != null && encoded.isNotEmpty) {
      try {
        bytes = base64Decode(encoded);
      } catch (_) {
        await preferences.remove(_localAvatarKey);
      }
    }
    if (mounted) setState(() => _profileAvatarBytes = bytes);
  }

  void _handleLogout({bool wasTimeout = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAdminLoggedIn', false);

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      if (wasTimeout) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out due to 20 minutes of inactivity.'),
            backgroundColor: Colors.orangeAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The permanent 300 px menu is reserved for wide desktops. Tablets and
        // smaller windows keep the dashboard content wide by using a drawer.
        final bool isHugeScreen = constraints.maxWidth >= 1200;

        return SessionListener(
          duration: const Duration(
            minutes: 30,
          ), // Log out after 30 inactive minutes.
          onTimeout: () => _handleLogout(wasTimeout: true),
          child: Scaffold(
            backgroundColor: const Color(0xFFFAF6F2),
            appBar: isHugeScreen
                ? null
                : AppBar(
                    backgroundColor: const Color(0xFFFAF6F2),
                    title: _getTitle(),
                  ),

            drawer: isHugeScreen
                ? null
                : Drawer(
                    child: NavigationContent(
                      selectedIndex: _selectedIndex,
                      onItemSelected: (index) {
                        setState(() => _selectedIndex = index);
                        Navigator.pop(context);
                      },
                      onLogout: () => _handleLogout(wasTimeout: false),
                      profileAvatarBytes: _profileAvatarBytes,
                    ),
                  ),

            body: Row(
              children: [
                if (isHugeScreen)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    child: Container(
                      width: 300,
                      color: const Color(0xFFD8C8BC),
                      child: NavigationContent(
                        selectedIndex: _selectedIndex,
                        onItemSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },
                        onLogout: () => _handleLogout(wasTimeout: false),
                        profileAvatarBytes: _profileAvatarBytes,
                      ),
                    ),
                  ),

                Expanded(child: _screens[_selectedIndex]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _getTitle() {
    if (_selectedIndex == 0) return const Text('Dashboard');
    if (_selectedIndex == 1) return const Text('Manage Receipts');
    if (_selectedIndex == 2) return const Text('Manage Products');
    if (_selectedIndex == 3) return const Text('Manage Categories');
    if (_selectedIndex == 4) return const Text('Product Sales');
    return const Text('Manage Profile');
  }
}

class NavigationContent extends StatelessWidget {
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final int selectedIndex;
  final Uint8List? profileAvatarBytes;

  const NavigationContent({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
    required this.onLogout,
    required this.profileAvatarBytes,
  });

  Widget buildNavItem({
    required String title,
    required IconData icon,
    required int index,
  }) {
    bool isSelected = selectedIndex == index;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => onItemSelected(index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(icon, color: isSelected ? Colors.black : Colors.black54),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.black54,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          color: const Color.fromRGBO(215, 199, 187, 1.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFC68B59).withValues(alpha: 0.35),
                  ),
                ),
                child: ClipOval(
                  child: profileAvatarBytes == null
                      ? Image.asset(
                          'assets/images/santiago_logo.jpg',
                          fit: BoxFit.cover,
                        )
                      : Image.memory(profileAvatarBytes!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Administrator',
                style: TextStyle(
                  color: Color(0xFF2C2221),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),

        buildNavItem(title: 'Dashboard', icon: Icons.dashboard, index: 0),
        buildNavItem(title: 'Manage Receipts', icon: Icons.receipt, index: 1),
        buildNavItem(title: 'Manage Products', icon: Icons.chair, index: 2),
        buildNavItem(
          title: 'Manage Categories',
          icon: Icons.category,
          index: 3,
        ),
        buildNavItem(
          title: 'Product Sales',
          icon: Icons.receipt_long,
          index: 4,
        ),
        buildNavItem(
          title: 'Manage Profile',
          icon: Icons.manage_accounts_outlined,
          index: 5,
        ),

        const Spacer(),
        const Divider(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent),
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}
