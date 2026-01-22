import 'package:flutter/material.dart';
import 'ad_upload_screen.dart';
import 'deals_feed_screen.dart';

class DealsPromotionScreen extends StatelessWidget {
  const DealsPromotionScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Deals & Promotions'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Post your deals, promotions, and ads here!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Upload New Ad'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => AdUploadScreen()),
                );
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.local_offer),
              label: const Text('View All Deals'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DealsFeedScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
