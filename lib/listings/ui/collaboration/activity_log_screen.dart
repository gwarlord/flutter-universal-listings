import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:instaflutter/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:instaflutter/listings/model/collaboration_model.dart';

class ActivityLogScreen extends StatefulWidget {
  final String listingId;

  const ActivityLogScreen({
    Key? key,
    required this.listingId,
  }) : super(key: key);

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  late Stream<List<ActivityLogEntry>> activityStream;

  @override
  void initState() {
    super.initState();
    activityStream = collaborationApiManager.streamActivityLog(
      listingId: widget.listingId,
      limit: 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        elevation: 0,
      ),
      body: StreamBuilder<List<ActivityLogEntry>>(
        stream: activityStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final activities = snapshot.data ?? [];

          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Activity',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity log will appear here',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final activity = activities[index];
              return ActivityLogTile(activity: activity);
            },
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    collaborationApiManager.dispose();
    super.dispose();
  }
}

// ============================================================================
// ACTIVITY LOG TILE
// ============================================================================

class ActivityLogTile extends StatelessWidget {
  final ActivityLogEntry activity;

  const ActivityLogTile({
    Key? key,
    required this.activity,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, y • h:mm a');
    final formattedDate = formatter.format(activity.createdAt);

    Color? tileColor;
    IconData icon = Icons.info_outline;

    if (activity.actionType.contains('COLLABORATOR')) {
      tileColor = Colors.blue[50];
      icon = Icons.person;
    } else if (activity.actionType.contains('ORDER')) {
      tileColor = Colors.orange[50];
      icon = Icons.shopping_cart;
    } else if (activity.actionType.contains('LISTING')) {
      tileColor = Colors.green[50];
      icon = Icons.edit;
    } else if (activity.actionType.contains('CHAT')) {
      tileColor = Colors.purple[50];
      icon = Icons.chat;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: tileColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.getActionLabel(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by ${activity.actorName ?? activity.actorUid}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    activity.actorRole,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _getRoleColor(activity.actorRole),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (activity.targetType.isNotEmpty)
              Row(
                children: [
                  Icon(
                    _getTargetIcon(activity.targetType),
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${activity.targetType}: ${activity.targetId}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (activity.note != null && activity.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  activity.note!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              formattedDate,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'OWNER':
        return Colors.red;
      case 'COLLABORATOR':
        return Colors.blue;
      case 'ADMIN':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getTargetIcon(String targetType) {
    switch (targetType) {
      case 'LISTING':
        return Icons.store;
      case 'ORDER':
        return Icons.shopping_cart;
      case 'RENTAL':
        return Icons.home;
      case 'BOOKING':
        return Icons.calendar_today;
      case 'CHAT':
        return Icons.chat;
      case 'COLLABORATOR':
        return Icons.person;
      default:
        return Icons.info;
    }
  }
}

// ============================================================================
// ACTIVITY LOG TIMELINE (ALTERNATIVE VIEW)
// ============================================================================

class ActivityLogTimeline extends StatelessWidget {
  final List<ActivityLogEntry> activities;

  const ActivityLogTimeline({
    Key? key,
    required this.activities,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        final isLast = index == activities.length - 1;
        final formatter = DateFormat('MMM d, y');
        final date = formatter.format(activity.createdAt);

        // Check if we need to show a date separator
        final showDateSeparator = index == 0 ||
            date !=
                formatter.format(activities[index - 1].createdAt);

        return Column(
          children: [
            if (showDateSeparator) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  date,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline line
                Column(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getActivityColor(activity),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 60,
                        color: Colors.grey[300],
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.getActionLabel(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by ${activity.actorName ?? activity.actorUid}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (activity.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            activity.note!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('h:mm a').format(activity.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Color _getActivityColor(ActivityLogEntry activity) {
    if (activity.actionType.contains('COLLABORATOR')) {
      return Colors.blue;
    } else if (activity.actionType.contains('ORDER')) {
      return Colors.orange;
    } else if (activity.actionType.contains('LISTING')) {
      return Colors.green;
    } else if (activity.actionType.contains('CHAT')) {
      return Colors.purple;
    }
    return Colors.grey;
  }
}
