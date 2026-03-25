import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // 1. ADD THIS IMPORT

// 2. DATA MODEL (Matches your uploaded Schema)
class Furniture {
  final String name;
  final String description;
  final double price;
  final String category;
  final String arModelUrl;

  Furniture({
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.arModelUrl,
  });

  // Map keys MUST match your Supabase column names exactly
  Map<String, dynamic> toMap() {
    return {
      'furniture_name': name,
      'description': description,
      'price': price,
      'category': category,
      'ar_model_url': arModelUrl,
      // 'created_at' is usually handled automatically by Supabase
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
  final _stockController = TextEditingController();
  final _arUrlController = TextEditingController();

  String _selectedCategory = 'Chair';
  final List<String> _categories = ['Chair', 'Table', 'Sofa', 'Bed', 'Cabinet'];

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _stockController.dispose();
    _arUrlController.dispose();
    super.dispose();
  }

  // 3. UPDATED SAVE FUNCTION FOR SUPABASE
  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      // Show loading indicator (Crucial for Web UX)
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
          arModelUrl: _arUrlController.text,
        );

        // INSERT DATA INTO SUPABASE
        // 'furniture' is the table name you created in Supabase
        await Supabase.instance.client
            .from('FURNITURE')
            .insert(newProduct.toMap());

        if (mounted) {
          Navigator.pop(context); // Close loading dialog
          Navigator.pop(context); // Close the AddFurniture sheet
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product successfully saved to Supabase!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading dialog
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
                'Add New Product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown,
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration('Product Name'),
                validator: (v) => v!.isEmpty ? 'Enter name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('Price').copyWith(prefixText: '₱ '),
                validator: (v) => double.tryParse(v!) == null ? 'Invalid price' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: _buildInputDecoration('Category'),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _arUrlController,
                decoration: _buildInputDecoration('AR Model URL (.glb)'),
                validator: (v) => v!.isEmpty ? 'AR link is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: _buildInputDecoration('Description').copyWith(alignLabelWithHint: true),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProduct, // Calls the async function above
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Save Product', style: TextStyle(fontSize: 16)),
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
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    );
  }
}