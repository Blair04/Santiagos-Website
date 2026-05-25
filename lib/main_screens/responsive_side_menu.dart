import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/manage_receipt_screen.dart';
import 'package:flutter_application_1/main_screens/preorder_screen.dart';
import 'package:flutter_application_1/main_screens/manage_furniture.dart';
// Import your login screen file here
import 'package:flutter_application_1/main_screens/login_screen.dart'; 

class MainResponsivePage extends StatefulWidget {
  const MainResponsivePage({super.key});

  @override
  State<MainResponsivePage> createState() => _MainResponsivePageState();
}

class _MainResponsivePageState extends State<MainResponsivePage> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const ManageReceipt(),         
    const ManageFurniture(), 
    const Preorder(),  
  ];

  // Root level logout function
  void _handleLogout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false, // This clears the entire route stack so they can't hit back to return
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isHugeScreen = constraints.maxWidth > 900;

        return Scaffold(
          backgroundColor: const Color(0xFFFAF6F2), 
          appBar: isHugeScreen ? null 
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
                    onLogout: _handleLogout, // Pass down to drawer view
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
                      onLogout: _handleLogout, // Pass down to sidebar view
                    ),
                  ),
                ),
                
              Expanded(child: _screens[_selectedIndex]),
            ],
          ),
        );
      },
    );
  }

  Widget _getTitle() {
    if (_selectedIndex == 0) return const Text('Manage Receipts');
    if (_selectedIndex == 1) return const Text('Manage Products');
    return const Text('Top Products');
  }
}

class NavigationContent extends StatelessWidget {
  final Function(int) onItemSelected;
  final VoidCallback onLogout; // Explicit parameter added here
  final int selectedIndex;

  const NavigationContent({
    super.key, 
    required this.onItemSelected, 
    required this.selectedIndex,
    required this.onLogout, // Required setup parameter
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
                Icon(
                  icon,
                  color: isSelected ? Colors.black : Colors.black54,
                ),
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage('assets/images/santiago_logo.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        
        buildNavItem(
          title: 'Manage Receipts',
          icon: Icons.receipt,
          index: 0,
        ),
        buildNavItem(
          title: 'Manage Products',
          icon: Icons.local_shipping,
          index: 1,
        ),
        buildNavItem(
          title: 'Top Products',
          icon: Icons.receipt_long,
          index: 2,
        ),
        
        const Spacer(),
        const Divider(),

        // Log out gesture zone updated
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onLogout, // Executes root function to exit and clear backstack
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.logout, color: Colors.redAccent), // Swapped out person icon for logout icon
                    SizedBox(width: 12),
                    Text(
                      'Logout',
                      style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
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