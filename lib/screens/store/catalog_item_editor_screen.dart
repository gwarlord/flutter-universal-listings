import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
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
  late TextEditingController _option1NameController;
  late TextEditingController _option2NameController;
  late TextEditingController _option3NameController;
  late TextEditingController _option4NameController;
  StreamSubscription<List<CatalogItem>>? _catalogItemsSubscription;

  bool _isAvailable = true;
  bool _trackStock = false;
  CatalogItemType _itemType = CatalogItemType.product;
  List<String> _photos = [];
  List<String> _videos = [];
  List<File> _newPhotoFiles = [];
  List<File> _newVideoFiles = [];
  List<CatalogVariant> _variants = [];
  bool _isSaving = false;
  List<String> _existingCategories = [];

  double _lowestVariantPrice() {
    if (_variants.isEmpty) {
      return double.tryParse(_priceController.text.trim()) ?? 0;
    }
    return _variants
        .map((v) => v.price)
        .reduce((a, b) => a < b ? a : b);
  }

  void _syncBasePriceFromVariants() {
    if (_variants.isEmpty) return;
    final lowest = _lowestVariantPrice();
    _priceController.text = lowest.toStringAsFixed(2);
  }

  @override
  void initState() {
    super.initState();
    
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _descriptionController = TextEditingController(text: item?.description ?? '');
    _priceController = TextEditingController(text: item?.price.toStringAsFixed(2) ?? '');
    _stockQtyController = TextEditingController(text: item?.stockQty.toString() ?? '0');
    _categoryController = TextEditingController(text: item?.category ?? '');
    _option1NameController = TextEditingController(
      text: item?.normalizedOption1Name ?? (item?.hasFirstVariantOption == true ? item!.resolvedOption1Name : ''),
    );
    _option2NameController = TextEditingController(
      text: item?.normalizedOption2Name ?? (item?.hasSecondVariantOption == true ? item!.resolvedOption2Name : ''),
    );
    _option3NameController = TextEditingController(
      text: item?.normalizedOption3Name ?? (item?.hasThirdVariantOption == true ? item!.resolvedOption3Name : ''),
    );
    _option4NameController = TextEditingController(
      text: item?.normalizedOption4Name ?? (item?.hasFourthVariantOption == true ? item!.resolvedOption4Name : ''),
    );
    _categoryController.addListener(_onCategoryChanged);
    
    if (item != null) {
      _isAvailable = item.isAvailable;
      _trackStock = item.trackStock;
      _itemType = item.type;
      _photos = List.from(item.photos);
      _videos = List.from(item.videos);
      _variants = List.from(item.variants);
      _syncBasePriceFromVariants();
    }

    _catalogItemsSubscription =
        _storeService.getCatalogItems(widget.listing.id).listen((items) {
      final categoryByNormalized = <String, String>{};
      for (final catalogItem in items) {
        final category = catalogItem.category.trim();
        final normalized = _normalizeCategory(category);
        if (category.isEmpty || normalized.isEmpty) continue;
        categoryByNormalized.putIfAbsent(normalized, () => category);
      }

      if (!mounted) return;
      setState(() {
        _existingCategories = categoryByNormalized.values.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    });
  }

  @override
  void dispose() {
    _catalogItemsSubscription?.cancel();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQtyController.dispose();
    _categoryController.removeListener(_onCategoryChanged);
    _categoryController.dispose();
    _option1NameController.dispose();
    _option2NameController.dispose();
    _option3NameController.dispose();
    _option4NameController.dispose();
    super.dispose();
  }

  String? _normalizedText(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _variantDisplayLabel(CatalogVariant variant) {
    final label = variant.displayLabel();
    return label.isEmpty ? 'Default variant'.tr() : label;
  }

  Widget _buildVariantImagePreview(String? imageValue, bool dark) {
    final imagePath = _normalizedText(imageValue ?? '');
    final preview = Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: dark ? Colors.grey.shade900 : Colors.grey.shade200,
      ),
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );

    if (imagePath == null) return preview;

    if (imagePath.startsWith('file://')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(imagePath.replaceFirst('file://', '')),
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => preview,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imagePath,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        cacheWidth: 144,
        cacheHeight: 144,
        errorBuilder: (_, __, ___) => preview,
      ),
    );
  }

  Future<String?> _pickVariantImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return null;
    return 'file://${pickedFile.path}';
  }

  void _onCategoryChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  String _normalizeCategory(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String _canonicalizeCategory(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '';

    final normalizedInput = _normalizeCategory(trimmed);
    for (final category in _existingCategories) {
      if (_normalizeCategory(category) == normalizedInput) {
        return category;
      }
    }
    return trimmed;
  }

  List<String> _categorySuggestions() {
    final query = _categoryController.text.trim();
    if (query.isEmpty) return _existingCategories.take(6).toList();

    final normalizedQuery = _normalizeCategory(query);
    return _existingCategories.where((category) {
      final normalizedCategory = _normalizeCategory(category);
      return category.toLowerCase().contains(query.toLowerCase()) ||
          normalizedCategory.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedCategory);
    }).take(6).toList();
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
                onEditingComplete: () {
                  final canonical =
                      _canonicalizeCategory(_categoryController.text);
                  if (canonical != _categoryController.text) {
                    _categoryController.text = canonical;
                    _categoryController.selection = TextSelection.fromPosition(
                      TextPosition(offset: canonical.length),
                    );
                  }
                  FocusScope.of(context).nextFocus();
                },
              ),
              if (_existingCategories.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categorySuggestions().map((category) {
                    final isSelected = _categoryController.text.trim() == category;
                    return ActionChip(
                      label: Text(category),
                      onPressed: () {
                        setState(() {
                          _categoryController.text = category;
                          _categoryController.selection = TextSelection.fromPosition(
                            TextPosition(offset: category.length),
                          );
                        });
                      },
                      backgroundColor: isSelected
                          ? Color(cfg.colorPrimary).withOpacity(0.18)
                          : (dark ? Colors.grey.shade800 : Colors.grey.shade200),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Color(cfg.colorPrimary)
                            : (dark ? Colors.white70 : Colors.black87),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 4),
                Text(
                  'Suggestions are based on categories already used in this store.'.tr(),
                  style: TextStyle(
                    color: dark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
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
                  label: hasVariants
                      ? 'Base Price (auto from variants)'.tr()
                      : 'Price *'.tr(),
                  prefix: getCurrencySymbol(widget.listing.currencyCode),
                  dark: dark,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return hasVariants ? null : 'Price is required'.tr();
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
                  child: Text(
                    'Using the lowest variant price for item display.'.tr(),
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
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
                  child: Text('Stock can be managed per Option 1 value.'.tr(), style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              const SizedBox(height: 16),

              // Variants Management
              if (_itemType == CatalogItemType.product) ...[
                Text(
                  'Variants'.tr(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: dark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Name up to four option types for this product. Each variant can have its own values, price, stock, and image.'.tr(),
                  style: TextStyle(color: dark ? Colors.white70 : Colors.black54),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _option1NameController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: _inputDecoration(
                    label: 'Option 1 Name'.tr(),
                    hint: 'e.g., Size, Style, Material'.tr(),
                    dark: dark,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _option2NameController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: _inputDecoration(
                    label: 'Option 2 Name (Optional)'.tr(),
                    hint: 'e.g., Color, Finish, Flavor'.tr(),
                    dark: dark,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _option3NameController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: _inputDecoration(
                    label: 'Option 3 Name (Optional)'.tr(),
                    hint: 'e.g., Fit, Pattern'.tr(),
                    dark: dark,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _option4NameController,
                  style: TextStyle(color: dark ? Colors.white : Colors.black),
                  decoration: _inputDecoration(
                    label: 'Option 4 Name (Optional)'.tr(),
                    hint: 'e.g., Region, Edition'.tr(),
                    dark: dark,
                  ),
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
            leading: _buildVariantImagePreview(variant.imageUrl, dark),
            title: Text(
              _variantDisplayLabel(variant),
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
                      _syncBasePriceFromVariants();
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
    final option1Controller = TextEditingController(text: variant?.effectiveOption1Value ?? '');
    final option2Controller = TextEditingController(text: variant?.effectiveOption2Value ?? '');
    final option3Controller = TextEditingController(text: variant?.effectiveOption3Value ?? '');
    final option4Controller = TextEditingController(text: variant?.effectiveOption4Value ?? '');
    final priceController = TextEditingController(text: variant?.price.toStringAsFixed(2) ?? '');
    final stockController = TextEditingController(text: variant?.stockQty.toString() ?? '0');
    String? variantImage = variant?.imageUrl;

    final option1Label = _normalizedText(_option1NameController.text) ?? 'Option 1'.tr();
    final option2Label = _normalizedText(_option2NameController.text) ?? 'Option 2'.tr();
    final option3Label = _normalizedText(_option3NameController.text) ?? 'Option 3'.tr();
    final option4Label = _normalizedText(_option4NameController.text) ?? 'Option 4'.tr();

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: dark ? Colors.grey.shade800 : Colors.white,
              title: Text(variant == null ? 'Add Variant'.tr() : 'Edit Variant'.tr(), style: TextStyle(color: dark ? Colors.white : Colors.black)),
              content: Form(
                key: _variantFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: option1Controller,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: _inputDecoration(label: '$option1Label *', dark: dark),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required'.tr() : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: option2Controller,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: _inputDecoration(label: option2Label, dark: dark),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: option3Controller,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: _inputDecoration(label: option3Label, dark: dark),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: option4Controller,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: _inputDecoration(label: option4Label, dark: dark),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: priceController,
                        style: TextStyle(color: dark ? Colors.white : Colors.black),
                        decoration: _inputDecoration(label: 'Price *'.tr(), dark: dark),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildVariantImagePreview(variantImage, dark),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Variant Image (Optional)'.tr(),
                                  style: TextStyle(
                                    color: dark ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'This image is used when the customer selects this variant.'.tr(),
                                  style: TextStyle(
                                    color: dark ? Colors.white70 : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () async {
                                        final picked = await _pickVariantImage();
                                        if (picked == null) return;
                                        setDialogState(() => variantImage = picked);
                                      },
                                      icon: const Icon(Icons.photo_library_outlined),
                                      label: Text('Choose Image'.tr()),
                                    ),
                                    if (_normalizedText(variantImage ?? '') != null)
                                      TextButton(
                                        onPressed: () => setDialogState(() => variantImage = null),
                                        child: Text('Remove'.tr()),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel'.tr())),
                ElevatedButton(
                  onPressed: () {
                    if (_variantFormKey.currentState!.validate()) {
                      final option1Value = _normalizedText(option1Controller.text);
                      final option2Value = _normalizedText(option2Controller.text);
                      final option3Value = _normalizedText(option3Controller.text);
                      final option4Value = _normalizedText(option4Controller.text);
                      final newVariant = CatalogVariant(
                        sku: skuController.text.trim(),
                        size: option1Value,
                        color: option2Value,
                        option1Value: option1Value,
                        option2Value: option2Value,
                        option3Value: option3Value,
                        option4Value: option4Value,
                        imageUrl: _normalizedText(variantImage ?? ''),
                        price: double.parse(priceController.text),
                        stockQty: int.tryParse(stockController.text) ?? 0,
                      );
                      setState(() {
                        if (index != null) {
                          _variants[index] = newVariant;
                        } else {
                          _variants.add(newVariant);
                        }
                        _syncBasePriceFromVariants();
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
            child: isPhotos
                ? (url != null
                    ? Image.network(url, fit: BoxFit.cover, cacheWidth: 200, cacheHeight: 200)
                    : (file != null ? Image.file(file, fit: BoxFit.cover) : const SizedBox()))
                : _CatalogVideoThumb(
                    source: url ?? file?.path ?? '',
                    dark: dark,
                  ),
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
      final pickedFiles = await picker.pickMultiImage(imageQuality: 85);
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

      final parsedBasePrice = double.tryParse(_priceController.text.trim()) ?? 0;
      final effectivePrice = _variants.isNotEmpty
          ? _lowestVariantPrice()
          : parsedBasePrice;

      final resolvedVariants = <CatalogVariant>[];
      for (var index = 0; index < _variants.length; index++) {
        final variant = _variants[index];
        final rawImage = _normalizedText(variant.imageUrl ?? '');
        if (rawImage != null && rawImage.startsWith('file://')) {
          final imageFile = File(rawImage.replaceFirst('file://', ''));
          final uploadedImage = await _storeService.uploadCatalogMedia(
            listingId: widget.listing.id,
            itemId: itemId,
            file: imageFile,
            isVideo: false,
          );
          resolvedVariants.add(CatalogVariant(
            sku: variant.sku,
            size: variant.effectiveOption1Value,
            color: variant.effectiveOption2Value,
            option1Value: variant.effectiveOption1Value,
            option2Value: variant.effectiveOption2Value,
            option3Value: variant.effectiveOption3Value,
            option4Value: variant.effectiveOption4Value,
            imageUrl: uploadedImage,
            price: variant.price,
            stockQty: variant.stockQty,
          ));
        } else {
          resolvedVariants.add(CatalogVariant(
            sku: variant.sku,
            size: variant.effectiveOption1Value,
            color: variant.effectiveOption2Value,
            option1Value: variant.effectiveOption1Value,
            option2Value: variant.effectiveOption2Value,
            option3Value: variant.effectiveOption3Value,
            option4Value: variant.effectiveOption4Value,
            imageUrl: rawImage,
            price: variant.price,
            stockQty: variant.stockQty,
          ));
        }

        if (index < _variants.length - 1) {
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }

      final canonicalCategory =
          _canonicalizeCategory(_categoryController.text);

      final item = CatalogItem(
        id: itemId,
        type: _itemType,
        category: canonicalCategory,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        price: effectivePrice,
        currencyCode: widget.listing.storeCurrencyCode ?? widget.listing.currencyCode,
        photos: [..._photos, ...uploadedPhotos],
        videos: [..._videos, ...uploadedVideos],
        isAvailable: _isAvailable,
        trackStock: _trackStock,
        stockQty: _trackStock ? int.tryParse(_stockQtyController.text) ?? 0 : 0,
        variants: resolvedVariants,
        option1Name: _normalizedText(_option1NameController.text),
        option2Name: _normalizedText(_option2NameController.text),
        option3Name: _normalizedText(_option3NameController.text),
        option4Name: _normalizedText(_option4NameController.text),
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

class _CatalogVideoThumb extends StatefulWidget {
  final String source;
  final bool dark;

  const _CatalogVideoThumb({required this.source, required this.dark});

  @override
  State<_CatalogVideoThumb> createState() => _CatalogVideoThumbState();
}

class _CatalogVideoThumbState extends State<_CatalogVideoThumb> {
  Uint8List? _thumb;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    if (widget.source.isEmpty) return;
    final bytes = await VideoThumbnail.thumbnailData(
      video: widget.source,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 100,
      quality: 75,
    );
    if (mounted) setState(() { _thumb = bytes; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    if (_thumb != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(_thumb!, fit: BoxFit.cover),
          const Center(
            child: Icon(Icons.play_circle_fill, color: Colors.white70, size: 28),
          ),
        ],
      );
    }
    return Center(
      child: _loaded
          ? Icon(Icons.videocam, size: 40, color: Colors.grey.shade600)
          : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
