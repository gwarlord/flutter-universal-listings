import 'package:flutter/material.dart';
import 'package:caribtap/listings/ai_search/models/search_result.dart';
import 'package:caribtap/listings/ai_search/ui/widgets/explainability_chip.dart';
import 'package:caribtap/listings/ai_search/utils/search_helpers.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Card widget for displaying search results
class SearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const SearchResultCard({
    Key? key,
    required this.result,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final listing = result.listing;
    final deal = result.deal;

    if (listing == null && deal == null) {
      return const SizedBox.shrink();
    }

    final title = result.title;
    final photoUrl = listing?.photo ?? deal?.mediaUrl ?? '';
    final description = listing?.description ?? deal?.caption ?? '';
    final rating = listing != null && listing.reviewsCount > 0
        ? (listing.reviewsSum / listing.reviewsCount)
        : null;
    final reviewCount = listing?.reviewsCount ?? 0;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placeholderColor = isDark ? Colors.grey[700] : Colors.grey[300];
    final iconColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final textSecondaryColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final descriptionColor = isDark ? Colors.grey[400] : Colors.grey[700];
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: photoUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: photoUrl,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: placeholderColor,
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: placeholderColor,
                          child: const Icon(Icons.image_not_supported),
                        ),
                      )
                    : Container(
                        width: 100,
                        height: 100,
                        color: placeholderColor,
                        child: Icon(
                          Icons.image,
                          size: 40,
                          color: iconColor,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Rating
                    if (rating != null && reviewCount > 0)
                      Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            ' ($reviewCount)',
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: descriptionColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Explainability chips
                    if (result.explainabilityChips.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: result.explainabilityChips.take(3).map((chip) {
                          return ExplainabilityChipWidget(chip: chip);
                        }).toList(),
                      ),

                    // Distance
                    if (result.distance != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, 
                              size: 14, 
                              color: textSecondaryColor),
                          const SizedBox(width: 2),
                          Text(
                            SearchHelpers.formatDistance(result.distance),
                            style: TextStyle(
                              fontSize: 12,
                              color: textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
