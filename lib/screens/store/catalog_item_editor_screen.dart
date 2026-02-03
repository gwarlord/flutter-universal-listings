import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/catalog_item.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/store_service.dart';
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

  CatalogItemType _selectedType = CatalogItemType.product;
  bool _isAvailable = true;
  bool _trackStock = false;
  List<String> _photos = [];
  List<String> _videos = [];
  List<File> _newPhotoFiles = [];
  List<File> _newVideoFiles = [];
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
      _selectedType = item.type;
      _isAvailable = item.isAvailable;
      _trackStock = item.trackStock;
      _photos = List.from(item.photos);
      _videos = List.from(item.videos);
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

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

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
              // Item Type
              Text(
                'Item Type'.tr(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<CatalogItemType>(
                segments: [
                  ButtonSegment(
                    value: CatalogItemType.foodDrink,
                    label: Text('Food & Drink'.tr()),
                    icon: const Icon(Icons.restaurant),
                  ),
                  ButtonSegment(
                    value: CatalogItemType.product,
                    label: Text('Product'.tr()),
                    icon: const Icon(Icons.shopping_bag),
                  ),
                  ButtonSegment(
                    value: CatalogItemType.service,
                    label: Text('Service'.tr()),
                    icon: const Icon(Icons.build),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<CatalogItemType> selection) {
                  setState(() => _selectedType = selection.first);
                },
              ),
              const SizedBox(height: 24),

              // Name
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Item Name *'.tr(),
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
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
                decoration: InputDecoration(
                  labelText: 'Category (Optional)'.tr(),
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  hintText: 'e.g., Appetizers, Beverages, Electronics'.tr(),
                ),
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)'.tr(),
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Price *'.tr(),
                  labelStyle: const TextStyle(color: Colors.white),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  prefixText: getCurrencySymbol(widget.listing.currencyCode),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required'.tr();
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid price'.tr();
                  }
                  return null;
                },
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
              
              if (_trackStock) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: _stockQtyController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Stock Quantity'.tr(),
                    labelStyle: const TextStyle(color: Colors.white),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
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

  Widget _buildMediaGrid({required bool isPhotos, required bool dark}) {
    final existingMedia = isPhotos ? _photos : _videos;
    final newFiles = isPhotos ? _newPhotoFiles : _newVideoFiles;
    final maxCount = isPhotos ? 6 : 2;
    final totalCount = existingMedia.length + newFiles.length;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Existing media
        ...existingMedia.map((url) => _buildMediaTile(
          url: url,
          isPhotos: isPhotos,
          dark: dark,
          onRemove: () {
            setState(() {
              if (isPhotos) {
                _photos.remove(url);
              } else {
                _videos.remove(url);
              }
            });
          },
        )),
        
        // New files
        ...newFiles.asMap().entries.map((entry) => _buildMediaTile(
          file: entry.value,
          isPhotos: isPhotos,
          dark: dark,
          onRemove: () {
            setState(() {
              if (isPhotos) {
                _newPhotoFiles.removeAt(entry.key);
              } else {
                _newVideoFiles.removeAt(entry.key);
              }
            });
          },
        )),
        
        // Add button
        if (totalCount < maxCount)
          _buildAddMediaButton(isPhotos: isPhotos, dark: dark),
      ],
    );
  }

  Widget _buildMediaTile({
    String? url,
    File? file,
    required bool isPhotos,
    required bool dark,
    required VoidCallback onRemove,
  }) {
    return Stack(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url != null
                ? Image.network(url, fit: BoxFit.cover)
                : (file != null && isPhotos
                    ? Image.file(file, fit: BoxFit.cover)
                    : Icon(Icons.videocam, size: 40, color: Colors.grey.shade600)),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
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
          border: Border.all(
            color: Color(cfg.colorPrimary).withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
        child: Icon(
          isPhotos ? Icons.add_photo_alternate : Icons.videocam,
          size: 40,
          color: Color(cfg.colorPrimary),
        ),
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
      case 'USD':
      case 'TTD':
      case 'JMD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '\$';
    }
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Upload new media
      final uploadedPhotos = <String>[];
      final uploadedVideos = <String>[];

      final itemId = widget.item?.id ?? _uuid.v4();

      // Upload photos
      for (final photoFile in _newPhotoFiles) {
        final url = await _storeService.uploadCatalogMedia(
          listingId: widget.listing.id,
          itemId: itemId,
          file: photoFile,
          isVideo: false,
        );
        uploadedPhotos.add(url);
      }

      // Upload videos
      for (final videoFile in _newVideoFiles) {
        final url = await _storeService.uploadCatalogMedia(
          listingId: widget.listing.id,
          itemId: itemId,
          file: videoFile,
          isVideo: true,
        );
        uploadedVideos.add(url);
      }

      // Create/update item
      final item = CatalogItem(
        id: itemId,
        type: _selectedType,
        category: _categoryController.text.trim(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        currencyCode: widget.listing.storeCurrencyCode ?? widget.listing.currencyCode,
        photos: [..._photos, ...uploadedPhotos],
        videos: [..._videos, ...uploadedVideos],
        isAvailable: _isAvailable,
        trackStock: _trackStock,
        stockQty: _trackStock ? int.tryParse(_stockQtyController.text) ?? 0 : 0,
        createdAt: widget.item?.createdAt,
      );

      await _storeService.upsertCatalogItem(
        listingId: widget.listing.id,
        item: item,
        currentUser: widget.currentUser,
      );

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
