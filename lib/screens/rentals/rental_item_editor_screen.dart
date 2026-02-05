import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/rental_catalog_item.dart';
import 'package:instaflutter/listings/model/rental_config.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/rental_catalog_service.dart';
import 'package:uuid/uuid.dart';

/// Rental Item Editor Screen
/// For creating and editing rental catalog items
class RentalItemEditorScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;
  final RentalCatalogItem? item; // null = create new

  const RentalItemEditorScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
    this.item,
  }) : super(key: key);

  @override
  State<RentalItemEditorScreen> createState() => _RentalItemEditorScreenState();
}

class _RentalItemEditorScreenState extends State<RentalItemEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final RentalCatalogService _rentalService = RentalCatalogService();
  final _uuid = const Uuid();

  // Basic fields
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _categoryController;
  late TextEditingController _basePriceController;
  late TextEditingController _stockQtyController;
  late TextEditingController _depositController;
  late TextEditingController _bufferMinutesController;
  late TextEditingController _termsController;

  // Vehicle-specific fields
  late TextEditingController _makeController;
  late TextEditingController _modelController;
  late TextEditingController _yearController;
  late TextEditingController _colorController;
  late TextEditingController _licensePlateController;
  late TextEditingController _vinController;

  RentalPricingUnit _pricingUnit = RentalPricingUnit.daily;
  bool _requiresLicense = false;
  bool _isVehicle = false;
  
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
    _categoryController = TextEditingController(text: item?.category ?? '');
    _basePriceController = TextEditingController(text: item?.basePrice.toStringAsFixed(2) ?? '');
    _stockQtyController = TextEditingController(text: item?.stockQty.toString() ?? '1');
    _depositController = TextEditingController(text: item?.depositAmount?.toStringAsFixed(2) ?? '');
    _bufferMinutesController = TextEditingController(text: item?.bufferMinutes.toString() ?? '30');
    _termsController = TextEditingController(text: item?.termsAndConditions ?? '');
    
    // Vehicle fields
    _makeController = TextEditingController(text: item?.make ?? '');
    _modelController = TextEditingController(text: item?.model ?? '');
    _yearController = TextEditingController(text: item?.year?.toString() ?? '');
    _colorController = TextEditingController(text: item?.color ?? '');
    _licensePlateController = TextEditingController(text: item?.licensePlate ?? '');
    _vinController = TextEditingController(text: item?.vin ?? '');
    
    if (item != null) {
      _pricingUnit = item.pricingUnit;
      _requiresLicense = item.requiresLicense;
      _isVehicle = item.isVehicle;
      _photos = List.from(item.photos);
      _videos = List.from(item.videos);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _categoryController.dispose();
    _basePriceController.dispose();
    _stockQtyController.dispose();
    _depositController.dispose();
    _bufferMinutesController.dispose();
    _termsController.dispose();
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _colorController.dispose();
    _licensePlateController.dispose();
    _vinController.dispose();
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
          widget.item == null ? 'Add Rental Item'.tr() : 'Edit Rental Item'.tr(),
          style: TextStyle(color: dark ? Colors.white : Colors.black),
        ),
        iconTheme: IconThemeData(color: dark ? Colors.white : Colors.black),
        actions: [
          if (_isSaving || _isUploading)
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
              if (_isUploading) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark ? Colors.grey.shade900 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: dark ? Colors.grey.shade800 : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(cfg.colorPrimary)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Uploading media...'.tr(),
                          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              // Item Type
              _buildSectionHeader('Item Type'.tr(), dark),
              SwitchListTile(
                title: Text(
                  'Vehicle Rental'.tr(),
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                ),
                subtitle: Text(
                  'Enable vehicle-specific fields'.tr(),
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
                value: _isVehicle,
                onChanged: (value) => setState(() => _isVehicle = value),
                activeColor: Color(cfg.colorPrimary),
                inactiveTrackColor: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 24),

              // Basic Information
              _buildSectionHeader('Basic Information'.tr(), dark),
              const SizedBox(height: 8),
              
              TextFormField(
                controller: _nameController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Item Name *'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'e.g., Power Drill, Toyota Camry'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
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

              TextFormField(
                controller: _categoryController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Category *'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'e.g., Power Tools, Vehicles, Equipment'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Category is required'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descriptionController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'Provide details about the rental item...'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),

              // Pricing
              _buildSectionHeader('Pricing'.tr(), dark),
              const SizedBox(height: 8),
              
              TextFormField(
                controller: _basePriceController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Base Price *'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  prefixText: '\$',
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
              const SizedBox(height: 16),

              DropdownButtonFormField<RentalPricingUnit>(
                value: _pricingUnit,
                dropdownColor: dark ? Colors.grey.shade900 : Colors.white,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Pricing Unit *'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
                items: RentalPricingUnit.values.map((unit) {
                  return DropdownMenuItem(
                    value: unit,
                    child: Text(_getPricingUnitLabel(unit)),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _pricingUnit = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _depositController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Security Deposit (Optional)'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'Refundable deposit amount'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  prefixText: '\$',
                ),
              ),
              const SizedBox(height: 24),

              // Availability & Stock
              _buildSectionHeader('Availability & Stock'.tr(), dark),
              const SizedBox(height: 8),
              
              TextFormField(
                controller: _stockQtyController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Stock Quantity *'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'Number of units available'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Stock quantity is required'.tr();
                  }
                  if (int.tryParse(value) == null) {
                    return 'Invalid quantity'.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _bufferMinutesController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Buffer Time (minutes)'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'Time between rentals for cleaning/prep'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),

              // Requirements
              _buildSectionHeader('Requirements'.tr(), dark),
              SwitchListTile(
                title: Text(
                  'License Required'.tr(),
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                ),
                subtitle: Text(
                  'Customer must have valid license'.tr(),
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
                value: _requiresLicense,
                onChanged: (value) => setState(() => _requiresLicense = value),
                activeColor: Color(cfg.colorPrimary),
                inactiveTrackColor: dark ? Colors.grey.shade700 : Colors.grey.shade300,
                inactiveThumbColor: dark ? Colors.grey.shade600 : Colors.grey.shade400,
              ),
              const SizedBox(height: 24),

              // Vehicle Details (conditional)
              if (_isVehicle) ...[
                _buildSectionHeader('Vehicle Details'.tr(), dark),
                const SizedBox(height: 8),
                
                TextFormField(
                  controller: _makeController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Make'.tr(),
                    labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    hintText: 'e.g., Toyota, Honda'.tr(),
                    hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _modelController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Model'.tr(),
                    labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    hintText: 'e.g., Camry, Civic'.tr(),
                    hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _yearController,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Year'.tr(),
                          labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                          hintText: '2020'.tr(),
                          hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _colorController,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Color'.tr(),
                          labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                          hintText: 'Black'.tr(),
                          hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _licensePlateController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'License Plate'.tr(),
                    labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    hintText: 'ABC-1234'.tr(),
                    hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _vinController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'VIN (Vehicle ID Number)'.tr(),
                    labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                    hintText: '17-character VIN'.tr(),
                    hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Terms and Conditions
              _buildSectionHeader('Terms and Conditions'.tr(), dark),
              const SizedBox(height: 8),
              TextFormField(
                controller: _termsController,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Rental Terms (Optional)'.tr(),
                  labelStyle: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                  hintText: 'Special conditions, restrictions, usage rules...'.tr(),
                  hintStyle: TextStyle(color: dark ? Colors.white38 : Colors.black38),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),

              // Photos
              _buildSectionHeader('Photos (up to 6)'.tr(), dark),
              const SizedBox(height: 8),
              _buildMediaGrid(isPhotos: true, dark: dark),
              const SizedBox(height: 24),

              // Videos
              _buildSectionHeader('Videos (up to 2)'.tr(), dark),
              const SizedBox(height: 8),
              _buildMediaGrid(isPhotos: false, dark: dark),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool dark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: dark ? Colors.white : Colors.black,
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
              decoration: const BoxDecoration(
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

  String _getPricingUnitLabel(RentalPricingUnit unit) {
    switch (unit) {
      case RentalPricingUnit.hourly:
        return 'Per Hour'.tr();
      case RentalPricingUnit.daily:
        return 'Per Day'.tr();
      case RentalPricingUnit.weekly:
        return 'Per Week'.tr();
      case RentalPricingUnit.monthly:
        return 'Per Month'.tr();
    }
  }

  String _friendlyErrorMessage(Object error) {
    final message = error.toString();
    if (message.contains('PERMISSION_DENIED')) {
      return 'You don’t have permission to save this rental item. Please check your account permissions or subscription.'.tr();
    }
    if (message.contains('No AppCheckProvider')) {
      return 'Upload failed because App Check is not configured for this build. Please enable App Check or use a debug provider.'.tr();
    }
    return message;
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _isUploading = _newPhotoFiles.isNotEmpty || _newVideoFiles.isNotEmpty;
    });

    try {
      // Upload new media
      final uploadedPhotos = <String>[];
      final uploadedVideos = <String>[];

      final itemId = widget.item?.id ?? _uuid.v4();

      // Upload photos
      for (final photoFile in _newPhotoFiles) {
        final url = await _rentalService.uploadRentalMedia(
          listingId: widget.listing.id,
          itemId: itemId,
          file: photoFile,
          isVideo: false,
        );
        uploadedPhotos.add(url);
      }

      // Upload videos
      for (final videoFile in _newVideoFiles) {
        final url = await _rentalService.uploadRentalMedia(
          listingId: widget.listing.id,
          itemId: itemId,
          file: videoFile,
          isVideo: true,
        );
        uploadedVideos.add(url);
      }

      if (mounted) {
        setState(() => _isUploading = false);
      }

      // Create/update item
      final item = RentalCatalogItem(
        id: itemId,
        listingId: widget.listing.id,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        category: _categoryController.text.trim(),
        basePrice: double.parse(_basePriceController.text),
        pricingUnit: _pricingUnit,
        photos: [..._photos, ...uploadedPhotos],
        videos: [..._videos, ...uploadedVideos],
        stockQty: int.parse(_stockQtyController.text),
        depositAmount: _depositController.text.trim().isEmpty 
            ? null 
            : double.tryParse(_depositController.text),
        bufferMinutes: int.tryParse(_bufferMinutesController.text) ?? 30,
        requiresLicense: _requiresLicense,
        termsAndConditions: _termsController.text.trim().isEmpty 
            ? null 
            : _termsController.text.trim(),
        // Vehicle-specific fields
        make: _isVehicle && _makeController.text.trim().isNotEmpty 
            ? _makeController.text.trim() 
            : null,
        model: _isVehicle && _modelController.text.trim().isNotEmpty 
            ? _modelController.text.trim() 
            : null,
        year: _isVehicle && _yearController.text.trim().isNotEmpty 
            ? _yearController.text.trim() 
            : null,
        color: _isVehicle && _colorController.text.trim().isNotEmpty 
            ? _colorController.text.trim() 
            : null,
        licensePlate: _isVehicle && _licensePlateController.text.trim().isNotEmpty 
            ? _licensePlateController.text.trim() 
            : null,
        vin: _isVehicle && _vinController.text.trim().isNotEmpty 
            ? _vinController.text.trim() 
            : null,
        createdAt: widget.item?.createdAt,
      );

      await _rentalService.upsertRentalItem(
        listingId: widget.listing.id,
        item: item,
        currentUser: widget.currentUser,
      );

      // If this is a vehicle rental, update the listing's rentalConfig to vehicle type
      if (_isVehicle && widget.listing.rentalConfig != null) {
        final updatedConfig = widget.listing.rentalConfig!.copyWith(
          rentalType: RentalType.vehicle,
        );
        await FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.listing.id)
            .update({
              'rentalConfig': updatedConfig.toJson(),
            });
      }

      if (mounted) {
        showSnackBar(context, 'Rental item saved successfully'.tr());
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        showSnackBar(context, _friendlyErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploading = false;
        });
      }
    }
  }
}
