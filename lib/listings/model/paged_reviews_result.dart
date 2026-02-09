import 'package:instaflutter/listings/model/listing_review_model.dart';

/// Represents a page of reviews with pagination metadata
class PagedReviewsResult {
  final List<ListingReviewModel> reviews;
  final int? nextCursorCreatedAt;
  final bool hasMore;

  PagedReviewsResult({
    required this.reviews,
    this.nextCursorCreatedAt,
    required this.hasMore,
  });

  PagedReviewsResult.empty()
      : reviews = [],
        nextCursorCreatedAt = null,
        hasMore = false;
}
