import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';

enum FeedItemType { listing, event }

class FeedItem {
  final FeedItemType type;
  final ListingModel? listing;
  final EventModel? event;

  const FeedItem._({
    required this.type,
    this.listing,
    this.event,
  });

  factory FeedItem.listing(ListingModel listing) {
    return FeedItem._(type: FeedItemType.listing, listing: listing);
  }

  factory FeedItem.event(EventModel event) {
    return FeedItem._(type: FeedItemType.event, event: event);
  }
}
