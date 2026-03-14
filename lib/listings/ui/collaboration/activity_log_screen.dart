import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/model/collaboration_model.dart';
import 'package:caribtap/core/ui/theme/app_theme.dart';

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
    final theme = Theme.of(context);
    final appColors = context.appThemeColors;

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
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
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
                    color: appColors.mutedText.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No Activity',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity log will appear here',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: appColors.mutedText,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
    final theme = Theme.of(context);
    final appColors = context.appThemeColors;
    final formatter = DateFormat('MMM d, y • h:mm a');
    final formattedDate = formatter.format(activity.createdAt);

    Color categoryColor = Colors.grey;
    IconData icon = Icons.info_outline;

    if (activity.actionType.contains('COLLABORATOR')) {
      categoryColor = Colors.blue;
      icon = Icons.person;
    } else if (activity.actionType.contains('ORDER')) {
      categoryColor = Colors.orange;
      icon = Icons.shopping_cart;
    } else if (activity.actionType.contains('LISTING')) {
      categoryColor = Colors.green;
      icon = Icons.edit;
    } else if (activity.actionType.contains('CHAT')) {
      categoryColor = Colors.purple;
      icon = Icons.chat;
    }

    final isDark = theme.brightness == Brightness.dark;
    final tileBgColor = isDark
        ? categoryColor.withOpacity(0.12)
        : categoryColor.withOpacity(0.08);

    // Prefer actorName (display name) over actorUid
    final actorDisplayName = activity.actorName != null && activity.actorName!.isNotEmpty
        ? activity.actorName!
        : activity.actorUid;

    // Prefer targetName (display name) over targetId
    final targetDisplayName = activity.targetName != null && activity.targetName!.isNotEmpty
        ? activity.targetName!
        : activity.targetId;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      color: tileBgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: categoryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: categoryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.getActionLabel(),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by $actorDisplayName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: appColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getRoleColor(activity.actorRole).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
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
            if (activity.targetType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    _getTargetIcon(activity.targetType),
                    size: 14,
                    color: appColors.mutedText,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${activity.targetType}: $targetDisplayName',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: appColors.mutedText,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (activity.note != null && activity.note!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black12 : Colors.white54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  activity.note!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                formattedDate,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: appColors.mutedText.withOpacity(0.7),
                ),
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
        return Colors.redAccent;
      case 'COLLABORATOR':
        return Colors.blueAccent;
      case 'ADMIN':
        return Colors.purpleAccent;
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
    final theme = Theme.of(context);
    final appColors = context.appThemeColors;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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

        // Prefer actorName over actorUid
        final actorDisplayName = activity.actorName != null && activity.actorName!.isNotEmpty
            ? activity.actorName!
            : activity.actorUid;

        return Column(
          children: [
            if (showDateSeparator) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: appColors.subtleBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      date,
                      style: theme.textTheme.bodySmall?.copyWith(
                            color: appColors.mutedText,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
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
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getActivityColor(activity),
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _getActivityColor(activity).withOpacity(0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 60,
                        color: appColors.cardBorder,
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'by $actorDisplayName',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: appColors.mutedText,
                        ),
                      ),
                      if (activity.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: appColors.subtleBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              activity.note!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('h:mm a').format(activity.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: appColors.mutedText.withOpacity(0.6),
                            ),
                      ),
                      const SizedBox(height: 16),
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
