import 'package:flutter/material.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'share_ad_widget.dart';

class DealsFeedScreen extends StatelessWidget {
  const DealsFeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Latest Deals & Promotions'),
        centerTitle: true,
      ),
      body: StreamBuilder<List<DealAdModel>>(
        stream: DealAdService().getApprovedAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return const Center(child: Text('No deals or promotions available.'));
          }
          return PageView.builder(
            itemCount: ads.length,
            controller: PageController(viewportFraction: 1),
            itemBuilder: (context, i) {
              final ad = ads[i];
              return Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: Stack(
                  children: [
                    Center(
                      child: ad.mediaType == 'image'
                          ? Image.network(ad.mediaUrl, fit: BoxFit.contain, width: double.infinity, height: double.infinity)
                          : const Icon(Icons.videocam, color: Colors.white, size: 120), // TODO: Video player
                    ),
                    Positioned(
                      top: 40,
                      right: 24,
                      child: ShareAdWidget(adTitle: ad.caption, adUrl: ad.mediaUrl),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.black.withOpacity(0.7),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ad.caption,
                              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Runs until: ' + ad.endDate.toLocal().toString().split(' ')[0],
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
