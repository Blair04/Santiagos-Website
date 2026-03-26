import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/add_furniture.dart' hide showModalBottomSheet;
import 'package:supabase_flutter/supabase_flutter.dart';
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
            ),
            //for adding bellow
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(color: Colors.brown.withOpacity(0.05),borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  _headerItem('Image', flex:1),
                  _headerItem('Product Name', flex: 2),
                  _headerItem('Price', flex: 1),
                  _headerItem('Category', flex: 2),
                  _headerItem('Color', flex: 2),
                  _headerItem('Description', flex: 3),
                  _headerItem('Edit', flex: 1),
                  _headerItem('Archive', flex: 1),
                ],
              )
            ),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: Supabase.instance.client.from('FURNITURE').stream(primaryKey: ['id']), 
                builder: (context, snapshot) {
                  if (!snapshot.hasData){
                    return const Center(child: CircularProgressIndicator(color: Colors.brown));
                  }
                  final products = snapshot.data!;

                  return ListView.builder(
                    itemCount: products.length,
                    itemBuilder: (context, index){
                      final item = products[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.brown.withOpacity(0.1)))
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: item['image_url'] != null 
                                ? Image.network(item['image_url'], height: 40, fit: BoxFit.cover)
                                : Icon(Icons.chair, color: Colors.brown[200]),
                              )
                            ),
                            _dataItem(item['furniture_name'] ?? 'No Name', flex: 2),
                            _dataItem('₱ ${item['price']?.toStringAsFixed(2) ?? '0.00'}', flex: 1),
                            _dataItem(item['category'] ?? 'N/A', flex: 2),
                            _dataItem(item['color'] ?? 'N/A', flex: 2),
                            _dataItem(item['description'] ?? 'No Description', flex: 3),

                            Expanded(
                              flex: 1,
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(Icons.edit_note, color: Colors.brown),
                                  onPressed: () => print("Edit ${item['id']}"), 
                                ),
                              )
                            ),
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: IconButton(
                                  icon: const Icon(Icons.archive, color: Colors.brown),
                                  onPressed: () => print("Archive ${item['id']}"), 
                                )
                              )
                            )
                          ]
                        ),
                      );
                    }
                  );
                },
              ),
            )
          ]
        )
      ),
    );
  }
}

Widget _headerItem(String title, { int flex = 1}) {
  return Expanded(
    flex: flex,
    child: Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 14),
    maxLines: 1, overflow: TextOverflow.ellipsis),
  );
}

Widget _dataItem(String text, { int flex = 1}) {
  return Expanded(
    flex: flex,
    child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.black87, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
  );
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
