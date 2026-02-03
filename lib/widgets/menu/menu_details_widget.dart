import 'package:flutter/material.dart';
import 'package:instaflutter/models/menu_models.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/core/utils/helper.dart';

/// Displays full digital menu with sections and items
class MenuDetailsWidget extends StatefulWidget {
  final List<MenuSection> sections;
  final String? currencyCode;

  const MenuDetailsWidget({
    Key? key,
    required this.sections,
    this.currencyCode,
  }) : super(key: key);

  @override
  State<MenuDetailsWidget> createState() => _MenuDetailsWidgetState();
}

class _MenuDetailsWidgetState extends State<MenuDetailsWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: widget.sections.length,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    if (widget.sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No menu items available',
            style: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Section tabs
        TabBar(
          controller: _tabController,
          isScrollable: true,
          unselectedLabelColor: dark ? Colors.white : null,
          tabs: widget.sections
              .map((section) => Tab(text: section.title))
              .toList(),
        ),
        const SizedBox(height: 16),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: widget.sections
                .map((section) => _buildSectionContent(context, section))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionContent(BuildContext context, MenuSection section) {
    final dark = isDarkMode(context);

    if (section.items.isEmpty) {
      return Center(
        child: Text(
          'No items in this section',
          style: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade600),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: section.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) =>
          _buildItemCard(context, section.items[index]),
    );
  }

  Widget _buildItemCard(BuildContext context, MenuItem item) {
    final dark = isDarkMode(context);
    final currencySymbol = _getCurrencySymbol(item.currencyCode);

    return Container(
      decoration: BoxDecoration(
        color: dark ? Colors.grey.shade900 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: dark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header with name and price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: dark ? Colors.white : Colors.black,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.description != null && item.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          item.description!,
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                dark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$currencySymbol${item.price.toStringAsFixed(2)}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Color(cfg.colorPrimary),
                ),
              ),
            ],
          ),

          // Tags
          if (item.tags != null && item.tags!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: item.tags!
                    .map(
                      (tag) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Color(cfg.colorPrimary).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(cfg.colorPrimary),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

          // Photos
          if (item.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: item.photos
                      .map(
                        (photo) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              photo.url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 100,
                                height: 100,
                                color: Colors.grey.shade300,
                                child: const Icon(Icons.image),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),

          // Availability status
          if (!item.isAvailable)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Currently unavailable',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _getCurrencySymbol(String currencyCode) {
    const symbols = {
      'USD': r'$',
      'XCD': r'$',
      'JMD': r'$',
      'TTD': r'$',
      'BSD': r'$',
      'BBD': r'$',
      'GYD': r'$',
      'HTG': 'G',
      'DOP': r'$',
      'KYD': r'$',
      'ANG': 'ƒ',
      'SRD': r'$',
      'XOF': 'CFA',
      'EUR': '€',
      'GBP': '£',
    };
    return symbols[currencyCode] ?? currencyCode;
  }
}
