import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/api/firebase/table_mode_firebase.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/table_mode_models.dart';

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
  
  // Cache staff list to reduce Firebase reads (avoids App Check rate limits)
  List<StaffMember>? _cachedStaffList;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startListening();
    _loadStaffList(); // Preload staff list
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
    final isDark = isDarkMode(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Table Sessions'.tr()),
        backgroundColor: Color(colorPrimary),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: isDark ? Colors.white.withOpacity(0.6) : Colors.white70,
          indicatorColor: Colors.white,
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
    final isDark = isDarkMode(context);
    
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
              color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              isPending
                  ? 'No pending sessions'.tr()
                  : isActive
                      ? 'No active sessions'.tr()
                      : 'No closed sessions'.tr(),
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
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
    // Fetch available staff (owner + collaborators)
    final selectedWaiters = await _showStaffSelectionDialog();
    
    if (selectedWaiters == null || selectedWaiters.isEmpty) {
      return;
    }

    showProgress(context, 'Assigning waiter...'.tr(), false, Color(colorPrimary));

    try {
      await _repository.assignWaiterToSession(
        sessionId: session.sessionId,
        waiterUids: selectedWaiters.map((s) => s.uid).toList(),
      );

      hideProgress();
      showSnackBar(context, 'Waiter assigned successfully!'.tr());
    } catch (e) {
      hideProgress();
      // Better error handling for App Check failures
      final errorMsg = e.toString().replaceAll('Exception: ', '');
      if (errorMsg.contains('Too many attempts') || errorMsg.contains('App Check')) {
        showSnackBar(context, 'Too many requests. Please wait a moment and try again.'.tr());
      } else {
        showSnackBar(context, errorMsg);
      }
    }
  }

  Future<List<StaffMember>?> _showStaffSelectionDialog() async {
    // Use cached list if available to avoid App Check rate limits
    if (_cachedStaffList != null && _cachedStaffList!.isNotEmpty) {
      return await showDialog<List<StaffMember>>(
        context: context,
        builder: (context) => _StaffSelectionDialog(staffList: _cachedStaffList!),
      );
    }

    // Otherwise load fresh (with loading indicator)
    showProgress(context, 'Loading staff...'.tr(), false, Color(colorPrimary));
    await _loadStaffList();
    hideProgress();

    if (_cachedStaffList == null || _cachedStaffList!.isEmpty) {
      showSnackBar(context, 'No available staff found'.tr());
      return null;
    }

    return await showDialog<List<StaffMember>>(
      context: context,
      builder: (context) => _StaffSelectionDialog(staffList: _cachedStaffList!),
    );
  }

  Future<void> _loadStaffList() async {
    try {
      // Fetch owner
      final ownerSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.listing.authorID)
          .get();
      
      final staffList = <StaffMember>[];
      
      if (ownerSnap.exists) {
        final ownerData = ownerSnap.data()!;
        staffList.add(StaffMember(
          uid: widget.listing.authorID,
          name: '${ownerData['firstName'] ?? ''} ${ownerData['lastName'] ?? ''}'.trim(),
          role: 'Owner',
          photoUrl: ownerData['profilePictureURL'] ?? '',
        ));
      }

      // Fetch collaborators with table management permissions
      final collabsSnap = await FirebaseFirestore.instance
          .collection('listings')
          .doc(widget.listing.id)
          .collection('collaborators')
          .where('isActive', isEqualTo: true)
          .get();

      for (final collabDoc in collabsSnap.docs) {
        final collabData = collabDoc.data();
        final permissions = collabData['permissions'] as Map<String, dynamic>? ?? {};
        
        // Only include collaborators with order/chat management permissions
        if (permissions['manageOrders'] == true || permissions['manageChats'] == true) {
          final userSnap = await FirebaseFirestore.instance
              .collection('users')
              .doc(collabDoc.id)
              .get();
          
          if (userSnap.exists) {
            final userData = userSnap.data()!;
            staffList.add(StaffMember(
              uid: collabDoc.id,
              name: '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
              role: 'Staff',
              photoUrl: userData['profilePictureURL'] ?? '',
            ));
          }
        }
      }

      _cachedStaffList = staffList;
    } catch (e) {
      debugPrint('Error loading staff list: $e');
      // Don't show error if this is background preload
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
    final isDark = isDarkMode(context);
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Close Session?'.tr(),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          'Close ${session.tableName} session for ${session.customerName}?'.tr(),
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.black87,
          ),
        ),
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

class _SessionCard extends StatefulWidget {
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
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expandedRequests = false;

