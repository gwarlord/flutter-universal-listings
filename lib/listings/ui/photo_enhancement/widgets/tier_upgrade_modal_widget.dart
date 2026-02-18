import 'package:flutter/material.dart';

/// Modal to upsell subscription tiers for enhanced features
class TierUpgradeModalWidget extends StatelessWidget {
  final String currentTier;
  final String requiredTier;
  final VoidCallback onUpgrade;
  final VoidCallback onDismiss;

  const TierUpgradeModalWidget({
    Key? key,
    required this.currentTier,
    required this.requiredTier,
    required this.onUpgrade,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final tierInfo = _getTierInfo(requiredTier);

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_fix_high,
              size: 48,
              color: Colors.blue[600],
            ),
            const SizedBox(height: 16),
            Text(
              tierInfo['title'] as String,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              tierInfo['description'] as String,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Premium Features:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(tierInfo['features'] as List<String>).map((feature) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle,
                              size: 14, color: Colors.green[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              feature,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDismiss,
                    child: const Text('Later'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onUpgrade,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Upgrade Now'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getTierInfo(String tier) {
    switch (tier) {
      case 'professional_plus':
        return {
          'title': 'Unlock Advanced Enhancements',
          'description': 'Upgrade to Professional Plus for more powerful tools',
          'features': [
            'Background cleanup & neutralization',
            'Subject isolation for sharper focus',
            'Studio-style professional backgrounds',
            'Multiple aspect ratio exports',
          ],
        };
      case 'professional_pro':
        return {
          'title': 'Professional Branding Tools',
          'description': 'Upgrade to Professional Pro for complete branding control',
          'features': [
            'Logo watermarking',
            'Custom position presets',
            'Opacity & transparency control',
            'Branded overlay templates',
            'All previous tier features',
          ],
        };
      default:
        return {
          'title': 'Professional AI Enhancement',
          'description': 'Upgrade to Professional to unlock AI photo enhancement',
          'features': [
            'Intelligent auto-crop & framing',
            'Lighting & clarity normalization',
            'Background blur & cleanup',
            'Batch processing capabilities',
          ],
        };
    }
  }
}
