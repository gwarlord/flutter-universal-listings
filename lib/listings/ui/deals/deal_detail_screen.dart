import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/ui/deals/deal_analytics_screen.dart';
import 'package:video_player/video_player.dart';

class DealDetailScreen extends StatefulWidget {
  final DealAdModel deal;
  final ListingsUser currentUser;

  const DealDetailScreen({
    Key? key,
    required this.deal,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  late DealAdService _dealAdService;
  late VideoPlayerController? _videoController;
  late Future<void> _initializeVideoFuture;

  @override
  void initState() {
    super.initState();
    _dealAdService = DealAdService();
    
    _dealAdService.incrementViewCount(widget.deal.id);

    if (widget.deal.mediaType == 'video') {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.deal.mediaUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _initializeVideoFuture = _videoController!.initialize().then((_) {
        _videoController!.setLooping(true);
      });
    } else {
      _videoController = null;
      _initializeVideoFuture = Future.value();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(context),
      body: _buildBody(context),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final isOwner = widget.currentUser.userID == widget.deal.listerId;
    return AppBar(
      title: const Text('Deal Details'),
      centerTitle: true,
      actions: [
        if (isOwner)
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'View Analytics',
            onPressed: () {
              push(
                context,
                DealAnalyticsScreen(
                  dealId: widget.deal.id,
                  currentUser: widget.currentUser,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final isExpired = widget.deal.isExpired;
    final isSoldOut = widget.deal.isSoldOut;
    final timeRemaining = widget.deal.getTimeRemainingString();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Media
          _buildMediaWidget(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status badges
                _buildStatusBadges(isExpired, isSoldOut),
                const SizedBox(height: 12),
                // Title
                Text(
                  widget.deal.caption,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Time remaining
                if (!isExpired)
                  _buildTimeRemaining(timeRemaining, primaryColor),
                const SizedBox(height: 16),
                _buildAvailability(),
                const SizedBox(height: 16),
                // Additional info
                _buildInfoContainer(isDark)
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaWidget() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: widget.deal.mediaType == 'video'
          ? FutureBuilder<void>(
        future: _initializeVideoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(_videoController!),
                  FloatingActionButton(
                    onPressed: () {
                      setState(() {
                        _videoController!.value.isPlaying
                            ? _videoController!.pause()
                            : _videoController!.play();
                      });
                    },
                    child: Icon(
                      _videoController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Container(
              height: 240,
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            );
          }
        },
      )
          : Image.network(
        widget.deal.mediaUrl,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }
  
  Widget _buildStatusBadges(bool isExpired, bool isSoldOut) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.deal.adType.toUpperCase(),
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        if (isExpired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Expired',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        if (isSoldOut && !isExpired)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Sold Out',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildTimeRemaining(String timeRemaining, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeRemaining,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          Text(
            'Until ${DateFormat('MMM d, yyyy').format(widget.deal.expireAt)}',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailability() {
     if (widget.deal.redemptionLimitTotal == null || widget.deal.redemptionLimitTotal == 0) {
      return const SizedBox.shrink();
    }
    final primaryColor = Color(colorPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          const Text(
            'Availability',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Redeemed: ${widget.deal.redemptionCountTotal}/${widget.deal.redemptionLimitTotal}',
              ),
              if (widget.deal.redemptionLimitTotal != null && (widget.deal.redemptionLimitTotal! - widget.deal.redemptionCountTotal) > 0)
                Text(
                  '${widget.deal.redemptionLimitTotal! - widget.deal.redemptionCountTotal} remaining',
                  style: TextStyle(
                    color: primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: widget.deal.redemptionCountTotal /
                  widget.deal.redemptionLimitTotal!,
              minHeight: 8,
            ),
          ),
      ],
    );
  }
  
  Widget _buildInfoContainer(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InfoRow(
            label: 'Type',
            value: widget.deal.redemptionType ==
                'PROMO_CODE'
                ? 'Promo Code'
                : 'Claim In-App',
          ),
          _InfoRow(
            label: 'Views',
            value: '${widget.deal.viewCount}',
          ),
          _InfoRow(
            label: 'Saves',
            value: '${widget.deal.saveCount}',
          ),
          _InfoRow(
            label: 'Claims',
            value: '${widget.deal.claimCount}',
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
