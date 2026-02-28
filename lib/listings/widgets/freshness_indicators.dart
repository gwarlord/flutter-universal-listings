import 'package:flutter/material.dart';
import 'package:caribtap/listings/model/listing_model.dart';

/// Visual indicator showing listing freshness status
class FreshnessStatusBadge extends StatelessWidget {
  final ListingModel listing;
  final bool compact;

  const FreshnessStatusBadge({
    Key? key,
    required this.listing,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (listing.hidden) {
      return _buildBadge(
        'Hidden',
        Colors.grey,
        Icons.visibility_off,
        compact,
      );
    }

    final freshness = listing.freshness;
    if (freshness == null) {
      return const SizedBox.shrink();
    }

    final daysRemaining = freshness.daysRemaining ?? 0;

    if (freshness.exempt) {
      return _buildBadge(
        'Never Expires',
        Colors.blue,
        Icons.stars,
        compact,
      );
    }

    if (daysRemaining <= 0) {
      return _buildBadge(
        'Expired',
        Colors.red.shade700,
        Icons.error,
        compact,
      );
    } else if (daysRemaining <= 1) {
      return _buildBadge(
        'Expiring Today',
        Colors.red,
        Icons.warning,
        compact,
      );
    } else if (daysRemaining <= 10) {
      return _buildBadge(
        '$daysRemaining days left',
        Colors.orange,
        Icons.schedule,
        compact,
      );
    } else if (daysRemaining <= 30) {
      return _buildBadge(
        '$daysRemaining days',
        Colors.amber,
        Icons.access_time,
        compact,
      );
    } else {
      return _buildBadge(
        'Fresh',
        Colors.green,
        Icons.check_circle,
        compact,
      );
    }
  }

  Widget _buildBadge(
    String text,
    Color color,
    IconData icon,
    bool compact,
  ) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(text),
      labelStyle: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
      backgroundColor: color.withOpacity(0.1),
      side: BorderSide(color: color, width: 1.5),
    );
  }
}

/// Progress bar showing freshness countdown
class FreshnessProgressBar extends StatelessWidget {
  final ListingModel listing;

  const FreshnessProgressBar({
    Key? key,
    required this.listing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final freshness = listing.freshness;
    if (freshness == null || freshness.exempt || listing.hidden) {
      return const SizedBox.shrink();
    }

    final daysRemaining = freshness.daysRemaining ?? 0;
    final totalDays = freshness.days;
    final progress = (daysRemaining / totalDays).clamp(0.0, 1.0);

    Color progressColor;
    if (daysRemaining <= 10) {
      progressColor = Colors.red;
    } else if (daysRemaining <= 30) {
      progressColor = Colors.orange;
    } else {
      progressColor = Colors.green;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Freshness',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '$daysRemaining of $totalDays days',
              style: TextStyle(
                fontSize: 12,
                color: progressColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

/// Activity level indicator
class ActivityLevelBadge extends StatelessWidget {
  final String activityLevel;
  final int score;
  final bool showScore;

  const ActivityLevelBadge({
    Key? key,
    required this.activityLevel,
    required this.score,
    this.showScore = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Color color;
    IconData icon;

    switch (activityLevel.toLowerCase()) {
      case 'very high':
        color = Colors.green.shade700;
        icon = Icons.trending_up;
        break;
      case 'high':
        color = Colors.green;
        icon = Icons.arrow_upward;
        break;
      case 'medium':
        color = Colors.amber;
        icon = Icons.trending_flat;
        break;
      case 'low':
        color = Colors.orange;
        icon = Icons.arrow_downward;
        break;
      default:
        color = Colors.grey;
        icon = Icons.remove;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            activityLevel,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showScore) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                score.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Auto-refresh notification badge
class AutoRefreshBadge extends StatelessWidget {
  final DateTime? lastAutoRefresh;

  const AutoRefreshBadge({
    Key? key,
    this.lastAutoRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (lastAutoRefresh == null) {
      return const SizedBox.shrink();
    }

    final daysAgo = DateTime.now().difference(lastAutoRefresh!).inDays;
    String text;

    if (daysAgo == 0) {
      text = 'Auto-refreshed today';
    } else if (daysAgo == 1) {
      text = 'Auto-refreshed yesterday';
    } else {
      text = 'Auto-refreshed $daysAgo days ago';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.purple.shade300, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome, size: 16, color: Colors.purple.shade700),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: Colors.purple.shade700,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Comprehensive freshness info card
class FreshnessInfoCard extends StatelessWidget {
  final ListingModel listing;

  const FreshnessInfoCard({
    Key? key,
    required this.listing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final freshness = listing.freshness;
    if (freshness == null) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Listing Freshness',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                FreshnessStatusBadge(listing: listing, compact: true),
              ],
            ),
            const SizedBox(height: 16),
            FreshnessProgressBar(listing: listing),
            if (!listing.hidden && !freshness.exempt) ...[
              const SizedBox(height: 16),
              _buildInfoRow(
                'Last refreshed',
                _formatDate(freshness.lastRefreshedAt.toDate()),
              ),
              _buildInfoRow(
                'Will hide on',
                _formatDate(freshness.hideAt.toDate()),
              ),
              if (freshness.warn10SentAt != null)
                _buildInfoRow(
                  '10-day warning sent',
                  _formatDate(freshness.warn10SentAt!.toDate()),
                  Icons.notifications_active,
                  Colors.orange,
                ),
              if (freshness.warn1SentAt != null)
                _buildInfoRow(
                  '1-day warning sent',
                  _formatDate(freshness.warn1SentAt!.toDate()),
                  Icons.notification_important,
                  Colors.red,
                ),
            ],
            if (freshness.exempt) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.stars, color: Colors.blue.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This listing is exempt from automatic hiding',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, [
    IconData? icon,
    Color? color,
  ]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color ?? Colors.grey[600]),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);

    if (difference.inDays.abs() == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Tomorrow';
    } else if (difference.inDays == -1) {
      return 'Yesterday';
    } else if (difference.inDays > 0 && difference.inDays <= 7) {
      return 'in ${difference.inDays} days';
    } else if (difference.inDays < 0 && difference.inDays >= -7) {
      return '${difference.inDays.abs()} days ago';
    }

    return '${date.month}/${date.day}/${date.year}';
  }
}
