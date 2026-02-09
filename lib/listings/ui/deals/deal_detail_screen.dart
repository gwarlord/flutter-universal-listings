import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:instaflutter/listings/services/saved_deal_service.dart';
import 'package:instaflutter/listings/ui/deals/deal_analytics_screen.dart';
import 'package:video_player/video_player.dart';

/// Detailed view of a single deal/promotion
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
  late SavedDealService _savedDealService;
  late VideoPlayerController? _videoController;
  late Future<void> _initializeVideoFuture;
  bool _isSaved = false;
  bool _isClaimed = false;
  bool _isLoadingClaim = false;

  @override
  void initState() {
    super.initState();
    _dealAdService = DealAdService();
    _savedDealService = SavedDealService();
    
    // Increment view count
    _dealAdService.incrementViewCount(widget.deal.id);

    // Check if already saved/claimed
    _checkSavedStatus();
    _checkClaimedStatus();

    // Initialize video if needed
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

  Future<void> _checkSavedStatus() async {
    final isSaved = await _savedDealService.isDealSaved(
      widget.currentUser.userID,
      widget.deal.id,
    );
    if (mounted) {
      setState(() => _isSaved = isSaved);
    }
  }

  Future<void> _checkClaimedStatus() async {
    final isClaimed = await _dealAdService.hasUserClaimedDeal(
      widget.deal.id,
      widget.currentUser.userID,
    );
    if (mounted) {
      setState(() => _isClaimed = isClaimed);
    }
  }

  Future<void> _toggleSave() async {
    try {
      if (_isSaved) {
        await _savedDealService.unsaveDeal(
          widget.currentUser.userID,
          widget.deal.id,
        );
        await _dealAdService.incrementSaveCount(widget.deal.id, isSaving: false);
      } else {
        await _savedDealService.saveDeal(
          widget.currentUser.userID,
          widget.deal.id,
        );
        await _dealAdService.incrementSaveCount(widget.deal.id, isSaving: true);
      }
      if (mounted) {
        setState(() => _isSaved = !_isSaved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _claimDeal() async {
    setState(() => _isLoadingClaim = true);
    try {
      final success = await _dealAdService.claimDeal(
        widget.deal.id,
        widget.currentUser.userID,
      );

      if (mounted) {
        setState(() => _isLoadingClaim = false);
        if (success) {
          setState(() => _isClaimed = true);
          _showClaimSuccessDialog();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Redemption limit reached or already claimed')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingClaim = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error claiming deal: $e')),
        );
      }
    }
  }

  void _showClaimSuccessDialog() {
    final isDark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: const Text('Deal Claimed!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('You have successfully claimed this deal.'),
            const SizedBox(height: 16),
            if (widget.deal.redemptionType == 'PROMO_CODE')
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Promo Code:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.deal.promoCode ?? 'N/A',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            // Copy to clipboard
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied to clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final isExpired = widget.deal.isExpired;
    final isSoldOut = widget.deal.isSoldOut;
    final timeRemaining = widget.deal.getTimeRemainingString();
    final isOwner = widget.currentUser.userID == widget.deal.listerId;

    return Scaffold(
      appBar: AppBar(
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
          IconButton(
            icon: Icon(
              _isSaved ? Icons.favorite : Icons.favorite_border,
              color: _isSaved ? Colors.red : null,
            ),
            onPressed: _toggleSave,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Media
            ClipRRect(
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
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badges
                  Row(
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
                  ),

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
                    Container(
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
                    ),

                  const SizedBox(height: 16),

                  // Redemption info
                  if (widget.deal.redemptionType == 'PROMO_CODE' &&
                      widget.deal.promoCode != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Promo Code',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey[400]!,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                widget.deal.promoCode!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Code copied')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Redemption limits
                  if (widget.deal.redemptionLimitTotal != null) ...[
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
                    const SizedBox(height: 16),
                  ],

                  // Claim button or status
                  if (isExpired)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'This deal has expired',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    )
                  else if (isSoldOut)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Sold Out',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    )
                  else if (_isClaimed)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Already claimed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    )
                  else if (!isOwner && widget.deal.status != 'approved')
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'Deal pending approval',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    )
                  else
                    ElevatedButton(
                      onPressed: _isLoadingClaim ? null : _claimDeal,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: primaryColor,
                      ),
                      child: _isLoadingClaim
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Text(
                        widget.deal.redemptionType == 'PROMO_CODE'
                            ? 'Copy Code'
                            : 'Claim Deal',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Additional info
                  Container(
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
                  ),
                ],
              ),
            ),
          ],
        ),
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
