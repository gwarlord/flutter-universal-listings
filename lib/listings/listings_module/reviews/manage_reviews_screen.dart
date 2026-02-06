import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/review_removal_request_model.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/services/review_removal_request_service.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class ManageReviewsScreen extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const ManageReviewsScreen({
    Key? key,
    required this.listing,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ManageReviewsScreen> createState() => _ManageReviewsScreenState();
}

class _ManageReviewsScreenState extends State<ManageReviewsScreen> {
  final ReviewRemovalRequestService _requestService =
      ReviewRemovalRequestService();

  List<ListingReviewModel> _reviews = [];
  Map<String, ReviewRemovalRequestModel?> _requestsByReview = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _isLoading = true);

    try {
      // Load all reviews for the listing
      final reviews = await listingApiManager.getReviews(
        listingID: widget.listing.id,
      );

      // Load request status for each review
      final Map<String, ReviewRemovalRequestModel?> requests = {};
      for (final review in reviews) {
        if (review.id.isNotEmpty) {
          requests[review.id] =
              await _requestService.getRequestForReview(review.id);
        }
      }

      setState(() {
        _reviews = reviews;
        _requestsByReview = requests;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading reviews: $e')),
        );
      }
    }
  }

  void _showRemovalRequestDialog(ListingReviewModel review) {
    String reasonCategory = 'spam';
    String reasonText = '';

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[850] : Colors.grey[100];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Text(
            'Request Review Removal'.tr(),
            style: TextStyle(color: onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why do you want to remove this review?'.tr(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: reasonCategory,
                  decoration: InputDecoration(
                    labelText: 'Reason Category'.tr(),
                    labelStyle: TextStyle(color: onSurface),
                    hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: fillColor,
                  ),
                  style: TextStyle(color: onSurface, fontSize: 16),
                  items: [
                    DropdownMenuItem(value: 'spam', child: Text('Spam'.tr())),
                    DropdownMenuItem(
                        value: 'abuse', child: Text('Abusive Content'.tr())),
                    DropdownMenuItem(
                        value: 'false_info',
                        child: Text('False Information'.tr())),
                    DropdownMenuItem(
                        value: 'privacy',
                        child: Text('Privacy Violation'.tr())),
                    DropdownMenuItem(value: 'other', child: Text('Other'.tr())),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => reasonCategory = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  maxLines: 4,
                  style: TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    labelText: 'Detailed Reason'.tr(),
                    labelStyle: TextStyle(color: onSurface),
                    hintText: 'Please explain why this review should be removed'
                        .tr(),
                    hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: fillColor,
                  ),
                  onChanged: (value) => reasonText = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonText.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Please provide a detailed reason'.tr())),
                  );
                  return;
                }

                Navigator.pop(context);
                await _submitRemovalRequest(
                  review: review,
                  reasonCategory: reasonCategory,
                  reasonText: reasonText,
                );
              },
              child: Text('Submit Request'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRemovalRequest({
    required ListingReviewModel review,
    required String reasonCategory,
    required String reasonText,
  }) async {
    try {
      await _requestService.submitRemovalRequest(
        review: review,
        listing: widget.listing,
        currentUser: widget.currentUser,
        reasonCategory: reasonCategory,
        reasonText: reasonText,
      );

      // Small delay to ensure Firestore write propagates
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Reload to show updated status
      await _loadReviews();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removal request sent to admins'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStatusBadge(ReviewRemovalRequestModel? request) {
    if (request == null) {
      return const SizedBox.shrink();
    }

    Color badgeColor;
    String statusText;
    IconData iconData;

    switch (request.status) {
      case 'PENDING':
        badgeColor = Colors.orange;
        statusText = 'Pending Review'.tr();
        iconData = Icons.schedule;
        break;
      case 'APPROVED':
        badgeColor = Colors.green;
        statusText = 'Hidden'.tr();
        iconData = Icons.check_circle;
        break;
      case 'REJECTED':
        badgeColor = Colors.red;
        statusText = 'Request Rejected'.tr();
        iconData = Icons.cancel;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: badgeColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      ListingReviewModel review, ReviewRemovalRequestModel? request) {
    if (request == null) {
      // No request exists - show "Request Removal" button
      return ElevatedButton.icon(
        onPressed: () => _showRemovalRequestDialog(review),
        icon: const Icon(Icons.report_problem, size: 18),
        label: Text('Request Removal'.tr()),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
        ),
      );
    }

    if (request.isPending) {
      // Request is pending - show disabled button
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.schedule, size: 18),
        label: Text('Request Pending'.tr()),
      );
    }

    if (request.isApproved) {
      // Request approved but review still showing (shouldn't happen normally)
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Review Hidden'.tr(),
          style: TextStyle(
            color: Colors.green[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (request.isRejected) {
      // Request was rejected - allow re-requesting
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (request.rejectionReasonVisibleToLister != null) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rejection Reason:'.tr(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.red[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    request.rejectionReasonVisibleToLister!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red[800],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          ElevatedButton.icon(
            onPressed: () => _showRemovalRequestDialog(review),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text('Request Again'.tr()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = theme.colorScheme.surface;
    final onSurface = theme.colorScheme.onSurface;
    final onSurfaceMuted = onSurface.withOpacity(0.7);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Reviews'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _reviews.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rate_review_outlined,
                          size: 64, color: isDark ? Colors.grey[600] : Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No reviews yet'.tr(),
                        style: TextStyle(
                          fontSize: 18,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReviews,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reviews.length,
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      final request = _requestsByReview[review.id];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        color: surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Header row with rating and status
                              Row(
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundImage: review
                                                  .profilePictureURL.isNotEmpty
                                              ? NetworkImage(
                                                  review.profilePictureURL)
                                              : null,
                                          child: review
                                                  .profilePictureURL.isEmpty
                                              ? Text(review.firstName[0])
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                review.fullName(),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: onSurface,
                                                ),
                                              ),
                                              Text(
                                                DateFormat.yMMMd().format(
                                                  DateTime
                                                      .fromMillisecondsSinceEpoch(
                                                    review.createdAt * 1000,
                                                  ),
                                                ),
                                                style: TextStyle(
                                                  color: onSurfaceMuted,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  _buildStatusBadge(request),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Rating
                              RatingBarIndicator(
                                rating: review.starCount,
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                itemCount: 5,
                                itemSize: 20,
                              ),
                              const SizedBox(height: 12),
                              // Review content
                              Text(
                                review.content,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Action button
                              _buildActionButton(review, request),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
