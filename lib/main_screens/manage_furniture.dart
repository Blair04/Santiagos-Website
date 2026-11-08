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
  // Archived VARIANT rows (each with its parent FURNITURE embedded)
  List<Map<String, dynamic>> _archivedVariants = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  List<String> searchHistory = [];
  String query = "";
  int? _animatingArchiveId; // furniture_id of the row being animated
  // furniture_id -> selected variant_id
  final Map<int, int> _selectedVariants = {};

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

  void _refresh() {
    setState(() {
      _isLoading = true;
      _searchController.clear();
      query = "";
    });
    _loadProducts();
  }

  // ---------------------------------------------------------------------------
  // LOAD
  // ---------------------------------------------------------------------------
  Future<void> _loadProducts() async {
    try {
      final response = await _supabase
          .from('FURNITURE')
          .select('''
            furniture_id, furniture_name, description, stock, price, created_at, category_id, is_archived,
            CATEGORY ( category_name ),
            VARIANT ( variant_id, color, image_url, ar_model_url, stock, description, is_archived )
          ''')
          .eq('is_archived', false)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> products = [];
      for (final row in response) {
        final item = Map<String, dynamic>.from(row);
        final List<dynamic> allVariants =
            item['VARIANT'] is List ? item['VARIANT'] : [];
        // Only keep variants that are NOT archived
        item['VARIANT'] =
            allVariants.where((v) => v['is_archived'] != true).toList();
        products.add(item);
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('Error loading products: ${e.toString()}', Colors.red);
    }
  }

  Future<void> _loadArchivedVariants() async {
    try {
      final response = await _supabase
          .from('VARIANT')
          .select('''
            variant_id, furniture_id, color, image_url, stock, description, is_archived,
            FURNITURE ( furniture_name, price )
          ''')
          .eq('is_archived', true)
          .order('variant_id', ascending: false);

      _archivedVariants = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error fetching archives: $e");
    }
  }

  // ---------------------------------------------------------------------------
  // ARCHIVE / RESTORE (per variant)
  // ---------------------------------------------------------------------------
  void _archiveVariant(
      Map<String, dynamic> item, Map<String, dynamic>? variant) async {
    final furnitureId = item['furniture_id'] as int;

    // Product with no variants: archive the furniture row itself
    if (variant == null) {
      await _archiveWholeProduct(item);
      return;
    }

    final variantId = variant['variant_id'] as int;
    final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];
    final bool isLastActive = variants.length <= 1;

    if (isLastActive) setState(() => _animatingArchiveId = furnitureId);

    try {
      // 1. Archive ONLY this variant
      await _supabase
          .from('VARIANT')
          .update({'is_archived': true}).eq('variant_id', variantId);

      // 2. If it was the last active variant, archive the product as well
      if (isLastActive) {
        await _supabase
            .from('FURNITURE')
            .update({'is_archived': true}).eq('furniture_id', furnitureId);
        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (!mounted) return;
      setState(() {
        if (isLastActive) {
          _products.removeWhere((p) => p['furniture_id'] == furnitureId);
        } else {
          item['VARIANT'] =
              variants.where((v) => v['variant_id'] != variantId).toList();
        }
        _selectedVariants.remove(furnitureId);
        _animatingArchiveId = null;
      });

      _showSnackBar(
        "${item['furniture_name']} (${variant['color']}) archived!",
        Colors.brown,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _animatingArchiveId = null);
      _showSnackBar("Archive failed: ${e.toString()}", Colors.red);
    }
  }

  // Used only for products that have no variants at all
  Future<void> _archiveWholeProduct(Map<String, dynamic> item) async {
    final furnitureId = item['furniture_id'] as int;
    setState(() => _animatingArchiveId = furnitureId);
    try {
      await _supabase
          .from('FURNITURE')
          .update({'is_archived': true}).eq('furniture_id', furnitureId);
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _products.removeWhere((p) => p['furniture_id'] == furnitureId);
        _animatingArchiveId = null;
      });
      _showSnackBar("${item['furniture_name']} archived!", Colors.brown);
    } catch (e) {
      if (!mounted) return;
      setState(() => _animatingArchiveId = null);
      _showSnackBar("Archive failed: ${e.toString()}", Colors.red);
    }
  }

  Future<void> _unarchiveVariant(
      Map<String, dynamic> variant, VoidCallback onDone) async {
    final variantId = variant['variant_id'];
    final furnitureId = variant['furniture_id'];
    final furniture = variant['FURNITURE'] as Map<String, dynamic>?;
    final name = furniture?['furniture_name'] ?? 'Item';

    try {
      // Restore the variant
      await _supabase
          .from('VARIANT')
          .update({'is_archived': false}).eq('variant_id', variantId);

      // Make sure the parent product is visible again
      await _supabase
          .from('FURNITURE')
          .update({'is_archived': false}).eq('furniture_id', furnitureId);

      if (!mounted) return;
      _archivedVariants.removeWhere((v) => v['variant_id'] == variantId);
      onDone();
      _showSnackBar("$name (${variant['color']}) restored to store", Colors.green);
    } catch (e) {
      _showSnackBar("Failed to restore item: ${e.toString()}", Colors.red);
    }
  }

  // ---------------------------------------------------------------------------
  // ARCHIVE MODAL
  // ---------------------------------------------------------------------------
  void _openArchiveModal() async {
    String archiveQuery = "";
    await _loadArchivedVariants();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final filteredArchived = _archivedVariants.where((v) {
            final name = (v['FURNITURE']?['furniture_name'] ?? '')
                .toString()
                .toLowerCase();
            final color = (v['color'] ?? '').toString().toLowerCase();
            final q = archiveQuery.toLowerCase();
            return name.contains(q) || color.contains(q);
          }).toList();

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 900,
              height: 520,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Archived Products",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.brown,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 50,
                    child: TextField(
                      onChanged: (v) => setModalState(() => archiveQuery = v),
                      decoration: InputDecoration(
                        hintText: "Search all archived items...",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.brown.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.brown),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.brown.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _headerItem('Image'),
                        _headerItem('Product Name', flex: 2),
                        _headerItem('Color/Variant'),
                        _headerItem('Price'),
                        _headerItem('Stock'),
                        _headerItem('Description', flex: 2),
                        _headerItem('Action'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Expanded(
                    child: filteredArchived.isEmpty
                        ? const Center(
                            child: Text(
                              "No archived products.",
                              style: TextStyle(color: Colors.brown),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredArchived.length,
                            itemBuilder: (context, index) {
                              final variant = filteredArchived[index];
                              final furniture =
                                  variant['FURNITURE'] as Map<String, dynamic>?;
                              final imageUrl = variant['image_url']?.toString();

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 10),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                        color: Colors.brown.withOpacity(0.08)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Center(
                                        child: imageUrl != null && imageUrl.isNotEmpty
                                            ? ClipRRect(
                                                borderRadius: BorderRadius.circular(8),
                                                child: Image.network(
                                                  imageUrl,
                                                  height: 45,
                                                  width: 45,
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : const Icon(Icons.chair, color: Colors.grey),
                                      ),
                                    ),
                                    _dataItem(
                                        furniture?['furniture_name']?.toString() ?? '',
                                        flex: 2),
                                    _dataItem(variant['color']?.toString() ?? 'N/A'),
                                    _dataItem("₱ ${_formatPrice(furniture?['price'])}"),
                                    _dataItem(variant['stock']?.toString() ?? '0'),
                                    // Description belongs to the variant
                                    _dataItem(
                                        variant['description']?.toString() ??
                                            'No Description',
                                        flex: 2),
                                    Expanded(
                                      flex: 2,
                                      child: Center(
                                        child: OutlinedButton.icon(
                                          onPressed: () => _unarchiveVariant(
                                          variant,
                                          () => setModalState(() {}),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        side: BorderSide(color: Colors.brown.shade300),
                                      ),
                                      icon: const Icon(Icons.unarchive, size: 18, color: Colors.brown),
                                        label: const Text(
                                          "Restore",
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(color: Colors.brown),
                                          ),
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
        },
      ),
    ).then((_) => _loadProducts());
  }

  // ---------------------------------------------------------------------------
  // ADD / EDIT
  // ---------------------------------------------------------------------------
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

  void _openEditProductSheet(
    BuildContext context,
    Map<String, dynamic> item,
    Map<String, dynamic>? currentVariant,
  ) {
    if (currentVariant == null) {
      _showSnackBar('Cannot edit product without active variant.', Colors.red);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddFurniture(editProduct: {
        'furniture_id': item['furniture_id'],
        'furniture_name': item['furniture_name'],
        'price': item['price'],
        'category_id': item['category_id'],
        // Variant-level values (independent from FURNITURE.stock / description)
        'variant_id': currentVariant['variant_id'],
        'color': currentVariant['color'],
        'stock': currentVariant['stock'],
        'description': currentVariant['description'],
        'image_url': currentVariant['image_url'],
        'ar_model_url': currentVariant['ar_model_url'],
      }),
    ).then((_) => _loadProducts());
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final String searchText = query.trim().toLowerCase();

    final filteredProducts = _products.where((item) {
      if (searchText.isEmpty) return true;

      final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];
      final String colors =
          variants.map((v) => (v['color'] ?? '').toString().toLowerCase()).join(' ');
      final String variantDescriptions = variants
          .map((v) => (v['description'] ?? '').toString().toLowerCase())
          .join(' ');
      final String variantStocks =
          variants.map((v) => (v['stock'] ?? '').toString()).join(' ');

      final String name = (item['furniture_name'] ?? '').toString().toLowerCase();
      final String category =
          (item['CATEGORY']?['category_name'] ?? '').toString().toLowerCase();
      final String price = _formatPrice(item['price']);

      // Product-level stock/description are only searchable when the
      // product has no variants (otherwise the variant values are shown)
      final bool hasVariants = variants.isNotEmpty;
      final String description =
          hasVariants ? '' : (item['description'] ?? '').toString().toLowerCase();
      final String stock = hasVariants ? '' : (item['stock'] ?? '').toString();

      return name.contains(searchText) ||
          category.contains(searchText) ||
          colors.contains(searchText) ||
          description.contains(searchText) ||
          variantDescriptions.contains(searchText) ||
          price.contains(searchText) ||
          stock.contains(searchText) ||
          variantStocks.contains(searchText);
    }).toList();

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F5F1),
        body: Center(child: CircularProgressIndicator(color: Colors.brown)),
      );
    }

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
                const Text(
                  'Manage Products',
                  style: TextStyle(
                    color: Colors.brown,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openArchiveModal,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    side: BorderSide(color: Colors.brown.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  icon: const Icon(Icons.archive_outlined, color: Colors.brown, size: 20),
                  label: const Text(
                    "Archive",
                    style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              height: 1,
              width: double.infinity,
              color: Colors.brown.withOpacity(0.15),
            ),
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
                        prefixIcon: const Icon(Icons.search),
                        hintText: "Search Product...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide(color: Colors.brown.withOpacity(0.2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: const BorderSide(color: Colors.brown, width: 1),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  height: 46,
                  width: 165,
                  child: ElevatedButton.icon(
                    onPressed: () => _openAddProductSheet(context),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF6D4C41),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text(
                      "Add New Product",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.brown),
                    onPressed: _refresh,
                    tooltip: "Refresh",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            if (searchHistory.isNotEmpty)
              Wrap(
                spacing: 8,
                children: searchHistory
                    .map(
                      (item) => GestureDetector(
                        onTap: () => setState(() {
                          _searchController.text = item;
                          query = item;
                        }),
                        child: Chip(
                          label: Text(item),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => setState(() => searchHistory.remove(item)),
                        ),
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 25),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.brown.withOpacity(0.1)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      decoration: BoxDecoration(
                        color: Colors.brown.withOpacity(0.04),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      child: Row(
                        children: [
                          _headerItem('Image'),
                          _headerItem('Product Name', flex: 2),
                          _headerItem('Price'),
                          _headerItem('Category', flex: 2),
                          _headerItem('Color/Variant', flex: 2),
                          _headerItem('Description', flex: 3),
                          _headerItem('Stock'),
                          _headerItem('Edit'),
                          _headerItem('Archive'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredProducts.isEmpty
                          ? const Center(
                              child: Text(
                                'No products found.',
                                style: TextStyle(color: Colors.brown),
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final item = filteredProducts[index];
                                final int furnitureId = item['furniture_id'];
                                final categoryName =
                                    item['CATEGORY']?['category_name'] ?? 'N/A';
                                final List<dynamic> variants =
                                    item['VARIANT'] is List ? item['VARIANT'] : [];

                                // Selected variant (falls back to the first active one)
                                final int? selectedId = _selectedVariants[furnitureId];
                                final dynamic currentVariant = variants.isEmpty
                                    ? null
                                    : variants.firstWhere(
                                        (v) => v['variant_id'] == selectedId,
                                        orElse: () => variants.first,
                                      );
                                final String currentColor =
                                    currentVariant?['color']?.toString() ?? 'N/A';
                                final imageUrl = currentVariant?['image_url']?.toString();

                                // Description & stock come from the selected VARIANT only.
                                // FURNITURE values are used only if there is no variant.
                                final String displayDescription = currentVariant != null
                                    ? (currentVariant['description']?.toString() ??
                                        'No Description')
                                    : (item['description']?.toString() ??
                                        'No Description');
                                final String displayStock = currentVariant != null
                                    ? (currentVariant['stock']?.toString() ?? '0')
                                    : (item['stock']?.toString() ?? 'N/A');

                                return AnimatedOpacity(
                                  duration: const Duration(milliseconds: 500),
                                  opacity: _animatingArchiveId == furnitureId ? 0.0 : 1.0,
                                  child: AnimatedScale(
                                    duration: const Duration(milliseconds: 500),
                                    scale: _animatingArchiveId == furnitureId ? 0.8 : 1.0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14, horizontal: 8),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                              color: Colors.brown.withOpacity(0.08)),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Center(
                                              child: imageUrl != null &&
                                                      imageUrl.isNotEmpty
                                                  ? ClipRRect(
                                                      borderRadius:
                                                          BorderRadius.circular(8),
                                                      child: Image.network(
                                                        imageUrl,
                                                        height: 45,
                                                        width: 45,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    )
                                                  : const Icon(Icons.chair,
                                                      color: Colors.grey),
                                            ),
                                          ),
                                          _dataItem(
                                              item['furniture_name']?.toString() ??
                                                  'No Name',
                                              flex: 2),
                                          _dataItem('₱ ${_formatPrice(item['price'])}'),
                                          _dataItem(categoryName, flex: 2),
                                          Expanded(
                                            flex: 2,
                                            child: variants.length > 1
                                                ? DropdownButtonHideUnderline(
                                                    child: DropdownButton<int>(
                                                      value: currentVariant['variant_id']
                                                          as int,
                                                      isExpanded: true,
                                                      style: const TextStyle(
                                                        color: Colors.black87,
                                                        fontSize: 12,
                                                      ),
                                                      icon: const Icon(
                                                        Icons.arrow_drop_down,
                                                        size: 16,
                                                        color: Colors.brown,
                                                      ),
                                                      items: variants
                                                          .map(
                                                            (v) => DropdownMenuItem<int>(
                                                              value:
                                                                  v['variant_id'] as int,
                                                              child: Center(
                                                                child: Text(
                                                                  (v['color'] ?? 'N/A')
                                                                      .toString(),
                                                                  style: const TextStyle(
                                                                    color: Colors.black87,
                                                                    fontSize: 12,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          )
                                                          .toList(),
                                                      onChanged: (newValue) {
                                                        if (newValue != null) {
                                                          setState(() =>
                                                              _selectedVariants[
                                                                  furnitureId] = newValue);
                                                        }
                                                      },
                                                    ),
                                                  )
                                                : Text(
                                                    currentColor,
                                                    textAlign: TextAlign.center,
                                                    style: const TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 12,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                          ),
                                          _dataItem(displayDescription, flex: 3),
                                          _dataItem(displayStock),
                                          Expanded(
                                            child: Center(
                                              child: IconButton(
                                                icon: const Icon(Icons.edit_note,
                                                    color: Colors.brown),
                                                onPressed: () => _openEditProductSheet(
                                                    context,
                                                    item,
                                                    currentVariant == null
                                                        ? null
                                                        : Map<String, dynamic>.from(
                                                            currentVariant)),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            child: Center(
                                              child: IconButton(
                                                icon: const Icon(Icons.archive,
                                                    color: Colors.brown),
                                                tooltip: currentVariant == null
                                                    ? 'Archive product'
                                                    : 'Archive this variant',
                                                onPressed: () => _archiveVariant(
                                                    item,
                                                    currentVariant == null
                                                        ? null
                                                        : Map<String, dynamic>.from(
                                                            currentVariant)),
                                              ),
                                            ),
                                          ),
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
      style: const TextStyle(color: Colors.black87, fontSize: 12),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}