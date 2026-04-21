//import 'dart:typed_material.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

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

  // Media Data
  Uint8List? _imageBytes;
  Uint8List? _modelBytes;
  String? _imageName;
  String? _modelName;
  
  bool _isUploading = false;
  
  // SEPARATE HIGHLIGHT STATES
  bool _isDraggingImage = false;
  bool _isDraggingModel = false;
  
  bool _linkToExisting = false; 

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _existingFurniture = [];
  int? _selectedCategoryId;
  int? _selectedFurnitureId;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final catRes = await _supabase.from('CATEGORY').select('category_id, category_name').order('category_name');
      final furnRes = await _supabase.from('FURNITURE').select('furniture_id, furniture_name').order('furniture_name');

      if (mounted) {
        setState(() {
          _categories = List<Map<String, dynamic>>.from(catRes);
          _existingFurniture = List<Map<String, dynamic>>.from(furnRes);
          if (_categories.isNotEmpty) _selectedCategoryId = _categories.first['category_id'];
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    }
  }

  // --- PICKER LOGIC ---
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() { _imageBytes = bytes; _imageName = pickedFile.name; });
    }
  }

  Future<void> _pickModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['glb', 'usdz', 'zip'], withData: true);
    if (result != null) {
      setState(() { _modelBytes = result.files.single.bytes; _modelName = result.files.single.name; });
    }
  }

  // --- SAVE LOGIC ---
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate() || _imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check your inputs and image.')));
      return;
    }

    if (_linkToExisting && _selectedFurnitureId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an existing furniture item.')));
      return;
    }

    setState(() => _isUploading = true);
    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.brown)));

    try {
      final String imageFileName = '${DateTime.now().millisecondsSinceEpoch}_${_imageName ?? 'img.png'}';
      await _supabase.storage.from('images').uploadBinary(imageFileName, _imageBytes!);
      final String imageUrl = _supabase.storage.from('images').getPublicUrl(imageFileName);

      String arUrl = '';
      if (_modelBytes != null) {
        final String modelFileName = '${DateTime.now().millisecondsSinceEpoch}.${_modelName?.split('.').last ?? 'glb'}';
        await _supabase.storage.from('3d_models').uploadBinary(modelFileName, _modelBytes!);
        arUrl = _supabase.storage.from('3d_models').getPublicUrl(modelFileName);
      }

      int targetFurnitureId;

      if (!_linkToExisting) { 
        final res = await _supabase.from('FURNITURE').insert({
          'furniture_name': _nameController.text.trim(),
          'description': _descController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'category_id': _selectedCategoryId,
        }).select('furniture_id').single();
        targetFurnitureId = res['furniture_id'];
      } else { 
        targetFurnitureId = _selectedFurnitureId!;
      }

      await _supabase.from('VARIANT').insert({
        'furniture_id': targetFurnitureId,
        'color': _colorController.text.trim(),
        'image_url': imageUrl,
        'ar_model_url': arUrl,
      });

      if (mounted) {
        Navigator.pop(context); 
        Navigator.pop(context); 
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Product successfully saved!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
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
              const Text('Add New Product', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.brown)),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  _buildFilePicker(
                    label: 'Image', 
                    icon: Icons.image, 
                    bytes: _imageBytes, 
                    onTap: _pickImage, 
                    isImage: true, 
                    isHighlighted: _isDraggingImage,
                    onDragEntered: () => setState(() => _isDraggingImage = true),
                    onDragExited: () => setState(() => _isDraggingImage = false),
                    onFileDropped: (b, n) => setState(() { _imageBytes = b; _imageName = n; _isDraggingImage = false; })
                  ),
                  const SizedBox(width: 12),
                  _buildFilePicker(
                    label: '3D Model', 
                    icon: Icons.view_in_ar, 
                    bytes: _modelBytes, 
                    onTap: _pickModel, 
                    isImage: false, 
                    isHighlighted: _isDraggingModel,
                    onDragEntered: () => setState(() => _isDraggingModel = true),
                    onDragExited: () => setState(() => _isDraggingModel = false),
                    onFileDropped: (b, n) => setState(() { _modelBytes = b; _modelName = n; _isDraggingModel = false; })
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.brown.withOpacity(0.1)),
                ),
                child: CheckboxListTile(
                  title: const Text('Add to existing furniture?', style: TextStyle(color: Colors.brown, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Check this if you are only adding a new color/variant.', style: TextStyle(fontSize: 11)),
                  value: _linkToExisting,
                  activeColor: Colors.brown,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setState(() => _linkToExisting = val ?? false),
                ),
              ),
              
              const SizedBox(height: 20),

              if (_linkToExisting) ...[
                DropdownButtonFormField<int>(
                  value: _selectedFurnitureId,
                  isExpanded: true,
                  decoration: _inputDeco('Select Existing Furniture'),
                  items: _existingFurniture.map((f) => DropdownMenuItem<int>(value: f['furniture_id'], child: Text(f['furniture_name']))).toList(),
                  onChanged: (v) => setState(() => _selectedFurnitureId = v),
                ),
              ] else ...[
                TextFormField(controller: _nameController, decoration: _inputDeco('Product Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: _inputDeco('Price').copyWith(prefixText: '₱ '), validator: (v) => double.tryParse(v!) == null ? 'Invalid' : null),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: _inputDeco('Category'),
                        items: _categories.map((c) => DropdownMenuItem<int>(value: c['category_id'], child: Text(c['category_name']))).toList(),
                        onChanged: (v) => setState(() => _selectedCategoryId = v!),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              TextFormField(controller: _colorController, decoration: _inputDeco('Variant/Color (e.g. Natural Oak)'), validator: (v) => v!.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              if (!_linkToExisting) TextFormField(controller: _descController, maxLines: 2, decoration: _inputDeco('Description')),
              
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _saveProduct,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown, 
                    foregroundColor: Colors.white, 
                    padding: const EdgeInsets.symmetric(vertical: 16), 
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                  ),
                  child: Text(
                    _linkToExisting ? 'Confirm & Add Variant' : 'Add New Product', 
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- REUSED HELPERS ---
  Widget _buildFilePicker({
    required String label, 
    required IconData icon, 
    Uint8List? bytes, 
    required VoidCallback onTap, 
    required bool isImage, 
    required bool isHighlighted,
    required VoidCallback onDragEntered,
    required VoidCallback onDragExited,
    required Function(Uint8List, String) onFileDropped
  }) {
    return Expanded(
      child: DropTarget(
        onDragDone: (detail) async {
          if (detail.files.isNotEmpty) {
            final b = await detail.files.first.readAsBytes();
            onFileDropped(b, detail.files.first.name);
          }
        },
        onDragEntered: (_) => onDragEntered(),
        onDragExited: (_) => onDragExited(),
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 100,
            decoration: BoxDecoration(
              // Highlight: Darker brown background and thick border when dragging
              color: isHighlighted ? Colors.brown.withOpacity(0.2) : Colors.brown.withOpacity(0.05), 
              borderRadius: BorderRadius.circular(10), 
              border: Border.all(
                color: isHighlighted ? Colors.brown : (bytes != null ? Colors.green : Colors.brown.withOpacity(0.15)),
                width: isHighlighted ? 2.5 : 1.0,
              )
            ),
            child: bytes != null && !isHighlighted
              ? (isImage ? ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, fit: BoxFit.cover)) : const Icon(Icons.check_circle, color: Colors.green))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center, 
                  children: [
                    Icon(
                      isHighlighted ? Icons.file_upload : icon, 
                      color: isHighlighted ? Colors.brown : Colors.brown.withOpacity(0.6)
                    ), 
                    Text(
                      isHighlighted ? 'Drop File' : label, 
                      style: TextStyle(fontSize: 12, fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal)
                    )
                  ]
                ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) => InputDecoration(
    labelText: label, 
    labelStyle: const TextStyle(color: Colors.brown, fontSize: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)), 
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.brown, width: 2)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
  );
}