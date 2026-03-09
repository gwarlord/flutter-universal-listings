
import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/deal_ad_admin_service.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/ui/profile/profile/_dialog_video_player.dart';
import 'package:caribtap/listings/ui/deals/ad_review_screen.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:caribtap/core/utils/helper.dart';

// Widget to show a video thumbnail (from URL or generated)
class _VideoThumbnailWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  const _VideoThumbnailWidget({Key? key, required this.videoUrl, this.thumbnailUrl}) : super(key: key);

  @override
  State<_VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<_VideoThumbnailWidget> {
  Uint8List? _thumb;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadThumb();
  }

  Future<void> _loadThumb() async {
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) return;
    setState(() => _loading = true);
    try {
      final thumb = await VideoThumbnail.thumbnailData(
        video: widget.videoUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 128,
        quality: 50,
      );
      if (mounted) setState(() => _thumb = thumb);
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.network(widget.thumbnailUrl!, width: 48, height: 48, fit: BoxFit.cover),
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 20),
        ],
      );
    }
    if (_thumb != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          Image.memory(_thumb!, width: 48, height: 48, fit: BoxFit.cover),
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 20),
        ],
      );
    }
    return Container(
      width: 48,
      height: 48,
      color: isDark ? Colors.white10 : Colors.black12,
      child: _loading
          ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
          : Icon(
              Icons.videocam,
              size: 32,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
    );
  }
}


class AdApprovalScreen extends StatefulWidget {
  final ListingsUser currentUser;
  const AdApprovalScreen({Key? key, required this.currentUser}) : super(key: key);

  @override
  State<AdApprovalScreen> createState() => _AdApprovalScreenState();
}



class _AdApprovalScreenState extends State<AdApprovalScreen> {
  late DealAdAdminService _dealAdAdminService;
  final Map<String, ListingsUser?> _listerCache = {};

  @override
  void initState() {
    super.initState();
    _dealAdAdminService = DealAdAdminService();
  }

  Future<ListingsUser?> _fetchLister(String listerId) async {
    if (_listerCache.containsKey(listerId)) {
      return _listerCache[listerId];
    }
    try {
      final user = await DealAdService().getUser(listerId);
      _listerCache[listerId] = user;
      return user;
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final titleColor = theme.colorScheme.onSurface;
    final subtitleColor = theme.colorScheme.onSurface.withOpacity(0.7);

    return Scaffold(
      appBar: AppBar(title: Text('Ad Approval'.tr())),
      body: StreamBuilder<List<DealAdModel>>(
        stream: _dealAdAdminService.getPendingAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return Center(child: Text('No pending ads'.tr()));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: ads.length,
            itemBuilder: (context, index) {
              final ad = ads[index];
              return FutureBuilder<ListingsUser?>(
                future: _fetchLister(ad.listerId),
                builder: (context, snapshot) {
                  final lister = snapshot.data;
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: theme.colorScheme.surface,
                    child: ListTile(
                      onTap: () => _openAdDetails(ad),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      leading: ad.mediaUrl.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                if (ad.mediaType == 'image') {
                                  _showFullImage(ad.mediaUrl);
                                } else {
                                  _showFullVideo(ad.mediaUrl);
                                }
                              },
                              child: ad.mediaType == 'image'
                                  ? Image.network(ad.mediaUrl, width: 48, height: 48, fit: BoxFit.cover)
                                  : _VideoThumbnailWidget(videoUrl: ad.mediaUrl, thumbnailUrl: ad.thumbnailUrl),
                            )
                          : const Icon(Icons.image, size: 48),
                      // ...existing code...
                      title: Text(
                        ad.caption.isNotEmpty
                            ? ad.caption
                            : (lister != null
                                ? (lister.fullName().isNotEmpty ? lister.fullName() : lister.email)
                                : 'Unknown User'),
                        maxLines: null,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: titleColor,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          [
                            'Duration: ${ad.durationDays} days',
                            'Type: ${ad.adType == 'promo' ? 'Promotion' : 'Advert'}',
                            if (lister != null)
                              'Lister: ${lister.fullName().isNotEmpty ? lister.fullName() : lister.email}',
                          ].join('\n'),
                          style: TextStyle(color: subtitleColor),
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () async {
                              try {
                                await _dealAdAdminService.approveAd(ad.id!, widget.currentUser.userID);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ad approved'.tr())),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to approve ad: $e')), // Show error
                                );
                              }
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () async {
                              try {
                                await _dealAdAdminService.rejectAd(ad.id!, widget.currentUser.userID);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Ad rejected'.tr())),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to reject ad: $e')), // Show error
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _openAdDetails(DealAdModel ad) {
    push(
      context,
      AdReviewScreen(
        existingMediaUrl: ad.mediaUrl,
        existingThumbnailUrl: ad.thumbnailUrl,
        mediaType: ad.mediaType,
        caption: ad.caption,
        adDays: ad.durationDays,
        promoStartDate: ad.adType == 'promo' ? ad.startDate : null,
        promoEndDate: ad.adType == 'promo' ? ad.endDate : null,
        adType: ad.adType,
        selectedCountryCodes: ad.visibilityCountries,
        targeting: ad.targeting,
        pricePaid: ad.pricePaid,
        redemptionType: ad.redemptionType,
        promoCode: ad.promoCode,
        redemptionLimitTotal: ad.redemptionLimitTotal,
        redemptionLimitPerUser: ad.redemptionLimitPerUser,
        expireAt: ad.expireAt,
        scheduleAt: ad.scheduleAt,
        listerId: ad.listerId,
        listingId: ad.listingId,
        adToEdit: ad,
        readOnly: true,
        screenTitle: 'Review Pending Ad'.tr(),
        instructionText: 'Review how this ad will appear to users before approving or rejecting it.'.tr(),
      ),
    );
  }

  Future<VideoPlayerController> _initVideoController(String url, {bool autoPlay = false}) async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    await controller.initialize();
    controller.setLooping(true);
    if (autoPlay) controller.play();
    return controller;
  }

  void _showFullImage(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullVideo(String videoUrl) {
    final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    showDialog(
      context: context,
      builder: (context) => DialogVideoPlayer(controller: controller),
    );
  }
}
