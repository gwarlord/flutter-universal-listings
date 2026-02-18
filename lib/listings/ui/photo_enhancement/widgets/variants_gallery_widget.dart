import 'package:caribtap/listings/ui/photo_enhancement/models/models.dart';
import 'package:caribtap/listings/ui/photo_enhancement/widgets/variant_card_widget.dart';
import 'package:flutter/material.dart';

/// Gallery view of all image variants for a listing
class VariantsGalleryWidget extends StatelessWidget {
  final List<ImageVariant> variants;
  final EnhancementQuota quota;
  final Function(ImageVariant) onVariantTap;
  final Function(ImageVariant) onDelete;
  final Function(ImageVariant) onPublish;
  final Function(ImageVariant) onRate;
  final bool isLoading;

  const VariantsGalleryWidget({
    Key? key,
    required this.variants,
    required this.quota,
    required this.onVariantTap,
    required this.onDelete,
    required this.onPublish,
    required this.onRate,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (variants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No enhanced variants yet',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enhance your first photo to see it here',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Enhanced Variants (${variants.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    quota.getQuotaStatusString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[900],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...variants.map((variant) {
            return VariantCardWidget(
              variant: variant,
              onTap: () => onVariantTap(variant),
              onDelete: () => onDelete(variant),
              onPublish: !variant.isPublished ? () => onPublish(variant) : null,
              onRate: () => onRate(variant),
            );
          }).toList(),
        ],
      ),
    );
  }
}
