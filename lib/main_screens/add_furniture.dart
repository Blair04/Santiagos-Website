import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:desktop_drop/desktop_drop.dart';

final _supabase = Supabase.instance.client;

class AddFurniture extends StatefulWidget {
  final Map<String, dynamic>? editProduct;

  const AddFurniture({super.key, this.editProduct});

  @override
  State<AddFurniture> createState() => _AddFurnitureState();
}

class _AddFurnitureState extends State<AddFurniture> {
  final _formKey = GlobalKey<FormState>();

  static const TextStyle _fieldStyle = TextStyle(fontSize: 14, color: Colors.black87);

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descController = TextEditingController();
  final _colorController = TextEditingController();
  final _stockController = TextEditingController();

  Uint8List? _imageBytes;
  Uint8List? _modelBytes;
  String? _imageName;
  String? _modelName;

  String? _existingImageUrl;
  String? _existingModelUrl;

  bool _isUploading = false;
  bool _isDraggingImage = false;
  bool _isDraggingModel = false;

  bool _imageError = false;

  bool _linkToExisting = false;

  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _existingFurniture = [];
  int? _selectedCategoryId;
  int? _selectedFurnitureId;

  bool get _isEditing => widget.editProduct != null;

  bool get _hasImage =>
      _imageBytes != null ||
      (_existingImageUrl != null && _existingImageUrl!.isNotEmpty);

  double get _screenWidth => MediaQuery.of(context).size.width;
  bool get _isTablet => _screenWidth >= 600;
  bool get _isDesktop => _screenWidth >= 1024;

