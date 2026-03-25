import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/manage_receipt_screen.dart';
import 'package:flutter_application_1/main_screens/preorder_screen.dart';
import 'package:flutter_application_1/main_screens/manage_furniture.dart';

class MainResponsivePage extends StatefulWidget {
  const MainResponsivePage({Key? key}) : super(key: key);

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
          appBar: isHugeScreen ? null : AppBar(
            backgroundColor: const Color.fromRGBO(215, 199, 187, 1.0),
            title: _screens[_selectedIndex] is ManageReceipt
                ? const Text('Manage Receipts')
                : _screens[_selectedIndex] is Preorder
                    ? const Text('Pre Order Detail')
                    : const Text('Manage Furniture'),
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
                  decoration: BoxDecoration(
                    border: Border(right: BorderSide(color: Colors.grey.shade300)),
                  ),
                  child: NavigationContent(
                    selectedIndex: _selectedIndex,
                    onItemSelected: (index) {
                      setState(() => _selectedIndex = index);
                    },
                  ),
                ),
                
              Expanded(
                child: SelectionArea(
                  child: _screens[_selectedIndex],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class NavigationContent extends StatelessWidget {
  final Function(int) onItemSelected;
  final int selectedIndex;

  const NavigationContent({
    Key? key, 
    required this.onItemSelected, 
    required this.selectedIndex
  }) : super(key: key);

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
                    image: NetworkImage('https://scontent.fmnl17-2.fna.fbcdn.net/v/t39.30808-6/565319095_1128726149395643_8094975518170593394_n.jpg?_nc_cat=107&ccb=1-7&_nc_sid=1d70fc&_nc_eui2=AeGz9tN_4QcssA9gLdQBlksJYjb1YxdZG-tiNvVjF1kb6yiQ6KbwAJHEAet14aFFr74ooX1wDQJD7eSmbPiCxfny&_nc_ohc=jQMUXikHHUQQ7kNvwH2I4w4&_nc_oc=Adona025_4vRnBtQbeyfW4bOrMiYs0vqGfuQfiFBzSiw9p0mTuIYYB0LHzrmCpT-At4&_nc_zt=23&_nc_ht=scontent.fmnl17-2.fna&_nc_gid=j7H6Hiv0v7mFDXh9AOAynw&_nc_ss=7a32e&oh=00_AfxYRjLcagNaBR_giPvPFAB2zdBzVfPaX0VdanNevYRrZw&oe=69C5BCF2'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
        
        // navigation items
        ListTile(
          selected: selectedIndex == 0,
          selectedTileColor: Colors.brown.withOpacity(0.1),
          leading: const Icon(Icons.receipt),
          title: const Text('Manage Receipts'),
          onTap: () => onItemSelected(0),
        ),
        ListTile(
          selected: selectedIndex == 1,
          selectedTileColor: Colors.brown.withOpacity(0.1),
          leading: const Icon(Icons.receipt_long),
          title: const Text('Pre Order Detail'),
          onTap: () => onItemSelected(1),
        ),
        ListTile(
          selected: selectedIndex == 2,
          selectedTileColor: Colors.brown.withOpacity(0.1),
          leading: const Icon(Icons.local_shipping),
          title: const Text('Manage Products'),
          onTap: () => onItemSelected(2),
        ),
        
        const Spacer(),
        const Divider(),
        
        ListTile(
          leading: const Icon(Icons.person, color: Colors.redAccent),
          title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          onTap: () {
            // log out logic here
          },
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}