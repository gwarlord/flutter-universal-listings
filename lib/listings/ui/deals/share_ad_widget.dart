import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:caribtap/listings/listings_app_config.dart';

class ShareAdWidget extends StatelessWidget {
  final String adTitle;
  final String adUrl;
  final String adId;
  final String listingId;

  const ShareAdWidget({
    Key? key,
    required this.adTitle,
    required this.adUrl,
    required this.adId,
    required this.listingId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const ValueKey('share_ad_button'),
      icon: const Icon(Icons.share, color: Colors.white, size: 28),
      onPressed: () {
        // Only use the listing deep link if listingId is a real Firestore document ID
        // (not a placeholder like 'demoListingId' or an empty string).
        final isRealListingId = listingId.isNotEmpty &&
            !listingId.toLowerCase().contains('demo') &&
            listingId.length > 10;
        final String appLink = isRealListingId
            ? 'https://caribtap.com/l/$listingId'
            : 'https://caribtap.com';
        final String shareMessage = 'Check out this deal on CaribTap: $adTitle\n\n$appLink';

        // Provide a share origin for iOS so the share sheet popover has a valid anchor.
        final RenderBox? box = context.findRenderObject() as RenderBox?;
        final Rect? origin = box != null && box.hasSize
            ? box.localToGlobal(Offset.zero) & box.size
            : null;
        final size = MediaQuery.sizeOf(context);
        final safeOrigin = (origin != null && origin.width > 0 && origin.height > 0)
            ? origin
            : Rect.fromCenter(
                center: Offset(size.width / 2, size.height / 2),
                width: 1,
                height: 1,
              );

        Share.share(
          shareMessage,
          sharePositionOrigin: safeOrigin,
        );
      },
      tooltip: 'Share',
    );
  }
}
