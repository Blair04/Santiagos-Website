import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/manage_receipt_screen.dart';
import 'package:flutter_application_1/main_screens/preorder_screen.dart';
import 'package:flutter_application_1/main_screens/manage_furniture.dart';

class MainResponsivePage extends StatefulWidget {
  const MainResponsivePage({super.key});

  @override
  State<MainResponsivePage> createState() => _MainResponsivePageState();
}

class _MainResponsivePageState extends State<MainResponsivePage> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const ManageReceipt(),   
    const Preorder(),        
    const ManageFurniture(), 
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isHugeScreen = constraints.maxWidth > 900;

        return Scaffold(
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
                  ),
                ),
                
          body: Row(
            children: [
              if (isHugeScreen)
                Container(
                  width: 300,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD8C8BC),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: NavigationContent(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
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
    if (_selectedIndex == 1) return const Text('Pre Order Detail');
    return const Text('Manage Furniture');
  }
}

class NavigationContent extends StatelessWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;

  const NavigationContent({
    super.key, 
    required this.onItemSelected, 
    required this.selectedIndex
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
        //for logo
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
        
        // navigations
        buildNavItem(
          title: 'Manage Receipts',
          icon: Icons.receipt,
          index: 0,
        ),
        buildNavItem(
          title: 'Pre Order Detail',
          icon: Icons.receipt_long,
          index: 1,
        ),
        buildNavItem(
          title: 'Manage Products',
          icon: Icons.local_shipping,
          index: 2,
        ),

        const Spacer(),
        const Divider(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Row(
                children: [
                  Icon(Icons.person, color: Colors.redAccent),
                  SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),
      ],
    );
  }
}