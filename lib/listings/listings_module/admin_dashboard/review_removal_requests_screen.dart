import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/review_removal_request_model.dart';
import 'package:caribtap/listings/services/review_removal_request_service.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/review_removal_request_detail_screen.dart';

class ReviewRemovalRequestsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const ReviewRemovalRequestsScreen({
    Key? key,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ReviewRemovalRequestsScreen> createState() =>
      _ReviewRemovalRequestsScreenState();
}

class _ReviewRemovalRequestsScreenState
    extends State<ReviewRemovalRequestsScreen> {
  final ReviewRemovalRequestService _requestService =
      ReviewRemovalRequestService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Review Removal Requests'.tr()),
      ),
      body: StreamBuilder<List<ReviewRemovalRequestModel>>(
        stream: _requestService.streamPendingRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator.adaptive());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading requests'.tr(),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          final requests = snapshot.data ?? [];

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests'.tr(),
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All review removal requests have been processed'.tr(),
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _buildRequestCard(request);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(ReviewRemovalRequestModel request) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToDetail(request),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category badge
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getCategoryColor(request.reasonCategory)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _getCategoryColor(request.reasonCategory),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getCategoryIcon(request.reasonCategory),
                            size: 16,
                            color: _getCategoryColor(request.reasonCategory),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _getCategoryLabel(request.reasonCategory),
                            style: TextStyle(
                              color: _getCategoryColor(request.reasonCategory),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(request.createdAt),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Listing info (will be loaded)
              FutureBuilder<ListingModel?>(
                future: _requestService.getListing(request.listingId),
                builder: (context, snapshot) {
                  final listing = snapshot.data;
                  return Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          listing?.title ?? 'Listing ID: ${request.listingId}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              // Reason preview
              Text(
                request.reasonText,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Footer with action hint
              Row(
                children: [
                  Icon(
                    Icons.touch_app,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tap to review and take action'.tr(),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'spam':
        return Colors.orange;
      case 'abuse':
        return Colors.red;
      case 'false_info':
        return Colors.purple;
      case 'privacy':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'spam':
        return Icons.report;
      case 'abuse':
        return Icons.warning;
      case 'false_info':
        return Icons.info;
      case 'privacy':
        return Icons.privacy_tip;
      default:
        return Icons.help;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'spam':
        return 'Spam'.tr();
      case 'abuse':
        return 'Abuse'.tr();
      case 'false_info':
        return 'False Info'.tr();
      case 'privacy':
        return 'Privacy'.tr();
      default:
        return 'Other'.tr();
    }
  }

  String _formatTimeAgo(int seconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return DateFormat.yMMMd().format(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now'.tr();
    }
  }

  Future<void> _navigateToDetail(ReviewRemovalRequestModel request) async {
    final result = await push(
      context,
      ReviewRemovalRequestDetailScreen(
        request: request,
        currentUser: widget.currentUser,
      ),
    );

    // Refresh is handled automatically by the stream
    if (result == true) {
      // Request was processed, no need to manually refresh
    }
  }
}
