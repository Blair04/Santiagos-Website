import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

class AddFurniture extends StatefulWidget {
  const AddFurniture({super.key});

  @override
  State<AddFurniture> createState() => _AddFurnitureState();
}

class _AddFurnitureState extends State<AddFurniture> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _arUrlController = TextEditingController();
  final _colorController = TextEditingController();

  List<Map<String, dynamic>> _categories = [];
  int _selectedCategoryId = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    _arUrlController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _supabase
          .from('CATEGORY')
          .select('category_id, category_name')
          .order('category_name', ascending: true);

      print('✅ Categories: $response');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['category_id'];
          }
        });
      }
    } catch (e) {
      print('❌ Error loading categories: $e');
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      // show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.brown),
        ),
      );

      try {
        // Step 1: insert into FURNITURE → get back furniture_id
        final furnitureResponse = await _supabase
            .from('FURNITURE')
            .insert({
              'furniture_name': _nameController.text.trim(),
              'description': _descController.text.trim(),
              'price': double.parse(_priceController.text.trim()),
              'category_id': _selectedCategoryId,
              'created_at': DateTime.now().toIso8601String(),
            })
            .select('furniture_id')
            .single();

        print('✅ Furniture inserted: $furnitureResponse');

       // final int newFurnitureId = furnitureResponse['furniture_id'];

        // Step 2: insert into VARIANT using the new furniture_id
        final variantResponse = await _supabase
            .from('VARIANT')
            .insert({
             // 'furniture_id': newFurnitureId,  // FK to FURNITURE
              'color': _colorController.text.trim(),
              'image_url': _imageUrlController.text.trim(),
              'ar_model_url': _arUrlController.text.trim(),
            })
            .select();

        print('✅ Variant inserted: $variantResponse');

        if (mounted) {
          Navigator.pop(context); // close loading
          Navigator.pop(context); // close sheet
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Furniture successfully added!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        print('❌ Error saving: $e');
        if (mounted) {
          Navigator.pop(context); // close loading
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Add New Furniture',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 20),

              // ── FURNITURE table fields ──────────────

              _sectionLabel('Furniture Details'),
              const SizedBox(height: 12),

              // furniture_name
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Product Name'),
                validator: (v) =>
                    v!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),

              // price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('Price')
                    .copyWith(prefixText: '₱ '),
                validator: (v) =>
                    double.tryParse(v!) == null ? 'Invalid price' : null,
              ),
              const SizedBox(height: 12),

              // category_id — from CATEGORY table
              _categories.isEmpty
                  ? const TextField(
                      enabled: false,
                      decoration: InputDecoration(
                        labelText: 'Category (loading...)',
                        border: OutlineInputBorder(),
                      ),
                    )
                  : DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      decoration: _buildInputDecoration('Category'),
                      items: _categories.map((c) {
                        return DropdownMenuItem<int>(
                          value: c['category_id'] as int,
                          child: Text(c['category_name']),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedCategoryId = v);
                        }
                      },
                      validator: (v) =>
                          v == null ? 'Select a category' : null,
                    ),
              const SizedBox(height: 12),

              // description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: _buildInputDecoration('Description'),
              ),
              const SizedBox(height: 20),

              // ── VARIANT table fields ────────────────

              _sectionLabel('Variant Details'),
              const SizedBox(height: 12),

              // color → VARIANT.color
              TextFormField(
                controller: _colorController,
                decoration: _buildInputDecoration('Color'),
                validator: (v) =>
                    v!.isEmpty ? 'Please enter a color' : null,
              ),
              const SizedBox(height: 12),

              // image_url → VARIANT.image_url
              TextFormField(
                controller: _imageUrlController,
                decoration: _buildInputDecoration('Image URL (HTTPS link)'),
                validator: (v) =>
                    v!.isEmpty ? 'Image link is required' : null,
              ),
              const SizedBox(height: 12),

              // ar_model_url → VARIANT.ar_model_url
              TextFormField(
                controller: _arUrlController,
                decoration: _buildInputDecoration('AR Model URL (.glb)'),
                validator: (v) =>
                    v!.isEmpty ? 'AR link is required' : null,
              ),
              const SizedBox(height: 24),

              // save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Save Product',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        color: Colors.grey,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 14, color: Colors.brown),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.brown, width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}