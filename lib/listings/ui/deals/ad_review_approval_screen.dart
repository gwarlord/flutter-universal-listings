import 'package:flutter/material.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';

class AdReviewApprovalScreen extends StatelessWidget {
  const AdReviewApprovalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Approve Ads'),
      ),
      body: StreamBuilder<List<DealAdModel>>(
        stream: DealAdService().getPendingAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return const Center(child: Text('No pending ads for review.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final ad = ads[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Lister: ${ad.listerId}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ad.mediaType == 'image'
                          ? Image.network(ad.mediaUrl, height: 160, fit: BoxFit.cover)
                          : const Icon(Icons.videocam, size: 48),
                      if (ad.caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(ad.caption),
                      ],
                      const SizedBox(height: 8),
                      Text('Duration: ${ad.durationDays} days'),
                      Text('Price: \$${ad.pricePaid.toStringAsFixed(2)}'),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            icon: const Icon(Icons.check, color: Colors.green),
                            label: const Text('Approve'),
                            onPressed: () async {
                              // TODO: Replace with actual reviewerId
                              await DealAdService().approveAd(ad.id, 'adminReviewer');
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad approved.')));
                            },
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            icon: const Icon(Icons.close, color: Colors.red),
                            label: const Text('Reject'),
                            onPressed: () async {
                              await DealAdService().rejectAd(ad.id, 'adminReviewer');
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad rejected.')));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
