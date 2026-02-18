import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/services/menu_service.dart';
import 'package:caribtap/models/menu_models.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';

class MenuItemEditorScreen extends StatefulWidget {
  final ListingModel listing;
  final MenuItem? item;
  final String currencyCode;

  const MenuItemEditorScreen({
    Key? key,
    required this.listing,
    this.item,
    required this.currencyCode,
  }) : super(key: key);

  @override
  State<MenuItemEditorScreen> createState() => _MenuItemEditorScreenState();
}

class _MenuItemEditorScreenState extends State<MenuItemEditorScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late String _currencyCode;
  late bool _isAvailable;
  late List<MenuItemPhoto> _photos;
  late List<File> _newPhotoFiles;
  late List<String> _tags;
  
  final MenuService _menuService = MenuService();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(text: item?.price.toString() ?? '');
    _currencyCode = item?.currencyCode ?? widget.currencyCode;
    _isAvailable = item?.isAvailable ?? true;
    _photos = item != null ? List.from(item.photos) : [];
    _newPhotoFiles = [];
    _tags = item?.tags != null ? List.from(item?.tags ?? []) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final availableSlots = 2 - _newPhotoFiles.length - _photos.length;
    
    if (availableSlots <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 2 photos allowed')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    
    if (pickedFiles.isNotEmpty) {
      final filesToAdd = pickedFiles.take(availableSlots).toList();
      setState(() {
        _newPhotoFiles.addAll(filesToAdd.map((xFile) => File(xFile.path)));
      });
    }
  }

  Future<void> _removePhoto(int index, {bool isNew = false}) async {
    if (isNew) {
      setState(() => _newPhotoFiles.removeAt(index));
    } else {
      setState(() => _photos.removeAt(index));
    }
  }

  Future<void> _saveItem() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item name is required')),
      );
      return;
    }

    if (_priceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price is required')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      // Upload new photos
      List<MenuItemPhoto> allPhotos = List.from(_photos);
      
      for (int i = 0; i < _newPhotoFiles.length; i++) {
        final url = await _menuService.uploadMenuItemImage(
          widget.listing.id,
          widget.item?.id ?? const Uuid().v4(),
          _newPhotoFiles[i],
        );
        allPhotos.add(MenuItemPhoto(
          id: const Uuid().v4(),
          url: url,
          sortOrder: allPhotos.length,
        ));
      }

      final itemId = widget.item?.id ?? const Uuid().v4();
      final menuItem = MenuItem(
        id: itemId,
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        price: double.parse(_priceController.text),
        currencyCode: _currencyCode,
        photos: allPhotos,
        tags: _tags.isEmpty ? null : _tags,
        isAvailable: _isAvailable,
        sortOrder: widget.item?.sortOrder ?? 0,
      );

      if (mounted) {
        Navigator.pop(context, menuItem);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item == null ? 'Add Item' : 'Edit Item'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Center(
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveItem,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(cfg.colorPrimary),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Item Name *',
                labelStyle: const TextStyle(color: Colors.white),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: const TextStyle(color: Colors.white),
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 16),

            // Price & Currency
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _priceController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Price *',
                      labelStyle: const TextStyle(color: Colors.white),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currencyCode,
                    onChanged: (value) =>
                        setState(() => _currencyCode = value ?? _currencyCode),
                    items: [
                      'USD',
                      'XCD',
                      'JMD',
                      'TTD',
                      'BSD',
                      'BBD',
                      'GYD',
                      'HTG',
                      'DOP',
                      'KYD',
                      'ANG',
                      'SRD',
                      'XOF',
                    ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Availability Toggle
            SwitchListTile(
              value: _isAvailable,
              onChanged: (value) => setState(() => _isAvailable = value),
              title: const Text('Available'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),

            // Photos Section
            Text(
              'Photos (Max 2)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            if (_photos.isEmpty && _newPhotoFiles.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Column(
                    children: [
                      Icon(Icons.image, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 8),
                      Text('No photos', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._photos.asMap().entries.map(
                    (entry) => _buildPhotoThumbnail(
                      context,
                      entry.value.url,
                      onRemove: () => _removePhoto(entry.key),
                    ),
                  ),
                  ..._newPhotoFiles.asMap().entries.map(
                    (entry) => _buildPhotoThumbnail(
                      context,
                      entry.value.path,
                      isFile: true,
                      onRemove: () => _removePhoto(entry.key, isNew: true),
                    ),
                  ),
                ],
              ),
            if (_photos.length + _newPhotoFiles.length < 2)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.add_photo_alternate),
                    label: const Text('Add Photo'),
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Tags
            Text(
              'Tags (Optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Popular', 'Spicy', 'Vegan', 'Vegetarian', 'Gluten-Free']
                  .map(
                    (tag) => FilterChip(
                      label: Text(
                        tag.tr(),
                        style: TextStyle(
                          color: _tags.contains(tag)
                              ? Color(cfg.colorPrimary)
                              : (dark ? Colors.white : Colors.black87),
                        ),
                      ),
                      selected: _tags.contains(tag),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _tags.add(tag);
                          } else {
                            _tags.remove(tag);
                          }
                        });
                      },
                      selectedColor: Color(cfg.colorPrimary).withOpacity(0.2),
                      backgroundColor: dark ? Colors.grey.shade800 : Colors.grey.shade200,
                      side: BorderSide(
                        color: _tags.contains(tag)
                            ? Color(cfg.colorPrimary)
                            : (dark ? Colors.grey.shade700 : Colors.grey.shade400),
                        width: 1,
                      ),
                      checkmarkColor: Color(cfg.colorPrimary),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context,
    String path, {
    bool isFile = false,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: isFile
              ? Image.file(
                  File(path),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                )
              : Image.network(
                  path,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.error),
                  ),
                ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
      ],
    );
  }
}
