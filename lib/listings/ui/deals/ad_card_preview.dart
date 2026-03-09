import 'dart:io';
import 'package:flutter/material.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:video_player/video_player.dart';

/// Reusable ad card preview widget that renders exactly as ads appear in-app
/// Can accept either a DealAdModel (for existing ads) or manual parameters (for draft preview)
class AdCardPreview extends StatefulWidget {
  final DealAdModel? ad;
  
  // Draft mode parameters (used when ad is not yet saved)
  final File? mediaFile;
  final String? mediaUrl;
  final String? mediaType;
  final String? caption;
  final String? thumbnailUrl;
  final String? redemptionType;
  final int? redemptionLimitTotal;
  final int? redemptionLimitPerUser;
  final String? promoCode;
  
  final bool showBorder;
  final VoidCallback? onTap;

  const AdCardPreview({
    Key? key,
    this.ad,
    this.mediaFile,
    this.mediaUrl,
    this.mediaType,
    this.caption,
    this.thumbnailUrl,
    this.redemptionType,
    this.redemptionLimitTotal,
    this.redemptionLimitPerUser,
    this.promoCode,
    this.showBorder = true,
    this.onTap,
  }) : super(key: key);

  @override
  State<AdCardPreview> createState() => _AdCardPreviewState();
}

class _AdCardPreviewState extends State<AdCardPreview> {
  VideoPlayerController? _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void didUpdateWidget(AdCardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_needsVideoReinit(oldWidget)) {
      _disposeVideo();
      _initializeVideo();
    }
  }

  bool _needsVideoReinit(AdCardPreview oldWidget) {
    if (_getMediaType() != 'video') return false;
    return widget.mediaFile != oldWidget.mediaFile ||
        widget.mediaUrl != oldWidget.mediaUrl ||
        widget.ad?.mediaUrl != oldWidget.ad?.mediaUrl;
  }

  void _initializeVideo() {
    final mediaType = _getMediaType();
    if (mediaType != 'video') return;

    if (widget.mediaFile != null) {
      _controller = VideoPlayerController.file(widget.mediaFile!);
    } else {
      final url = widget.ad?.mediaUrl ?? widget.mediaUrl;
      if (url != null && url.isNotEmpty) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
    }

    _controller?.initialize().then((_) {
      if (mounted) {
        setState(() => _initialized = true);
        _controller?.setLooping(true);
        _controller?.setVolume(0);
        _controller?.play();
      }
    });
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  String _getMediaType() {
    return widget.ad?.mediaType ?? widget.mediaType ?? 'image';
  }

  String _getCaption() {
    return widget.ad?.caption ?? widget.caption ?? '';
  }

  Widget _buildMediaWidget(BuildContext context) {
    final mediaType = _getMediaType();
    
    if (mediaType == 'video') {
      if (_controller != null && _initialized) {
        return AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        );
      } else {
        return Container(
          height: 200,
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator()),
        );
      }
    } else {
      // Image
      if (widget.mediaFile != null) {
        return Image.file(widget.mediaFile!, fit: BoxFit.cover, height: 200);
      } else {
        final url = widget.ad?.mediaUrl ?? widget.mediaUrl;
        if (url != null && url.isNotEmpty) {
          return Image.network(url, fit: BoxFit.cover, height: 200);
        } else {
          return Container(
            height: 200,
            color: Colors.grey[300],
            child: const Icon(Icons.image, size: 48, color: Colors.grey),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final caption = _getCaption();
    final primaryColor = Color(colorPrimary);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: widget.showBorder
              ? Border.all(color: primaryColor.withOpacity(0.3), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sponsored badge
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.campaign, size: 12, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          'Sponsored',
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Media
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(0)),
              child: _buildMediaWidget(context),
            ),
            
            // Caption
            if (caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  caption,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // Redemption/Claim Info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: _buildRedemptionInfo(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionInfo(BuildContext context) {
    final ad = widget.ad;
    String? redemptionType;
    int? redemptionLimitTotal;
    int? redemptionLimitPerUser;
    String? promoCode;

    if (ad != null) {
      redemptionType = ad.redemptionType;
      redemptionLimitTotal = ad.redemptionLimitTotal;
      redemptionLimitPerUser = ad.redemptionLimitPerUser;
      promoCode = ad.promoCode;
    } else {
      // Draft mode
      redemptionType = widget.redemptionType;
      redemptionLimitTotal = widget.redemptionLimitTotal;
      redemptionLimitPerUser = widget.redemptionLimitPerUser;
      promoCode = widget.promoCode;
    }

    if (redemptionType == null) return SizedBox.shrink();

    List<Widget> info = [];
    if (redemptionType == 'PROMO_CODE') {
      info.add(Row(
        children: [
          Icon(Icons.confirmation_number, size: 16, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 6),
          Text('Promo Code', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ));
      if (promoCode != null && promoCode.isNotEmpty) {
        info.add(Text('Code: $promoCode'));
      }
      if (redemptionLimitTotal != null) {
        info.add(Text('Total Uses: $redemptionLimitTotal'));
      }
      if (redemptionLimitPerUser != null) {
        info.add(Text('Per User: $redemptionLimitPerUser'));
      }
    }
    if (info.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: info,
    );
  }
}
