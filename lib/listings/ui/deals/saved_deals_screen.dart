import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/saved_deal_service.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/ui/deals/deal_detail_screen.dart';

/// Screen to display user's saved deals
class SavedDealsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const SavedDealsScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<SavedDealsScreen> createState() => _SavedDealsScreenState();
}

class _SavedDealsScreenState extends State<SavedDealsScreen> {
  final SavedDealService _savedDealService = SavedDealService();
  final DealAdService _dealAdService = DealAdService();

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Saved Deals'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: StreamBuilder<List<DealAdModel>>(
        stream: _savedDealService.getSavedDeals(widget.currentUser.userID),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final savedDeals = snapshot.data ?? [];

          if (savedDeals.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 48,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Saved Deals',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save deals to view them here later',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: savedDeals.length,
            itemBuilder: (context, index) {
              return _SavedDealCard(
                deal: savedDeals[index],
                currentUser: widget.currentUser,
                onUnsave: () {
                  _savedDealService.unsaveDeal(
                    widget.currentUser.userID,
                    savedDeals[index].id,
                  ).then((_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Deal removed from saved')),
                    );
                  });
                },
              );
            },
          );
        },
      ),
    );
  }
}

/// Card widget for displaying a saved deal
class _SavedDealCard extends StatefulWidget {
  final DealAdModel deal;
  final ListingsUser currentUser;
  final VoidCallback onUnsave;

  const _SavedDealCard({
    Key? key,
    required this.deal,
    required this.currentUser,
    required this.onUnsave,
  }) : super(key: key);

  @override
  State<_SavedDealCard> createState() => _SavedDealCardState();
}

class _SavedDealCardState extends State<_SavedDealCard> {
  late SavedDealService _savedDealService;
  late bool _notifyBefore;

  @override
  void initState() {
    super.initState();
    _savedDealService = SavedDealService();
    _notifyBefore = true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final timeRemaining = widget.deal.getTimeRemainingString();
    final isExpired = widget.deal.isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: isDark ? 1 : 2,
      color: isDark ? Colors.grey[900] : Colors.white,
      shadowColor: isDark ? Colors.black54 : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Image/Video thumbnail
          GestureDetector(
            onTap: () {
              push(context, DealDetailScreen(deal: widget.deal, currentUser: widget.currentUser));
            },
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    child: widget.deal.mediaType == 'image'
                        ? Image.network(
                      widget.deal.mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(
                            Icons.image,
                            size: 48,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                    )
                        : Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.network(
                          widget.deal.thumbnailUrl ?? widget.deal.mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Icon(
                                Icons.videocam,
                                size: 48,
                                color: isDark ? Colors.grey[600] : Colors.grey[400],
                              ),
                        ),
                        Icon(
                          Icons.play_circle_fill,
                          size: 48,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ),
                  // Status badges
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Row(
                      children: [
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
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else if (widget.deal.endingToday)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Ending Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Countdown
                  if (!isExpired)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          timeRemaining,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Deal info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.deal.caption,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Valid until',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          Text(
                            DateFormat('MMM d, yyyy').format(widget.deal.expireAt),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.deal.redemptionLimitTotal != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: primaryColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          '${widget.deal.redemptionCountTotal}/${widget.deal.redemptionLimitTotal}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),

                // Notification toggle
                if (!isExpired) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Notify before expiry',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      Switch(
                        value: _notifyBefore,
                        onChanged: (value) {
                          setState(() => _notifyBefore = value);
                          _savedDealService.toggleNotification(
                            widget.currentUser.userID,
                            widget.deal.id,
                            value,
                          );
                        },
                        activeColor: primaryColor,
                      ),
                    ],
                  ),
                ],

                // Action buttons
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('View'),
                        onPressed: () {
                          push(context, DealDetailScreen(deal: widget.deal, currentUser: widget.currentUser));
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove'),
                        onPressed: widget.onUnsave,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          side: BorderSide(
                            color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
