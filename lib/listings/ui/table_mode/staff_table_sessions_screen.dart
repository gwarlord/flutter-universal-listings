import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/model/user.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/api/firebase/table_mode_firebase.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/table_mode_models.dart';

class StaffTableSessionsScreen extends StatefulWidget {
  final ListingModel listing;
  final User currentUser;

  const StaffTableSessionsScreen({
    super.key,
    required this.listing,
    required this.currentUser,
  });

  @override
  State<StaffTableSessionsScreen> createState() => _StaffTableSessionsScreenState();
}

class _StaffTableSessionsScreenState extends State<StaffTableSessionsScreen>
    with SingleTickerProviderStateMixin {
  final _repository = tableModeRepository;
  late final TabController _tabController;
  StreamSubscription? _sessionsSubscription;

  List<TableSessionModel> _pendingSessions = [];
  List<TableSessionModel> _activeSessions = [];
  List<TableSessionModel> _closedSessions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startListening();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _sessionsSubscription?.cancel();
    super.dispose();
  }

  void _startListening() {
    _sessionsSubscription?.cancel();
    _sessionsSubscription = _repository
        .streamListingSessions(listingId: widget.listing.id)
        .listen((sessions) {
      if (!mounted) return;

      setState(() {
        _pendingSessions = sessions
            .where((s) => s.status == TableSessionStatus.PENDING)
            .toList();
        _activeSessions = sessions
            .where((s) => s.status == TableSessionStatus.ACTIVE)
            .toList();
        _closedSessions = sessions
            .where((s) => s.status == TableSessionStatus.CLOSED)
            .toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Table Sessions'.tr()),
        backgroundColor: Color(colorPrimary),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'Pending'.tr(),
              icon: Badge(
                label: Text('${_pendingSessions.length}'),
                isLabelVisible: _pendingSessions.isNotEmpty,
                child: const Icon(Icons.pending),
              ),
            ),
            Tab(
              text: 'Active'.tr(),
              icon: Badge(
                label: Text('${ _activeSessions.length}'),
                isLabelVisible: _activeSessions.isNotEmpty,
                child: const Icon(Icons.check_circle),
              ),
            ),
            Tab(
              text: 'Closed'.tr(),
              icon: const Icon(Icons.history),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSessionsList(_pendingSessions, isPending: true),
          _buildSessionsList(_activeSessions, isActive: true),
          _buildSessionsList(_closedSessions),
        ],
      ),
    );
  }

  Widget _buildSessionsList(
    List<TableSessionModel> sessions, {
    bool isPending = false,
    bool isActive = false,
  }) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending
                  ? Icons.pending
                  : isActive
                      ? Icons.check_circle
                      : Icons.history,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'No pending sessions'.tr()
                  : isActive
                      ? 'No active sessions'.tr()
                      : 'No closed sessions'.tr(),
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sessions.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final session = sessions[index];
        return _SessionCard(
          session: session,
          isPending: isPending,
          isActive: isActive,
          onAssignWaiter: () => _assignWaiter(session),
          onAcknowledgeSummon: () => _acknowledgeSummon(session),
          onCloseSession: () => _closeSession(session),
        );
      },
    );
  }

  Future<void> _assignWaiter(TableSessionModel session) async {
    // TODO: In a real implementation, you'd fetch available staff from Firestore
    // For now, use current user as the waiter
    showProgress(context, 'Assigning waiter...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.assignWaiterToSession(
        sessionId: session.sessionId,
        waiterUids: [widget.currentUser.userID],
      );

      hideProgress();
      showSnackBar(context, 'Waiter assigned successfully!'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _acknowledgeSummon(TableSessionModel session) async {
    showProgress(context, 'Acknowledging summon...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.acknowledgeSummon(sessionId: session.sessionId);

      hideProgress();
      showSnackBar(context, 'Summon acknowledged!'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> _closeSession(TableSessionModel session) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Close Session?'.tr()),
        content: Text('Close ${session.tableName} session for ${session.customerName}?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Close'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showProgress(context, 'Closing session...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.closeTableSession(sessionId: session.sessionId);

      hideProgress();
      showSnackBar(context, 'Session closed!'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }
}

// ============================================================================
// SESSION CARD WIDGET
// ============================================================================

class _SessionCard extends StatelessWidget {
  final TableSessionModel session;
  final bool isPending;
  final bool isActive;
  final VoidCallback onAssignWaiter;
  final VoidCallback onAcknowledgeSummon;
  final VoidCallback onCloseSession;

  const _SessionCard({
    required this.session,
    this.isPending = false,
    this.isActive = false,
    required this.onAssignWaiter,
    required this.onAcknowledgeSummon,
    required this.onCloseSession,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Table + Customer
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: session.customerPhotoUrl.isNotEmpty
                      ? NetworkImage(session.customerPhotoUrl)
                      : null,
                  child: session.customerPhotoUrl.isEmpty
                      ? Text(session.customerName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.tableName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        session.customerName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.orange.shade100
                        : isActive
                            ? Colors.green.shade100
                            : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.status.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isPending
                          ? Colors.orange.shade900
                          : isActive
                              ? Colors.green.shade900
                              : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time info
            Text(
              'Started: ${_formatTime(session.createdAt)}'.tr(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (session.activatedAt != null)
              Text(
                'Activated: ${_formatTime(session.activatedAt!)}'.tr(),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

            // Assigned staff (if any)
            if (session.assignedStaff.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: session.assignedStaff.map((staff) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: staff.photoUrl.isNotEmpty
                          ? NetworkImage(staff.photoUrl)
                          : null,
                      child: staff.photoUrl.isEmpty
                          ? Text(staff.firstName[0])
                          : null,
                    ),
                    label: Text(staff.firstName),
                    labelStyle: const TextStyle(fontSize: 12),
                  );
                }).toList(),
              ),
            ],

            // Actions
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (isPending)
                  ElevatedButton.icon(
                    onPressed: onAssignWaiter,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text('Assign Waiter'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                if (isActive) ...[
                  OutlinedButton.icon(
                    onPressed: onAcknowledgeSummon,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Acknowledge'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCloseSession,
                    icon: const Icon(Icons.close, size: 16),
                    label: Text('Close'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d, HH:mm').format(time);
  }
}
