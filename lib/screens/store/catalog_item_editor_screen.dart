import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/catalog_item.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/store_service.dart';
import 'package:uuid/uuid.dart';

/// Catalog Item Editor Screen
/// For creating and editing catalog items
class CatalogItemEditorScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;
  final CatalogItem? item; // null = create new

  const CatalogItemEditorScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
    this.item,
  }) : super(key: key);

  @override
  State<CatalogItemEditorScreen> createState() => _CatalogItemEditorScreenState();
}

class _CatalogItemEditorScreenState extends State<CatalogItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final StoreService _storeService = StoreService();
  final _uuid = const Uuid();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockQtyController;
  late TextEditingController _categoryController;

  bool _isAvailable = true;
  bool _trackStock = false;
  CatalogItemType _itemType = CatalogItemType.product;
  List<String> _photos = [];
  List<String> _videos = [];
  List<File> _newPhotoFiles = [];
  List<File> _newVideoFiles = [];
  List<CatalogVariant> _variants = [];
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(text: item?.price.toStringAsFixed(2) ?? '');
    _stockQtyController = TextEditingController(text: item?.stockQty.toString() ?? '0');
    _categoryController = TextEditingController(text: item?.category ?? '');
    
    if (item != null) {
      _isAvailable = item.isAvailable;
      _trackStock = item.trackStock;
      _itemType = item.type;
      _photos = List.from(item.photos);
      _videos = List.from(item.videos);
      _variants = List.from(item.variants);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQtyController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    String? prefix,
    required bool dark,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: dark ? Colors.white : Colors.black87),
      hintText: hint,
      hintStyle: TextStyle(color: dark ? Colors.white70 : Colors.black45),
      border: const OutlineInputBorder(),
      filled: true,
      fillColor: enabled ? (dark ? Colors.grey.shade900 : Colors.grey.shade50) : (dark ? Colors.grey.shade800 : Colors.grey.shade200),
      prefixText: prefix,
      prefixStyle: TextStyle(color: dark ? Colors.white : Colors.black87),
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final bool hasVariants = _variants.isNotEmpty;

    return Scaffold(
      backgroundColor: dark ? Colors.black : Colors.white,
      appBar: AppBar(
        backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          widget.item == null ? 'Add Item'.tr() : 'Edit Item'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _saveItem,
              child: Text(
                'Save'.tr(),
                style: TextStyle(
                  color: Color(cfg.colorPrimary),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  label: 'Item Name *'.tr(),
                  dark: dark,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Category
              TextFormField(
                controller: _categoryController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: _inputDecoration(
                  label: 'Category (Optional)'.tr(),
                  hint: 'e.g., Appetizers, Beverages, Electronics'.tr(),
                  dark: dark,
                ),
              ),
              const SizedBox(height: 16),

              // Item Type Selector
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: dark ? Colors.grey.shade700 : Colors.grey.shade400,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Item Type *'.tr(),
                        style: TextStyle(
                          color: dark ? Colors.white70 : Colors.black54,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    DropdownButton<CatalogItemType>(
                      value: _itemType,
                      dropdownColor: dark ? Colors.grey.shade800 : Colors.white,
                      style: TextStyle(
                        color: dark ? Colors.white : Colors.black87,
                        fontSize: 16,
                      ),
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: CatalogItemType.foodDrink,
                          child: Row(
                            children: [
                              const Text('🍽️ ', style: TextStyle(fontSize: 18)),
                              Text('Food/Drink'.tr()),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: CatalogItemType.product,
                          child: Row(
                            children: [
                              const Text('🛍️ ', style: TextStyle(fontSize: 18)),
                              Text('Product'.tr()),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: CatalogItemType.service,
                          child: Row(
                            children: [
                              const Text('⚙️ ', style: TextStyle(fontSize: 18)),
                              Text('Service'.tr()),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _itemType = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                maxLines: 3,
                decoration: _inputDecoration(
                  label: 'Description (Optional)'.tr(),
                  dark: dark,
                ),
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _inputDecoration(
                  label: 'Price *'.tr(),
                  prefix: getCurrencySymbol(widget.listing.currencyCode),
                  dark: dark,
                  enabled: !hasVariants,
                ),
                validator: (value) {
                  if (hasVariants) return null;
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required'.tr();
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid price'.tr();
                  }
                  return null;
                },
              ),
              if (hasVariants)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('Price is managed in variants.'.tr(), style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 24),

              // Inventory Management
              SwitchListTile(
                title: Text(
                  'Track Stock'.tr(),
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                ),
                subtitle: Text(
                  'Enable inventory tracking for this item'.tr(),
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
                value: _trackStock,
                onChanged: (value) => setState(() => _trackStock = value),
                activeColor: Color(cfg.colorPrimary),
              ),
              
              if (_trackStock && !hasVariants) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stockQtyController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    label: 'Stock Quantity'.tr(),
                    dark: dark,
                    enabled: !hasVariants,
                  ),
                ),
              ],
               if (hasVariants)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text('Stock is managed in variants.'.tr(), style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 16),

              // Variants Management
              if (_itemType == CatalogItemType.product) ...[
                Text(
                  'Variants (e.g., Size, Color)'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add different options for this product. Each variant can have its own price and stock.'.tr(),
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 12),
                _buildVariantList(dark),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.add),
                    label: Text('Add Variant'.tr()),
                    onPressed: () => _showVariantDialog(dark: dark),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(cfg.colorPrimary),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Availability
              SwitchListTile(
                title: Text(
                  'Available'.tr(),
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                ),
                subtitle: Text(
                  'Customers can see and order this item'.tr(),
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
                value: _isAvailable,
                onChanged: (value) => setState(() => _isAvailable = value),
                activeColor: Color(cfg.colorPrimary),
              ),
              const SizedBox(height: 24),

              // Photos
              Text(
                'Photos (up to 6)'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _buildMediaGrid(isPhotos: true, dark: dark),
              const SizedBox(height: 24),

              // Videos
              Text(
                'Videos (up to 2)'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              _buildMediaGrid(isPhotos: false, dark: dark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantList(bool dark) {
    if (_variants.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No variants yet. Add one to get started.'.tr(),
            style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
          ),
        ),
      );
    }

    return Column(
      children: _variants.asMap().entries.map((entry) {
        final index = entry.key;
        final variant = entry.value;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          color: dark ? Colors.grey.shade900 : Colors.white,
          child: ListTile(
            title: Text(
              '${variant.size ?? ''}${variant.size != null && variant.color != null ? ' - ' : ''}${variant.color ?? ''}',
              style: TextStyle(color: dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Price: ${getCurrencySymbol(widget.listing.currencyCode)}${variant.price.toStringAsFixed(2)} - Stock: ${variant.stockQty}',
              style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showVariantDialog(variant: variant, index: index, dark: dark),
                  color: dark ? Colors.white70 : Colors.black54,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, size: 20),
                  onPressed: () {
                    setState(() {
                      _variants.removeAt(index);
                    });
                  },
                  color: Colors.red,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _showVariantDialog({CatalogVariant? variant, int? index, required bool dark}) async {
    final _variantFormKey = GlobalKey<FormState>();
    final skuController = TextEditingController(text: variant?.sku ?? '');
    final sizeController = TextEditingController(text: variant?.size ?? '');
    final colorController = TextEditingController(text: variant?.color ?? '');
    final priceController = TextEditingController(text: variant?.price.toStringAsFixed(2) ?? '');
    final stockController = TextEditingController(text: variant?.stockQty.toString() ?? '0');

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: dark ? Colors.grey.shade800 : Colors.white,
          title: Text(variant == null ? 'Add Variant'.tr() : 'Edit Variant'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
          content: Form(
            key: _variantFormKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: sizeController, style: TextStyle(color: dark ? Colors.white : Colors.black), decoration: _inputDecoration(label: 'Size (e.g., S, M, L)'.tr(), dark: dark)),
                  const SizedBox(height: 12),
                  TextFormField(controller: colorController, style: TextStyle(color: dark ? Colors.white : Colors.black), decoration: _inputDecoration(label: 'Color (e.g., Red, Blue)'.tr(), dark: dark)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceController,
                    style: TextStyle(color: dark ? Colors.white : Colors.black),
                    decoration: _inputDecoration(label: 'Price *'.tr(), dark: dark),
                    keyboardType: TextInputType.number,
                    validator: (v) => (v == null || v.isEmpty || double.tryParse(v) == null) ? 'Required'.tr() : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: stockController,
                    style: TextStyle(color: dark ? Colors.white : Colors.black),
                    decoration: _inputDecoration(label: 'Stock Quantity'.tr(), dark: dark),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: skuController, style: TextStyle(color: dark ? Colors.white : Colors.black), decoration: _inputDecoration(label: 'SKU (Optional)'.tr(), dark: dark)),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr())),
            ElevatedButton(
              onPressed: () {
                if (_variantFormKey.currentState!.validate()) {
                  final newVariant = CatalogVariant(
                    sku: skuController.text.trim(),
                    size: sizeController.text.trim().isEmpty ? null : sizeController.text.trim(),
                    color: colorController.text.trim().isEmpty ? null : colorController.text.trim(),
                    price: double.parse(priceController.text),
                    stockQty: int.tryParse(stockController.text) ?? 0,
                  );
                  setState(() {
                    if (index != null) {
                      _variants[index] = newVariant;
                    } else {
                      _variants.add(newVariant);
                    }
                  });
                  Navigator.pop(context);
                }
              },
              child: Text('Save'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMediaGrid({required bool isPhotos, required bool dark}) {
    final existingMedia = isPhotos ? _photos : _videos;
    final newFiles = isPhotos ? _newPhotoFiles : _newVideoFiles;
    final maxCount = isPhotos ? 6 : 2;
    final totalCount = existingMedia.length + newFiles.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...existingMedia.map((url) => _buildMediaTile(url: url, isPhotos: isPhotos, dark: dark, onRemove: () => setState(() => isPhotos ? _photos.remove(url) : _videos.remove(url)))),
        ...newFiles.asMap().entries.map((entry) => _buildMediaTile(file: entry.value, isPhotos: isPhotos, dark: dark, onRemove: () => setState(() => isPhotos ? _newPhotoFiles.removeAt(entry.key) : _newVideoFiles.removeAt(entry.key)))),
        if (totalCount < maxCount)
          _buildAddMediaButton(isPhotos: isPhotos, dark: dark),
      ],
    );
  }

  Widget _buildMediaTile({String? url, File? file, required bool isPhotos, required bool dark, required VoidCallback onRemove}) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: dark ? Colors.grey.shade800 : Colors.grey.shade200),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url != null ? Image.network(url, fit: BoxFit.cover) : (file != null && isPhotos ? Image.file(file, fit: BoxFit.cover) : Icon(Icons.videocam, size: 40, color: Colors.grey.shade600)),
          ),
        ),
        Positioned(top: 4, right: 4, child: GestureDetector(onTap: onRemove, child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)))),
      ],
    );
  }

  Widget _buildAddMediaButton({required bool isPhotos, required bool dark}) {
    return GestureDetector(
      onTap: () => _pickMedia(isPhotos: isPhotos),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          border: Border.all(color: Color(cfg.colorPrimary).withOpacity(0.5), width: 2, style: BorderStyle.solid),
        ),
        child: Icon(isPhotos ? Icons.add_photo_alternate : Icons.videocam, size: 40, color: Color(cfg.colorPrimary)),
      ),
    );
  }

  Future<void> _pickMedia({required bool isPhotos}) async {
    final picker = ImagePicker();
    if (isPhotos) {
      final pickedFiles = await picker.pickMultiImage();
      if (pickedFiles.isNotEmpty) {
        setState(() {
          _newPhotoFiles.addAll(pickedFiles.map((xFile) => File(xFile.path)));
        });
      }
    } else {
      final pickedFile = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _newVideoFiles.add(File(pickedFile.path));
        });
      }
    }
  }

  String getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD': case 'TTD': case 'JMD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      default: return '\$';
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final itemId = widget.item?.id ?? _uuid.v4();
      final uploadedPhotos = <String>[];
      for (final photoFile in _newPhotoFiles) {
        final url = await _storeService.uploadCatalogMedia(listingId: widget.listing.id, itemId: itemId, file: photoFile, isVideo: false);
        uploadedPhotos.add(url);
        if (_newPhotoFiles.indexOf(photoFile) < _newPhotoFiles.length - 1) await Future.delayed(const Duration(milliseconds: 500));
      }
      final uploadedVideos = <String>[];
      for (final videoFile in _newVideoFiles) {
        final url = await _storeService.uploadCatalogMedia(listingId: widget.listing.id, itemId: itemId, file: videoFile, isVideo: true);
        uploadedVideos.add(url);
        if (_newVideoFiles.indexOf(videoFile) < _newVideoFiles.length - 1) await Future.delayed(const Duration(milliseconds: 500));
      }

      final item = CatalogItem(
        id: itemId,
        type: _itemType,
        category: _categoryController.text.trim(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        price: double.tryParse(_priceController.text) ?? 0,
        currencyCode: widget.listing.storeCurrencyCode ?? widget.listing.currencyCode,
        photos: [..._photos, ...uploadedPhotos],
        videos: [..._videos, ...uploadedVideos],
        isAvailable: _isAvailable,
        trackStock: _trackStock,
        stockQty: _trackStock ? int.tryParse(_stockQtyController.text) ?? 0 : 0,
        variants: _variants,
        createdAt: widget.item?.createdAt,
      );

      await _storeService.upsertCatalogItem(listingId: widget.listing.id, item: item, currentUser: widget.currentUser);

      if (mounted) {
        showSnackBar(context, 'Item saved successfully'.tr());
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