  String _localizedStatus(TableSessionStatus status) {
    switch (status) {
      case TableSessionStatus.PENDING:
        return 'Pending'.tr();
      case TableSessionStatus.ACTIVE:
        return 'Active'.tr();
      case TableSessionStatus.CLOSED:
        return 'Closed'.tr();
      case TableSessionStatus.REJECTED:
        return 'Rejected'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return Card(
      elevation: 2,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  backgroundImage: widget.session.customerPhotoUrl.isNotEmpty
                      ? NetworkImage(widget.session.customerPhotoUrl)
                      : null,
                  child: widget.session.customerPhotoUrl.isEmpty
                      ? Text(
                          widget.session.customerName[0].toUpperCase(),
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.tableName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        widget.session.customerName,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: widget.isPending
                        ? (isDark ? Colors.orange.shade900 : Colors.orange.shade100)
                        : widget.isActive
                            ? (isDark ? Colors.green.shade900 : Colors.green.shade100)
                            : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _localizedStatus(widget.session.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: widget.isPending
                          ? (isDark ? Colors.orange.shade200 : Colors.orange.shade900)
                          : widget.isActive
                              ? (isDark ? Colors.green.shade200 : Colors.green.shade900)
                              : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Time info
            Text(
              '${'Started'.tr()}: ${_formatTime(widget.session.createdAt)}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            if (widget.session.activatedAt != null)
              Text(
                '${'Activated'.tr()}: ${_formatTime(widget.session.activatedAt!)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),

            // Assigned staff (if any)
            if (widget.session.assignedStaff.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: widget.session.assignedStaff.map((staff) {
                  return Chip(
                    backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                    avatar: CircleAvatar(
                      backgroundColor: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                      backgroundImage: staff.photoUrl.isNotEmpty
                          ? NetworkImage(staff.photoUrl)
                          : null,
                      child: staff.photoUrl.isEmpty
                          ? Text(
                              staff.firstName[0],
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            )
                          : null,
                    ),
                    label: Text(staff.firstName),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
              ),
            ],

            // Pending requests section
            if (widget.isActive) ...[
              const SizedBox(height: 12),
              _buildRequestsSection(context, isDark),
            ],

            // Actions
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.isPending)
                  ElevatedButton.icon(
                    onPressed: widget.onAssignWaiter,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: Text('Assign Waiter'.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                if (widget.isActive) ...[
                  OutlinedButton.icon(
                    onPressed: widget.onAcknowledgeSummon,
                    icon: const Icon(Icons.check, size: 16),
                    label: Text('Acknowledge'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _reassignWaiter(),
                    icon: const Icon(Icons.person, size: 16),
                    label: Text('Change Waiter'.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.onCloseSession,
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

  Widget _buildRequestsSection(BuildContext context, bool isDark) {
    final repository = tableModeRepository;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with expand/collapse
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _expandedRequests = !_expandedRequests;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _expandedRequests ? Icons.expand_less : Icons.expand_more,
                    color: Color(colorPrimary),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Customer Requests'.tr(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(colorPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Requests list (expanded)
        if (_expandedRequests)
          StreamBuilder<List<SessionEventModel>>(
            stream: repository.streamSessionEvents(sessionId: widget.session.sessionId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SizedBox(
                    height: 30,
                    child: Center(
                      child: SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Color(colorPrimary)),
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Error loading requests'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                    ),
                  ),
                );
              }

              final events = snapshot.data ?? [];
              
              // Filter for pending requests (not yet acknowledged)
              final pendingRequests = events
                  .where((e) => e.type == SessionEventType.WAITER_SUMMONED || 
                                e.type == SessionEventType.BILL_REQUESTED)
                  .toList();

              if (pendingRequests.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'No pending requests'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: pendingRequests.map((event) {
                    return _buildRequestItem(event, isDark);
                  }).toList(),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildRequestItem(SessionEventModel event, bool isDark) {
    final isSummon = event.type == SessionEventType.WAITER_SUMMONED;
    final requestColor = isSummon ? Colors.blue : Colors.amber;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? requestColor.shade900.withOpacity(0.3) : requestColor.shade50,
        border: Border.all(
          color: requestColor.shade200,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request type and time
          Row(
            children: [
              Icon(
                isSummon ? Icons.person_add : Icons.receipt,
                size: 16,
                color: requestColor.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                isSummon ? 'Waiter Summon'.tr() : 'Bill Request'.tr(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: requestColor.shade700,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(event.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
          
          // Details
          if (isSummon && event.metadata != null) ...[
            const SizedBox(height: 4),
            Text(
              '${'Purpose'.tr()}: ${event.metadata?['purpose'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ] else if (!isSummon && event.metadata != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${'Payment'.tr()}: ${event.metadata?['paymentMethod'] ?? 'N/A'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () {
                    final value = (event.metadata?['paymentMethod'] ?? 'N/A').toString();
                    Clipboard.setData(ClipboardData(text: value));
                    showSnackBar(context, 'Copied to clipboard'.tr());
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 14, color: requestColor.shade600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now'.tr();
    if (diff.inMinutes < 60) {
      return 'minutes_ago'.tr(args: [diff.inMinutes.toString()]);
    }
    if (diff.inHours < 24) {
      return 'hours_ago'.tr(args: [diff.inHours.toString()]);
    }
    return DateFormat('MMM d, HH:mm').format(time);
  }

  Future<void> _reassignWaiter() async {
    final parentState = context.findAncestorStateOfType<_StaffTableSessionsScreenState>();
    if (parentState == null) return;

    final availableStaff = parentState._cachedStaffList ?? [];
    if (availableStaff.isEmpty) {
      showSnackBar(context, 'No staff available to assign'.tr());
      return;
    }

    final selectedStaff = await showDialog<List<StaffMember>>(
      context: context,
      builder: (context) => _StaffSelectionDialog(staffList: availableStaff),
    );

    if (selectedStaff == null || selectedStaff.isEmpty) return;

    final isDark = isDarkMode(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Change Waiter?'.tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        content: Text(
          'Replace current waiter(s) with ${selectedStaff.map((s) => s.name).join(', ')}?'.tr(),
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Change'.tr()),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    showProgress(context, 'Reassigning waiter...'.tr(), false, Color(colorPrimary));

    try {
      await tableModeRepository.assignWaiterToSession(
        sessionId: widget.session.sessionId,
        waiterUids: selectedStaff.map((s) => s.uid).toList(),
      );

      hideProgress();
      showSnackBar(context, 'Waiter changed successfully!'.tr());
    } catch (e) {
      hideProgress();
      showSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }
}

// ============================================================================
// STAFF MEMBER MODEL
// ============================================================================

class StaffMember {
  final String uid;
  final String name;
  final String role;
  final String photoUrl;

  StaffMember({
    required this.uid,
    required this.name,
    required this.role,
    required this.photoUrl,
  });
}

// ============================================================================
// STAFF SELECTION DIALOG
// ============================================================================

class _StaffSelectionDialog extends StatefulWidget {
  final List<StaffMember> staffList;

  const _StaffSelectionDialog({required this.staffList});

  @override
  State<_StaffSelectionDialog> createState() => _StaffSelectionDialogState();
}

class _StaffSelectionDialogState extends State<_StaffSelectionDialog> {
  final Set<String> _selectedUids = {};

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Text(
        'Assign Waiter(s)'.tr(),
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select one or more staff members to assign'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.staffList.length,
                itemBuilder: (context, index) {
                  final staff = widget.staffList[index];
                  final isSelected = _selectedUids.contains(staff.uid);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (selected) {
                      setState(() {
                        if (selected == true) {
                          _selectedUids.add(staff.uid);
                        } else {
                          _selectedUids.remove(staff.uid);
                        }
                      });
                    },
                    title: Text(
                      staff.name.isEmpty ? 'User ${staff.uid.substring(0, 6)}' : staff.name,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    subtitle: Text(
                      staff.role,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    secondary: CircleAvatar(
                      backgroundColor: Color(colorPrimary).withOpacity(0.2),
                      backgroundImage: staff.photoUrl.isNotEmpty
                          ? NetworkImage(staff.photoUrl)
                          : null,
                      child: staff.photoUrl.isEmpty
                          ? Icon(
                              Icons.person,
                              color: Color(colorPrimary),
                            )
                          : null,
                    ),
                    activeColor: Color(colorPrimary),
                    contentPadding: EdgeInsets.zero,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel'.tr(),
            style: TextStyle(
              color: isDark ? Colors.grey[300] : Colors.black54,
            ),
          ),
        ),
        TextButton(
          onPressed: _selectedUids.isEmpty
              ? null
              : () {
                  final selected = widget.staffList
                      .where((s) => _selectedUids.contains(s.uid))
                      .toList();
                  Navigator.pop(context, selected);
                },
          child: Text(
            'Assign (${_selectedUids.length})'.tr(),
            style: TextStyle(
              color: _selectedUids.isEmpty
                  ? Colors.grey
                  : Color(colorPrimary),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

