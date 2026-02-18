import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/services/deal_analytics_service.dart';

/// Screen for deal owners to view analytics and performance metrics
class DealAnalyticsScreen extends StatefulWidget {
  final String dealId;
  final ListingsUser currentUser;

  const DealAnalyticsScreen({
    Key? key,
    required this.dealId,
    required this.currentUser,
  }) : super(key: key);

  @override
  State<DealAnalyticsScreen> createState() => _DealAnalyticsScreenState();
}

class _DealAnalyticsScreenState extends State<DealAnalyticsScreen> {
  late DealAnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();
    _analyticsService = DealAnalyticsService();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        title: const Text('Deal Analytics'),
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
      body: StreamBuilder<DealAnalytics>(
        stream: _analyticsService.streamDealAnalytics(widget.dealId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return Center(
              child: Text(
                'No analytics available',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            );
          }

          final analytics = snapshot.data!;
          return _AnalyticsContent(
            analytics: analytics,
            analyticsService: _analyticsService,
          );
        },
      ),
    );
  }
}

class _AnalyticsContent extends StatefulWidget {
  final DealAnalytics analytics;
  final DealAnalyticsService analyticsService;

  const _AnalyticsContent({
    required this.analytics,
    required this.analyticsService,
  });

  @override
  State<_AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<_AnalyticsContent> {
  late Future<EngagementMetrics> _engagementMetrics;

  @override
  void initState() {
    super.initState();
    _engagementMetrics = widget.analyticsService.getEngagementMetrics(
      widget.analytics.dealId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Deal title
            if (widget.analytics.dealCaption != null) ...[
              Text(
                'Deal: ${widget.analytics.dealCaption}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Status cards
            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    icon: Icons.visibility,
                    label: 'Views',
                    value: widget.analytics.viewCount.toString(),
                    color: Colors.blue,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    icon: Icons.favorite,
                    label: 'Saves',
                    value: widget.analytics.saveCount.toString(),
                    color: Colors.red,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _StatusCard(
                    icon: Icons.check_circle,
                    label: 'Claims',
                    value: widget.analytics.claimCount.toString(),
                    color: Colors.green,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatusCard(
                    icon: Icons.people,
                    label: 'Users',
                    value: widget.analytics.redemptionCountByUser.toString(),
                    color: Colors.purple,
                    isDark: isDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Redemption section
            Card(
              elevation: isDark ? 1 : 2,
              color: isDark ? Colors.grey[900] : Colors.white,
              shadowColor: isDark ? Colors.black54 : Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Redemption Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Redeemed',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        Text(
                          widget.analytics.redemptionCountTotal.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.analytics.redemptionLimitTotal != null) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Limit',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Text(
                            widget.analytics.redemptionLimitTotal.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Remaining',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          Text(
                            widget.analytics.redemptionRemaining.toString(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: widget.analytics.redemptionRemaining > 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.analytics.redemptionCountTotal /
                              widget.analytics.redemptionLimitTotal!,
                          minHeight: 8,
                          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Engagement metrics
            FutureBuilder<EngagementMetrics>(
              future: _engagementMetrics,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final metrics = snapshot.data!;
                return Card(
                  elevation: isDark ? 1 : 2,
                  color: isDark ? Colors.grey[900] : Colors.white,
                  shadowColor: isDark ? Colors.black54 : Colors.black12,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Engagement Metrics',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _MetricRow(
                          label: 'View to Claim Rate',
                          value: '${metrics.saleRate}%',
                          description: 'of viewers claimed the deal',
                        ),
                        const SizedBox(height: 12),
                        _MetricRow(
                          label: 'View to Save Rate',
                          value: '${metrics.saveRate}%',
                          description: 'of viewers saved the deal',
                        ),
                        const SizedBox(height: 12),
                        _MetricRow(
                          label: 'Save to Claim Rate',
                          value: '${metrics.redemptionRate}%',
                          description: 'of savers claimed the deal',
                        ),
                        const SizedBox(height: 12),
                        _MetricRow(
                          label: 'Avg Claims per User',
                          value: metrics.averageRedemptionsPerUser,
                          description: 'times each user claimed on average',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Status summary
            Card(
              elevation: isDark ? 1 : 2,
              color: isDark
                  ? (widget.analytics.isActive ? Colors.green[900] : Colors.red[900])
                  : (widget.analytics.isActive ? Colors.green[50] : Colors.red[50]),
              shadowColor: isDark ? Colors.black54 : Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      widget.analytics.isActive
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: widget.analytics.isActive
                          ? Colors.green
                          : Colors.red,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.analytics.isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Text(
                            widget.analytics.isSoldOut
                                ? 'Sold out'
                                : 'Accepting claims',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom card for displaying a status metric
class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isDark ? 1 : 2,
      color: isDark ? Colors.grey[900] : Colors.white,
      shadowColor: isDark ? Colors.black54 : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row for displaying a metric with label and value
class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final String description;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(colorPrimary),
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
