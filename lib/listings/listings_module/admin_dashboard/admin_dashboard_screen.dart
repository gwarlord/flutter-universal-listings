import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/reported_listing_model.dart';
import 'package:caribtap/listings/model/suspension_info.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/admin_bloc.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/suspension_reason_dialog.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/review_removal_requests_screen.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/services/review_removal_request_service.dart';
import 'package:caribtap/listings/services/featured_service.dart';
import 'package:caribtap/listings/utils/suspension_reason_details.dart';
import 'package:caribtap/listings/utils/category_localization.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/global_notification_screen.dart';

class AdminDashboardWrappingWidget extends StatelessWidget {
  final ListingsUser currentUser;
  final int initialTabIndex;

  const AdminDashboardWrappingWidget({
    super.key,
    required this.currentUser,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc(
        currentUser: currentUser,
        listingsRepository: listingApiManager,
        profileRepository: profileApiManager,
      ),
      child: AdminDashboardScreen(
        currentUser: currentUser,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final int initialTabIndex;

  const AdminDashboardScreen({
    super.key,
    required this.currentUser,
    this.initialTabIndex = 0,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<ListingsUser> suspendedUsers = [];
  List<ListingsUser> allUsers = [];
  List<ListingModel> suspendedListings = [];
  List<ReportedListing> reportedListings = [];
  List<ListingModel> allListings = [];
  List<EventModel> allEvents = [];
  List<ListingModel> unverifiedListings = [];
  late ListingsUser currentUser;
  bool isLoading = true;
  String userSearchQuery = '';
  String listingSearchQuery = '';
  bool showOnlySuspendedUsers = false;
  bool showOnlySuspendedListings = false;

  // Verification tab filters
  String verificationSearchQuery = '';
  bool vHasPhone = false;
  bool vHasEmail = false;
  bool vHasVideo = false;
  bool vHighRating = false;
  String vCountryCode = '';

  // Moderation & Feedback segment state
  String _moderationMode = 'verification';
  String _feedbackMode = 'suggestions';

  // Review removal requests
  final ReviewRemovalRequestService _reviewRequestService =
      ReviewRemovalRequestService();
  int _pendingReviewRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    final safeInitialIndex = widget.initialTabIndex.clamp(0, 3);
    _tabController =
      TabController(length: 4, vsync: this, initialIndex: safeInitialIndex);
    currentUser = widget.currentUser;
    _loadAllData();
    _loadPendingRequestsCount();

    _tabController.addListener(() {
      if (_tabController.index == 2) {
        // Pre-load both sections when Moderation tab is opened
        if (unverifiedListings.isEmpty) _loadUnverifiedListings();
        context.read<AdminBloc>().add(GetReportedListingsEvent());
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUnverifiedListings();
    });
  }

  void _loadAllData() {
    context.read<AdminBloc>().add(GetAllUsersEvent());
    context.read<AdminBloc>().add(GetSuspendedUsersEvent());
    context.read<AdminBloc>().add(GetAllListingsEvent());
    context.read<AdminBloc>().add(GetSuspendedListingsEvent());
    _loadAllEvents();
  }

  Future<void> _loadAllEvents() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('events').get();
      final events = snapshot.docs
          .map((doc) => EventModel.fromJson(doc.data()..['id'] = doc.id))
          .toList()
        ..sort((a, b) => b.createdAtSeconds.compareTo(a.createdAtSeconds));

      if (!mounted) return;
      setState(() {
        allEvents = events;
      });
    } catch (_) {}
  }

  Future<void> _loadPendingRequestsCount() async {
    final count = await _reviewRequestService.getPendingRequestsCount();
    if (mounted) {
      setState(() {
        _pendingReviewRequestsCount = count;
      });
    }
  }

  Future<void> _navigateToReviewRequests() async {
    await push(
      context,
      ReviewRemovalRequestsScreen(currentUser: currentUser),
    );
    // Reload count after returning
    _loadPendingRequestsCount();
  }

  void _searchUsers(String query) {
    userSearchQuery = query;
    context.read<AdminBloc>().add(GetAllUsersEvent(searchQuery: query));
  }

  List<ListingsUser> get filteredUsers {
    List<ListingsUser> list =
        showOnlySuspendedUsers ? suspendedUsers : allUsers;
    if (userSearchQuery.isEmpty) return list;

    return list
        .where((user) =>
            user.firstName
                .toLowerCase()
                .contains(userSearchQuery.toLowerCase()) ||
            user.lastName
                .toLowerCase()
                .contains(userSearchQuery.toLowerCase()) ||
            user.email.toLowerCase().contains(userSearchQuery.toLowerCase()))
        .toList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Console'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // Global Notification broadcast button
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Send Global Notification'.tr(),
            onPressed: () => push(
              context,
              GlobalNotificationScreen(currentUser: currentUser),
            ),
          ),
          // Review Removal Requests Button with Badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.report_problem),
                tooltip: 'Review Removal Requests'.tr(),
                onPressed: _navigateToReviewRequests,
              ),
              if (_pendingReviewRequestsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _pendingReviewRequestsCount > 99
                          ? '99+'
                          : _pendingReviewRequestsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Platform.isIOS ? Color(colorPrimary) : Colors.white,
          indicatorWeight: 3,
          labelColor: isDark ? Colors.white : Colors.black87,
          unselectedLabelColor: isDark ? Colors.white70 : Colors.black,
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: [
            Tab(text: 'Users'.tr()),
            Tab(text: 'Listings'.tr()),
            Tab(text: 'Moderation'.tr()),
            Tab(text: 'Feedback'.tr()),
          ],
          isScrollable: false,
        ),
      ),
      body: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AllUsersState) {
            isLoading = false;
            allUsers = state.users;
            setState(() {});
          } else if (state is SuspendedUsersState) {
            isLoading = false;
            suspendedUsers = state.suspendedUsers;
            setState(() {});
          } else if (state is AllListingsState) {
            isLoading = false;
            allListings = state.listings;
            setState(() {});
          } else if (state is SuspendedListingsState) {
            isLoading = false;
            suspendedListings = state.suspendedListings;
            setState(() {});
          } else if (state is ReportedListingsState) {
            isLoading = false;
            reportedListings = state.reportedListings;
            setState(() {});
          } else if (state is LoadingState) {
            isLoading = true;
            setState(() {});
          }
        },
        builder: (context, state) {
          return TabBarView(
            controller: _tabController,
            children: [
              _buildAllUsersTab(),
              _buildAllListingsTab(),
              _buildModerationTab(),
              _buildFeedbackTab(),
            ],
          );
        },
      ),
    );
  }

