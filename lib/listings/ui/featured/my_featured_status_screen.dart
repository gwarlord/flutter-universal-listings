import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:caribtap/listings/services/featured_service.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;

/// Screen showing user's featured usage and history
class MyFeaturedStatusScreen extends StatefulWidget {
  final String userId;

  const MyFeaturedStatusScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<MyFeaturedStatusScreen> createState() => _MyFeaturedStatusScreenState();
}

class _MyFeaturedStatusScreenState extends State<MyFeaturedStatusScreen> {
  final _service = FeaturedService();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final monthKey = _service.getCurrentMonthKey();

    return Scaffold(
      appBar: AppBar(
        title: Text('Featured Status'.tr()),
        backgroundColor: Color(cfg.colorPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current Month Usage Card
          StreamBuilder<FeaturedUsage?>(
            stream: _service.streamCurrentUsage(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final usage = snapshot.data;
              final allocated = usage?.allocatedSlots ?? 0;
              final used = usage?.usedSlots ?? 0;
              final remaining = usage?.remainingSlots ?? 0;
              final tier = usage?.tier ?? 'none';

              return Card(
                color: isDark ? Colors.grey[850] : Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            'Featured Slots - ${_formatMonthKey(monthKey)}'.tr(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Subscription Tier: ${_formatTier(tier)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatItem('Allocated', allocated.toString(), Colors.blue, isDark),
                          _buildStatItem('Used', used.toString(), Colors.orange, isDark),
                          _buildStatItem('Remaining', remaining.toString(), Colors.green, isDark),
                        ],
                      ),
                      if (allocated > 0) ...[
                        const SizedBox(height: 12),
                        LinearProgressIndicator(
                          value: allocated > 0 ? used / allocated : 0,
                          backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            remaining > 0 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                      if (allocated == 0) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Upgrade to Professional or Premium to get featured slots!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Info Card
          Card(
            color: isDark ? Colors.grey[850] : Colors.blue[50],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How Featured Slots Work'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('• Professional: 1 slot per month (7 days each)', isDark),
                  _buildInfoRow('• Premium: 2 slots per month (7 days each)', isDark),
                  _buildInfoRow('• Slots reset monthly', isDark),
                  _buildInfoRow('• Featured listings appear in the home carousel', isDark),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Recent Requests
          Text(
            'Recent Requests'.tr(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<FeaturedRequest>>(
            stream: _service.streamMyRequests(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final requests = snapshot.data ?? [];
              if (requests.isEmpty) {
                return Card(
                  color: isDark ? Colors.grey[850] : Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No featured requests yet',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                children: requests.take(5).map((request) {
                  return Card(
                    color: isDark ? Colors.grey[850] : Colors.white,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: _getStatusIcon(request.status),
                      title: Text(
                        'Listing: ${request.listingId.substring(0, 8)}...',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Status: ${_formatStatus(request.status)}',
                            style: TextStyle(
                              color: _getStatusColor(request.status),
                            ),
                          ),
                          Text(
                            DateFormat.yMMMd().format(request.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                      trailing: request.featuredUntil != null
                          ? Chip(
                              label: Text(
                                'Until ${DateFormat.MMMd().format(request.featuredUntil!)}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: Colors.amber[100],
                            )
                          : null,
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.white70 : Colors.black87,
        ),
      ),
    );
  }

  Icon _getStatusIcon(String status) {
    switch (status) {
      case 'activated':
        return const Icon(Icons.check_circle, color: Colors.green);
      case 'pending':
        return const Icon(Icons.pending, color: Colors.orange);
      case 'rejected':
        return const Icon(Icons.cancel, color: Colors.red);
      case 'expired':
        return const Icon(Icons.access_time, color: Colors.grey);
      default:
        return const Icon(Icons.help_outline, color: Colors.grey);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'activated':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1);
  }

  String _formatTier(String tier) {
    if (tier == 'professional') return 'Professional';
    if (tier == 'premium') return 'Premium';
    return 'None';
  }

  String _formatMonthKey(String monthKey) {
    final parts = monthKey.split('-');
    if (parts.length == 2) {
      final year = parts[0];
      final month = parts[1];
      return '$month/$year';
    }
    return monthKey;
  }
}
