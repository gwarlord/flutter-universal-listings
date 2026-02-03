import 'package:flutter/material.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/models/menu_models.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';
import 'menu_preview_widget.dart';
import 'menu_details_widget.dart';
import '../../screens/menu/menu_photos_viewer_screen.dart';

/// Main menu section widget for Listing Details
/// Shows either uploaded menu photos, digital menu, or both with tabs
class MenuSectionWidget extends StatefulWidget {
  final ListingModel listing;

  const MenuSectionWidget({
    Key? key,
    required this.listing,
  }) : super(key: key);

  @override
  State<MenuSectionWidget> createState() => _MenuSectionWidgetState();
}

class _MenuSectionWidgetState extends State<MenuSectionWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showPreview = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _getTabCount(),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  int _getTabCount() {
    final hasUploads = widget.listing.menuUploads.isNotEmpty;
    final hasSections = widget.listing.menuSections.isNotEmpty;
    if (hasUploads && hasSections) return 2;
    return 1;
  }

  bool _shouldShow() {
    if (!widget.listing.menuEnabled) return false;
    return widget.listing.menuUploads.isNotEmpty ||
        widget.listing.menuSections.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow()) {
      return const SizedBox.shrink();
    }

    final dark = isDarkMode(context);
    final hasUploads = widget.listing.menuUploads.isNotEmpty;
    final hasSections = widget.listing.menuSections.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Color(cfg.colorPrimary),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Menu',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: dark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Tabs if both exist
        if (hasUploads && hasSections)
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Digital Menu'),
              Tab(text: 'Menu Photos'),
            ],
          ),

        // Content
        if (hasSections && (!hasUploads || _tabController.index == 0))
          _buildDigitalMenuContent(context)
        else if (hasUploads)
          _buildPhotoMenuContent(context),
      ],
    );
  }

  Widget _buildDigitalMenuContent(BuildContext context) {
    final sections = widget.listing.menuSections
        .map((e) => MenuSection.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (_showPreview && sections.isNotEmpty) {
      return MenuPreviewWidget(
        sections: sections,
        currencyCode: widget.listing.menuCurrencyCode,
        onViewFullMenu: () => _showFullMenuDialog(context, sections),
      );
    }

    return SizedBox(
      height: 400,
      child: MenuDetailsWidget(
        sections: sections,
        currencyCode: widget.listing.menuCurrencyCode,
      ),
    );
  }

  Widget _buildPhotoMenuContent(BuildContext context) {
    final uploads = widget.listing.menuUploads
        .map((e) => MenuUpload.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: uploads.length,
            itemBuilder: (context, index) {
              final upload = uploads[index];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuPhotosViewerScreen(
                      photoUrls: uploads.map((u) => u.url).toList(),
                      initialIndex: index,
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    upload.thumbUrl ?? upload.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.image),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showFullMenuDialog(BuildContext context, List<MenuSection> sections) {
    final dark = isDarkMode(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Full Menu',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: dark ? Colors.white : Colors.black,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: MenuDetailsWidget(
                sections: sections,
                currencyCode: widget.listing.menuCurrencyCode,
              ),
            ),
          ],
        ),
      ),
    );
  }
}