// ---- Combined Moderation tab (Verification Queue + Reports) ----
  Widget _buildModerationTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Color(colorPrimary),
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13),
            ),
            segments: [
              ButtonSegment(
                value: 'verification',
                label: Text('Queue'.tr()),
                icon: const Icon(Icons.verified_outlined, size: 16),
              ),
              ButtonSegment(
                value: 'reports',
                label: Text('Reports'.tr()),
                icon: const Icon(Icons.flag_outlined, size: 16),
              ),
            ],
            selected: {_moderationMode},
            onSelectionChanged: (Set<String> sel) {
              setState(() => _moderationMode = sel.first);
              if (_moderationMode == 'reports') {
                context.read<AdminBloc>().add(GetReportedListingsEvent());
              } else if (unverifiedListings.isEmpty) {
                _loadUnverifiedListings();
              }
            },
          ),
        ),
        Expanded(
          child: _moderationMode == 'verification'
              ? _buildVerificationTab()
              : _buildReportsTab(),
        ),
      ],
    );
  }

  // ---- Combined Feedback tab (Suggestions + Featured Requests) ----
  Widget _buildFeedbackTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: SegmentedButton<String>(
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: Color(colorPrimary),
              selectedForegroundColor: Colors.white,
              textStyle: const TextStyle(fontSize: 13),
            ),
            segments: [
              ButtonSegment(
                value: 'suggestions',
                label: Text('Suggestions'.tr()),
                icon: const Icon(Icons.lightbulb_outline, size: 16),
              ),
              ButtonSegment(
                value: 'featured',
                label: Text('Featured'.tr()),
                icon: const Icon(Icons.star_outline, size: 16),
              ),
            ],
            selected: {_feedbackMode},
            onSelectionChanged: (Set<String> sel) =>
                setState(() => _feedbackMode = sel.first),
          ),
        ),
        Expanded(
          child: _feedbackMode == 'suggestions'
              ? _buildSuggestionsTab()
              : _buildFeaturedTab(),
        ),
      ],
    );
  }

  Widget _buildSuggestionsTab() {
    final isDark = isDarkMode(context);
    final categoryOrder = <String>[
      'Look & Feel',
      'Listing Feature',
      'General App Feature',
      'Search & Discovery',
      'Performance & Reliability',
      'Other',
    ];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('app_suggestions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load suggestions'.tr(),
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          );
        }

        final allDocs = snapshot.data?.docs ?? const [];
        final docs = allDocs
            .where((doc) => (doc.data()['archived'] as bool?) != true)
            .toList();

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No active suggestions'.tr(),
              style: TextStyle(color: isDark ? Colors.white70 : Colors.black87),
            ),
          );
        }

        final grouped =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in docs) {
          final data = doc.data();
          final rawCategory = (data['category'] as String?)?.trim();
          final category = (rawCategory == null || rawCategory.isEmpty)
              ? 'Other'
              : rawCategory;
          grouped.putIfAbsent(category, () => []).add(doc);
        }

        final orderedCategories = [
          ...categoryOrder.where(grouped.containsKey),
          ...grouped.keys.where((c) => !categoryOrder.contains(c)).toList()
            ..sort(),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Text(
              'Suggestions by Category'.tr(),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${docs.length} total suggestions'.tr(),
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 14),
            for (final category in orderedCategories)
              _buildSuggestionCategoryCard(
                category: category,
                docs: grouped[category]!,
                isDark: isDark,
              ),
          ],
        );
      },
    );
  }

  Widget _buildSuggestionCategoryCard({
    required String category,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required bool isDark,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey[900] : Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: ExpansionTile(
        collapsedIconColor: isDark ? Colors.white70 : Colors.black54,
        iconColor: Color(colorPrimary),
        title: Text(
          localizeCategoryLabel(category, context),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          '${docs.length} suggestions'.tr(),
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
        ),
        children: docs.map((doc) {
          final data = doc.data();
          final suggestion = (data['suggestion'] as String?) ?? '';
          final userName = (data['userName'] as String?) ?? 'Unknown user';
          final userEmail = (data['userEmail'] as String?) ?? '';
          final relatedListingId =
              (data['relatedListingId'] as String?)?.trim() ?? '';
          final relatedListingTitle =
              (data['relatedListingTitle'] as String?)?.trim() ?? '';
          final createdAt = data['createdAt'];
          String timeLabel = '';
          if (createdAt is Timestamp) {
            timeLabel = DateFormat.yMMMd().add_jm().format(createdAt.toDate());
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$userName${userEmail.isNotEmpty ? ' • $userEmail' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                  if (timeLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ),
                  if (relatedListingId.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            visualDensity: const VisualDensity(
                                horizontal: -2, vertical: -2),
                          ),
                          onPressed: () => _openSuggestionListing(
                            relatedListingId,
                            relatedListingTitle,
                          ),
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: Text(
                            relatedListingTitle.isNotEmpty
                                ? 'View Listing: $relatedListingTitle'
                                : 'View Related Listing'.tr(),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Checkbox(
                        value: false,
                        visualDensity:
                            const VisualDensity(horizontal: -4, vertical: -4),
                        onChanged: (checked) async {
                          if (checked != true) return;
                          await FirebaseFirestore.instance
                              .collection('app_suggestions')
                              .doc(doc.id)
                              .update({
                            'archived': true,
                            'archivedAt': FieldValue.serverTimestamp(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });
                        },
                      ),
                      Text(
                        'Archive'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openSuggestionListing(
      String listingId, String listingTitle) async {
    context.read<LoadingCubit>().showLoading(
          context,
          'Loading listing...'.tr(),
          false,
          Color(colorPrimary),
        );
    try {
      final listing = await listingApiManager.getListing(listingID: listingId);
      if (!mounted) return;
      context.read<LoadingCubit>().hideLoading();

      if (listing == null) {
        showSnackBar(
          context,
          listingTitle.isNotEmpty
              ? 'Listing "$listingTitle" is no longer available.'.tr()
              : 'Listing is no longer available.'.tr(),
        );
        return;
      }

      await push(
        context,
        ListingDetailsWrappingWidget(
            listing: listing, currentUser: currentUser),
      );
    } catch (e) {
      if (!mounted) return;
      context.read<LoadingCubit>().hideLoading();
      showSnackBar(context, 'Error loading listing: $e'.tr());
    }
  }

  Widget _buildTabHeader({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required Function(String) onChanged,
    required bool filterActive,
    required Function(bool) onFilterChanged,
    required String filterLabel,
  }) {
    final isDark = isDarkMode(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle,
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: onChanged,
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search...'.tr(),
                      hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      prefixIcon: Icon(Icons.search,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(filterLabel),
                labelStyle: TextStyle(
                  color: filterActive
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight:
                      filterActive ? FontWeight.bold : FontWeight.normal,
                ),
                selected: filterActive,
                onSelected: onFilterChanged,
                selectedColor: Colors.red,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllUsersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
      },
      child: Column(
        children: [
          _buildTabHeader(
            title: 'User Management'.tr(),
            subtitle: '${allUsers.length} total users registered'.tr(),
            controller: TextEditingController(),
            onChanged: _searchUsers,
            filterActive: showOnlySuspendedUsers,
            onFilterChanged: (v) => setState(() => showOnlySuspendedUsers = v),
            filterLabel: 'Suspended'.tr(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _buildTrialProgramPanel(),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : filteredUsers.isEmpty
                    ? showEmptyState('No Users Found'.tr(),
                        'Try a different search query.'.tr())
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return ModernUserCard(
                            user: user,
                            onSuspend: () => _showSuspendUserConfirmation(user),
                            onUnsuspend: () =>
                                _showUnsuspendUserConfirmation(user),
                            onToggleFreshnessExempt: (value) =>
                                _toggleUserFreshnessExempt(user, value),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateTrialConfig({
    bool? enabled,
    bool? requiresPhoneVerified,
  }) async {
    try {
      final update = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUser.userID,
      };
      if (enabled != null) {
        update['professionalTrialEnabled'] = enabled;
      }
      if (requiresPhoneVerified != null) {
        update['professionalTrialRequiresPhoneVerified'] = requiresPhoneVerified;
      }

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('subscription_config')
          .set(update, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trial program settings updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update trial settings: $e')),
      );
    }
  }

  Widget _buildTrialProgramPanel() {
    final isDark = isDarkMode(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trial Program',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Control trial rollout and review recent claims.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('settings')
                .doc('subscription_config')
                .snapshots(),
            builder: (context, snapshot) {
              final data = snapshot.data?.data() ?? const <String, dynamic>{};
              final enabled = data['professionalTrialEnabled'] != false;
              final requiresPhone =
                  data['professionalTrialRequiresPhoneVerified'] == true;

              return Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable 30-day Professional trial'),
                    subtitle: const Text('Global server-side rollout switch'),
                    value: enabled,
                    onChanged: (value) => _updateTrialConfig(enabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Require phone verification'),
                    subtitle: const Text('Applies when users claim the trial'),
                    value: requiresPhone,
                    onChanged: enabled
                        ? (value) => _updateTrialConfig(
                            requiresPhoneVerified: value,
                          )
                        : null,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Text(
            'Recent Trial Claims',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 180,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('subscription_trial_claims')
                  .orderBy('claimedAt', descending: true)
                  .limit(12)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator.adaptive(),
                  );
                }

                final docs = snapshot.data?.docs ?? const [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No trial claims yet.',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final email = (data['email'] ?? '').toString();
                    final tier = (data['tier'] ?? 'professional').toString();
                    final phoneVerified = data['phoneVerified'] == true;
                    final claimedAt = data['claimedAt'] as Timestamp?;
                    final timeLabel = claimedAt != null
                        ? DateFormat.yMMMd().add_jm().format(claimedAt.toDate())
                        : '-';

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        email.isNotEmpty ? email : 'Unknown user',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('$tier • $timeLabel'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: phoneVerified
                              ? Colors.green.withOpacity(0.12)
                              : Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          phoneVerified ? 'Phone ✓' : 'Phone -',
                          style: TextStyle(
                            fontSize: 11,
                            color: phoneVerified ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllListingsTab() {
    final listings = _getFilteredListings();
    final events = _getFilteredEventsForAdmin();
    final unsuspensionRequestCount = suspendedListings
        .where((l) => l.suspensionInfo?.unsuspensionRequested == true)
        .length;
    final totalManagedCount = allListings.length + allEvents.length;
    final subtitleText = unsuspensionRequestCount > 0
      ? '$totalManagedCount total items • ${allListings.length} listings • ${allEvents.length} events • $unsuspensionRequestCount unsuspension ${unsuspensionRequestCount == 1 ? 'request' : 'requests'}'
            .tr()
      : '$totalManagedCount total items • ${allListings.length} listings • ${allEvents.length} events'.tr();

    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
      },
      child: Column(
        children: [
          _buildTabHeader(
            title: 'Listing Management'.tr(),
            subtitle: subtitleText,
            controller: TextEditingController(),
            onChanged: (v) => setState(() => listingSearchQuery = v),
            filterActive: showOnlySuspendedListings,
            onFilterChanged: (v) =>
                setState(() => showOnlySuspendedListings = v),
            filterLabel: 'Suspended'.tr(),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : listings.isEmpty && events.isEmpty
                    ? showEmptyState('No Listings Found'.tr(),
                        'Try a different search query.'.tr())
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 24),
                        children: [
                          if (listings.isNotEmpty) ...[
                            _AdminListSectionHeader(
                              title: 'Listings'.tr(),
                              count: listings.length,
                            ),
                            ...listings.map(
                              (listing) => ModernListingCard(
                                listing: listing,
                                onSuspend: () =>
                                    _showSuspendListingConfirmation(listing),
                                onUnsuspend: () =>
                                    _showUnsuspendListingConfirmation(listing),
                                onFeature: () => _featureListing(listing),
                                onUnfeature: () => _unfeatureListing(listing),
                                onToggleFreshnessExempt: (value) =>
                                    _toggleListingFreshnessExempt(listing, value),
                                onToggleDemo: (value) =>
                                    _toggleListingDemo(listing, value),
                                onToggleMainVisibility: (value) =>
                                    _toggleListingMainVisibility(listing, value),
                              ),
                            ),
                          ],
                          if (events.isNotEmpty) ...[
                            _AdminListSectionHeader(
                              title: 'Events'.tr(),
                              count: events.length,
                            ),
                            ...events.map(
                              (event) => ModernEventCard(
                                event: event,
                                onOpen: () => _viewEvent(event),
                                onDelete: () => _deleteManagedEvent(event),
                                onToggleDemo: (value) =>
                                    _toggleEventDemo(event, value),
                                onToggleMainVisibility: (value) =>
                                    _toggleEventMainVisibility(event, value),
                              ),
                            ),
                          ],
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        context.read<AdminBloc>().add(GetReportedListingsEvent());
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Flagged Content'.tr(),
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode(context) ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Review listings reported by users.'.tr(),
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode(context)
                        ? Colors.grey[400]
                        : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : reportedListings.isEmpty
                    ? showEmptyState(
                        'No Reports Found'.tr(), 'All caught up!'.tr())
                    : Builder(
                        builder: (context) {
                          final groupedReports = <String, List<ReportedListing>>{};
                          for (final report in reportedListings) {
                            final key = _reportGroupKey(report);
                            groupedReports.putIfAbsent(key, () => []).add(report);
                          }

                          final uniqueReports = groupedReports.values
                              .map((group) => group.first)
                              .toList();

                          return ListView.builder(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: uniqueReports.length,
                            itemBuilder: (context, index) {
                              final report = uniqueReports[index];
                              final reportCount = groupedReports[_reportGroupKey(report)]?.length ?? 1;
                              return _buildReportCard(report, reportCount);
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  String _reportGroupKey(ReportedListing report) {
    if (report.isOrderFulfillmentIssue &&
        report.orderId != null &&
        report.orderId!.isNotEmpty) {
      return '${report.listingId}_${report.orderId}';
    }
    return report.listingId;
  }

  List<ReportedListing> _reportsInSameGroup(ReportedListing report) {
    final key = _reportGroupKey(report);
    return reportedListings.where((r) => _reportGroupKey(r) == key).toList();
  }

  String _formatOrderLabel(String orderId) {
    if (orderId.length <= 8) return orderId.toUpperCase();
    return orderId.substring(0, 8).toUpperCase();
  }

  String _buildSuspensionReasonDetails(ReportedListing report) {
    final details = <String>[];

    if (report.isOrderFulfillmentIssue) {
      details.add('Order fulfillment fraud report');
      if (report.orderId != null && report.orderId!.isNotEmpty) {
        details.add('Order ID: ${report.orderId}');
      }
      if (report.orderStatus != null && report.orderStatus!.isNotEmpty) {
        details.add('Order status: ${report.orderStatus}');
      }
    } else {
      details.add('Fraudulent activity reported by users');
    }

    if (report.reporterName.trim().isNotEmpty) {
      details.add('Reported by: ${report.reporterName.trim()}');
    }
    if (report.reason.trim().isNotEmpty) {
      details.add('Reported issue: ${report.reason.trim()}');
    }

    return details.join('\n');
  }

  Widget _buildReportCard(ReportedListing report, int reportCount) {
    final isDark = isDarkMode(context);
    return GestureDetector(
      onTap: () => _viewReportedListing(report),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.flag, color: Colors.red, size: 24),
                    ),
                    if (reportCount > 1)
                      Positioned(
                        right: -6,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    isDark ? Colors.grey[900]! : Colors.white,
                                width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            reportCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        report.listingTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (report.isOrderFulfillmentIssue &&
                          report.orderId != null &&
                          report.orderId!.isNotEmpty)
                        Text(
                          'Order #${_formatOrderLabel(report.orderId!)} • ${report.orderStatus ?? 'fulfilled'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.orange[300] : Colors.orange[800],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (report.isOrderFulfillmentIssue &&
                          report.orderId != null &&
                          report.orderId!.isNotEmpty)
                        const SizedBox(height: 2),
                      Text(
                        reportCount > 1
                            ? '$reportCount reports • Latest by ${report.reporterName}'
                            : 'Reported by ${report.reporterName}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: isDark ? Colors.grey[600] : Colors.grey[400]),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Reason'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    report.reason,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _dismissReport(report),
                  icon: Icon(Icons.check, size: 18),
                  label: Text('Dismiss'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isDark ? Colors.grey[300] : Colors.grey[700],
                    side: BorderSide(
                        color: isDark ? Colors.grey[600]! : Colors.grey[400]!),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _suspendUserFromReport(report),
                  icon: Icon(Icons.person_off, size: 18),
                  label: Text('Suspend User'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _suspendListingFromReport(report),
                  icon: Icon(Icons.block, size: 18),
                  label: Text('Suspend Listing'.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _viewReportedListing(ReportedListing report) async {
    if (report.listingId.isEmpty) {
      showSnackBar(context, 'Listing reference is missing for this report.'.tr());
      return;
    }

    context
        .read<LoadingCubit>()
        .showLoading(context, 'Loading...'.tr(), false, Color(colorPrimary));
    try {
      final listing =
          await listingApiManager.getListing(listingID: report.listingId);
      context.read<LoadingCubit>().hideLoading();

      if (listing != null && mounted) {
        await push(
          context,
          ListingDetailsWrappingWidget(
              listing: listing, currentUser: currentUser),
        );
        if (mounted) {
          context.read<AdminBloc>().add(GetReportedListingsEvent());
        }
      } else {
        if (mounted) {
          showSnackBar(context, 'Listing not found or has been deleted.'.tr());
        }
      }
    } catch (e) {
      context.read<LoadingCubit>().hideLoading();
      if (mounted) {
        showSnackBar(context, 'Error loading listing: $e'.tr());
      }
    }
  }

  void _dismissReport(ReportedListing report) async {
    final reportsToDismiss = _reportsInSameGroup(report);
    final count = reportsToDismiss.length;
    final message =
        count > 1 ? 'Dismissing $count reports...'.tr() : 'Dismissing...'.tr();

    context
        .read<LoadingCubit>()
        .showLoading(context, message, false, Color(colorPrimary));

    for (final r in reportsToDismiss) {
      await listingApiManager.dismissReport(r.id);
    }

    context.read<LoadingCubit>().hideLoading();
    context.read<AdminBloc>().add(GetReportedListingsEvent());
  }

  Future<void> _suspendListingFromReport(ReportedListing report) async {
    final listing =
        await listingApiManager.getListing(listingID: report.listingId);
    if (listing == null) {
      showSnackBar(context, 'Listing not found or has been deleted.'.tr());
      return;
    }

    final result = await _showModernActionDialog(
      context,
      title: 'Suspend Listing?'.tr(),
      content:
          'Suspend "${listing.title}" for reported fraud and hide it from the public directory?'
              .tr(),
      isDestructive: true,
      actionLabel: 'Suspend Listing'.tr(),
    );

    if (result != true || !mounted) {
      return;
    }

    final suspensionInfo = SuspensionInfo(
      isSuspended: true,
      reason: SuspensionReason.fraudulent,
      reasonText: _buildSuspensionReasonDetails(report),
      suspendedAt: DateTime.now(),
      suspendedBy: currentUser.userID,
    );

    context.read<AdminBloc>().add(
          SuspendListingEvent(
            listing: listing,
            suspensionInfo: suspensionInfo,
          ),
        );

    final reportsToDismiss = _reportsInSameGroup(report);
    for (final r in reportsToDismiss) {
      await listingApiManager.resolveReport(r.id);
    }

    if (!mounted) return;
    context.read<AdminBloc>().add(GetReportedListingsEvent());
  }

  Future<void> _suspendUserFromReport(ReportedListing report) async {
    if (report.listingAuthorId.isEmpty) {
      showSnackBar(context, 'No reported user found for this report.'.tr());
      return;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection(usersCollection)
        .doc(report.listingAuthorId)
        .get();

    if (!userDoc.exists) {
      showSnackBar(context, 'Reported user not found.'.tr());
      return;
    }

    final user = ListingsUser.fromJson(userDoc.data()!);
    if (user.suspended) {
      showSnackBar(context, 'User is already suspended.'.tr());
      return;
    }

    final result = await _showModernActionDialog(
      context,
      title: 'Suspend User?'.tr(),
      content:
          'Suspend ${user.fullName()} for suspected fraud and prevent further activity?'.tr(),
      isDestructive: true,
      actionLabel: 'Suspend User'.tr(),
    );

    if (result != true || !mounted) {
      return;
    }

    final suspensionInfo = SuspensionInfo(
      isSuspended: true,
      reason: SuspensionReason.fraudulent,
      reasonText: _buildSuspensionReasonDetails(report),
      suspendedAt: DateTime.now(),
      suspendedBy: currentUser.userID,
    );

    context.read<AdminBloc>().add(
          SuspendUserEvent(
            user: user,
            suspensionInfo: suspensionInfo,
          ),
        );

    final reportsToDismiss = _reportsInSameGroup(report);
    for (final r in reportsToDismiss) {
      await listingApiManager.resolveReport(r.id);
    }

    if (!mounted) return;
    context.read<AdminBloc>().add(GetReportedListingsEvent());
  }

  List<ListingModel> _getFilteredListings() {
    final list = showOnlySuspendedListings ? suspendedListings : allListings;
    if (listingSearchQuery.isEmpty) return list;

    return list
        .where((l) =>
            l.title.toLowerCase().contains(listingSearchQuery.toLowerCase()) ||
            l.place.toLowerCase().contains(listingSearchQuery.toLowerCase()) ||
            l.authorName
                .toLowerCase()
                .contains(listingSearchQuery.toLowerCase()))
        .toList();
  }

  List<EventModel> _getFilteredEventsForAdmin() {
    if (showOnlySuspendedListings) return const [];
    if (listingSearchQuery.isEmpty) return allEvents;

    final query = listingSearchQuery.toLowerCase();
    return allEvents.where((event) {
      return event.title.toLowerCase().contains(query) ||
          event.venueName.toLowerCase().contains(query) ||
          event.committee.toLowerCase().contains(query) ||
          event.countryCode.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _loadUnverifiedListings() async {
    try {
      final snap = await context
          .read<AdminBloc>()
          .listingsRepository
          .getUnverifiedListings();
      setState(() {
        unverifiedListings = snap;
      });
    } catch (_) {}
  }

  Widget _buildVerificationTab() {
    final list = _getFilteredUnverifiedListings();
    final isDark = isDarkMode(context);

    return RefreshIndicator(
      onRefresh: () async {
        await _loadUnverifiedListings();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification Queue'.tr(),
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text(
                    '${unverifiedListings.length} listings pending review'.tr(),
                    style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (v) =>
                        setState(() => verificationSearchQuery = v),
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search queue...'.tr(),
                      hintStyle: TextStyle(
                          color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      prefixIcon: Icon(Icons.search,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('Phone'.tr(), vHasPhone,
                    (v) => setState(() => vHasPhone = v)),
                const SizedBox(width: 8),
                _buildFilterChip('Email'.tr(), vHasEmail,
                    (v) => setState(() => vHasEmail = v)),
                const SizedBox(width: 8),
                _buildFilterChip('Video'.tr(), vHasVideo,
                    (v) => setState(() => vHasVideo = v)),
                const SizedBox(width: 8),
                _buildFilterChip('4+ Star'.tr(), vHighRating,
                    (v) => setState(() => vHighRating = v)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text('All caught up! No pending verifications.'.tr(),
                        style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final listing = list[index];
                      return ModernVerificationCard(
                        listing: listing,
                        onVerify: () => _verifyListing(listing),
                        onReject: () => _rejectListing(listing),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label, bool selected, Function(bool) onSelected) {
    final isDark = isDarkMode(context);
    return FilterChip(
      label: Text(label),
      labelStyle: TextStyle(
        color: selected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      selected: selected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      selectedColor: Color(colorPrimary),
      backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
      checkmarkColor: Colors.white,
    );
  }

  List<ListingModel> _getFilteredUnverifiedListings() {
    List<ListingModel> list = List<ListingModel>.from(unverifiedListings);
    if (verificationSearchQuery.isNotEmpty) {
      final q = verificationSearchQuery.toLowerCase();
      list = list
          .where((l) =>
              l.title.toLowerCase().contains(q) ||
              l.authorName.toLowerCase().contains(q))
          .toList();
    }
    if (vHasPhone) list = list.where((l) => l.phone.isNotEmpty).toList();
    if (vHasEmail) list = list.where((l) => l.email.isNotEmpty).toList();
    if (vHasVideo) list = list.where((l) => l.videos.isNotEmpty).toList();
    if (vHighRating) {
      list = list
          .where((l) =>
              (l.reviewsSum / (l.reviewsCount > 0 ? l.reviewsCount : 1)) >= 4.0)
          .toList();
    }
    return list;
  }

  // --- Confirmation Dialogs ---

  void _showSuspendUserConfirmation(ListingsUser user) async {
    final suspensionInfo = await showDialog(
      context: context,
      builder: (_) => SuspensionReasonDialog(subjectName: user.fullName()),
    );

    if (suspensionInfo != null && mounted) {
      context.read<AdminBloc>().add(
            SuspendUserEvent(
              user: user,
              suspensionInfo: suspensionInfo,
            ),
          );
    }
  }

  void _showUnsuspendUserConfirmation(ListingsUser user) async {
    final result = await _showModernActionDialog(
      context,
      title: 'Unsuspend User?'.tr(),
      content: 'Restore access for ${user.fullName()}?'.tr(),
      isDestructive: false,
      actionLabel: 'Unsuspend'.tr(),
    );
    if (result == true) {
      if (!mounted) return;
      context.read<AdminBloc>().add(UnsuspendUserEvent(user: user));
    }
  }

  void _showSuspendListingConfirmation(ListingModel listing) async {
    debugPrint(
        '[Admin] Suspend listing tapped: ${listing.id} (${listing.title})');
    final suspensionInfo = await showDialog(
      context: context,
      builder: (_) => SuspensionReasonDialog(
        subjectName: listing.title,
        title: 'Suspend Listing',
        warningText:
            'This listing will be hidden from all users and the lister will be notified.',
      ),
    );

    debugPrint(
      '[Admin] Suspend listing dialog result: ${suspensionInfo == null ? 'cancelled' : 'confirmed'}',
    );
    if (suspensionInfo != null && mounted) {
      debugPrint('[Admin] Dispatching SuspendListingEvent for ${listing.id}');
      context.read<AdminBloc>().add(
            SuspendListingEvent(
              listing: listing,
              suspensionInfo: suspensionInfo,
            ),
          );
    }
  }

  void _showUnsuspendListingConfirmation(ListingModel listing) async {
    final result = await _showModernActionDialog(
      context,
      title: 'Unsuspend Listing?'.tr(),
      content: 'Restore "${listing.title}" to the public directory?'.tr(),
      isDestructive: false,
      actionLabel: 'Unsuspend'.tr(),
    );
    if (result == true) {
      if (!mounted) return;
      context.read<AdminBloc>().add(UnsuspendListingEvent(listing: listing));
    }
  }

  Future<bool?> _showModernActionDialog(BuildContext context,
      {required String title,
      required String content,
      required bool isDestructive,
      required String actionLabel}) {
    final isDark = isDarkMode(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87)),
        content: Text(content,
            style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'.tr(),
                  style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  // --- Existing Logic Handlers ---

  Future<void> _verifyListing(ListingModel listing) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Verify Listing'),
        content: TextField(
          decoration:
              const InputDecoration(hintText: 'Verification reason (optional)'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Verify'),
          ),
        ],
      ),
    );

    if (reason != null) {
      try {
        await context.read<AdminBloc>().listingsRepository.verifyListing(
              listing.id,
              currentUser.userID,
              reason.isNotEmpty ? reason : 'Admin verified',
            );
        setState(() {
          unverifiedListings.removeWhere((l) => l.id == listing.id);
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Listing verified')));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectListing(ListingModel listing) async {
    try {
      await context
          .read<AdminBloc>()
          .listingsRepository
          .rejectListing(listing.id);
      setState(() {
        unverifiedListings.removeWhere((l) => l.id == listing.id);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Listing rejected')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _featureListing(ListingModel listing) async {
    final duration = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Feature Listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Feature "${listing.title}" for how many days?'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 7),
                    child: const Text('7 days')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 14),
                    child: const Text('14 days')),
                TextButton(
                    onPressed: () => Navigator.pop(ctx, 30),
                    child: const Text('30 days')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (duration != null) {
      try {
        await context.read<AdminBloc>().listingsRepository.featureListing(
              listing.id,
              currentUser.userID,
              durationDays: duration,
            );
        setState(() {
          final idx = allListings.indexWhere((l) => l.id == listing.id);
          if (idx >= 0) {
            allListings[idx].isFeatured = true;
            final now = Timestamp.now().seconds;
            allListings[idx].featuredUntil = now + (duration * 24 * 60 * 60);
            allListings[idx].featuredBy = currentUser.userID;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Featured for $duration days')));
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unfeatureListing(ListingModel listing) async {
    try {
      await context
          .read<AdminBloc>()
          .listingsRepository
          .unfeatureListing(listing.id);
      setState(() {
        final idx = allListings.indexWhere((l) => l.id == listing.id);
        if (idx >= 0) {
          allListings[idx].isFeatured = false;
          allListings[idx].featuredUntil = null;
          allListings[idx].featuredBy = null;
        }
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Unfeatured')));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _toggleUserFreshnessExempt(
    ListingsUser user,
    bool value,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(user.userID)
          .set({'listingFreshnessExempt': value}, SetOptions(merge: true));
      setState(() {
        for (final entry in allUsers) {
          if (entry.userID == user.userID) {
            entry.listingFreshnessExempt = value;
          }
        }
        for (final entry in suspendedUsers) {
          if (entry.userID == user.userID) {
            entry.listingFreshnessExempt = value;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'User is exempt from listing expiry'.tr()
                : 'User exemption removed'.tr(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleListingFreshnessExempt(
    ListingModel listing,
    bool value,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(listingsCollection)
          .doc(listing.id)
          .set({
        'freshness': {
          'exempt': value,
        }
      }, SetOptions(merge: true));
      setState(() {
        final idx = allListings.indexWhere((l) => l.id == listing.id);
        if (idx >= 0) {
          allListings[idx].freshness =
              allListings[idx].freshness.copyWithExempt(value);
        }
        final suspendedIdx =
            suspendedListings.indexWhere((l) => l.id == listing.id);
        if (suspendedIdx >= 0) {
          suspendedListings[suspendedIdx].freshness =
              suspendedListings[suspendedIdx].freshness.copyWithExempt(value);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? 'Listing is exempt from expiry'.tr()
                : 'Listing exemption removed'.tr(),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _toggleListingDemo(ListingModel listing, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection(listingsCollection)
          .doc(listing.id)
          .update({'isDemo': value});
      setState(() {
        final idx = allListings.indexWhere((l) => l.id == listing.id);
        if (idx >= 0) allListings[idx].isDemo = value;
        final suspendedIdx = suspendedListings.indexWhere((l) => l.id == listing.id);
        if (suspendedIdx >= 0) suspendedListings[suspendedIdx].isDemo = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Listing marked as demo. Non-admin users can view configuration but cannot save changes.'.tr()
                  : 'Listing removed from demo.'.tr(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleListingMainVisibility(
    ListingModel listing,
    bool visibleOnMainFeed,
  ) async {
    try {
      final hidden = !visibleOnMainFeed;
      await FirebaseFirestore.instance
          .collection(listingsCollection)
          .doc(listing.id)
          .update({'hidden': hidden});

      setState(() {
        final idx = allListings.indexWhere((l) => l.id == listing.id);
        if (idx >= 0) allListings[idx].hidden = hidden;
        final suspendedIdx = suspendedListings.indexWhere((l) => l.id == listing.id);
        if (suspendedIdx >= 0) suspendedListings[suspendedIdx].hidden = hidden;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              visibleOnMainFeed
                  ? 'Listing is now visible on the main feed.'.tr()
                  : 'Listing removed from main feed visibility (still available in Demo Listings if marked as demo).'.tr(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _viewListing(String listingId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .get();

      if (!doc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing not found')),
          );
        }
        return;
      }

      final listing = ListingModel.fromJson(doc.data()!);
      listing.id = listingId;

      if (mounted) {
        await push(
          context,
          ListingDetailsWrappingWidget(
            listing: listing,
            currentUser: currentUser,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _viewEvent(EventModel event) async {
    await push(
      context,
      EventDetailsScreen(event: event),
    );
    await _loadAllEvents();
  }

  Future<void> _toggleEventDemo(EventModel event, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set({'isDemo': value}, SetOptions(merge: true));
      setState(() {
        final idx = allEvents.indexWhere((entry) => entry.id == event.id);
        if (idx >= 0) allEvents[idx].isDemo = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Event marked as demo. Non-admin users can inspect configuration but cannot save changes.'.tr()
                  : 'Event removed from demo mode.'.tr(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _toggleEventMainVisibility(
    EventModel event,
    bool visibleOnMainFeed,
  ) async {
    try {
      final status = visibleOnMainFeed ? 'active' : 'hidden';
      await FirebaseFirestore.instance
          .collection('events')
          .doc(event.id)
          .set({'status': status}, SetOptions(merge: true));
      setState(() {
        final idx = allEvents.indexWhere((entry) => entry.id == event.id);
        if (idx >= 0) allEvents[idx].status = status;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              visibleOnMainFeed
                  ? 'Event is now visible on the main feed.'.tr()
                  : 'Event removed from main feed visibility.'.tr(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteManagedEvent(EventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete Event?'.tr()),
        content: Text('Are you sure you want to remove this event?'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('No'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Yes'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('events').doc(event.id).delete();
      setState(() {
        allEvents.removeWhere((entry) => entry.id == event.id);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Event deleted.'.tr())),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _approveRequest(FeaturedRequest request) async {
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Featured Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Are you sure you want to approve this request?'),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Admin Note (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (mounted) {
        context
            .read<LoadingCubit>()
            .showLoading(context, 'Approving...', false, Color(colorPrimary));
      }

      final service = FeaturedService();
      await service.adminApproveFeaturedRequest(
        request.id,
        adminNote: noteController.text.isNotEmpty ? noteController.text : null,
      );

      if (mounted) {
        context.read<LoadingCubit>().hideLoading();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Featured request approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        context.read<LoadingCubit>().hideLoading();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildFeaturedTab() {
    final isDark = isDarkMode(context);
    final service = FeaturedService();

    return StreamBuilder<List<FeaturedRequest>>(
      stream: service.streamPendingRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No pending featured requests',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
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
            return Card(
              color: isDark ? Colors.grey[850] : Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Featured Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            request.tierAtRequest?.toUpperCase() ?? 'UNKNOWN',
                            style: const TextStyle(fontSize: 11),
                          ),
                          backgroundColor: request.tierAtRequest == 'premium'
                              ? Colors.purple[100]
                              : Colors.blue[100],
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildFeaturedInfoRow('Listing ID',
                        request.listingId.substring(0, 12) + '...', isDark),
                    _buildFeaturedInfoRow('Owner UID',
                        request.ownerUid.substring(0, 12) + '...', isDark),
                    _buildFeaturedInfoRow(
                        'Country', request.country ?? 'N/A', isDark),
                    _buildFeaturedInfoRow(
                        'Category', request.category ?? 'N/A', isDark),
                    _buildFeaturedInfoRow(
                        'Requested',
                        DateFormat.yMMMd().add_jm().format(request.createdAt),
                        isDark),
                    const SizedBox(height: 8),
                    Text(
                      'Eligibility:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (request.eligibilityPassed)
                      Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: Colors.green, size: 16),
                          const SizedBox(width: 4),
                          Text('Passed all checks',
                              style: TextStyle(color: Colors.green)),
                        ],
                      )
                    else
                      ...request.eligibilityReasons.map((reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(Icons.cancel, color: Colors.red, size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                    child: Text(reason,
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          )),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            await _viewListing(request.listingId);
                          },
                          icon: const Icon(Icons.visibility),
                          label: const Text('View Listing'),
                        ),
                        const SizedBox(width: 8),
                        if (request.eligibilityPassed)
                          ElevatedButton.icon(
                            onPressed: () async {
                              await _approveRequest(request);
                            },
                            icon: const Icon(Icons.check),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.block),
                            label: const Text('Not Eligible'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFeaturedInfoRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Modern Card Widgets ---

class ModernUserCard extends StatelessWidget {
  final ListingsUser user;
  final VoidCallback onSuspend;
  final VoidCallback onUnsuspend;
  final ValueChanged<bool> onToggleFreshnessExempt;

  const ModernUserCard({
    super.key,
    required this.user,
    required this.onSuspend,
    required this.onUnsuspend,
    required this.onToggleFreshnessExempt,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final isSuspended = user.suspended;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user.profilePictureURL.isNotEmpty
                ? NetworkImage(user.profilePictureURL)
                : null,
            child: user.profilePictureURL.isEmpty
                ? const Icon(Icons.person)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87)),
                Text(user.email,
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (user.isAdmin)
                      _buildBadge('ADMIN', Colors.green, isDark),
                    if (isSuspended)
                      _buildBadge('SUSPENDED', Colors.red, isDark),
                    if (!user.isAdmin && !isSuspended)
                      _buildBadge(user.subscriptionTier.toUpperCase(),
                          Color(colorPrimary), isDark),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.timer_off, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Listing expiry exempt'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ),
                    Switch(
                      value: user.listingFreshnessExempt,
                      activeColor: Colors.orange,
                      onChanged: onToggleFreshnessExempt,
                    ),
                  ],
                ),
                // Show suspension details if suspended
                if (isSuspended && user.suspensionInfo != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (user.suspensionInfo!.reason != null)
                          Text(
                            'Reason: ${user.suspensionInfo!.reason!.displayName}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.red),
                          ),
                        if (user.suspensionInfo!.reasonText != null &&
                            user.suspensionInfo!.reasonText!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          FutureBuilder<String?>(
                            future: SuspensionReasonDetailsResolver.resolve(
                              reasonText: user.suspensionInfo!.reasonText!,
                            ),
                            builder: (context, snapshot) => Text(
                              snapshot.data ?? user.suspensionInfo!.reasonText!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red.shade700),
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: Icon(isSuspended ? Icons.check_circle_outline : Icons.block,
                color: isSuspended ? Colors.green : Colors.red),
            onPressed: isSuspended ? onUnsuspend : onSuspend,
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class ModernListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onSuspend;
  final VoidCallback onUnsuspend;
  final VoidCallback onFeature;
  final VoidCallback onUnfeature;
  final ValueChanged<bool> onToggleFreshnessExempt;
  final ValueChanged<bool> onToggleDemo;
  final ValueChanged<bool> onToggleMainVisibility;

  const ModernListingCard({
    super.key,
    required this.listing,
    required this.onSuspend,
    required this.onUnsuspend,
    required this.onFeature,
    required this.onUnfeature,
    required this.onToggleFreshnessExempt,
    required this.onToggleDemo,
    required this.onToggleMainVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final isSuspended = listing.suspended;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.network(listing.photo,
                    height: 120, width: double.infinity, fit: BoxFit.cover),
                if (isSuspended)
                  Positioned.fill(
                      child: Container(
                          color: Colors.black.withOpacity(0.6),
                          child: const Center(
                              child: Text('SUSPENDED',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold))))),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(
                        listing.isFeatured ? Icons.star : Icons.star_border,
                        color: Colors.amber),
                    onPressed: listing.isFeatured ? onUnfeature : onFeature,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(listing.title,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('by ${listing.authorName} • ${listing.place}',
                          style: TextStyle(
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                      isSuspended ? Icons.check_circle_outline : Icons.block,
                      color: isSuspended ? Colors.green : Colors.red),
                  onPressed: isSuspended ? onUnsuspend : onSuspend,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Icon(Icons.timer_off, size: 14, color: Colors.orange),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Listing expiry exempt'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Switch(
                  value: listing.freshness.exempt,
                  activeColor: Colors.orange,
                  onChanged: onToggleFreshnessExempt,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 14, color: Colors.blue.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Demo listing'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Switch(
                  value: listing.isDemo,
                  activeColor: Colors.blue,
                  onChanged: onToggleDemo,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined, size: 14, color: Colors.green.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Visible on main feed'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Switch(
                  value: !listing.hidden,
                  activeColor: Colors.green,
                  onChanged: onToggleMainVisibility,
                ),
              ],
            ),
          ),
          if (isSuspended && listing.suspensionInfo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (listing.suspensionInfo!.reason != null)
                          Text(
                            'Reason: ${listing.suspensionInfo!.reason!.displayName}',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.red),
                          ),
                        if (listing.suspensionInfo!.reasonText != null &&
                            listing.suspensionInfo!.reasonText!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          FutureBuilder<String?>(
                            future: SuspensionReasonDetailsResolver.resolve(
                              reasonText: listing.suspensionInfo!.reasonText!,
                              listingId: listing.id,
                            ),
                            builder: (context, snapshot) => Text(
                              snapshot.data ?? listing.suspensionInfo!.reasonText!,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.red.shade700),
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (listing.suspensionInfo!.unsuspensionRequested) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.feedback,
                                  size: 16, color: Colors.orange),
                              const SizedBox(width: 6),
                              Text(
                                'Unsuspension Request Pending'.tr(),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange),
                              ),
                            ],
                          ),
                          if (listing.suspensionInfo!.unsuspensionRequestText !=
                                  null &&
                              listing.suspensionInfo!.unsuspensionRequestText!
                                  .isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Response:'.tr(),
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.orange),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              listing.suspensionInfo!.unsuspensionRequestText!,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.grey[300]
                                      : Colors.grey[800]),
                            ),
                          ],
                          if (listing.suspensionInfo!.unsuspensionRequestedAt !=
                              null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Requested: ${DateFormat('MMM d, y h:mm a').format(listing.suspensionInfo!.unsuspensionRequestedAt!)}',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AdminListSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _AdminListSectionHeader({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModernEventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleDemo;
  final ValueChanged<bool> onToggleMainVisibility;

  const ModernEventCard({
    super.key,
    required this.event,
    required this.onOpen,
    required this.onDelete,
    required this.onToggleDemo,
    required this.onToggleMainVisibility,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final isVisible = event.status.toLowerCase() == 'active';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: event.posterImageUrl.trim().isNotEmpty
                      ? Image.network(event.posterImageUrl, fit: BoxFit.cover)
                      : Container(
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
                          child: const Icon(Icons.event, size: 40),
                        ),
                ),
                if (!isVisible)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.6),
                      child: const Center(
                        child: Text(
                          'HIDDEN',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'EVENT',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'by ${event.committee.isNotEmpty ? event.committee : event.createdBy} • ${event.venueName}',
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: onOpen,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: onDelete,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined,
                    size: 14, color: Colors.blue.shade400),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Demo listing'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Switch(
                  value: event.isDemo,
                  activeThumbColor: Colors.blue,
                  onChanged: onToggleDemo,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Icon(Icons.visibility_outlined,
                    size: 14, color: Colors.green.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Visible on main feed'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ),
                Switch(
                  value: isVisible,
                  activeThumbColor: Colors.green,
                  onChanged: onToggleMainVisibility,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ModernVerificationCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onVerify;
  final VoidCallback onReject;

  const ModernVerificationCard(
      {super.key,
      required this.listing,
      required this.onVerify,
      required this.onReject});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final avgRating = (listing.reviewsCount > 0)
        ? (listing.reviewsSum / listing.reviewsCount)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(listing.photo,
                      height: 60, width: 60, fit: BoxFit.cover)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text('by ${listing.authorName}',
                        style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 13)),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(avgRating.toStringAsFixed(1),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(width: 8),
                        Text('(${listing.reviewsCount.toInt()} reviews)',
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Verify'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
