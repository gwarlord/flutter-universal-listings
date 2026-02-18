import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/models/menu_models.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/core/utils/helper.dart';

/// Shows a preview of the first 3 items across all sections
class MenuPreviewWidget extends StatelessWidget {
  final List<MenuSection> sections;
  final String? currencyCode;
  final VoidCallback onViewFullMenu;

  const MenuPreviewWidget({
    Key? key,
    required this.sections,
    this.currencyCode,
    required this.onViewFullMenu,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);
    final previewItems = _getPreviewItems();

    if (previewItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Menu Preview'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: dark ? Colors.white : Colors.black,
            ),
          ),
        ),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: previewItems.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => _buildItemCard(context, previewItems[index]),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onViewFullMenu,
              child: Text('View Full Menu'.tr()),
            ),
          ),
        ),
      ],
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.photos.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item.photos.first.url,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.image),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: dark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$currencySymbol${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(cfg.colorPrimary),
                      ),
                    ),
                  ],
                ),
                if (item.description != null && item.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: dark ? Colors.grey.shade400 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                if (item.tags != null && item.tags!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 6,
                      children: item.tags!
                          .take(2)
                          .map(
                            (tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Color(cfg.colorPrimary).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                tag.tr(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(cfg.colorPrimary),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<MenuItem> _getPreviewItems() {
    final items = <MenuItem>[];
    for (final section in sections) {
      items.addAll(section.items.where((item) => item.isAvailable));
      if (items.length >= 3) break;
    }
    return items.take(3).toList();
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
