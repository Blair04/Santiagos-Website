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
  List<Map<String, dynamic>> _archivedProducts = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  List<String> searchHistory = [];
  String query = "";
  int? _animatingArchiveId;
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

  void addToHistory(String value) {
    if (value.isNotEmpty && !searchHistory.contains(value)) {
      setState(() => searchHistory.insert(0, value));
    }
  }

  Future<void> _loadProducts() async {
    try {
      final response = await _supabase.from('FURNITURE').select('''
        furniture_id, furniture_name, description, price, created_at, category_id,
        CATEGORY ( category_name ),
        VARIANT ( variant_id, color, image_url, ar_model_url )
      ''').order('created_at', ascending: false);

      setState(() {
        _products = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Error loading products: ${e.toString()}', Colors.red);
    }
  }

  // FIXED: Copies data safely using upsert to avoid duplicate key exceptions, then drops from source table
  // 1. ARCHIVE: Moves item from FURNITURE to FURNITURE_ARCHIVE (including its variants)
  // ARCHIVE Lifecyle Handshake
  void _archiveProduct(Map<String, dynamic> item) async {
    final furnitureId = item['furniture_id'];
    setState(() => _animatingArchiveId = furnitureId);

    try {
      final furniturePayload = {
        'furniture_id': item['furniture_id'],
        'furniture_name': item['furniture_name'],
        'description': item['description'],
        'price': item['price'],
        'created_at': item['created_at'],
        'category_id': item['category_id'],
      };

      final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];

      // 1. Write the backup copies to the archive tables first
      await _supabase.from('FURNITURE_ARCHIVE').upsert(furniturePayload);

      if (variants.isNotEmpty) {
        final variantsPayload = variants.map((v) => {
          'variant_id': v['variant_id'],
          'color': v['color'],
          'image_url': v['image_url'],
          'ar_model_url': v['ar_model_url'],
          'furniture_id': furnitureId,
        }).toList();
        await _supabase.from('VARIANT_ARCHIVE').upsert(variantsPayload);
      }

      // 2. NOW delete it from active table (The cascade rule clears out active VARIANT rows safely)
      await _supabase.from('FURNITURE').delete().eq('furniture_id', furnitureId);
      
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _products.removeWhere((p) => p['furniture_id'] == furnitureId);
        _archivedProducts.insert(0, item);
        _animatingArchiveId = null;
      });
      _showSnackBar("${item['furniture_name']} archived!", Colors.brown);
    } catch (e) {
      setState(() => _animatingArchiveId = null);
      _showSnackBar("Archive failed: ${e.toString()}", Colors.red);
    }
  }

  // 2. UNARCHIVE: Moves item from FURNITURE_ARCHIVE back to active FURNITURE (including variants)
  void _unarchiveProduct(Map<String, dynamic> item) async {
    final furnitureId = item['furniture_id'];
    try {
      final furniturePayload = {
        'furniture_id': item['furniture_id'],
        'furniture_name': item['furniture_name'],
        'description': item['description'],
        'price': item['price'],
        'created_at': item['created_at'],
        'category_id': item['category_id'],
      };

      final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];

      // Step A: Restore core product specs map signature layout to active table
      await _supabase.from('FURNITURE').upsert(furniturePayload);

      // Step B: Push stored snapshot variations database rows back to production active variants layout
      if (variants.isNotEmpty) {
        final variantsPayload = variants.map((v) => {
          'variant_id': v['variant_id'],
          'color': v['color'],
          'image_url': v['image_url'],
          'ar_model_url': v['ar_model_url'],
          'furniture_id': furnitureId,
        }).toList();

        await _supabase.from('VARIANT').upsert(variantsPayload);
      }

      // Step C: Clear out history logs references from your system backup tracking storage tables
      await _supabase.from('FURNITURE_ARCHIVE').delete().eq('furniture_id', furnitureId);

      setState(() {
        _archivedProducts.removeWhere((p) => p['furniture_id'] == furnitureId);
        _products.insert(0, item);
      });

      if (!mounted) return;
      Navigator.pop(context);
      Future.delayed(const Duration(milliseconds: 200), () => _openArchiveModal());
      _showSnackBar("${item['furniture_name']} restored to store", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to restore item: ${e.toString()}", Colors.red);
    }
  }

  void _openArchiveModal() async {
    String archiveQuery = "";
    try {
      // Locate this section inside your existing _openArchiveModal function block:
      final response = await _supabase.from('FURNITURE_ARCHIVE').select('''
        furniture_id, furniture_name, description, price, created_at, category_id,
        VARIANT:VARIANT_ARCHIVE ( variant_id, color, image_url )
      ''').order('furniture_name', ascending: true);

      setState(() => _archivedProducts = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint("Error fetching archives: $e");
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredArchived = _archivedProducts.where((item) {
            return (item['furniture_name'] ?? '').toString().toLowerCase().contains(archiveQuery.toLowerCase());
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 900, height: 520, padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22)),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Archived Products", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown)),
                      IconButton(onPressed: () { Navigator.pop(context); _loadProducts(); }, icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 50,
                    child: TextField(
                      onChanged: (v) => setModalState(() => archiveQuery = v),
                      decoration: InputDecoration(
                        hintText: "Search all archived items...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.brown.withOpacity(0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.brown)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(color: Colors.brown.withOpacity(0.05), borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [_headerItem('Image'), _headerItem('Product Name', flex: 2), _headerItem('Price'), _headerItem('Action')]),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: filteredArchived.isEmpty
                        ? const Center(child: Text("No archived products.", style: TextStyle(color: Colors.brown)))
                        : ListView.builder(
                            itemCount: filteredArchived.length,
                            itemBuilder: (context, index) {
                              final item = filteredArchived[index];
                              final variants = item['VARIANT'] is List ? item['VARIANT'] : [];
                              final imageUrl = variants.isNotEmpty ? variants.first['image_url'] : null;

                              return Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.brown.withOpacity(0.08)))),
                                child: Row(
                                  children: [
                                    Expanded(child: Center(child: imageUrl != null && imageUrl.isNotEmpty
                                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, height: 45, width: 45, fit: BoxFit.cover))
                                        : const Icon(Icons.chair, color: Colors.grey))),
                                    _dataItem(item['furniture_name']?.toString() ?? '', flex: 2),
                                    _dataItem("₱ ${_formatPrice(item['price'])}"),
                                    Expanded(child: Center(child: OutlinedButton.icon(
                                      onPressed: () => _unarchiveProduct(item),
                                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)), side: BorderSide(color: Colors.brown.shade300)),
                                      icon: const Icon(Icons.unarchive, size: 18, color: Colors.brown),
                                      label: const Text("Unarchive", style: TextStyle(color: Colors.brown)),
                                    ))),
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
        },
      ),
    ).then((_) => _loadProducts());
  }

  void _openAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => const AddFurniture(),
    ).then((_) => _loadProducts());
  }

  void _openEditProductSheet(BuildContext context, Map<String, dynamic> item, Map<String, dynamic>? currentVariant) {
    if (currentVariant == null) {
      _showSnackBar('Cannot edit product without active variant.', Colors.red);
      return;
    }

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => AddFurniture(editProduct: {
        'furniture_id': item['furniture_id'], 'furniture_name': item['furniture_name'], 'price': item['price'],
        'description': item['description'], 'category_id': item['category_id'], 'variant_id': currentVariant['variant_id'],
        'color': currentVariant['color'], 'image_url': currentVariant['image_url'], 'ar_model_url': currentVariant['ar_model_url'],
      }),
    ).then((_) => _loadProducts());
  }

  void _showSnackBar(String message, Color background) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0.00';
    return (double.tryParse(price.toString()) ?? 0.0).toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _products.where((item) {
      return (item['furniture_name'] ?? '').toString().toLowerCase().contains(query.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('My Products', style: TextStyle(color: Colors.brown, fontSize: 24, fontWeight: FontWeight.bold)),
                OutlinedButton.icon(
                  onPressed: _openArchiveModal,
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), side: BorderSide(color: Colors.brown.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  icon: const Icon(Icons.archive_outlined, color: Colors.brown, size: 20),
                  label: const Text("Archive", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(height: 1, width: double.infinity, color: Colors.brown.withOpacity(0.15)),
            const SizedBox(height: 25),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: addToHistory,
                      onChanged: (v) => setState(() => query = v),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search), hintText: "Search products...", contentPadding: const EdgeInsets.symmetric(horizontal: 12), filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide(color: Colors.brown.withOpacity(0.2))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: const BorderSide(color: Colors.brown, width: 1)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 46, width: 165,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddProductSheet(context),
                    style: ElevatedButton.styleFrom(elevation: 0, backgroundColor: const Color(0xFF6D4C41), padding: const EdgeInsets.symmetric(horizontal: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text("Add New Product", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 13)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (searchHistory.isNotEmpty)
              Wrap(
                spacing: 8,
                children: searchHistory.map((item) => GestureDetector(
                  onTap: () => setState(() { _searchController.text = item; query = item; }),
                  child: Chip(label: Text(item), deleteIcon: const Icon(Icons.close, size: 16), onDeleted: () => setState(() => searchHistory.remove(item))),
                )).toList(),
              ),
            const SizedBox(height: 25),
            Expanded(
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.brown.withOpacity(0.1)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))]),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(color: Colors.brown.withOpacity(0.04), borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18))),
                      child: Row(
                        children: [
                          _headerItem('Image'), _headerItem('Product Name', flex: 2), _headerItem('Price'),
                          _headerItem('Category', flex: 2), _headerItem('Color'), _headerItem('Description', flex: 3),
                          _headerItem('Edit'), _headerItem('Archive'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.brown))
                          : filteredProducts.isEmpty
                              ? const Center(child: Text('No products found.', style: TextStyle(color: Colors.brown)))
                              : ListView.builder(
                                  itemCount: filteredProducts.length,
                                  itemBuilder: (context, index) {
                                    final item = filteredProducts[index];
                                    final int furnitureId = item['furniture_id'];
                                    final categoryName = item['CATEGORY']?['category_name'] ?? 'N/A';
                                    final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];

                                    final String currentSelection = _selectedColors[furnitureId] ?? (variants.isNotEmpty ? variants.first['color'].toString() : 'N/A');
                                    final currentVariant = variants.firstWhere((v) => v['color'].toString() == currentSelection, orElse: () => variants.isNotEmpty ? variants.first : null);
                                    final imageUrl = currentVariant?['image_url']?.toString();

                                    return AnimatedOpacity(
                                      duration: const Duration(milliseconds: 500),
                                      opacity: _animatingArchiveId == furnitureId ? 0.0 : 1.0,
                                      child: AnimatedScale(
                                        duration: const Duration(milliseconds: 500),
                                        scale: _animatingArchiveId == furnitureId ? 0.8 : 1.0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.brown.withOpacity(0.08)))),
                                          child: Row(
                                            children: [
                                              Expanded(child: Center(child: imageUrl != null && imageUrl.isNotEmpty
                                                  ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(imageUrl, height: 45, width: 45, fit: BoxFit.cover))
                                                  : const Icon(Icons.chair, color: Colors.grey))),
                                              _dataItem(item['furniture_name']?.toString() ?? 'No Name', flex: 2),
                                              _dataItem('₱ ${_formatPrice(item['price'])}'),
                                              _dataItem(categoryName, flex: 2),
                                              Expanded(child: variants.length > 1
                                                  ? DropdownButtonHideUnderline(
                                                      child: DropdownButton<String>(
                                                        value: currentSelection, isExpanded: true, icon: const Icon(Icons.arrow_drop_down, size: 16, color: Colors.brown),
                                                        items: variants.map((v) => DropdownMenuItem<String>(value: v['color'].toString(), child: Center(child: Text(v['color'].toString())))).toList(),
                                                        onChanged: (newValue) { if (newValue != null) setState(() => _selectedColors[furnitureId] = newValue); },
                                                      ),
                                                    )
                                                  : _dataItem(currentSelection)),
                                              _dataItem(item['description']?.toString() ?? 'No Description', flex: 3),
                                              Expanded(child: Center(child: IconButton(icon: const Icon(Icons.edit_note, color: Colors.brown), onPressed: () => _openEditProductSheet(context, item, currentVariant)))),
                                              Expanded(child: Center(child: IconButton(icon: const Icon(Icons.archive, color: Colors.brown), onPressed: () => _archiveProduct(item)))),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _headerItem(String title, {int flex = 1}) {
  return Expanded(flex: flex, child: Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis));
}

Widget _dataItem(String text, {int flex = 1}) {
  return Expanded(flex: flex, child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis));
}