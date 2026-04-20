import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'dart:typed_data';

final _supabase = Supabase.instance.client;

class AddFurniture extends StatefulWidget {
  const AddFurniture({super.key});

  @override
  State<AddFurniture> createState() => _AddFurnitureState();
}

class _AddFurnitureState extends State<AddFurniture> {
  final _formKey = GlobalKey<FormState>();

  // Text Controllers
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _colorController = TextEditingController();

  // Media Data (Using bytes for Web compatibility)
  Uint8List? _imageBytes;
  Uint8List? _modelBytes;
  String? _imageName;
  String? _modelName;
  
  bool _isUploading = false;
  bool _isDragging = false;

  List<Map<String, dynamic>> _categories = [];
  int _selectedCategoryId = 0;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _supabase
          .from('CATEGORY')
          .select('category_id, category_name')
          .order('category_name', ascending: true);

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(response);
          if (_categories.isNotEmpty) {
            _selectedCategoryId = _categories.first['category_id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  // --- PICKER LOGIC ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
      });
    }
  }

  Future<void> _pickModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['glb', 'usdz'],
      withData: true, // Crucial for Web
    );
    if (result != null) {
      setState(() {
        _modelBytes = result.files.single.bytes;
        _modelName = result.files.single.name;
      });
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image and fill all fields.')),
      );
      return;
    }

    setState(() => _isUploading = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.brown)),
    );

    try {
      // 1. Upload to "images" bucket
      final String imageFileName = '${DateTime.now().millisecondsSinceEpoch}_$_imageName';
      await _supabase.storage.from('images').uploadBinary(imageFileName, _imageBytes!);
      final String imageUrl = _supabase.storage.from('images').getPublicUrl(imageFileName);

      // 2. Upload to "3d_models" bucket
      String arUrl = '';
      if (_modelBytes != null) {
        final String modelFileName = '${DateTime.now().millisecondsSinceEpoch}_$_modelName';
        await _supabase.storage.from('3d_models').uploadBinary(modelFileName, _modelBytes!);
        arUrl = _supabase.storage.from('3d_models').getPublicUrl(modelFileName);
      }

      // 3. Insert into FURNITURE
      final furnitureResponse = await _supabase.from('FURNITURE').insert({
        'furniture_name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'category_id': _selectedCategoryId,
        'created_at': DateTime.now().toIso8601String(),
      }).select('furniture_id').single();

      final int newFurnitureId = furnitureResponse['furniture_id'];

      // 4. Insert into VARIANT
      await _supabase.from('VARIANT').insert({
        'furniture_id': newFurnitureId,
        'color': _colorController.text.trim(),
        'image_url': imageUrl,
        'ar_model_url': arUrl,
      });

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.pop(context); // Close sheet
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Product added successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Add New Furniture', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.brown)),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  _buildFilePicker(
                    label: 'Image', 
                    icon: Icons.image, 
                    bytes: _imageBytes, 
                    onTap: _pickImage, 
                    isImage: true,
                    onFileDropped: (bytes, name) => setState(() { _imageBytes = bytes; _imageName = name; }),
                  ),
                  const SizedBox(width: 12),
                  _buildFilePicker(
                    label: '3D Model', 
                    icon: Icons.view_in_ar, 
                    bytes: _modelBytes, 
                    onTap: _pickModel, 
                    isImage: false,
                    onFileDropped: (bytes, name) => setState(() { _modelBytes = bytes; _modelName = name; }),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              TextFormField(controller: _nameController, decoration: _inputDeco('Product Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: _inputDeco('Price').copyWith(prefixText: '₱ '), validator: (v) => double.tryParse(v!) == null ? 'Invalid price' : null),
              const SizedBox(height: 12),
              _categories.isEmpty 
                ? const LinearProgressIndicator(color: Colors.brown)
                : DropdownButtonFormField<int>(
                    value: _selectedCategoryId,
                    decoration: _inputDeco('Category'),
                    items: _categories.map((c) => DropdownMenuItem<int>(value: c['category_id'], child: Text(c['category_name']))).toList(),
                    onChanged: (v) => setState(() => _selectedCategoryId = v!),
                  ),
              const SizedBox(height: 12),
              TextFormField(controller: _colorController, decoration: _inputDeco('Color'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descController, maxLines: 2, decoration: _inputDeco('Description')),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.brown, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Confirm & Save Product', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePicker({
    required String label, 
    required IconData icon, 
    Uint8List? bytes, 
    required VoidCallback onTap, 
    required bool isImage,
    required Function(Uint8List, String) onFileDropped,
  }) {
    return Expanded(
      child: DropTarget(
        onDragDone: (detail) async {
          if (detail.files.isNotEmpty) {
            final fileBytes = await detail.files.first.readAsBytes();
            onFileDropped(fileBytes, detail.files.first.name);
          }
        },
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              color: _isDragging ? Colors.brown.withOpacity(0.1) : Colors.brown.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: bytes != null ? Colors.green : (_isDragging ? Colors.brown : Colors.brown.withOpacity(0.2)),
                width: _isDragging ? 2 : 1,
              ),
            ),
            child: bytes != null
                ? (isImage 
                    ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, fit: BoxFit.cover))
                    : const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, color: Colors.green), Text('3D Model Ready', style: TextStyle(fontSize: 12))]))
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.brown), Text(label, style: const TextStyle(fontSize: 12))]),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.brown, fontSize: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.brown, width: 2)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12));
}