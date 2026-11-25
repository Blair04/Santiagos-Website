import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/main_screens/add_furniture.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class ManageFurniture extends StatefulWidget {
  final int? highlightFurnitureId;
  final int highlightStock;

  const ManageFurniture({
    super.key,
    this.highlightFurnitureId,
    this.highlightStock = 0,
  });
  static String get routeName => '/manage-furniture';

  @override
  State<ManageFurniture> createState() => _ManageFurnitureState();
}

class _ManageFurnitureState extends State<ManageFurniture> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();
  int? _highlightId;
  int _highlightStock = 0;
  bool _compact = false;

  @override
  void initState() {
    super.initState();
    _highlightId = widget.highlightFurnitureId;
    _highlightStock = widget.highlightStock;
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant ManageFurniture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightFurnitureId != oldWidget.highlightFurnitureId) {
      setState(() {
        _highlightId = widget.highlightFurnitureId;
        _highlightStock = widget.highlightStock;
      });
      _scrollToHighlight();
    }
  }

  void _applyHighlight() {
    if (widget.highlightFurnitureId != null) {
      setState(() {
        _highlightId = widget.highlightFurnitureId;
        _highlightStock = widget.highlightStock;
      });
    }
  }

  Color _highlightColorFor(int stock) {
    if (stock <= 0) return const Color(0xFFD9534F);
    if (stock <= 2) return const Color(0xFFF0AD4E);
    return const Color(0xFF438A5E);
  }

  void _scrollToHighlight() {
    if (_highlightId == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final index =
          _products.indexWhere((p) => p['furniture_id'] == _highlightId);
      if (index < 0 || !_scrollController.hasClients) return;
      final double rowExtent = _compact ? 215.0 : 77.0;
      _scrollController.jumpTo(
        (index * rowExtent)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
      final ctx = _highlightKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300), alignment: 0.3);
      }
    });
  }

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _archivedVariants = [];
  bool _isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  List<String> searchHistory = [];
  String query = "";
  int? _animatingArchiveId;
  final Map<int, int> _selectedVariants = {};

  String? _sortColumn;
  bool _sortAscending = true;

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
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
      _highlightId = null;
      query = "";
    });
    _loadProducts();
  }

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
        item['VARIANT'] =
            allVariants.where((v) => v['is_archived'] != true).toList();
        products.add(item);
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _isLoading = false;
      });
      _scrollToHighlight();
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

  void _archiveVariant(
      Map<String, dynamic> item, Map<String, dynamic>? variant) async {
    final furnitureId = item['furniture_id'] as int;

    if (variant == null) {
      await _archiveWholeProduct(item);
      return;
    }

    final variantId = variant['variant_id'] as int;
    final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];
    final bool isLastActive = variants.length <= 1;

    if (isLastActive) setState(() => _animatingArchiveId = furnitureId);

    try {
      await _supabase
          .from('VARIANT')
          .update({'is_archived': true}).eq('variant_id', variantId);

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
      await _supabase
          .from('VARIANT')
          .update({'is_archived': false}).eq('variant_id', variantId);

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

  Widget _archivedItem(
    Map<String, dynamic> variant,
    bool narrow,
    VoidCallback onDone,
  ) {
    final furniture = variant['FURNITURE'] as Map<String, dynamic>?;
    final imageUrl = variant['image_url']?.toString();
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    if (narrow) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.brown.withOpacity(0.08)),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 48,
                height: 48,
                child: hasImage
                    ? Image.network(imageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.chair, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    furniture?['furniture_name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${variant['color'] ?? 'N/A'} · ₱ ${_formatPrice(furniture?['price'])} · Stock ${variant['stock'] ?? 0}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    variant['description']?.toString() ?? 'No Description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Restore',
              onPressed: () => _unarchiveVariant(variant, onDone),
              icon: const Icon(Icons.unarchive, color: Colors.brown),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.brown.withOpacity(0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: hasImage
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
          _dataItem(furniture?['furniture_name']?.toString() ?? '', flex: 2),
          _dataItem(variant['color']?.toString() ?? 'N/A'),
          _dataItem("₱ ${_formatPrice(furniture?['price'])}"),
          _dataItem(variant['stock']?.toString() ?? '0'),
          _dataItem(variant['description']?.toString() ?? 'No Description',
              flex: 2),
          Expanded(
            flex: 2,
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => _unarchiveVariant(variant, onDone),
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
  }

  void _openArchiveModal() async {
    String archiveQuery = "";
    await _loadArchivedVariants();

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final Size size = MediaQuery.of(context).size;
          final bool narrow = size.width < 700;

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
            insetPadding: EdgeInsets.symmetric(
              horizontal: narrow ? 12 : 40,
              vertical: 24,
            ),
            child: Container(
              width: math.min(900.0, size.width - (narrow ? 24 : 80)),
              height: math.min(520.0, size.height * 0.85),
              padding: EdgeInsets.all(narrow ? 16 : 22),
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
                  if (!narrow)
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
                  if (!narrow) const SizedBox(height: 5),
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
                            itemBuilder: (context, index) => _archivedItem(
                              filteredArchived[index],
                              narrow,
                              () => setModalState(() {}),
                            ),
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
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      constraints: const BoxConstraints(maxWidth: 720),
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
      constraints: const BoxConstraints(maxWidth: 720),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddFurniture(editProduct: {
        'furniture_id': item['furniture_id'],
        'furniture_name': item['furniture_name'],
        'price': item['price'],
        'category_id': item['category_id'],
        'variant_id': currentVariant['variant_id'],
        'color': currentVariant['color'],
        'stock': currentVariant['stock'],
        'description': currentVariant['description'],
        'image_url': currentVariant['image_url'],
        'ar_model_url': currentVariant['ar_model_url'],
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

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  int _stockValueForSort(Map<String, dynamic> item) {
    final List<dynamic> variants =
        item['VARIANT'] is List ? item['VARIANT'] : <dynamic>[];

    if (variants.isEmpty) {
      return int.tryParse(item['stock']?.toString() ?? '') ?? 0;
    }

    final int? selectedId = _selectedVariants[item['furniture_id']];
    final dynamic selectedVariant = variants.firstWhere(
      (variant) => variant['variant_id'] == selectedId,
      orElse: () => variants.first,
    );
    return int.tryParse(selectedVariant['stock']?.toString() ?? '') ?? 0;
  }

  Widget _sortableHeaderItem(
    String title, {
    required String sortColumn,
    int flex = 1,
  }) {
    final bool isActive = _sortColumn == sortColumn;
    final Color mutedArrow = Colors.brown.withOpacity(0.32);
    final Color activeArrow = Colors.brown.withOpacity(0.78);

    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: () => _toggleSort(sortColumn),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.brown,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.keyboard_arrow_up_rounded,
                    size: 13,
                    color: isActive && _sortAscending ? activeArrow : mutedArrow,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -5),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 13,
                      color: isActive && !_sortAscending ? activeArrow : mutedArrow,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortChip(String title, String column) {
    final bool active = _sortColumn == column;
    return InkWell(
      onTap: () => _toggleSort(column),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? Colors.brown.withOpacity(0.12) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.brown.withOpacity(active ? 0.5 : 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.brown,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              Icon(
                _sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: Colors.brown,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _compactSortBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            'Sort by',
            style: TextStyle(
              color: Colors.brown.withOpacity(0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 10),
          _sortChip('Category', 'category'),
          const SizedBox(width: 8),
          _sortChip('Stock', 'stock'),
        ],
      ),
    );
  }

  Widget _variantSelector({
    required int furnitureId,
    required List<dynamic> variants,
    required dynamic currentVariant,
    required String currentColor,
    required bool centered,
  }) {
    if (variants.length > 1) {
      return DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: currentVariant['variant_id'] as int,
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
          items: variants.map((v) {
            final label = Text(
              (v['color'] ?? 'N/A').toString(),
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 12,
              ),
            );
            return DropdownMenuItem<int>(
              value: v['variant_id'] as int,
              child: centered ? Center(child: label) : label,
            );
          }).toList(),
          onChanged: (newValue) {
            if (newValue != null) {
              setState(() => _selectedVariants[furnitureId] = newValue);
            }
          },
        ),
      );
    }

    return Text(
      currentColor,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Colors.black87,
        fontSize: 12,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _productItem(Map<String, dynamic> item, {required bool compact}) {
    final int furnitureId = item['furniture_id'];
    final categoryName = item['CATEGORY']?['category_name'] ?? 'N/A';
    final List<dynamic> variants = item['VARIANT'] is List ? item['VARIANT'] : [];

    final int? selectedId = _selectedVariants[furnitureId];
    final dynamic currentVariant = variants.isEmpty
        ? null
        : variants.firstWhere(
            (v) => v['variant_id'] == selectedId,
            orElse: () => variants.first,
          );
    final String currentColor = currentVariant?['color']?.toString() ?? 'N/A';
    final imageUrl = currentVariant?['image_url']?.toString();
    final bool hasImage = imageUrl != null && imageUrl.isNotEmpty;

    final String displayDescription = currentVariant != null
        ? (currentVariant['description']?.toString() ?? 'No Description')
        : (item['description']?.toString() ?? 'No Description');
    final String displayStock = currentVariant != null
        ? (currentVariant['stock']?.toString() ?? '0')
        : (item['stock']?.toString() ?? 'N/A');
    final bool isHighlighted = furnitureId == _highlightId;
    final Color? rowColor = isHighlighted
        ? _highlightColorFor(_highlightStock).withOpacity(0.15)
        : null;
    final Map<String, dynamic>? variantMap = currentVariant == null
        ? null
        : Map<String, dynamic>.from(currentVariant);
    final String productName = item['furniture_name']?.toString() ?? 'No Name';

    final Widget content;

    if (compact) {
      content = Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: rowColor == null
              ? Colors.white
              : Color.alphaBlend(rowColor, Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.brown.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: hasImage
                        ? Image.network(imageUrl, fit: BoxFit.cover)
                        : Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.chair, color: Colors.grey),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₱ ${_formatPrice(item['price'])}',
                        style: const TextStyle(
                          color: Colors.brown,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        categoryName.toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_note, color: Colors.brown),
                      tooltip: 'Edit',
                      onPressed: () =>
                          _openEditProductSheet(context, item, variantMap),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.archive, color: Colors.brown),
                      tooltip: currentVariant == null
                          ? 'Archive product'
                          : 'Archive this variant',
                      onPressed: () => _archiveVariant(item, variantMap),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: Colors.brown.withOpacity(0.08)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Variant',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _variantSelector(
                        furnitureId: furnitureId,
                        variants: variants,
                        currentVariant: currentVariant,
                        currentColor: currentColor,
                        centered: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Stock: $displayStock',
                    style: const TextStyle(
                      color: Colors.brown,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              displayDescription,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      content = Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: rowColor,
          border: Border(
            bottom: BorderSide(color: Colors.brown.withOpacity(0.08)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: hasImage
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
            _dataItem(productName, flex: 2),
            _dataItem('₱ ${_formatPrice(item['price'])}'),
            _dataItem(categoryName.toString(), flex: 2),
            Expanded(
              flex: 2,
              child: _variantSelector(
                furnitureId: furnitureId,
                variants: variants,
                currentVariant: currentVariant,
                currentColor: currentColor,
                centered: true,
              ),
            ),
            _dataItem(displayDescription, flex: 3),
            _dataItem(displayStock),
            Expanded(
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.edit_note, color: Colors.brown),
                  onPressed: () =>
                      _openEditProductSheet(context, item, variantMap),
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: IconButton(
                  icon: const Icon(Icons.archive, color: Colors.brown),
                  tooltip: currentVariant == null
                      ? 'Archive product'
                      : 'Archive this variant',
                  onPressed: () => _archiveVariant(item, variantMap),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return AnimatedOpacity(
      key: isHighlighted ? _highlightKey : null,
      duration: const Duration(milliseconds: 500),
      opacity: _animatingArchiveId == furnitureId ? 0.0 : 1.0,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 500),
        scale: _animatingArchiveId == furnitureId ? 0.8 : 1.0,
        child: content,
      ),
    );
  }

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

    if (_sortColumn == 'category') {
      filteredProducts.sort((a, b) {
        final String categoryA =
            (a['CATEGORY']?['category_name'] ?? '').toString().toLowerCase();
        final String categoryB =
            (b['CATEGORY']?['category_name'] ?? '').toString().toLowerCase();
        final int comparison = categoryA.compareTo(categoryB);
        return _sortAscending ? comparison : -comparison;
      });
    } else if (_sortColumn == 'stock') {
      filteredProducts.sort((a, b) {
        final int comparison =
            _stockValueForSort(a).compareTo(_stockValueForSort(b));
        return _sortAscending ? comparison : -comparison;
      });
    }

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8F5F1),
        body: Center(child: CircularProgressIndicator(color: Colors.brown)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F1),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double width = constraints.maxWidth;
          final bool phone = width < 600;
          final bool compact = width < 900;
          final bool wideToolbar = width >= 700;
          _compact = compact;

          final Widget searchField = SizedBox(
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
          );

          final Widget addButton = SizedBox(
            height: 46,
            width: wideToolbar ? 165 : null,
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
          );

          final Widget refreshButton = Container(
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
          );

          final Widget tableView = Container(
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
                      _sortableHeaderItem('Category', sortColumn: 'category', flex: 2),
                      _headerItem('Color/Variant', flex: 2),
                      _headerItem('Description', flex: 3),
                      _sortableHeaderItem('Stock', sortColumn: 'stock'),
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
                          controller: _scrollController,
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) =>
                              _productItem(filteredProducts[index], compact: false),
                        ),
                ),
              ],
            ),
          );

          final Widget cardView = Column(
            children: [
              _compactSortBar(),
              Expanded(
                child: filteredProducts.isEmpty
                    ? const Center(
                        child: Text(
                          'No products found.',
                          style: TextStyle(color: Colors.brown),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) =>
                            _productItem(filteredProducts[index], compact: true),
                      ),
              ),
            ],
          );

          return Padding(
            padding: EdgeInsets.all(phone ? 14 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Manage Products',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.brown,
                          fontSize: phone ? 20 : 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _openArchiveModal,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: phone ? 14 : 20,
                          vertical: 14,
                        ),
                        side: BorderSide(color: Colors.brown.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      icon: const Icon(Icons.archive_outlined,
                          color: Colors.brown, size: 20),
                      label: const Text(
                        "Archive",
                        style: TextStyle(
                            color: Colors.brown, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: phone ? 14 : 18),
                Container(
                  height: 1,
                  width: double.infinity,
                  color: Colors.brown.withOpacity(0.15),
                ),
                SizedBox(height: phone ? 16 : 25),
                if (wideToolbar)
                  Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 16),
                      addButton,
                      const SizedBox(width: 12),
                      refreshButton,
                    ],
                  )
                else
                  Column(
                    children: [
                      searchField,
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: addButton),
                          const SizedBox(width: 12),
                          refreshButton,
                        ],
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
                              onDeleted: () =>
                                  setState(() => searchHistory.remove(item)),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                SizedBox(height: phone ? 15 : 25),
                Expanded(child: compact ? cardView : tableView),
              ],
            ),
          );
        },
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