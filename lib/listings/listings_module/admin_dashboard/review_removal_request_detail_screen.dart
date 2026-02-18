import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listing_review_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/review_removal_request_model.dart';
import 'package:caribtap/listings/services/review_removal_request_service.dart';

class ReviewRemovalRequestDetailScreen extends StatefulWidget {
  final ReviewRemovalRequestModel request;
  final ListingsUser currentUser;

  const ReviewRemovalRequestDetailScreen({
    Key? key,
    required this.request,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<ReviewRemovalRequestDetailScreen> createState() =>
      _ReviewRemovalRequestDetailScreenState();
}

class _ReviewRemovalRequestDetailScreenState
    extends State<ReviewRemovalRequestDetailScreen> {
  final ReviewRemovalRequestService _requestService =
      ReviewRemovalRequestService();

  bool _isLoading = true;
  ListingReviewModel? _review;
  ListingModel? _listing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final review =
          await _requestService.getReview(widget.request.reviewId);
      final listing =
          await _requestService.getListing(widget.request.listingId);

      if (review == null) {
        throw Exception('Review not found');
      }
      if (listing == null) {
        throw Exception('Listing not found');
      }

      setState(() {
        _review = review;
        _listing = listing;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _showApproveDialog() {
    String adminNotes = '';

    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;
    final fillColor = isDark ? Colors.grey[850] : Colors.grey[100];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text(
          'Approve Removal Request'.tr(),
          style: TextStyle(color: onSurface),
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This will hide the review from public view. The action cannot be undone easily.'
                      .tr(),
                  style: TextStyle(fontSize: 14, color: onSurface),
                ),
                const SizedBox(height: 16),
                TextField(
                  maxLines: 3,
                  style: TextStyle(color: onSurface),
                  decoration: InputDecoration(
                    labelText: 'Admin Notes (optional)'.tr(),
                    labelStyle: TextStyle(color: onSurface),
                    hintText: 'Add notes for internal records'.tr(),
                    hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: fillColor,
                  ),
                  onChanged: (value) => adminNotes = value,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _approveRequest(adminNotes);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Approve & Hide Review'.tr()),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog() {
    String rejectionReason = '';
    String adminNotes = '';

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
            'Reject Removal Request'.tr(),
            style: TextStyle(color: onSurface),
          ),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Please provide a reason that will be visible to the lister.'
                        .tr(),
                    style: TextStyle(fontSize: 14, color: onSurface),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    maxLines: 3,
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      labelText: 'Rejection Reason (required)'.tr(),
                      labelStyle: TextStyle(color: onSurface),
                      hintText: 'e.g., Review does not violate guidelines'.tr(),
                      hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: fillColor,
                    ),
                    onChanged: (value) => rejectionReason = value,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    maxLines: 2,
                    style: TextStyle(color: onSurface),
                    decoration: InputDecoration(
                      labelText: 'Admin Notes (optional, internal)'.tr(),
                      labelStyle: TextStyle(color: onSurface),
                      hintText: 'Notes for internal records'.tr(),
                      hintStyle: TextStyle(color: onSurface.withOpacity(0.6)),
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: fillColor,
                    ),
                    onChanged: (value) => adminNotes = value,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'.tr()),
            ),
            ElevatedButton(
              onPressed: () {
                if (rejectionReason.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Rejection reason is required'.tr()),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context);
                _rejectRequest(rejectionReason, adminNotes);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text('Reject Request'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(String adminNotes) async {
    try {
      await _requestService.approveRequest(
        requestId: widget.request.id,
        adminId: widget.currentUser.userID,
        adminNotes: adminNotes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review removal approved'.tr()),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest(String rejectionReason, String adminNotes) async {
    try {
      await _requestService.rejectRequest(
        requestId: widget.request.id,
        adminId: widget.currentUser.userID,
        rejectionReason: rejectionReason,
        adminNotes: adminNotes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Review removal request rejected'.tr()),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final onSurface = theme.colorScheme.onSurface;
    final reasonBg = isDark ? Colors.grey[850] : Colors.grey[100];
    final reasonBorder = isDark ? Colors.grey[700] : Colors.grey[300];

    return Scaffold(
      appBar: AppBar(
        title: Text('Review Removal Request'.tr()),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator.adaptive())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data'.tr(),
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Retry'.tr()),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Listing Info Section
                      _buildSection(
                        title: 'Listing'.tr(),
                        icon: Icons.store,
                        color: Colors.blue,
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _listing!.title,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(_listing!.place),
                        ),
                      ),

                      const Divider(height: 32),

                      // Review Section
                      _buildSection(
                        title: 'Review Being Contested'.tr(),
                        icon: Icons.rate_review,
                        color: Colors.orange,
                        child: Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color: Colors.orange.withOpacity(0.1),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundImage: _review!
                                              .profilePictureURL.isNotEmpty
                                          ? NetworkImage(
                                              _review!.profilePictureURL)
                                          : null,
                                      child: _review!
                                              .profilePictureURL.isEmpty
                                          ? Text(_review!.firstName[0])
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _review!.fullName(),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            DateFormat.yMMMd().format(
                                              DateTime
                                                  .fromMillisecondsSinceEpoch(
                                                _review!.createdAt * 1000,
                                              ),
                                            ),
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                RatingBarIndicator(
                                  rating: _review!.starCount,
                                  itemBuilder: (context, _) => const Icon(
                                    Icons.star,
                                    color: Colors.amber,
                                  ),
                                  itemCount: 5,
                                  itemSize: 20,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _review!.content,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const Divider(height: 32),

                      // Request Details Section
                      _buildSection(
                        title: 'Removal Request Details'.tr(),
                        icon: Icons.report_problem,
                        color: Colors.red,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDetailRow(
                              'Category'.tr(),
                              _getCategoryLabel(widget.request.reasonCategory),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow(
                              'Submitted'.tr(),
                              DateFormat.yMMMd().add_jm().format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      widget.request.createdAt * 1000,
                                    ),
                                  ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Lister\'s Reason:'.tr(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: reasonBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: reasonBorder!),
                              ),
                              child: Text(
                                widget.request.reasonText,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showRejectDialog,
                                icon: const Icon(Icons.cancel),
                                label: Text('Reject'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showApproveDialog,
                                icon: const Icon(Icons.check_circle),
                                label: Text('Approve'.tr()),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                ),
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

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'spam':
        return 'Spam'.tr();
      case 'abuse':
        return 'Abusive Content'.tr();
      case 'false_info':
        return 'False Information'.tr();
      case 'privacy':
        return 'Privacy Violation'.tr();
      default:
        return 'Other'.tr();
    }
  }
}
