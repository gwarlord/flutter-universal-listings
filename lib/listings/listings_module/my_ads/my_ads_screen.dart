import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart'; // Assuming this service exists
import 'package:instaflutter/listings/ui/deals/ad_upload_screen.dart'; // For editing ads

class MyAdsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const MyAdsScreen({super.key, required this.currentUser});

  @override
  State<MyAdsScreen> createState() => _MyAdsScreenState();
}

class _MyAdsScreenState extends State<MyAdsScreen> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('My Ads'.tr()),
        centerTitle: true,
        backgroundColor: Color(cfg.colorPrimary),
      ),
      body: StreamBuilder<List<DealAdModel>>(
        stream: DealAdService().getAdsByUserId(widget.currentUser.userID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'.tr()));
          }
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.campaign_outlined, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 24),
                    Text(
                      'No Ads Yet'.tr(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You haven't posted any advertisements. Tap the button below to create your first ad!'.tr(),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => push(context, AdUploadScreen()),
                      icon: const Icon(Icons.add_rounded),
                      label: Text('Post New Ad'.tr()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(cfg.colorPrimary),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 2,
                child: ListTile(
                  leading: ad.mediaType == 'image'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: displayImage(ad.mediaUrl, width: 60, height: 60),
                        )
                      : const Icon(Icons.videocam, size: 40),
                  title: Text(ad.caption, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                      '${DateFormat('MMM d').format(ad.startDate)} - ${DateFormat('MMM d, yyyy').format(ad.endDate)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          push(context, AdUploadScreen(adToEdit: ad));
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _confirmDelete(context, ad),
                      ),
                    ],
                  ),
                  onTap: () {
                    // Optionally navigate to a full ad detail view if you have one
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => push(context, AdUploadScreen()),
        label: Text('Post New Ad'.tr()),
        icon: const Icon(Icons.add),
        backgroundColor: Color(cfg.colorPrimary),
        foregroundColor: Colors.white,
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, DealAdModel ad) async {
    final bool isDark = isDarkMode(context);
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text(
          'Delete Ad?'.tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to permanently remove this advertisement?'.tr(),
          style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete'.tr()),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Perform deletion
      await DealAdService().deleteAd(ad.id);
      if (mounted) {
        showSnackBar(context, 'Ad deleted successfully'.tr());
      }
    }
  }
}
