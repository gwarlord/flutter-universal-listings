import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/services/menu_service.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/screens/menu/menu_builder_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

/// Menu Section Widget for Edit Listing Screen
class MenuEditSectionWidget extends StatefulWidget {
  final ListingModel listing;
  final VoidCallback onMenuUpdated;

  const MenuEditSectionWidget({
    Key? key,
    required this.listing,
    required this.onMenuUpdated,
  }) : super(key: key);

  @override
  State<MenuEditSectionWidget> createState() => _MenuEditSectionWidgetState();
}

class _MenuEditSectionWidgetState extends State<MenuEditSectionWidget> {
  late bool _menuEnabled;
  late String _menuMode;
  late List<Map<String, dynamic>> _menuUploads;
  late List<Map<String, dynamic>> _menuSections;
  
  final MenuService _menuService = MenuService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _menuEnabled = widget.listing.menuEnabled;
    _menuMode = widget.listing.menuMode;
    _menuUploads = List.from(widget.listing.menuUploads);
    _menuSections = List.from(widget.listing.menuSections);
  }

  Future<void> _toggleMenuEnabled(bool value) async {
    setState(() {
      _menuEnabled = value;
      _isLoading = true;
    });
    try {
      await _menuService.setMenuEnabled(widget.listing.id, value);
      widget.onMenuUpdated();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildMenuSection(BuildContext context) {
    final dark = isDarkMode(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Toggle
        SwitchListTile(
          value: _menuEnabled,
          onChanged: _isLoading ? null : _toggleMenuEnabled,
          title: Text(
            'Show Menu on Listing',
            style: TextStyle(
              color: dark ? Colors.white : Colors.black,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            _menuEnabled
                ? 'Menu is visible to customers'
                : 'Menu is hidden from customers',
            style: TextStyle(
              color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
              fontSize: 12,
            ),
          ),
          activeColor: Color(cfg.colorPrimary),
        ),
        const SizedBox(height: 16),

        // Menu options (visible when enabled)
        if (_menuEnabled) ...[
          // Option A: Upload Menu
          _buildMenuOptionCard(
            context,
            title: 'Upload Menu Photos',
            description: 'Upload 1-6 menu images',
            icon: Icons.image_outlined,
            onTap: () => _uploadMenuPhotos(context),
            count: _menuUploads.length,
            maxCount: 6,
          ),
          const SizedBox(height: 12),

          // Option B: Create Digital Menu
          _buildMenuOptionCard(
            context,
            title: 'Create Digital Menu',
            description: 'Build items with prices and descriptions',
            icon: Icons.restaurant_menu,
            onTap: () => _openMenuBuilder(context),
            count: _menuSections.length,
            maxCount: 20,
          ),
        ] else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? Colors.grey.shade800 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Menu hidden from customers',
                style: TextStyle(
                  color: dark ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
    );
  }

  Widget _buildMenuOptionCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
    required int count,
    required int maxCount,
  }) {
    final dark = isDarkMode(context);
    final isFull = count >= maxCount;

    return GestureDetector(
      onTap: isFull ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: dark ? Colors.grey.shade900 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFull
                ? Colors.grey.shade400
                : Color(cfg.colorPrimary),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isFull ? Colors.grey.shade400 : Color(cfg.colorPrimary),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: dark
                          ? Colors.grey.shade400
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isFull
                    ? Colors.grey.shade300
                    : Color(cfg.colorPrimary).withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '$count/$maxCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isFull
                      ? Colors.grey.shade600
                      : Color(cfg.colorPrimary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(
            'Menu (Food & Beverage)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(cfg.colorPrimary),
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (_isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(cfg.colorPrimary)),
              ),
            ),
          )
        else
          _buildMenuSection(context),
      ],
    );
  }

  Future<void> _openMenuBuilder(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MenuBuilderScreen(listing: widget.listing),
      ),
    );
    widget.onMenuUpdated();
  }

  Future<void> _uploadMenuPhotos(BuildContext context) async {
    if (_menuUploads.length >= 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Maximum 6 menu photos allowed')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();

    if (pickedFiles.isEmpty) return;

    final availableSlots = 6 - _menuUploads.length;
    final filesToUpload = pickedFiles.take(availableSlots).toList();

    setState(() => _isLoading = true);

    try {
      for (var pickedFile in filesToUpload) {
        final file = File(pickedFile.path);
        final url = await _menuService.uploadMenuUploadImage(
          widget.listing.id,
          file,
        );
        _menuUploads.add({
          'id': const Uuid().v4(),
          'url': url,
          'sortOrder': _menuUploads.length,
          'createdAt': Timestamp.now(),
        });
      }

      await _menuService.updateMenuUploads(widget.listing.id, _menuUploads);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uploaded ${filesToUpload.length} photo(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onMenuUpdated();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
