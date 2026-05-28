import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FurnitureCategory {
  final int? id;
  final String name;
  final List<FurnitureProduct> products;

  FurnitureCategory({this.id, required this.name, this.products = const []});

  factory FurnitureCategory.fromMap(Map<String, dynamic> map) {
    return FurnitureCategory(
      id: map['category_id'] as int?,
      name: map['category_name'] as String,
      products: map['FURNITURE'] != null
          ? (map['FURNITURE'] as List).map((p) => FurnitureProduct.fromMap(p)).toList()
          : const [],
    );
  }
}

class FurnitureProduct {
  final int id;
  final String name;
  final double price;

  FurnitureProduct({required this.id, required this.name, required this.price});

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
      final data = await _supabase.from('CATEGORY').select('*, FURNITURE(*)').order('category_name', ascending: true);
      setState(() => _categories = (data as List).map((e) => FurnitureCategory.fromMap(e)).toList());
    } catch (e) {
      _showSnackBar('Error fetching data', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addCategory(String name) async {
    try {
      await _supabase.from('CATEGORY').insert({'category_name': name});
      _showSnackBar('Category "$name" added!');
      await _fetchCategories();
    } catch (e) {
      _showSnackBar('Error adding category', isError: true);
    }
  }

  Future<void> _updateCategory(int id, String name) async {
    try {
      await _supabase.from('CATEGORY').update({'category_name': name}).eq('category_id', id);
      _showSnackBar('Category updated!');
      await _fetchCategories();
    } catch (e) {
      _showSnackBar('Error updating category', isError: true);
    }
  }

  Future<void> _deleteCategory(int id, String name) async {
    if (!await _showConfirmDialog('Delete "$name"?')) return;
    try {
      await _supabase.from('CATEGORY').delete().eq('category_id', id);
      _showSnackBar('Category deleted.');
      await _fetchCategories();
    } catch (e) {
      _showSnackBar('Error deleting category', isError: true);
    }
  }

  List<FurnitureCategory> get _filtered => _searchQuery.isEmpty
      ? _categories
      : _categories.where((c) => c.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: _bg, body: _buildMain());
  }

  Widget _buildMain() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
          child: Row(
            children: [
              const Text('Manage Categories', style: TextStyle(color: _brown, fontSize: 26, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: _white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.add, size: 20),
                label: const Text('Add New Category', style: TextStyle(fontWeight: FontWeight.w600)),
                onPressed: () => _showCategoryDialog(),
              ),
            ],
          ),
        ),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 32), child: Divider(height: 28, color: Color(0xFFD9CEC5))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: TextField(
            controller: _searchController,
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: _textMuted, size: 22),
              hintText: 'Search categories...',
              filled: true,
              fillColor: _white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: _brown.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Text('${_filtered.length} ${_filtered.length == 1 ? 'category' : 'categories'}', style: const TextStyle(color: _brown, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _brown))
                : _filtered.isEmpty
                    ? const Center(child: Text('No categories found.', style: TextStyle(color: _brown, fontSize: 16)))
                    : _buildCategoryList(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildCategoryList() {
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (context, index) {
        final category = _filtered[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF0EBE4))),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: _brown.withOpacity(0.08), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.category_rounded, color: _brownLight, size: 18)),
              title: Text(category.name, style: const TextStyle(color: _brown, fontSize: 15, fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit_note_rounded, color: _brownLight), onPressed: () => _showCategoryDialog(existing: category)),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: () => _deleteCategory(category.id!, category.name)),
                  const Icon(Icons.expand_more_rounded, color: _textMuted),
                ],
              ),
              children: [
                const Divider(height: 1, color: Color(0xFFF0EBE4)),
                Container(
                  width: double.infinity,
                  color: _bg.withOpacity(0.25),
                  padding: const EdgeInsets.all(16),
                  child: category.products.isEmpty
                      ? const Text('No furniture products registered.', style: TextStyle(color: _textMuted, fontSize: 13, fontStyle: FontStyle.italic))
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: category.products.map((product) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: _white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD9CEC5))),
                                child: Text('${product.name} — ₱${product.price.toStringAsFixed(2)}', style: const TextStyle(color: _brown, fontSize: 13, fontWeight: FontWeight.w500)),
                              )).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCategoryDialog({FurnitureCategory? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        title: Text(existing == null ? 'Add New Category' : 'Edit Category', style: const TextStyle(color: _brown, fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            decoration: InputDecoration(hintText: 'Category Name', filled: true, fillColor: _bg, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brown, foregroundColor: _white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              if (existing == null) {
                await _addCategory(nameCtrl.text.trim());
              } else {
                await _updateCategory(existing.id!, nameCtrl.text.trim());
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
            title: Text(title, style: const TextStyle(color: _brown, fontWeight: FontWeight.bold)),
            content: const Text('This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: _textMuted))),
              ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: _white), onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
            ],
          ),
        ) ?? false;
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: isError ? Colors.redAccent : _brown, behavior: SnackBarBehavior.floating));
  }
}