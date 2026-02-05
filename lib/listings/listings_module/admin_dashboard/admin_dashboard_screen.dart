import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/suspension_info.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/listings_module/admin_dashboard/admin_bloc.dart';
import 'package:instaflutter/listings/listings_module/admin_dashboard/suspension_reason_dialog.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/constants.dart';

class AdminDashboardWrappingWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const AdminDashboardWrappingWidget({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AdminBloc(
        currentUser: currentUser,
        listingsRepository: listingApiManager,
        profileRepository: profileApiManager,
      ),
      child: AdminDashboardScreen(currentUser: currentUser),
    );
  }
}

class AdminDashboardScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const AdminDashboardScreen({super.key, required this.currentUser});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  List<ListingsUser> suspendedUsers = [];
  List<ListingsUser> allUsers = [];
  List<ListingModel> suspendedListings = [];
  List<ListingModel> allListings = [];
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    currentUser = widget.currentUser;
    _loadAllData();

    _tabController.addListener(() {
      if (_tabController.index == 2 && unverifiedListings.isEmpty) {
        _loadUnverifiedListings();
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
  }

  void _searchUsers(String query) {
    userSearchQuery = query;
    context.read<AdminBloc>().add(GetAllUsersEvent(searchQuery: query));
  }

  List<ListingsUser> get filteredUsers {
    List<ListingsUser> list = showOnlySuspendedUsers ? suspendedUsers : allUsers;
    if (userSearchQuery.isEmpty) return list;
    
    return list.where((user) =>
        user.firstName.toLowerCase().contains(userSearchQuery.toLowerCase()) ||
        user.lastName.toLowerCase().contains(userSearchQuery.toLowerCase()) ||
        user.email.toLowerCase().contains(userSearchQuery.toLowerCase())
    ).toList();
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
        title: Text('Admin Console'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Platform.isIOS ? Color(colorPrimary) : Colors.white,
          indicatorWeight: 3,
          labelColor: Platform.isIOS ? Color(colorPrimary) : Colors.white,
          unselectedLabelColor: Platform.isIOS
              ? (isDark ? Colors.white70 : Colors.black54)
              : Colors.white70,
          tabs: [
            Tab(text: 'Users'.tr()),
            Tab(text: 'Listings'.tr()),
            Tab(text: 'Verification'.tr()),
          ],
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
              _buildVerificationTab(),
            ],
          );
        },
      ),
    );
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
          Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
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
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search...'.tr(),
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
                  fontWeight: filterActive ? FontWeight.bold : FontWeight.normal,
                ),
                selected: filterActive,
                onSelected: onFilterChanged,
                selectedColor: Colors.red,
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : filteredUsers.isEmpty
                    ? showEmptyState('No Users Found'.tr(), 'Try a different search query.'.tr())
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return ModernUserCard(
                            user: user,
                            onSuspend: () => _showSuspendUserConfirmation(user),
                            onUnsuspend: () => _showUnsuspendUserConfirmation(user),
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
    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
      },
      child: Column(
        children: [
          _buildTabHeader(
            title: 'Listing Management'.tr(),
            subtitle: '${allListings.length} total listings available'.tr(),
            controller: TextEditingController(),
            onChanged: (v) => setState(() => listingSearchQuery = v),
            filterActive: showOnlySuspendedListings,
            onFilterChanged: (v) => setState(() => showOnlySuspendedListings = v),
            filterLabel: 'Suspended'.tr(),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : listings.isEmpty
                    ? showEmptyState('No Listings Found'.tr(), 'Try a different search query.'.tr())
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: listings.length,
                        itemBuilder: (context, index) {
                          final listing = listings[index];
                          return ModernListingCard(
                            listing: listing,
                            onSuspend: () => _showSuspendListingConfirmation(listing),
                            onUnsuspend: () => _showUnsuspendListingConfirmation(listing),
                            onFeature: () => _featureListing(listing),
                            onUnfeature: () => _unfeatureListing(listing),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  List<ListingModel> _getFilteredListings() {
    final list = showOnlySuspendedListings ? suspendedListings : allListings;
    if (listingSearchQuery.isEmpty) return list;
    
    return list.where((l) =>
        l.title.toLowerCase().contains(listingSearchQuery.toLowerCase()) ||
        l.place.toLowerCase().contains(listingSearchQuery.toLowerCase()) ||
        l.authorName.toLowerCase().contains(listingSearchQuery.toLowerCase())
    ).toList();
  }

  Future<void> _loadUnverifiedListings() async {
    try {
      final snap = await context.read<AdminBloc>().listingsRepository.getUnverifiedListings();
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
                Text('Verification Queue'.tr(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 4),
                Text('${unverifiedListings.length} listings pending review'.tr(), style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => verificationSearchQuery = v),
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Search queue...'.tr(),
                      hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                      prefixIcon: Icon(Icons.search, size: 20, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
                _buildFilterChip('Phone'.tr(), vHasPhone, (v) => setState(() => vHasPhone = v)),
                const SizedBox(width: 8),
                _buildFilterChip('Email'.tr(), vHasEmail, (v) => setState(() => vHasEmail = v)),
                const SizedBox(width: 8),
                _buildFilterChip('Video'.tr(), vHasVideo, (v) => setState(() => vHasVideo = v)),
                const SizedBox(width: 8),
                _buildFilterChip('4+ Star'.tr(), vHighRating, (v) => setState(() => vHighRating = v)),
              ],
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text('All caught up! No pending verifications.'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)))
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

  Widget _buildFilterChip(String label, bool selected, Function(bool) onSelected) {
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
      list = list.where((l) => l.title.toLowerCase().contains(q) || l.authorName.toLowerCase().contains(q)).toList();
    }
    if (vHasPhone) list = list.where((l) => l.phone.isNotEmpty).toList();
    if (vHasEmail) list = list.where((l) => l.email.isNotEmpty).toList();
    if (vHasVideo) list = list.where((l) => l.videos.isNotEmpty).toList();
    if (vHighRating) {
      list = list.where((l) => (l.reviewsSum / (l.reviewsCount > 0 ? l.reviewsCount : 1)) >= 4.0).toList();
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
    debugPrint('[Admin] Suspend listing tapped: ${listing.id} (${listing.title})');
    final suspensionInfo = await showDialog(
      context: context,
      builder: (_) => SuspensionReasonDialog(
        subjectName: listing.title,
        title: 'Suspend Listing',
        warningText: 'This listing will be hidden from all users and the lister will be notified.',
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

  Future<bool?> _showModernActionDialog(BuildContext context, {required String title, required String content, required bool isDestructive, required String actionLabel}) {
    final isDark = isDarkMode(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text(content, style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel'.tr(), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? Colors.red : Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          decoration: const InputDecoration(hintText: 'Verification reason (optional)'),
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing verified')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _rejectListing(ListingModel listing) async {
    try {
      await context.read<AdminBloc>().listingsRepository.rejectListing(listing.id);
      setState(() {
        unverifiedListings.removeWhere((l) => l.id == listing.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing rejected')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                TextButton(onPressed: () => Navigator.pop(ctx, 7), child: const Text('7 days')),
                TextButton(onPressed: () => Navigator.pop(ctx, 14), child: const Text('14 days')),
                TextButton(onPressed: () => Navigator.pop(ctx, 30), child: const Text('30 days')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Featured for $duration days')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _unfeatureListing(ListingModel listing) async {
    try {
      await context.read<AdminBloc>().listingsRepository.unfeatureListing(listing.id);
      setState(() {
        final idx = allListings.indexWhere((l) => l.id == listing.id);
        if (idx >= 0) {
          allListings[idx].isFeatured = false;
          allListings[idx].featuredUntil = null;
          allListings[idx].featuredBy = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unfeatured')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

// --- Modern Card Widgets ---

class ModernUserCard extends StatelessWidget {
  final ListingsUser user;
  final VoidCallback onSuspend;
  final VoidCallback onUnsuspend;

  const ModernUserCard({super.key, required this.user, required this.onSuspend, required this.onUnsuspend});

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
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: user.profilePictureURL.isNotEmpty ? NetworkImage(user.profilePictureURL) : null,
            child: user.profilePictureURL.isEmpty ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
                Text(user.email, style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (user.isAdmin)
                      _buildBadge('ADMIN', Colors.green, isDark),
                    if (isSuspended)
                      _buildBadge('SUSPENDED', Colors.red, isDark),
                    if (!user.isAdmin && !isSuspended)
                      _buildBadge(user.subscriptionTier.toUpperCase(), Color(colorPrimary), isDark),
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
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red),
                          ),
                        if (user.suspensionInfo!.reasonText != null && user.suspensionInfo!.reasonText!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.suspensionInfo!.reasonText!,
                            style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
            icon: Icon(isSuspended ? Icons.check_circle_outline : Icons.block, color: isSuspended ? Colors.green : Colors.red),
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class ModernListingCard extends StatelessWidget {
  final ListingModel listing;
  final VoidCallback onSuspend;
  final VoidCallback onUnsuspend;
  final VoidCallback onFeature;
  final VoidCallback onUnfeature;

  const ModernListingCard({super.key, required this.listing, required this.onSuspend, required this.onUnsuspend, required this.onFeature, required this.onUnfeature});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final isSuspended = listing.suspended;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Stack(
              children: [
                Image.network(listing.photo, height: 120, width: double.infinity, fit: BoxFit.cover),
                if (isSuspended)
                  Positioned.fill(child: Container(color: Colors.black.withOpacity(0.6), child: const Center(child: Text('SUSPENDED', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: Icon(listing.isFeatured ? Icons.star : Icons.star_border, color: Colors.amber),
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
                      Text(listing.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('by ${listing.authorName} • ${listing.place}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isSuspended ? Icons.check_circle_outline : Icons.block, color: isSuspended ? Colors.green : Colors.red),
                  onPressed: isSuspended ? onUnsuspend : onSuspend,
                ),
              ],
            ),
          ),
          if (isSuspended && listing.suspensionInfo != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Container(
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
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red),
                      ),
                    if (listing.suspensionInfo!.reasonText != null && listing.suspensionInfo!.reasonText!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        listing.suspensionInfo!.reasonText!,
                        style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
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

  const ModernVerificationCard({super.key, required this.listing, required this.onVerify, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final avgRating = (listing.reviewsCount > 0) ? (listing.reviewsSum / listing.reviewsCount) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(listing.photo, height: 60, width: 60, fit: BoxFit.cover)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(listing.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('by ${listing.authorName}', style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 13)),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(avgRating.toStringAsFixed(1), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(width: 8),
                        Text('(${listing.reviewsCount.toInt()} reviews)', style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
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
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onVerify,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Verify'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
