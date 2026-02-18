import 'package:flutter/material.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/model/listings_user.dart'; 
import 'package:intl/intl.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:caribtap/core/utils/helper.dart'; // Import helper for isDarkMode

class AdReviewApprovalScreen extends StatelessWidget {
  const AdReviewApprovalScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : null, // Explicit dark background for Scaffold
      appBar: AppBar(
        title: Text('Review & Approve Ads', style: TextStyle(color: isDark ? Colors.white : Colors.black)), // Adaptive title color
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : null, // Explicit dark background for AppBar
        foregroundColor: isDark ? Colors.white : Colors.black, // AppBar title/icon color
      ),
      body: StreamBuilder<List<DealAdModel>>(
        stream: DealAdService().getPendingAds(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final ads = snapshot.data ?? [];
          if (ads.isEmpty) {
            return const Center(child: Text('No pending ads for review.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, i) {
              final ad = ads[i];
              return _AdDisplayCard(ad: ad);
            },
          );
        },
      ),
    );
  }
}

class _AdDisplayCard extends StatefulWidget {
  final DealAdModel ad;

  const _AdDisplayCard({Key? key, required this.ad}) : super(key: key);

  @override
  State<_AdDisplayCard> createState() => _AdDisplayCardState();
}

class _AdDisplayCardState extends State<_AdDisplayCard> {
  ListingsUser? _lister;

  @override
  void initState() {
    super.initState();
    _fetchLister();
  }

  Future<void> _fetchLister() async {
    final lister = await DealAdService().getUser(widget.ad.listerId);
    if (mounted) {
      setState(() {
        _lister = lister;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final reviewerId = context.read<AuthenticationBloc>().user?.userID ?? 'anonymousReviewer';
    final isDark = isDarkMode(context);
    final adaptiveTextColor = isDark ? Colors.white : Colors.black87;
    final adaptiveSubtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    Widget mediaWidget;
    if (widget.ad.mediaType == 'image') {
      mediaWidget = Image.network(
        widget.ad.mediaUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          height: 200,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
          child: Icon(Icons.broken_image, size: 50, color: isDark ? Colors.grey[400] : Colors.grey),
        ),
      );
    } else { // It's a video
      if (widget.ad.thumbnailUrl != null && widget.ad.thumbnailUrl!.isNotEmpty) {
        mediaWidget = Image.network(
          widget.ad.thumbnailUrl!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
            child: Icon(Icons.video_file, size: 50, color: isDark ? Colors.grey[400] : Colors.grey),
          ),
        );
      } else {
        mediaWidget = Container(
          height: 200,
          color: isDark ? Colors.grey[700] : Colors.grey[300],
          child: Icon(Icons.video_file, size: 50, color: isDark ? Colors.grey[400] : Colors.grey),
        );
      }
    }

    return Card(
      elevation: 0, // Set elevation to 0 for a flat look in dark mode
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white, // Explicit dark card background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lister Info
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _lister?.profilePictureURL != null && _lister!.profilePictureURL.isNotEmpty 
                      ? NetworkImage(_lister!.profilePictureURL) : null,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[200], // Adaptive background for avatar
                  child: _lister?.profilePictureURL == null || _lister!.profilePictureURL.isEmpty 
                      ? Icon(Icons.account_circle, size: 40, color: isDark ? Colors.grey[400] : Colors.grey[600]) : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lister?.fullName() ?? 'Unknown Lister', // Fallback for lister name
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: adaptiveTextColor),
                    ),
                    Text(
                      'Submitted on: ${DateFormat('MMM dd, yyyy - hh:mm a').format(widget.ad.createdAt)}',
                      style: TextStyle(color: adaptiveSubtitleColor, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 24, color: isDark ? Colors.grey[600] : Colors.grey[300]), // Adaptive divider

            // Media
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: mediaWidget,
            ),
            
            const SizedBox(height: 16),

            // Caption
            if (widget.ad.caption.isNotEmpty) ...[
              Text(
                widget.ad.caption,
                style: TextStyle(fontSize: 14, color: adaptiveTextColor),
              ),
              const SizedBox(height: 12),
            ],

            // Ad Type Chips
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  label: Text(
                    widget.ad.adType == 'promo' ? 'Promotion' : 'Advert',
                    style: TextStyle(fontSize: 12, color: adaptiveTextColor), 
                  ),
                  backgroundColor: isDark
                      ? (widget.ad.adType == 'promo' ? Colors.blue.shade900 : Colors.green.shade900)
                      : (widget.ad.adType == 'promo' ? Colors.blue.shade100 : Colors.green.shade100),
                ),
                if (widget.ad.adType == 'promo') ...[
                  Chip(
                    label: Text(
                      '${DateFormat('MMM dd, yyyy').format(widget.ad.startDate)} - ${DateFormat('MMM dd, yyyy').format(widget.ad.endDate)}',
                      style: TextStyle(fontSize: 12, color: adaptiveTextColor), 
                    ),
                    backgroundColor: isDark ? Colors.orange.shade900 : Colors.orange.shade100, 
                  ),
                  Chip(
                    label: Text(
                      '${widget.ad.durationDays} ${widget.ad.durationDays == 1 ? 'Day' : 'Days'}', // Corrected pluralization
                      style: TextStyle(fontSize: 12, color: adaptiveTextColor), 
                    ),
                    backgroundColor: isDark ? Colors.purple.shade900 : Colors.purple.shade100, 
                  ),
                ],
                Chip(
                  label: Text(
                    'Price Paid: \$${widget.ad.pricePaid.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 12, color: adaptiveTextColor), 
                  ),
                  backgroundColor: isDark ? Colors.teal.shade900 : Colors.teal.shade100, 
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Visibility Countries
            if (widget.ad.visibilityCountries.isNotEmpty) ...[
              Text('Target Countries:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: adaptiveTextColor)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.ad.visibilityCountries.map((code) {
                  final country = CaribbeanCountries.byCode(code);
                  return Chip(
                    label: Text(country?.name ?? code, style: TextStyle(fontSize: 12, color: adaptiveTextColor)),
                    backgroundColor: isDark ? Colors.grey[700] : Colors.grey.shade200, 
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Approval Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.check, color: Colors.green),
                  label: Text('Approve', style: TextStyle(color: Colors.green)),
                  onPressed: () async {
                    await DealAdService().approveAd(widget.ad.id, reviewerId);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad approved.')));
                  },
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  icon: const Icon(Icons.close, color: Colors.red),
                  label: Text('Reject', style: TextStyle(color: Colors.red)),
                  onPressed: () async {
                    await DealAdService().rejectAd(widget.ad.id, reviewerId);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad rejected.')));
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
