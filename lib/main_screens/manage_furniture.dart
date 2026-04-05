import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/add_furniture.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class ManageFurniture extends StatefulWidget {
  const ManageFurniture({super.key});

  static String get routeName => '/manage-furniture';

  @override
  State<ManageFurniture> createState() => _ManageFurnitureState();
}

class _ManageFurnitureState extends State<ManageFurniture> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _supabase
          .from('FURNITURE')
          .select('''
            furniture_id,
            furniture_name,
            description,
            price,
            created_at,
            CATEGORY (
              category_name
            ),
            VARIANT (
              color,
              image_url,
              ar_model_url
            )
          ''')
          .order('created_at', ascending: false);

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // safely parse price regardless of type coming from Supabase
  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    if (price is double) return price.toStringAsFixed(2);
    if (price is int) return price.toDouble().toStringAsFixed(2);
    if (price is String) {
      final parsed = double.tryParse(price);
      return parsed != null ? parsed.toStringAsFixed(2) : '0.00';
    }
    return '0.00';
  }

  void _openAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddFurniture(),
    ).then((_) => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(249, 246, 241, 1.0),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Products',
                  style: TextStyle(
                    color: Colors.brown,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _openAddProductSheet(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.brown),
                  ),
                  child: const Text(
                    '+ Add New Product',
                    style: TextStyle(color: Colors.brown, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // table header
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.brown.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  _headerItem('Image', flex: 1),
                  _headerItem('Product Name', flex: 2),
                  _headerItem('Price', flex: 1),
                  _headerItem('Category', flex: 2),
                  _headerItem('Color', flex: 1),
                  _headerItem('Description', flex: 3),
                  _headerItem('Edit', flex: 1),
                  _headerItem('Archive', flex: 1),
                ],
              ),
            ),

            // table body
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Colors.brown),
                    )
                  : _products.isEmpty
                      ? const Center(
                          child: Text(
                            'No products yet. Tap + Add New Product.',
                            style: TextStyle(color: Colors.brown),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            final item = _products[index];

                            // safely get category
                            final category =
                                item['CATEGORY'] as Map<String, dynamic>?;
                            final categoryName =
                                category?['category_name'] ?? 'N/A';

                            // safely get first variant
                            final variantRaw = item['VARIANT'];
                            Map<String, dynamic>? firstVariant;
                            if (variantRaw is List &&
                                variantRaw.isNotEmpty) {
                              firstVariant = Map<String, dynamic>.from(
                                  variantRaw.first);
                            }

                            final color =
                                firstVariant?['color']?.toString() ?? 'N/A';
                            final imageUrl =
                                firstVariant?['image_url']?.toString();

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.brown.withOpacity(0.1),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // image
                                  Expanded(
                                    flex: 1,
                                    child: Center(
                                      child: imageUrl != null &&
                                              imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (_, __, ___) => Icon(
                                                Icons.chair,
                                                color: Colors.brown[200],
                                              ),
                                            )
                                          : Icon(Icons.chair,
                                              color: Colors.brown[200]),
                                    ),
                                  ),

                                  _dataItem(
                                    item['furniture_name']?.toString() ??
                                        'No Name',
                                    flex: 2,
                                  ),

                                  // fixed price formatting
                                  _dataItem(
                                    '₱ ${_formatPrice(item['price'])}',
                                    flex: 1,
                                  ),

                                  _dataItem(categoryName, flex: 2),
                                  _dataItem(color, flex: 1),
                                  _dataItem(
                                    item['description']?.toString() ??
                                        'No Description',
                                    flex: 3,
                                  ),

                                  // edit button
                                  Expanded(
                                    flex: 1,
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.edit_note,
                                            color: Colors.brown),
                                        onPressed: () {
                                          // edit logic here
                                        },
                                      ),
                                    ),
                                  ),

                                  // archive button
                                  Expanded(
                                    flex: 1,
                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(Icons.archive,
                                            color: Colors.brown),
                                        onPressed: () {
                                          // archive logic here
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _headerItem(String title, {int flex = 1}) {
  return Expanded(
    flex: flex,
    child: Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.brown,
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _dataItem(String text, {int flex = 1}) {
  return Expanded(
    flex: flex,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.black87, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}