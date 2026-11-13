import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FurnitureCategory {
  final int? id;
  final String name;
  final List<FurnitureProduct> products;

  FurnitureCategory({
    this.id,
    required this.name,
    this.products = const [],
  });

  factory FurnitureCategory.fromMap(Map<String, dynamic> map) {
    return FurnitureCategory(
      id: map['category_id'] as int?,
      name: map['category_name'] as String,
      // Only show products that are NOT archived
      products: map['FURNITURE'] != null
          ? (map['FURNITURE'] as List)
              .where((p) => p['is_archived'] != true)
              .map((p) => FurnitureProduct.fromMap(p))
              .toList()
          : const [],
    );
  }
}

class FurnitureProduct {
  final int id;
  final String name;
  final double price;

  FurnitureProduct({
    required this.id,
    required this.name,
    required this.price,
  });

  factory FurnitureProduct.fromMap(Map<String, dynamic> map) {
    return FurnitureProduct(
      id: map['furniture_id'] as int,
      name: map['furniture_name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }
}

class ManageCategoryScreen extends StatefulWidget {
  const ManageCategoryScreen({super.key});

  @override
  State<ManageCategoryScreen> createState() => _ManageCategoryScreenState();
}

class _ManageCategoryScreenState extends State<ManageCategoryScreen> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();

  List<FurnitureCategory> _categories = [];
  bool _isLoading = true;
  String _searchQuery = '';
  int _currentPage = 0;
  static const int _itemsPerPage = 6;

  static const _bg = Color(0xFFF5EFE6);
  static const _brown = Color(0xFF5C3D2E);
  static const _brownLight = Color(0xFF8B6355);
  static const _white = Colors.white;
  static const _textMuted = Color(0xFF9E8878);

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('CATEGORY')
          .select('*, FURNITURE(*)')
          .order('category_name', ascending: true);

      setState(() {
        _categories = (data as List)
            .map((e) => FurnitureCategory.fromMap(e))
            .toList();
      });
    } catch (e) {
      _showSnackBar(
        'Error fetching data',
        isError: true,
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Checks if a category name already exists (case-insensitive, ignores
  // extra spaces). Use excludeId when editing so it doesn't clash with itself.
  bool _categoryExists(String name, {int? excludeId}) {
    final normalized = name.trim().toLowerCase();

    return _categories.any(
      (c) =>
          c.name.trim().toLowerCase() == normalized && c.id != excludeId,
    );
  }

  Future<void> _addCategory(String name) async {
    if (_categoryExists(name)) {
      _showSnackBar('Category "$name" already exists', isError: true);
      return;
    }

    try {
      await _supabase.from('CATEGORY').insert({
        'category_name': name,
      });

      _showSnackBar('Category "$name" added!');
      await _fetchCategories();
    } on PostgrestException catch (e) {
      _showSnackBar(
        e.code == '23505'
            ? 'Category "$name" already exists'
            : 'Error adding category',
        isError: true,
      );
    } catch (e) {
      _showSnackBar(
        'Error adding category',
        isError: true,
      );
    }
  }

  Future<void> _updateCategory(int id, String name) async {
    if (_categoryExists(name, excludeId: id)) {
      _showSnackBar('Category "$name" already exists', isError: true);
      return;
    }

    try {
      await _supabase
          .from('CATEGORY')
          .update({
            'category_name': name,
          })
          .eq('category_id', id);

      _showSnackBar('Category updated!');
      await _fetchCategories();
    } on PostgrestException catch (e) {
      _showSnackBar(
        e.code == '23505'
            ? 'Category "$name" already exists'
            : 'Error updating category',
        isError: true,
      );
    } catch (e) {
      _showSnackBar(
        'Error updating category',
        isError: true,
      );
    }
  }

  Future<void> _deleteCategory(int id, String name) async {
    if (!await _showConfirmDialog('Delete "$name"?')) return;

    try {
      await _supabase
          .from('CATEGORY')
          .delete()
          .eq('category_id', id);

      _showSnackBar('Category deleted.');
      await _fetchCategories();
    } catch (e) {
      _showSnackBar(
        'Cannot delete category "$name". It may have associated products.',
        isError: true,
      );
    }
  }

  List<FurnitureCategory> get _filtered => _searchQuery.isEmpty
      ? _categories
      : _categories
          .where(
            (c) => c.name
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()),
          )
          .toList();

  int get _pageCount =>
      (_filtered.length / _itemsPerPage).ceil().clamp(1, 999999).toInt();

  List<FurnitureCategory> get _pageCategories {
    final start = _currentPage * _itemsPerPage;
    if (start >= _filtered.length) return const [];
    final end = (start + _itemsPerPage).clamp(0, _filtered.length).toInt();
    return _filtered.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6F0),
      body: _buildMain(),
    );
  }

  Widget _buildMain() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(30, 24, 30, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manage Categories',
              style: TextStyle(
                color: _brown,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 14, bottom: 14),
              child: Divider(height: 1, color: Color(0xFFD9CEC5)),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final search = SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() {
                      _searchQuery = v;
                      _currentPage = 0;
                    }),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, color: _brown),
                      hintText: 'Search Category...',
                      hintStyle: const TextStyle(color: Color(0xFF82766F)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: Color(0xFFE2DAD3)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: Color(0xFFE2DAD3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: _brownLight),
                      ),
                    ),
                  ),
                );
                final addButton = SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: () => _showCategoryDialog(),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _brown,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 19),
                    label: const Text(
                      'Add New Category',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      search,
                      const SizedBox(height: 10),
                      Align(alignment: Alignment.centerRight, child: addButton),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: search),
                    const SizedBox(width: 16),
                    addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFECE3DC),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_filtered.length} ${_filtered.length == 1 ? 'category' : 'categories'}',
                style: const TextStyle(
                  color: _brown,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _brown),
                    )
                  : _filtered.isEmpty
                      ? const Center(
                          child: Text(
                            'No categories found.',
                            style: TextStyle(color: _brown, fontSize: 16),
                          ),
                        )
                      : _buildCategoryList(),
            ),
            if (!_isLoading && _filtered.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildPagination(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryList() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050 ? 3 : width >= 650 ? 2 : 1;
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 8, right: 2, left: 2, top: 1),
          itemCount: _pageCategories.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 18,
            mainAxisSpacing: 18,
            mainAxisExtent: 255,
          ),
          itemBuilder: (context, index) {
            final category = _pageCategories[index];
            return Material(
              color: Colors.white,
              elevation: 2.5,
              shadowColor: Colors.black.withOpacity(0.16),
              borderRadius: BorderRadius.circular(17),
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () => _showProductsDialog(category),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE9E0D9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _categoryIcon(category.name),
                          color: _brownLight,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF2F1B14),
                          fontSize: 27,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${category.products.length} ${category.products.length == 1 ? 'Item' : 'Items'}',
                        style: const TextStyle(
                          color: Color(0xFF2F1B14),
                          fontSize: 17,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            tooltip: 'Edit category',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _showCategoryDialog(existing: category),
                            icon: const Icon(
                              Icons.edit,
                              color: Color(0xFF999491),
                              size: 25,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete category',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _deleteCategory(
                              category.id!,
                              category.name,
                            ),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Color(0xFF999491),
                              size: 26,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPagination() {
    final pageCount = _pageCount;
    final firstPage = (_currentPage - 1).clamp(0, pageCount - 1).toInt();
    final lastPage = (_currentPage + 1).clamp(0, pageCount - 1).toInt();
    final visiblePages = <int>{};
    for (var page = firstPage; page <= lastPage; page++) {
      visiblePages.add(page);
    }
    if (pageCount > 3) {
      if (_currentPage == 0) visiblePages.add(2);
      if (_currentPage == pageCount - 1) visiblePages.add(pageCount - 3);
    }
    final pages = visiblePages.toList()..sort();

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          tooltip: 'Previous page',
          onPressed: _currentPage > 0
              ? () => setState(() => _currentPage--)
              : null,
          icon: const Icon(Icons.chevron_left, color: _brown),
        ),
        ...pages.map(
          (page) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(7),
              onTap: () => setState(() => _currentPage = page),
              child: Container(
                width: 32,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: page == _currentPage ? _brown : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '${page + 1}',
                  style: TextStyle(
                    color: page == _currentPage ? Colors.white : _brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: _currentPage < pageCount - 1
              ? () => setState(() => _currentPage++)
              : null,
          icon: const Icon(Icons.chevron_right, color: _brown),
        ),
      ],
    );
  }

  IconData _categoryIcon(String name) {
    final value = name.toLowerCase();
    if (value.contains('bed')) return Icons.bed;
    if (value.contains('cabinet') || value.contains('wardrobe')) {
      return Icons.door_sliding;
    }
    if (value.contains('chair')) return Icons.chair;
    if (value.contains('sofa') || value.contains('couch')) {
      return Icons.weekend;
    }
    if (value.contains('table')) return Icons.table_restaurant;
    return Icons.category;
  }

  void _showProductsDialog(FurnitureCategory category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          category.name,
          style: const TextStyle(color: _brown, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: category.products.isEmpty
              ? const Text(
                  'No furniture products registered.',
                  style: TextStyle(color: _textMuted),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: category.products.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Color(0xFFF0EBE4)),
                  itemBuilder: (context, index) {
                    final product = category.products[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        product.name,
                        style: const TextStyle(color: _brown),
                      ),
                      trailing: Text(
                        '₱${product.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: _brown,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close', style: TextStyle(color: _brown)),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog({
    FurnitureCategory? existing,
  }) {
    final nameCtrl = TextEditingController(
      text: existing?.name ?? '',
    );

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        title: Text(
          existing == null ? 'Add New Category' : 'Edit Category',
          style: const TextStyle(
            color: _brown,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Required';
              }
              if (_categoryExists(v, excludeId: existing?.id)) {
                return 'Category already exists';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: 'Category Name',
              filled: true,
              fillColor: _bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _textMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _brown,
              foregroundColor: _white,
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) {
                return;
              }

              Navigator.pop(ctx);

              if (existing == null) {
                await _addCategory(
                  nameCtrl.text.trim(),
                );
              } else {
                await _updateCategory(
                  existing.id!,
                  nameCtrl.text.trim(),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmDialog(String title) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              title,
              style: const TextStyle(
                color: _brown,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: const Text(
              'This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: _textMuted,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: _white,
                ),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showSnackBar(
    String msg, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent : _brown,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}