import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class Furniture {
  final String name;
  final String description;
  final double price;
  final String category;
  final String color;
  final String imageUrl;
  final String arModelUrl;

  Furniture({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.color,
    required this.imageUrl,
    required this.arModelUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'furniture_name': name,
      'description': description,
      'price': price,
      'category': category,
      'color': color,
      'image_url': imageUrl,
      'ar_model_url': arModelUrl,
    };
  }
}

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

  String _selectedCategory = 'Chair';
  final List<String> _categories = ['Chair', 'Table', 'Sofa', 'Bed', 'Cabinet'];

  String _selectedColor = 'Oak';
  final List<String> _colors = ['Oak', 'Walnut', 'White', 'Black', 'Grey', 'Beige', 'Mahogany'];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _imageUrlController.dispose();
    _arUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Colors.brown),
        ),
      );

      try {
        final newProduct = Furniture(
          name: _nameController.text,
          description: _descController.text,
          price: double.parse(_priceController.text),
          category: _selectedCategory,
          color: _selectedColor,
          imageUrl: _imageUrlController.text,
          arModelUrl: _arUrlController.text,
        );

        // Insert into the furniture table
        await Supabase.instance.client
            .from('FURNITURE')
            .insert(newProduct.toMap());

        if (mounted) {
          Navigator.pop(context); 
          Navigator.pop(context); 
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Furniture successfully added to the catalog!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); 
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

              // Product Name
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Product Name'),
                validator: (v) => v!.isEmpty ? 'Please enter a name' : null,
              ),
              const SizedBox(height: 12),

              // Price
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('Price').copyWith(prefixText: '₱ '),
                validator: (v) => double.tryParse(v!) == null ? 'Invalid price' : null,
              ),
              const SizedBox(height: 12),

              // Category and Color Dropdown
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: _buildInputDecoration('Category'),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedColor,
                      decoration: _buildInputDecoration('Color'),
                      items: _colors.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedColor = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Image URL
              TextFormField(
                controller: _imageUrlController,
                decoration: _buildInputDecoration('Image URL (HTTPS link)'),
                validator: (v) => v!.isEmpty ? 'Image link is required' : null,
              ),
              const SizedBox(height: 12),

              // AR Model URL
              TextFormField(
                controller: _arUrlController,
                decoration: _buildInputDecoration('AR Model URL (.glb)'),
                validator: (v) => v!.isEmpty ? 'AR link is required' : null,
              ),
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: _buildInputDecoration('Description'),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Save Product',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}