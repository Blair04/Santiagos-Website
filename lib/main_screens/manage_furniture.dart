import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/add_furniture.dart' hide showModalBottomSheet;
class ManageFurniture extends StatefulWidget {
  const ManageFurniture({super.key});

  static String get routeName => '/manage-furniture';

  @override
  State<ManageFurniture> createState() => _ManageFurnitureState();
}

class _ManageFurnitureState extends State<ManageFurniture> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromRGBO(249, 246, 241, 1.0), 
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
            Text('My Products', style: TextStyle(color:Colors.brown, fontSize: 20, fontWeight: FontWeight.bold)),
            OutlinedButton(
              onPressed: () => _openAddProductSheet(context),
              child: Text('+ Add New Product', style: TextStyle(color: Colors.brown, fontSize: 16)),
            )
            ]
            )
          ],
        )
      ),
    );
  }
}

void _openAddProductSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => AddFurniture(),
  );
}

