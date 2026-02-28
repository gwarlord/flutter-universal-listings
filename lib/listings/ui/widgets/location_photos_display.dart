import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class LocationPhotosDisplay extends StatelessWidget {
  final String? exteriorImageUrl;
  final String? interiorImageUrl;
  final String? locationInstructions;
  final Function(String imageUrl, String title) onThumbnailTap;
  final bool isDark;

  const LocationPhotosDisplay({
    Key? key,
    this.exteriorImageUrl,
    this.interiorImageUrl,
    this.locationInstructions,
    required this.onThumbnailTap,
    required this.isDark,
  }) : super(key: key);

  bool get hasPhotos => (exteriorImageUrl != null && exteriorImageUrl!.isNotEmpty) ||
      (interiorImageUrl != null && interiorImageUrl!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    if (!hasPhotos) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // If width >= 700px (tablet/web), show vertical layout to the right
        if (constraints.maxWidth >= 700) {
          return _buildResponsiveLayout(context, isVertical: true);
        } else {
          // On mobile, show horizontal layout below
          return _buildResponsiveLayout(context, isVertical: false);
        }
      },
    );
  }

  Widget _buildResponsiveLayout(BuildContext context, {required bool isVertical}) {
    if (isVertical) {
      // Tablet/Web: vertical column (will be placed to the right of carousel in parent)
      return Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          if (exteriorImageUrl != null && exteriorImageUrl!.isNotEmpty)
            _buildThumbnail(
              imageUrl: exteriorImageUrl!,
              label: 'Exterior'.tr(),
              onTap: () => onThumbnailTap(exteriorImageUrl!, 'Exterior'.tr()),
            ),
          if (interiorImageUrl != null && interiorImageUrl!.isNotEmpty)
            _buildThumbnail(
              imageUrl: interiorImageUrl!,
              label: 'Interior'.tr(),
              onTap: () => onThumbnailTap(interiorImageUrl!, 'Interior'.tr()),
            ),
          if (locationInstructions != null && locationInstructions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                locationInstructions!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: null,
              ),
            ),
        ],
      );
    } else {
      // Mobile: horizontal row
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Location Photos'.tr(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                spacing: 12,
                children: [
                  if (exteriorImageUrl != null && exteriorImageUrl!.isNotEmpty)
                    _buildThumbnail(
                      imageUrl: exteriorImageUrl!,
                      label: 'Exterior'.tr(),
                      onTap: () => onThumbnailTap(exteriorImageUrl!, 'Exterior'.tr()),
                    ),
                  if (interiorImageUrl != null && interiorImageUrl!.isNotEmpty)
                    _buildThumbnail(
                      imageUrl: interiorImageUrl!,
                      label: 'Interior'.tr(),
                      onTap: () => onThumbnailTap(interiorImageUrl!, 'Interior'.tr()),
                    ),
                ],
              ),
            ),
            if (locationInstructions != null && locationInstructions!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Finding Instructions'.tr(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                locationInstructions!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  height: 1.4,
                ),
                maxLines: null,
              ),
            ],
          ],
        ),
      );
    }
  }

  Widget _buildThumbnail({
    required String imageUrl,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Center(
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                          size: 32,
                        ),
                      );
                    },
                  ),
                  // Tap overlay hint
                  Positioned.fill(
                    child: Material(
                      color: Colors.black26,
                      child: InkWell(
                        onTap: onTap,
                        child: Center(
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.white70,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}
