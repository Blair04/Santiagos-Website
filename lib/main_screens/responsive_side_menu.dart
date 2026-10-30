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
  bool _isDrawerOpen = false;
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

  Future<void> _handleLogout({bool wasTimeout = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isAdminLoggedIn', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );

    if (wasTimeout) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged out due to 30 minutes of inactivity.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

// Logout confirmation dialog

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFFFFF1EC),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Color(0xFFFF8383)),
              SizedBox(width: 10),
              Expanded(child: Text('Confirm Logout')),
            ],
          ),

          content: const Text(
            'Are you sure you want to log out?',
            style: TextStyle(
              color: Color.fromARGB(255, 92, 71, 69), height: 1.5,
            ),
          ),

          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF805445)),
              ),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 255, 69, 69),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Yes, Logout'),
            ),
          ],
        );
      },
    );



    if (shouldLogout == true && mounted) {
      await _handleLogout();
    }
  }



  String _getTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Dashboard';
      case 1:
        return 'Manage Receipts';
      case 2:
        return 'Manage Products';
      case 3:
        return 'Manage Categories';
      case 4:
        return 'Product Sales';
      case 5:
        return 'Manage Profile';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isHugeScreen = constraints.maxWidth >= 1200;

        return SessionListener(
          duration: const Duration(minutes: 30),
          onTimeout: () => _handleLogout(wasTimeout: true),
          child: Scaffold(
            backgroundColor: const Color(0xFFFAF6F2),
            onDrawerChanged: (isOpen) {
              if (mounted) setState(() => _isDrawerOpen = isOpen);
            },
            appBar: isHugeScreen
                ? null
                : AppBar(
                    backgroundColor: const Color(0xFFFAF6F2),
                    title: Text(_getTitle()),
                    leading: Builder(
                      builder: (leadingContext) => IconButton(
                        tooltip: _isDrawerOpen ? 'Close menu' : 'Open menu',
                        onPressed: () {
                          if (_isDrawerOpen) {
                            Navigator.of(leadingContext).pop();
                          } else {
                            Scaffold.of(leadingContext).openDrawer();
                          }
                        },
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) => RotationTransition(
                            turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                            child: FadeTransition(opacity: animation, child: child),
                          ),
                          child: Icon(
                            _isDrawerOpen ? Icons.close_rounded : Icons.menu_rounded,
                            key: ValueKey<bool>(_isDrawerOpen),
                          ),
                        ),
                      ),
                    ),
                  ),

            drawer: isHugeScreen
                ? null
                : Drawer(
                    backgroundColor: NavigationContent.sidebarColor,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    child: NavigationContent(
                      selectedIndex: _selectedIndex,
                      onItemSelected: (index) {
                        setState(() => _selectedIndex = index);
                        Navigator.pop(context);
                      },

                      onLogout: _confirmLogout,
                      profileAvatarBytes: _profileAvatarBytes,
                      showCloseButton: _isDrawerOpen,
                      onClose: () => Navigator.of(context).pop(),
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

                    child: SizedBox(
                      width: 250,
                      child: NavigationContent(
                        selectedIndex: _selectedIndex,
                        onItemSelected: (index) {
                          setState(() => _selectedIndex = index);
                        },

                        onLogout: _confirmLogout,
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
}


class NavigationContent extends StatelessWidget {
  final Function(int) onItemSelected;
  final VoidCallback onLogout;
  final int selectedIndex;
  final Uint8List? profileAvatarBytes;
  final bool showCloseButton;
  final VoidCallback? onClose;


  const NavigationContent({
    super.key,
    required this.onItemSelected,
    required this.selectedIndex,
    required this.onLogout,
    required this.profileAvatarBytes,
    this.showCloseButton = false,
    this.onClose,
  });

  static const Color sidebarColor = Color(0xFFD9C3B3);
  static const Color selectedColor = Color(0xFF805445);
  static const Color textColor = Color(0xFF786E69);
  static const Color textDark = Color(0xFF2C2221);


  Widget buildNavItem({
    required String title,
    required IconData icon,
    required int index,
  }) {
    return _HoverableNavItem(
      title: title,
      icon: icon,
      isSelected: selectedIndex == index,
      onTap: () => onItemSelected(index),
      selectedColor: selectedColor,
      textColor: textColor,
    );
  }

  Widget buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onLogout,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 28,
                  color: Colors.redAccent,
                ),

                SizedBox(width: 16),
                Text(
                  'Logout',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w500,
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
  @override
  Widget build(BuildContext context) {
    return Container(
      color: sidebarColor,
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    children: [
                      Container(
                        width: 130,
                        height: 130,
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
                              ? Image.asset('assets/images/santiago_logo.jpg', fit: BoxFit.cover)
                              : Image.memory(profileAvatarBytes!, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Manager',
                        style: TextStyle(
                          color: textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            buildNavItem(title: 'Overview', icon: Icons.dashboard_rounded, index: 0),
                            buildNavItem(title: 'Order Slips', icon: Icons.receipt_long_rounded, index: 1),
                            buildNavItem(title: 'Products', icon: Icons.chair_rounded, index: 2),
                            buildNavItem(title: 'Categories', icon: Icons.category_rounded, index: 3),
                            buildNavItem(title: 'Sales', icon: Icons.point_of_sale_rounded, index: 4),
                            buildNavItem(title: 'Account', icon: Icons.manage_accounts_rounded, index: 5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                buildLogoutButton(),
              ],
            ),
          ),
          if (onClose != null)
            Positioned(
              top: 4,
              left: 8,
              child: IgnorePointer(
                ignoring: !showCloseButton,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutBack,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) => RotationTransition(
                    turns: Tween<double>(begin: 0.75, end: 1).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  ),
                  child: showCloseButton
                      ? Material(
                          key: const ValueKey('drawer-close'),
                          color: sidebarColor,
                          shape: const CircleBorder(),
                          child: IconButton(
                            tooltip: 'Close menu',
                            onPressed: onClose,
                            icon: const Icon(Icons.close_rounded),
                            color: textDark,
                          ),
                        )
                      : const SizedBox(
                          key: ValueKey('drawer-empty'),
                          width: 48,
                          height: 48,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

}


class _HoverableNavItem extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color textColor;

  const _HoverableNavItem({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.selectedColor,
    required this.textColor,
  });

  @override
  State<_HoverableNavItem> createState() => _HoverableNavItemState();
}

class _HoverableNavItemState extends State<_HoverableNavItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.isSelected;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(
                color: selected
                    ? widget.selectedColor
                    : _isHovered
                        ? widget.selectedColor.withValues(alpha: 0.14)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  AnimatedScale(
                    scale: _isHovered && !selected ? 1.06 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      widget.icon,
                      size: 28,
                      color: selected ? Colors.white : widget.textColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontSize: 16,
                        color: selected ? Colors.white : widget.textColor,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  AnimatedOpacity(
                    opacity: _isHovered && !selected ? 1 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: widget.textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
