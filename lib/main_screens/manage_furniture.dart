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

  // ✅ SEARCH
  final TextEditingController _searchController =
      TextEditingController();

  List<String> searchHistory = [];
  String query = "";

  // Track selected colors
  final Map<int, String> _selectedColors = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ✅ SEARCH HISTORY
  void addToHistory(String value) {
    if (value.isNotEmpty && !searchHistory.contains(value)) {
      setState(() {
        searchHistory.insert(0, value);
      });
    }
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
            category_id,
            CATEGORY (
              category_name
            ),
            VARIANT (
              variant_id,
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
            content:
                Text('Error loading products: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';

    final parsed =
        double.tryParse(price.toString()) ?? 0.0;

    return parsed.toStringAsFixed(2);
  }

  void _openAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const AddFurniture(),
    ).then((_) => _loadProducts());
  }

  void _openEditProductSheet(
    BuildContext context,
    Map<String, dynamic> item,
    Map<String, dynamic>? currentVariant,
  ) {
    if (currentVariant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Cannot edit product without active variant.'),
        ),
      );
      return;
    }

    final Map<String, dynamic> editPayload = {
      'furniture_id': item['furniture_id'],
      'furniture_name': item['furniture_name'],
      'price': item['price'],
      'description': item['description'],
      'category_id': item['category_id'],
      'variant_id': currentVariant['variant_id'],
      'color': currentVariant['color'],
      'image_url': currentVariant['image_url'],
      'ar_model_url': currentVariant['ar_model_url'],
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) =>
          AddFurniture(editProduct: editPayload),
    ).then((_) => _loadProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromRGBO(249, 246, 241, 1.0),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // HEADER
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
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
                  onPressed: () =>
                      _openAddProductSheet(context),

                  style: OutlinedButton.styleFrom(
                    side:
                        const BorderSide(color: Colors.brown),
                  ),

                  child: const Text(
                    '+ Add New Product',
                    style: TextStyle(
                      color: Colors.brown,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ✅ SEARCH LABEL
            const Text(
              "Search",
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 8),

            // ✅ SEARCH BAR
            SizedBox(
              width: double.infinity,

              child: TextField(
                controller: _searchController,

                onSubmitted: (value) {
                  addToHistory(value);
                },

                onChanged: (value) {
                  setState(() {
                    query = value;
                  });
                },

                decoration: InputDecoration(
                  prefixIcon:
                      const Icon(Icons.search),

                  hintText: "Search products...",

                  contentPadding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),

                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(30),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ✅ SEARCH HISTORY
            if (searchHistory.isNotEmpty)
              Wrap(
                spacing: 8,

                children: searchHistory
                    .map(
                      (item) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _searchController.text =
                                item;

                            query = item;
                          });
                        },

                        child: Chip(
                          label: Text(item),

                          deleteIcon: const Icon(
                            Icons.close,
                            size: 16,
                          ),

                          onDeleted: () {
                            setState(() {
                              searchHistory
                                  .remove(item);
                            });
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),

            const SizedBox(height: 25),

            // HEADER TABLE
            Container(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 8,
              ),

              decoration: BoxDecoration(
                color:
                    Colors.brown.withOpacity(0.05),

                borderRadius:
                    BorderRadius.circular(8),
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

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.brown,
                      ),
                    )

                  : _products.isEmpty
                      ? const Center(
                          child: Text(
                            'No products yet.',
                            style: TextStyle(
                                color: Colors.brown),
                          ),
                        )

                      : ListView.builder(
                          itemCount: _products.length,

                          itemBuilder:
                              (context, index) {

                            // FILTER
                            final filteredProducts =
                            _products.where((item) {

                            final productName =
                            item['furniture_name']
                            ?.toString()
                            .toLowerCase() ?? '';

                           return productName.contains(
                           query.toLowerCase(),
                                   );

                             }).toList();

                            if (index >=
                                filteredProducts.length) {
                              return const SizedBox();
                            }

                            final item =
                                filteredProducts[index];

                            final int furnitureId =
                                item['furniture_id'];

                            final categoryName =
                                item['CATEGORY']
                                        ?[
                                        'category_name'] ??
                                    'N/A';

                            final List<dynamic> variants =
                                item['VARIANT'] is List
                                    ? item['VARIANT']
                                    : [];

                            final String currentSelection =
                                _selectedColors[
                                        furnitureId] ??
                                    (variants.isNotEmpty
                                        ? variants.first[
                                                'color']
                                            .toString()
                                        : 'N/A');

                            final currentVariant =
                                variants.firstWhere(
                              (v) =>
                                  v['color'].toString() ==
                                  currentSelection,

                              orElse: () =>
                                  variants.isNotEmpty
                                      ? variants.first
                                      : null,
                            );

                            final imageUrl =
                                currentVariant?[
                                        'image_url']
                                    ?.toString();

                            return Container(
                              padding:
                                  const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 8,
                              ),

                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.brown
                                        .withOpacity(0.1),
                                  ),
                                ),
                              ),

                              child: Row(
                                children: [

                                  // IMAGE
                                  Expanded(
                                    flex: 1,

                                    child: Center(
                                      child: imageUrl !=
                                                  null &&
                                              imageUrl
                                                  .isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                          4),

                                              child:
                                                  Image.network(
                                                imageUrl,
                                                height: 40,
                                                width: 40,
                                                fit: BoxFit
                                                    .cover,
                                              ),
                                            )

                                          : const Icon(
                                              Icons.chair,
                                              color:
                                                  Colors.grey,
                                            ),
                                    ),
                                  ),

                                  _dataItem(
                                    item['furniture_name']
                                            ?.toString() ??
                                        'No Name',

                                    flex: 2,
                                  ),

                                  _dataItem(
                                    '₱ ${_formatPrice(item['price'])}',
                                    flex: 1,
                                  ),

                                  _dataItem(
                                    categoryName,
                                    flex: 2,
                                  ),

                                  // COLOR DROPDOWN
                                  Expanded(
                                    flex: 1,

                                    child:
                                        variants.length > 1
                                            ? DropdownButtonHideUnderline(
                                                child:
                                                    DropdownButton<
                                                        String>(
                                                  value:
                                                      currentSelection,

                                                  isExpanded:
                                                      true,

                                                  icon:
                                                      const Icon(
                                                    Icons
                                                        .arrow_drop_down,
                                                    size: 16,
                                                    color: Colors
                                                        .brown,
                                                  ),

                                                  items:
                                                      variants
                                                          .map(
                                                              (v) {
                                                    return DropdownMenuItem<
                                                        String>(
                                                      value: v[
                                                              'color']
                                                          .toString(),

                                                      child:
                                                          Center(
                                                        child:
                                                            Text(
                                                          v['color']
                                                              .toString(),
                                                        ),
                                                      ),
                                                    );
                                                  }).toList(),

                                                  onChanged:
                                                      (String?
                                                          newValue) {
                                                    if (newValue !=
                                                        null) {
                                                      setState(() {
                                                        _selectedColors[
                                                                furnitureId] =
                                                            newValue;
                                                      });
                                                    }
                                                  },
                                                ),
                                              )
                                            : _dataItem(
                                                currentSelection,
                                                flex: 1,
                                              ),
                                  ),

                                  _dataItem(
                                    item['description']
                                            ?.toString() ??
                                        'No Description',

                                    flex: 3,
                                  ),

                                  // EDIT
                                  Expanded(
                                    flex: 1,

                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.edit_note,
                                          color:
                                              Colors.brown,
                                        ),

                                        onPressed: () =>
                                            _openEditProductSheet(
                                          context,
                                          item,
                                          currentVariant,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // ARCHIVE
                                  Expanded(
                                    flex: 1,

                                    child: Center(
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.archive,
                                          color:
                                              Colors.brown,
                                        ),

                                        onPressed: () {},
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
        fontSize: 13,
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

      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),

      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}