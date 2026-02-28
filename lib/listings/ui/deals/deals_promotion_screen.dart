import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/deal_ad_quota.dart';
import 'package:caribtap/listings/services/deal_ad_quota_manager.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'ad_upload_screen.dart';
import 'deals_feed_screen.dart';

class DealsPromotionScreen extends StatefulWidget {
  const DealsPromotionScreen({Key? key}) : super(key: key);

  @override
  State<DealsPromotionScreen> createState() => _DealsPromotionScreenState();
}

class _DealsPromotionScreenState extends State<DealsPromotionScreen> {
  late Future<Map<String, String>> _quotaData;

  @override
  void initState() {
    super.initState();
    final authBloc = context.read<AuthenticationBloc>();
    final user = authBloc.user;
    
    if (user != null) {
      final tier = DealAdQuota.normalizeTier(user.subscriptionTier);
      _quotaData = _loadQuotaData(user.userID, tier);
    } else {
      _quotaData = Future.value({'usage': '0/0', 'resetDate': ''});
    }
  }

  Future<Map<String, String>> _loadQuotaData(String userId, String subscriptionTier) async {
    final quotaManager = DealAdQuotaManager();
    final usage = await quotaManager.getUsageString(userId, subscriptionTier);
    final resetDate = await quotaManager.getResetDateString(userId, subscriptionTier);
    return {'usage': usage, 'resetDate': resetDate};
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final authBloc = context.read<AuthenticationBloc>();
    final user = authBloc.user;

    final tier = DealAdQuota.normalizeTier(user?.subscriptionTier);
    final canPostAds = user != null && 
        (tier == 'professional' || tier == 'premium');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deals & Promotions'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Quota Card (show for pro/premium users)
            if (canPostAds)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildQuotaCard(context, isDark, primaryColor, user!),
              ),
            // Upgrade Card (show for free users)
            if (!canPostAds)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: _buildUpgradeCard(context, isDark, primaryColor),
              ),
            // Main Content
            Padding(
              padding: const EdgeInsets.all(20.0),
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
                    onPressed: canPostAds ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AdUploadScreen()),
                      );
                    } : null,
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
          ],
        ),
      ),
    );
  }

  Widget _buildQuotaCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
    dynamic user,
  ) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Card(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.card_membership, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ad Posting Quota',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        '${user.subscriptionTier?.toUpperCase() ?? 'FREE'} Tier',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FutureBuilder<Map<String, String>>(
              future: _quotaData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SizedBox(
                    height: 60,
                    child: Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    ),
                  );
                }

                final usage = snapshot.data?['usage'] ?? '0/0';
                final resetDate = snapshot.data?['resetDate'] ?? '';
                final parts = usage.split('/');
                final current = int.tryParse(parts.isNotEmpty ? parts[0] : '0') ?? 0;
                final max = int.tryParse(parts.length > 1 ? parts[1] : '1') ?? 1;
                final percentage = max > 0 ? (current / max).toDouble() : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Usage Display
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Posts this month',
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        Text(
                          usage,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 8,
                        backgroundColor: isDark ? Colors.white24 : Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          percentage < 0.5
                              ? Colors.green
                              : percentage < 0.8
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Reset Info
                    if (resetDate.isNotEmpty)
                      Text(
                        'Resets on $resetDate',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpgradeCard(
    BuildContext context,
    bool isDark,
    Color primaryColor,
  ) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return Card(
      color: primaryColor.withOpacity(0.1),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lock, color: primaryColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upgrade to Post Ads',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'You\'re on the Free plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Professional plan: 10 ads/month\nPremium plan: 20 ads/month',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Also requires at least one active listing.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