  double get _contentMaxWidth => _isDesktop ? 760 : (_isTablet ? 640 : double.infinity);
  double get _horizontalPadding => _isDesktop ? 40 : (_isTablet ? 32 : 20);
  double get _pickerHeight => _isDesktop ? 150 : (_isTablet ? 130 : 100);
  double get _pickerIconSize => _isDesktop ? 34 : (_isTablet ? 30 : 24);
  double get _pickerLabelSize => _isDesktop ? 14 : (_isTablet ? 13 : 12);
  double get _titleSize => _isDesktop ? 28 : (_isTablet ? 25 : 22);
  double get _gap => _isDesktop ? 20 : (_isTablet ? 16 : 12);
  double get _sectionGap => _isDesktop ? 32 : (_isTablet ? 28 : 24);

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _checkEditMode();
  }

  void _checkEditMode() {
    if (_isEditing) {
      final p = widget.editProduct!;
      _nameController.text = p['furniture_name'] ?? '';
      _priceController.text = p['price']?.toString() ?? '';
      _descController.text = p['description'] ?? '';
      _stockController.text = p['stock']?.toString() ?? '0';
      _colorController.text = p['color'] ?? '';
      _selectedCategoryId = p['category_id'];
      _existingImageUrl = p['image_url'];
      _existingModelUrl = p['ar_model_url'];
      _loadVariantDetails();
    }
  }

  Future<void> _loadVariantDetails() async {
    final variantId = widget.editProduct!['variant_id'];
    if (variantId == null) return;
    try {
      final v = await _supabase
          .from('VARIANT')
          .select('stock, description')
          .eq('variant_id', variantId)
          .maybeSingle();
      if (v != null && mounted) {
        setState(() {
          if (v['stock'] != null) _stockController.text = v['stock'].toString();
          if (v['description'] != null) _descController.text = v['description'];
        });
      }
    } catch (e) {
      debugPrint('Error loading variant details: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    _colorController.dispose();
    _stockController.dispose();
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

          if (_categories.isNotEmpty && _selectedCategoryId == null) {
            _selectedCategoryId = _categories.first['category_id'];
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading initial data: $e');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageName = pickedFile.name;
        _imageError = false;
      });
    }
  }

  Future<void> _pickModel() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['glb', 'usdz', 'zip'], withData: true);
    if (result != null) {
      setState(() { _modelBytes = result.files.single.bytes; _modelName = result.files.single.name; });
    }
  }

  void _removeImage() {
    setState(() {
      _imageBytes = null;
      _imageName = null;
      _existingImageUrl = null;
    });
  }

  void _removeModel() {
    setState(() {
      _modelBytes = null;
      _modelName = null;
      _existingModelUrl = null;
    });
  }

  Future<void> _saveProduct() async {
    final bool formValid = _formKey.currentState!.validate();
    final bool imageMissing = !_hasImage;
    setState(() => _imageError = imageMissing);

    if (!formValid || imageMissing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please check your inputs and selected image.')));
      return;
    }

    if (!_isEditing && _linkToExisting && _selectedFurnitureId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an existing furniture item.')));
      return;
    }

    setState(() => _isUploading = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.brown)),
    );

    try {
      final String uniqueTimestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String namingReference = _nameController.text.trim();

      if (!_isEditing && _linkToExisting && _selectedFurnitureId != null) {
        final match = _existingFurniture.firstWhere((f) => f['furniture_id'] == _selectedFurnitureId, orElse: () => {});
        if (match.isNotEmpty) {
          namingReference = match['furniture_name'] ?? 'furniture';
        }
      }

      final String cleanBaseName = namingReference.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      final String baseFileName = '${uniqueTimestamp}_$cleanBaseName';

      String imageUrl = _existingImageUrl ?? '';
      if (_imageBytes != null) {
        final String imgExt = _imageName?.split('.').last ?? 'png';
        final String imageFileName = '$baseFileName.$imgExt';

        await _supabase.storage.from('images').uploadBinary(imageFileName, _imageBytes!);
        imageUrl = _supabase.storage.from('images').getPublicUrl(imageFileName);
      }

      String arUrl = _existingModelUrl ?? '';
      if (_modelBytes != null) {
        final String modelExt = _modelName?.split('.').last ?? 'glb';
        final String modelFileName = '$baseFileName.$modelExt';

        await _supabase.storage.from('3d_models').uploadBinary(modelFileName, _modelBytes!);
        arUrl = _supabase.storage.from('3d_models').getPublicUrl(modelFileName);
      }

      final int variantStock = int.parse(_stockController.text.trim());
      final String variantDesc = _descController.text.trim();

      if (_isEditing) {
        final furnitureId = widget.editProduct!['furniture_id'];
        final variantId = widget.editProduct!['variant_id'];

        await _supabase.from('FURNITURE').update({
          'furniture_name': _nameController.text.trim(),
          'price': double.parse(_priceController.text.trim()),
          'category_id': _selectedCategoryId,
        }).eq('furniture_id', furnitureId);

        await _supabase.from('VARIANT').update({
          'color': _colorController.text.trim(),
          'image_url': imageUrl,
          'ar_model_url': arUrl,
          'stock': variantStock,
          'description': variantDesc,
        }).eq('variant_id', variantId);

      } else {
        int targetFurnitureId;

        if (!_linkToExisting) {
          final res = await _supabase.from('FURNITURE').insert({
            'furniture_name': _nameController.text.trim(),
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
          'stock': variantStock,
          'description': variantDesc,
          'is_archived': false,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_isEditing ? 'Product successfully updated!' : 'Product successfully saved!'),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Align(
      alignment: Alignment.topCenter,
      heightFactor: 1.0,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(_horizontalPadding, 16, _horizontalPadding, bottomInset + 20),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),

                  Text(_isEditing ? 'Edit Product' : 'Add New Product', style: TextStyle(fontSize: _titleSize, fontWeight: FontWeight.bold, color: Colors.brown)),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      _buildFilePicker(
                        label: 'Image',
                        icon: Icons.image,
                        bytes: _imageBytes,
                        networkUrl: _existingImageUrl,
                        onTap: _pickImage,
                        onRemove: _removeImage,
                        isImage: true,
                        isHighlighted: _isDraggingImage,
                        hasError: _imageError,
                        onDragEntered: () => setState(() => _isDraggingImage = true),
                        onDragExited: () => setState(() => _isDraggingImage = false),
                        onFileDropped: (b, n) => setState(() {
                          _imageBytes = b;
                          _imageName = n;
                          _isDraggingImage = false;
                          _imageError = false;
                        })
                      ),
                      SizedBox(width: _gap),
                      _buildFilePicker(
                        label: '3D Model',
                        icon: Icons.view_in_ar,
                        bytes: _modelBytes,
                        networkUrl: _existingModelUrl,
                        onTap: _pickModel,
                        onRemove: _removeModel,
                        isImage: false,
                        isHighlighted: _isDraggingModel,
                        onDragEntered: () => setState(() => _isDraggingModel = true),
                        onDragExited: () => setState(() => _isDraggingModel = false),
                        onFileDropped: (b, n) => setState(() { _modelBytes = b; _modelName = n; _isDraggingModel = false; })
                      ),
                    ],
                  ),

                  SizedBox(height: _sectionGap),

                  if (!_isEditing) ...[
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
                  ],

                  if (!_isEditing && _linkToExisting) ...[
                    DropdownButtonFormField<int>(
                      value: _selectedFurnitureId,
                      isExpanded: true,
                      style: _fieldStyle,
                      decoration: _inputDeco('Select Existing Furniture'),
                      items: _existingFurniture.map((f) => DropdownMenuItem<int>(value: f['furniture_id'], child: Text(f['furniture_name'], style: _fieldStyle))).toList(),
                      onChanged: (v) => setState(() => _selectedFurnitureId = v),
                    ),
                  ] else ...[
                    TextFormField(controller: _nameController, style: _fieldStyle, decoration: _inputDeco('Product Name'), validator: (v) => v!.isEmpty ? 'Required' : null),
                    SizedBox(height: _gap),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            style: _fieldStyle,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              TextInputFormatter.withFunction((oldValue, newValue) {
                                if (newValue.text.isEmpty) return newValue;
                                final isValid = RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text);
                                return isValid ? newValue : oldValue;
                              }),
                            ],
                            decoration: _inputDeco('Price').copyWith(prefixText: '₱ ', prefixStyle: _fieldStyle),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              final price = double.tryParse(v.trim());
                              if (price == null) return 'Invalid price';
                              if (price <= 0) return 'Must be greater than 0';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: _gap),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: _selectedCategoryId,
                            isExpanded: true,
                            style: _fieldStyle,
                            decoration: _inputDeco('Category'),
                            items: _categories.map((c) => DropdownMenuItem<int>(value: c['category_id'], child: Text(c['category_name'], style: _fieldStyle))).toList(),
                            onChanged: (v) => setState(() => _selectedCategoryId = v!),
                          ),
                        ),
                      ],
                    ),
                  ],

                  SizedBox(height: _gap),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _colorController,
                          style: _fieldStyle,
                          decoration: _inputDeco('Variant/Color (e.g. Natural Oak)'),
                          validator: (v) => v!.isEmpty ? 'Required' : null
                        ),
                      ),
                      SizedBox(width: _gap),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _stockController,
                          style: _fieldStyle,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: _inputDeco('Stock Qty'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final stock = int.tryParse(v);
                            if (stock == null) return 'Invalid integer';
                            if (stock <= 0) return 'Must be at least 1';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: _gap),
                  TextFormField(controller: _descController, style: _fieldStyle, maxLines: _isTablet ? 3 : 2, decoration: _inputDeco('Description')),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _saveProduct,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: _isTablet ? 18 : 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      child: Text(
                        _isEditing
                            ? 'Update Product'
                            : (_linkToExisting ? 'Confirm & Add Variant' : 'Add New Product'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilePicker({
    required String label,
    required IconData icon,
    Uint8List? bytes,
    String? networkUrl,
    required VoidCallback onTap,
    required VoidCallback onRemove,
    required bool isImage,
    required bool isHighlighted,
    bool hasError = false,
    required VoidCallback onDragEntered,
    required VoidCallback onDragExited,
    required Function(Uint8List, String) onFileDropped
  }) {
    final hasAsset = bytes != null || (networkUrl != null && networkUrl.isNotEmpty && networkUrl.startsWith('http'));
    final showError = hasError && !hasAsset && !isHighlighted;

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
            height: _pickerHeight,
            decoration: BoxDecoration(
              color: isHighlighted ? Colors.brown.withOpacity(0.2) : Colors.brown.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: showError
                    ? Colors.red
                    : (isHighlighted ? Colors.brown : (hasAsset ? Colors.green : Colors.brown.withOpacity(0.15))),
                width: (isHighlighted || showError) ? 2.5 : 1.0,
              )
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasAsset && !isHighlighted
                    ? (isImage
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: bytes != null
                                ? Image.memory(bytes, fit: BoxFit.cover)
                                : Image.network(networkUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.grey))
                          )
                        : Center(child: Icon(Icons.check_circle, color: Colors.green, size: _pickerIconSize)))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isHighlighted ? Icons.file_upload : icon,
                            size: _pickerIconSize,
                            color: showError
                                ? Colors.red
                                : (isHighlighted ? Colors.brown : Colors.brown.withOpacity(0.6))
                          ),
                          Text(
                            isHighlighted ? 'Drop File' : label,
                            style: TextStyle(
                              fontSize: _pickerLabelSize,
                              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                              color: showError ? Colors.red : null,
                            )
                          )
                        ]
                      ),
                ),
                if (hasAsset && !isHighlighted)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, size: _isTablet ? 18 : 16, color: Colors.white),
                      ),
                    ),
                  ),
              ],
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
    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: _isTablet ? 14 : 12)
  );
}