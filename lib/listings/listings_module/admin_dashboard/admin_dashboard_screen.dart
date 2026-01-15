import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/listings_module/admin_dashboard/admin_bloc.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';

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
  late ListingsUser currentUser;
  bool isLoading = true;
  String userSearchQuery = '';
  String listingSearchQuery = '';
  bool showOnlySuspendedUsers = false;
  bool showOnlySuspendedListings = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    currentUser = widget.currentUser;
    _loadAllData();
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
    if (showOnlySuspendedUsers) {
      return suspendedUsers
          .where((user) =>
              user.firstName.toLowerCase().contains(userSearchQuery.toLowerCase()) ||
              user.lastName.toLowerCase().contains(userSearchQuery.toLowerCase()) ||
              user.email.toLowerCase().contains(userSearchQuery.toLowerCase()))
          .toList();
    }
    return allUsers;
  }

  List<ListingModel> get filteredListings {
    if (showOnlySuspendedListings) {
      return suspendedListings;
    }
    return allListings;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin Dashboard'.tr()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: isDarkMode(context) ? Colors.white70 : Colors.black54,
          tabs: [
            Tab(text: 'All Users'.tr()),
            Tab(text: 'All Listings'.tr()),
          ],
        ),
      ),
      body: BlocConsumer<AdminBloc, AdminState>(
        listener: (context, state) {
          if (state is AllUsersState) {
            isLoading = false;
            allUsers = state.users;
            setState(() {});
            Future.delayed(Duration.zero, () {
              context.read<LoadingCubit>().hideLoading();
            });
          } else if (state is SuspendedUsersState) {
            isLoading = false;
            suspendedUsers = state.suspendedUsers;
            setState(() {});
            Future.delayed(Duration.zero, () {
              context.read<LoadingCubit>().hideLoading();
            });
          } else if (state is AllListingsState) {
            isLoading = false;
            allListings = state.listings;
            setState(() {});
            Future.delayed(Duration.zero, () {
              context.read<LoadingCubit>().hideLoading();
            });
          } else if (state is SuspendedListingsState) {
            isLoading = false;
            suspendedListings = state.suspendedListings;
            setState(() {});
            Future.delayed(Duration.zero, () {
              context.read<LoadingCubit>().hideLoading();
            });
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
            ],
          );
        },
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      style: TextStyle(
                        color: isDarkMode(context) ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search users...'.tr(),
                        hintStyle: TextStyle(
                          color: isDarkMode(context) ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode(context) ? Colors.white : Colors.grey.shade600,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: _searchUsers,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(
                    'Suspended'.tr(),
                    style: TextStyle(
                      color: isDarkMode(context) ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: showOnlySuspendedUsers,
                  onSelected: (value) {
                    setState(() {
                      showOnlySuspendedUsers = value;
                    });
                  },
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red.shade900,
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : filteredUsers.isEmpty
                    ? Stack(
                        children: [
                          ListView(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: showEmptyState(
                                showOnlySuspendedUsers 
                                    ? 'No Suspended Users'.tr()
                                    : 'No Users Found'.tr(),
                                showOnlySuspendedUsers
                                    ? 'Suspended users will show up here.'.tr()
                                    : 'Search for users to manage.'.tr()),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: filteredUsers.length,
                        itemBuilder: (context, index) => showOnlySuspendedUsers
                            ? SuspendedUserCard(
                                user: filteredUsers[index],
                                onUnsuspend: (user) {
                                  context
                                      .read<AdminBloc>()
                                      .add(UnsuspendUserEvent(user: user));
                                },
                              )
                            : AllUserCard(
                                user: filteredUsers[index],
                                onSuspend: (user) {
                                  context
                                      .read<AdminBloc>()
                                      .add(SuspendUserEvent(user: user));
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllListingsTab() {
    return RefreshIndicator(
      onRefresh: () async {
        _loadAllData();
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      style: TextStyle(
                        color: isDarkMode(context) ? Colors.white : Colors.black,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search listings...'.tr(),
                        hintStyle: TextStyle(
                          color: isDarkMode(context) ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: isDarkMode(context) ? Colors.white : Colors.grey.shade600,
                          size: 20,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          listingSearchQuery = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: Text(
                    'Suspended'.tr(),
                    style: TextStyle(
                      color: isDarkMode(context) ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: showOnlySuspendedListings,
                  onSelected: (value) {
                    setState(() {
                      showOnlySuspendedListings = value;
                    });
                  },
                  selectedColor: Colors.red.shade100,
                  checkmarkColor: Colors.red.shade900,
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _getFilteredListings().isEmpty
                    ? Stack(
                        children: [
                          ListView(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: showEmptyState(
                                showOnlySuspendedListings
                                    ? 'No Suspended Listings'.tr()
                                    : 'No Listings Found'.tr(),
                                showOnlySuspendedListings
                                    ? 'Suspended listings will show up here.'.tr()
                                    : 'All listings will show up here.'.tr()),
                          ),
                        ],
                      )
                    : ListView.builder(
                        itemCount: _getFilteredListings().length,
                        itemBuilder: (context, index) {
                          final listing = _getFilteredListings()[index];
                          return showOnlySuspendedListings
                              ? SuspendedListingCard(
                                  listing: listing,
                                  onUnsuspend: (listing) {
                                    context
                                        .read<AdminBloc>()
                                        .add(UnsuspendListingEvent(listing: listing));
                                  },
                                )
                              : AllListingCard(
                                  listing: listing,
                                  onSuspend: (listing) {
                                    context
                                        .read<AdminBloc>()
                                        .add(SuspendListingEvent(listing: listing));
                                  },
                                );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  List<ListingModel> _getFilteredListings() {
    final listings = showOnlySuspendedListings ? suspendedListings : allListings;
    if (listingSearchQuery.isEmpty) return listings;
    
    return listings
        .where((listing) =>
            listing.title.toLowerCase().contains(listingSearchQuery.toLowerCase()) ||
            listing.place.toLowerCase().contains(listingSearchQuery.toLowerCase()) ||
            listing.authorName.toLowerCase().contains(listingSearchQuery.toLowerCase()))
        .toList();
  }
}

class AllUserCard extends StatelessWidget {
  final ListingsUser user;
  final Function(ListingsUser) onSuspend;

  const AllUserCard({
    super.key,
    required this.user,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundImage: user.profilePictureURL.isNotEmpty
              ? NetworkImage(user.profilePictureURL)
              : null,
          child: user.profilePictureURL.isEmpty
              ? const Icon(Icons.person, size: 16)
              : null,
        ),
        title: Text(
          '${user.firstName} ${user.lastName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                user.email,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (user.isAdmin)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'ADMIN'.tr(),
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        trailing: IconButton(
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.block),
          onPressed: () => _showSuspendConfirmation(context, user),
        ),
      ),
    );
  }

  void _showSuspendConfirmation(BuildContext context, ListingsUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode(context) ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Suspend Account?'.tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to suspend ${user.firstName} ${user.lastName}?'
              .tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSuspend(user);
            },
            child: Text(
              'Suspend'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class SuspendedUserCard extends StatelessWidget {
  final ListingsUser user;
  final Function(ListingsUser) onUnsuspend;

  const SuspendedUserCard({
    super.key,
    required this.user,
    required this.onUnsuspend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: CircleAvatar(
          radius: 16,
          backgroundImage: user.profilePictureURL.isNotEmpty
              ? NetworkImage(user.profilePictureURL)
              : null,
          child: user.profilePictureURL.isEmpty
              ? const Icon(Icons.person, size: 16)
              : null,
        ),
        title: Text(
          '${user.firstName} ${user.lastName}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                user.email,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              margin: const EdgeInsets.only(left: 4),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'Suspended'.tr(),
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: IconButton(
          iconSize: 20,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: const Icon(Icons.check_circle),
          color: Colors.green,
          onPressed: () => _showUnsuspendConfirmation(context, user),
        ),
      ),
    );
  }

  void _showUnsuspendConfirmation(BuildContext context, ListingsUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode(context) ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Unsuspend Account?'.tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to unsuspend ${user.firstName} ${user.lastName}?'
              .tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onUnsuspend(user);
            },
            child: Text(
              'Unsuspend'.tr(),
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class SuspendedListingCard extends StatelessWidget {
  final ListingModel listing;
  final Function(ListingModel) onUnsuspend;

  const SuspendedListingCard({
    super.key,
    required this.listing,
    required this.onUnsuspend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                child: Image.network(
                  listing.photo,
                  height: 50,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 50,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 16),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Suspended'.tr(),
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  listing.place,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'By: ${listing.authorName}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showUnsuspendConfirmation(context),
                        icon: const Icon(Icons.check_circle, size: 14),
                        label: Text('Unsuspend'.tr(), style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showUnsuspendConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode(context) ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Unsuspend Listing?'.tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to unsuspend "${listing.title}"?'.tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onUnsuspend(listing);
            },
            child: Text(
              'Unsuspend'.tr(),
              style: const TextStyle(color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }
}

class AllListingCard extends StatelessWidget {
  final ListingModel listing;
  final Function(ListingModel) onSuspend;

  const AllListingCard({
    super.key,
    required this.listing,
    required this.onSuspend,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
                child: Image.network(
                  listing.photo,
                  height: 50,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 50,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image_not_supported, size: 16),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  listing.place,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 2),
                Text(
                  'By: ${listing.authorName}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 9),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showSuspendConfirmation(context),
                        icon: const Icon(Icons.block, size: 14),
                        label: Text('Suspend'.tr(), style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: const Size(0, 28),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showSuspendConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode(context) ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Suspend Listing?'.tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to suspend "${listing.title}"?'.tr(),
          style: TextStyle(color: isDarkMode(context) ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onSuspend(listing);
            },
            child: Text(
              'Suspend'.tr(),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
