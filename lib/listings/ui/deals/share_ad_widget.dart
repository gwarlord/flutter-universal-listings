import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:instaflutter/listings/listings_app_config.dart';

class ShareAdWidget extends StatelessWidget {
  final String adTitle;
  final String adUrl;
  final String adId;

  const ShareAdWidget({
    Key? key,
    required this.adTitle,
    required this.adUrl,
    required this.adId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.share, color: Colors.white, size: 28),
      onPressed: () {
        // Construct the sharing message
        // In a real scenario, this would be a deep link URL
        final String appLink = "https://caribtap.page.link/ad/$adId"; 
        final String shareMessage = "Check out this deal on CaribTap: $adTitle\n\n$appLink";

        Share.share(shareMessage);
      },
      tooltip: 'Share',
    );
  }
}
