import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/reauth_user/reauth_user_screen.dart';
import 'package:caribtap/listings/ui/auth/welcome/welcome_screen.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/admin_dashboard_screen.dart';
import 'package:caribtap/listings/ui/profile/profile/ad_approval_screen.dart';
import 'package:caribtap/listings/listings_module/admin_dashboard/edit_user_subscription_screen.dart';
import 'package:caribtap/listings/listings_module/favorite_listings/favorite_listings_screen.dart';
import 'package:caribtap/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:caribtap/listings/listings_module/home/home_screen.dart';
import 'package:caribtap/listings/listings_module/booking/my_bookings_screen.dart';
import 'package:caribtap/listings/listings_module/booking/booking_management_screen.dart';
import 'package:caribtap/listings/ui/container/container_screen.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/listings/ui/profile/account_details/account_details_screen.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:caribtap/listings/ui/profile/contact_us/contact_us_screen.dart';
import 'package:caribtap/listings/ui/profile/settings/settings_screen.dart';
import 'package:caribtap/listings/ui/profile/profile/profile_bloc.dart';
import 'package:caribtap/core/ui/theme/theme_cubit.dart';
import 'package:caribtap/listings/screens/listing_freshness_dashboard.dart';
import 'package:caribtap/listings/utils/populate_test_data.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/model/collaboration_model.dart';
import 'package:caribtap/listings/ui/collaboration/assigned_listings_screen.dart';
import 'package:caribtap/listings/ui/collaboration/activity_log_screen.dart';
import 'package:caribtap/listings/model/listing_model.dart';

class ProfileScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final bool showAppBar;

  const ProfileScreen({
    super.key,
    required this.currentUser,
    this.showAppBar = true,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ListingsUser currentUser;
  late final Stream<List<AssignedListingModel>> _assignedListingsStream;
  bool _canShowActivityLog = false;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _assignedListingsStream = collaborationApiManager.streamAssignedListings(
      userId: currentUser.userID,
    );
    _loadActivityLogVisibility();
  }

  Future<void> _loadActivityLogVisibility() async {
    if (!mounted) return;

    if (currentUser.isAdmin) {
      setState(() => _canShowActivityLog = true);
      return;
    }

    final hasPremium = currentUser.isPremium && currentUser.isSubscriptionActive;
    if (!hasPremium) {
      setState(() => _canShowActivityLog = false);
      return;
    }

    try {
      final listings = await listingApiManager.getMyListings(
        currentUserID: currentUser.userID,
        favListingsIDs: currentUser.likedListingsIDs,
      );
      if (!mounted) return;
      setState(() => _canShowActivityLog = listings.isNotEmpty);
    } catch (_) {
      if (!mounted) return;
      setState(() => _canShowActivityLog = false);
    }
  }

  Future<void> _openActivityLogForOwnedListing() async {
    context.read<LoadingCubit>().showLoading(
          context,
          'Loading listings...'.tr(),
          false,
          Color(colorPrimary),
        );
    List<ListingModel> listings = [];
    try {
      listings = await listingApiManager.getMyListings(
        currentUserID: currentUser.userID,
        favListingsIDs: currentUser.likedListingsIDs,
      );
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, 'Failed to load listings'.tr());
      }
    } finally {
      if (context.mounted) {
        context.read<LoadingCubit>().hideLoading();
      }
    }

    if (!context.mounted) return;
    if (listings.isEmpty) {
      showSnackBar(context, 'No listings found'.tr());
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        backgroundColor: isDark ? Colors.grey.shade900 : Colors.white,
        title: Text(
          'Select Listing'.tr(),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        children: listings
            .map(
              (listing) => SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  push(
                    context,
                    ActivityLogScreen(listingId: listing.id),
                  );
                },
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Color(colorPrimary),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        listing.title,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Future<void> _refreshUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(currentUser.userID)
          .get(const GetOptions(source: Source.server));

      if (!doc.exists) return;
      final freshUser = ListingsUser.fromJson(doc.data()!);
      if (!mounted) return;
      setState(() => currentUser = freshUser);
      context.read<AuthenticationBloc>().add(UpdateAuthUserEvent(freshUser));
      _loadActivityLogVisibility();
    } catch (e) {
      if (!mounted) return;
      showSnackBar(context, 'Failed to refresh profile'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build the body content
    final bodyWidget = BlocProvider(
      create: (context) => ProfileBloc(
        currentUser: currentUser,
        profileRepository: profileApiManager,
      ),
      child: Builder(
        builder: (context) {
          return MultiBlocListener(
            listeners: [
              BlocListener<AuthenticationBloc, AuthenticationState>(
                listener: (context, state) {
                      context.read<LoadingCubit>().hideLoading();
                      if (state.authState == AuthState.unauthenticated) {
                        pushAndRemoveUntil(context, const WelcomeScreen(), false);
                      }
                    },
                  ),
                  BlocListener<ProfileBloc, ProfileState>(
                    listener: (context, state) async {
                      if (state is UpdatedUserState) {
                        context.read<LoadingCubit>().hideLoading();
                        context.read<AuthenticationBloc>().user =
                            state.updatedUser;
                        currentUser = state.updatedUser;
                        _loadActivityLogVisibility();
                      } else if (state is UploadingImageState) {
                        context.read<LoadingCubit>().showLoading(
                              context,
                              'Uploading image...'.tr(),
                              false,
                              Color(colorPrimary),
                            );
                      } else if (state is ReauthRequiredState) {
                        bool? result = await showDialog(
                          context: context,
                          builder: (context) => ReAuthUserScreen(
                            provider: state.authProvider,
                            currentEmail:
                                auth.FirebaseAuth.instance.currentUser!.email,
                            phoneNumber: auth
                                .FirebaseAuth.instance.currentUser!.phoneNumber,
                            isDeleteUser: true,
                          ),
                        );
                        if (result != null && result) {
                          if (!context.mounted) return;
                          context
                              .read<AuthenticationBloc>()
                              .add(UserDeletedEvent());
                        }
                      } else if (state is DeleteUserConfirmationState) {
                        bool? result = await _showModernDeleteConfirmationDialog(context);
                        if (result == true) {
                          if (!context.mounted) return;
                          context.read<LoadingCubit>().showLoading(
                                context,
                                'Deleting account...'.tr(),
                                false,
                                Color(colorPrimary),
                              );
                          context
                              .read<ProfileBloc>()
                              .add(DeleteUserConfirmedEvent());
                        }
                      } else if (state is UserDeletedState) {
                        context.read<LoadingCubit>().hideLoading();
                        context
                            .read<AuthenticationBloc>()
                            .add(UserDeletedEvent());
                      }
                    },
                  ),
                ],
                child: RefreshIndicator(
                  onRefresh: _refreshUserData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 32.0, left: 32, right: 32),
                        child: Column(
                          children: [
                            BlocBuilder<ProfileBloc, ProfileState>(
                                buildWhen: (old, current) =>
                                    current is UpdatedUserState && old != current,
                                builder: (context, state) {
                                  return Center(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Theme.of(context).colorScheme.primary,
                                          width: 3,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: displayCircleImage(
                                          currentUser.profilePictureURL,
                                          130,
                                          false,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                            SizedBox(
                              width: 175,
                              child: FloatingActionButton(
                                  backgroundColor: Color(colorAccent),
                                  mini: true,
                                  onPressed: () => _onCameraClick(context),
                                  child: Icon(
                                    Icons.camera_alt,
                                    color: isDarkMode(context)
                                        ? Colors.black
                                        : Colors.white,
                                  )),
                            )
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 16.0, right: 32, left: 32),
                        child: BlocBuilder<ProfileBloc, ProfileState>(
                            buildWhen: (old, current) =>
                                current is UpdatedUserState && old != current,
                            builder: (context, state) {
                              return Text(
                                currentUser.fullName(),
                                style: TextStyle(
                                    color: isDarkMode(context)
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 20),
                                textAlign: TextAlign.center,
                              );
                            }),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          currentUser.isAdmin
                              ? 'Plan: ADMIN'
                              : 'Plan: ${currentUser.subscriptionTier.toUpperCase()}',
                          style: TextStyle(
                            color: currentUser.isAdmin
                                ? Colors.green.shade600
                                : (isDarkMode(context) ? Colors.grey.shade400 : Colors.grey.shade700),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Column(
                          children: [
                            StreamBuilder<List<AssignedListingModel>>(
                              stream: _assignedListingsStream,
                              builder: (context, snapshot) {
                                final assignedCount = snapshot.data?.length ?? 0;
                                if (assignedCount == 0) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: [
                                    _modernListTile(
                                      context,
                                      icon: Icons.group_outlined,
                                      iconColor: Theme.of(context).colorScheme.primary,
                                      title: 'Assigned Listings (${assignedCount.toString()})'.tr(),
                                      onTap: () => push(
                                        context,
                                        AssignedListingsScreen(
                                          userId: currentUser.userID,
                                          onListingSelected: (listingId) async {
                                            final listing = await listingApiManager.getListing(
                                              listingID: listingId,
                                            );
                                            if (listing == null) {
                                              if (context.mounted) {
                                                showSnackBar(context, 'Listing not found'.tr());
                                              }
                                              return;
                                            }
                                            if (!context.mounted) return;
                                            await push(
                                              context,
                                              ListingDetailsWrappingWidget(
                                                listing: listing,
                                                currentUser: currentUser,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const Divider(height: 32, indent: 32, endIndent: 32),
                                  ],
                                );
                              },
                            ),
                            if (_canShowActivityLog) ...[
                              _modernListTile(
                                context,
                                icon: Icons.history,
                                iconColor: Theme.of(context).colorScheme.primary,
                                title: 'Activity Log'.tr(),
                                onTap: _openActivityLogForOwnedListing,
                              ),
                              const Divider(height: 32, indent: 32, endIndent: 32),
                            ],
                            if (currentUser.isAdmin) ...[
                              _modernListTile(
                                context,
                                icon: Icons.playlist_add_rounded,
                                iconColor: Colors.orange,
                                title: 'Populate Test Data'.tr(),
                                onTap: () async {
                                  context.read<LoadingCubit>().showLoading(
                                    context,
                                    'Generating test content...'.tr(),
                                    false,
                                    Color(colorPrimary),
                                  );
                                  try {
                                    await TestDataPopulator.populateAll();
                                    if (context.mounted) {
                                      context.read<LoadingCubit>().hideLoading();
                                      showSnackBar(context, 'Test data generated successfully!'.tr());
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      context.read<LoadingCubit>().hideLoading();
                                      showSnackBar(context, 'Error populating data. Check Firestore rules.'.tr());
                                    }
                                  }
                                },
                              ),
                              _modernListTile(
                                context,
                                icon: Icons.delete_sweep_rounded,
                                iconColor: Colors.redAccent,
                                title: 'Purge Test Data'.tr(),
                                onTap: () async {
                                  final isDark = isDarkMode(context);
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      title: Row(
                                        children: [
                                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Purge Data?'.tr(),
                                            style: TextStyle(
                                              color: isDark ? Colors.white : Colors.black,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Are you sure you want to remove all test data?'.tr(),
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'This will permanently delete all demo/test data from the database.'.tr(),
                                            style: TextStyle(
                                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: Text('No'.tr(), style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600])),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          child: Text('Yes'.tr(), style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true && context.mounted) {
                                    context.read<LoadingCubit>().showLoading(
                                      context,
                                      'Purging test content...'.tr(),
                                      false,
                                      Color(colorPrimary),
                                    );
                                    try {
                                      await TestDataPopulator.purgeTestData();
                                      if (context.mounted) {
                                        context.read<LoadingCubit>().hideLoading();
                                        showSnackBar(context, 'Test data purged successfully!'.tr());
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        context.read<LoadingCubit>().hideLoading();
                                        showSnackBar(context, 'Error purging data. Check Firestore rules.'.tr());
                                      }
                                    }
                                  }
                                },
                              ),
                              const Divider(height: 32, indent: 32, endIndent: 32),
                            ],
                            if (currentUser.isAdmin)
                              _modernListTile(
                                context,
                                icon: Icons.verified_outlined,
                                iconColor: Theme.of(context).colorScheme.primary,
                                title: 'Ad Approval'.tr(),
                                onTap: () => push(context, AdApprovalScreen(currentUser: currentUser)),
                              ),
                            _modernListTile(
                              context,
                              icon: Icons.list_alt_outlined,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'My Listings'.tr(),
                              onTap: () => push(context, MyListingsWrapperWidget(currentUser: currentUser)),
                            ),
                            _modernListTile(
                              context,
                              icon: Icons.schedule_outlined,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'Listing Freshness'.tr(),
                              subtitle: 'Manage your active listings'.tr(),
                              onTap: () => _openFreshnessDashboard(context, currentUser),
                            ),
                            _modernListTile(
                              context,
                              icon: Icons.favorite_outline,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'My Favorites'.tr(),
                              onTap: () => push(context, FavoriteListingsWrapperWidget(currentUser: currentUser)),
                            ),
                            _modernListTile(
                              context,
                              icon: Icons.calendar_month_outlined,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'My Bookings'.tr(),
                              onTap: () => push(context, MyBookingsWrapperWidget(currentUser: currentUser)),
                            ),
                            if (currentUser.isAdmin || const ['professional', 'premium', 'business'].contains(currentUser.subscriptionTier.toLowerCase()))
                              _modernListTile(
                                context,
                                icon: Icons.event_note_outlined,
                                iconColor: Theme.of(context).colorScheme.primary,
                                title: 'Booking Requests'.tr(),
                                onTap: () => push(context, BookingManagementWrapperWidget(currentUser: currentUser)),
                              ),
                            _modernListTile(
                              context,
                              icon: Icons.person_outline,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'Account Details'.tr(),
                              onTap: () async {
                                await push(context, AccountDetailsWrapperWidget(user: currentUser));
                                if (!context.mounted) return;
                                currentUser = context.read<AuthenticationBloc>().user!;
                                context.read<ProfileBloc>().add(InvalidateUserObjectEvent(newUser: currentUser));
                              },
                            ),
                            _modernListTile(
                              context,
                              icon: Icons.settings_outlined,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'Settings'.tr(),
                              onTap: () => push(context, SettingsScreen(user: currentUser)),
                            ),
                            _modernListTile(
                              context,
                              icon: isDarkMode(context) ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'Theme'.tr(),
                              onTap: () => _showThemeSelectionDialog(context),
                            ),
                            _modernListTile(
                              context,
                              icon: Icons.call_outlined,
                              iconColor: Theme.of(context).colorScheme.primary,
                              title: 'Contact Us'.tr(),
                              onTap: () => push(context, ContactUsScreen(currentUser: currentUser)),
                            ),
                            _modernListTile(
                              context,
                              icon: Icons.delete_outline,
                              iconColor: Colors.red,
                              title: 'Delete Account'.tr(),
                              onTap: () => context.read<ProfileBloc>().add(TryToDeleteUserEvent()),
                            ),
                            if (currentUser.isAdmin)
                              _modernListTile(
                                context,
                                icon: Icons.dashboard_outlined,
                                iconColor: Colors.blueGrey,
                                title: 'Admin Dashboard'.tr(),
                                onTap: () => push(context, AdminDashboardWrappingWidget(currentUser: currentUser)),
                              ),
                            if (currentUser.isAdmin)
                              _modernListTile(
                                context,
                                icon: Icons.manage_accounts_outlined,
                                iconColor: Colors.indigo,
                                title: 'Edit User Subscription',
                                onTap: () => push(context, EditUserSubscriptionScreen(currentUser: currentUser)),
                              ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 80.0),
                        child: ConstrainedBox(
                          constraints:
                              const BoxConstraints(minWidth: double.infinity),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.only(top: 12, bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                                side: BorderSide(
                                    color: isDarkMode(context)
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade200),
                              ),
                            ),
                            onPressed: () {
                              context.read<LoadingCubit>().showLoading(
                                    context,
                                    'Logging out...'.tr(),
                                    false,
                                    Color(colorPrimary),
                                  );
                              context
                                  .read<AuthenticationBloc>()
                                  .add(LogoutEvent(currentUser));
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Logout',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode(context)
                                          ? Colors.white
                                          : Colors.black),
                                ).tr(),
                                const SizedBox(height: 4),
                                Text(
                                  "It's ok, your listings are safe",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDarkMode(context)
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ).tr(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );

    // If showAppBar is false, return just the body
    if (!widget.showAppBar) {
      return bodyWidget;
    }

    // Otherwise wrap with PopScope and Scaffold
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (Platform.isAndroid) {
          pushAndRemoveUntil(
            context,
            HomeScreen(currentUser: currentUser),
            false,
          );
        } else {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Profile'.tr()),
          leading: IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              pushAndRemoveUntil(
                context,
                ContainerWrapperWidget(currentUser: currentUser),
                false,
              );
            },
          ),
        ),
        body: bodyWidget,
      ),
    );
  }

  Future<bool?> _showModernDeleteConfirmationDialog(BuildContext context) {
    final isDark = isDarkMode(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Account'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you absolutely sure?'.tr(),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'This action is permanent and cannot be undone. All your listings, bookings, and data will be lost forever.'.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Keep My Account'.tr(),
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete Permanently'.tr()),
          ),
        ],
      ),
    );
  }

  void _showThemeSelectionDialog(BuildContext context) {
    final isDark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Select Theme'.tr(),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildThemeOption(
                  context,
                  title: 'Light'.tr(),
                  icon: Icons.light_mode_outlined,
                  value: ThemeMode.light,
                  groupValue: themeState.themeMode,
                  isDark: isDark,
                ),
                _buildThemeOption(
                  context,
                  title: 'Dark'.tr(),
                  icon: Icons.dark_mode_outlined,
                  value: ThemeMode.dark,
                  groupValue: themeState.themeMode,
                  isDark: isDark,
                ),
                _buildThemeOption(
                  context,
                  title: 'System Default'.tr(),
                  icon: Icons.settings_suggest_outlined,
                  value: ThemeMode.system,
                  groupValue: themeState.themeMode,
                  isDark: isDark,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close'.tr(),
                  style: TextStyle(color: Color(colorPrimary)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
    required bool isDark,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () {
        context.read<ThemeCubit>().setThemeMode(value);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Color(colorPrimary).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Color(colorPrimary) : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: Color(colorPrimary), size: 20),
          ],
        ),
      ),
    );
  }

  void _onCameraClick(BuildContext context) => showCupertinoModalPopup(
        context: context,
        builder: (actionSheetContext) => CupertinoActionSheet(
          message: const Text(
            'Manage Profile Picture',
            style: TextStyle(fontSize: 15.0),
          ).tr(),
          actions: [
            if (currentUser.profilePictureURL.isNotEmpty)
              CupertinoActionSheetAction(
                isDestructiveAction: true,
                onPressed: () {
                  Navigator.pop(actionSheetContext);
                  context.read<LoadingCubit>().showLoading(
                        context,
                        'Removing picture...'.tr(),
                        false,
                        Color(colorPrimary),
                      );
                  context.read<ProfileBloc>().add(DeleteUserImageEvent());
                },
                child: const Text('Remove picture').tr(),
              ),
            CupertinoActionSheetAction(
              child: const Text('Choose from gallery').tr(),
              onPressed: () {
                Navigator.pop(actionSheetContext);
                context.read<ProfileBloc>().add(ChooseImageFromGalleryEvent());
              },
            ),
            CupertinoActionSheetAction(
              child: const Text('Take a picture').tr(),
              onPressed: () {
                Navigator.pop(actionSheetContext);
                context.read<ProfileBloc>().add(CaptureImageByCameraEvent());
              },
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            child: const Text('Cancel').tr(),
            onPressed: () => Navigator.pop(actionSheetContext),
          ),
        ),
      );

  Widget _modernListTile(BuildContext context, {required IconData icon, required Color iconColor, required String title, String? subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          leading: Icon(icon, color: iconColor, size: 28),
          title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(fontSize: 12)) : null,
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          tileColor: Theme.of(context).colorScheme.surface,
        ),
      ),
    );
  }

  Future<void> _openFreshnessDashboard(BuildContext context, ListingsUser currentUser) async {
    // Load listings for the current user
    try {
      final db = FirebaseFirestore.instance;
      final listingsSnapshot = await db
          .collection('listings')
          .where('authorID', isEqualTo: currentUser.userID)
          .get();
      
      final listings = listingsSnapshot.docs
          .map((doc) => ListingModel.fromJson(doc.data()))
          .toList();
      
      if (!context.mounted) return;
      
      push(
        context,
        ListingFreshnessDashboard(
          listings: listings,
          onRefreshListing: (listing) => _refreshSingleListing(context, listing),
          onRefreshMultiple: (listings) => _refreshMultipleListings(context, listings),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading listings: $e')),
      );
    }
  }

  Future<void> _refreshSingleListing(BuildContext context, ListingModel listing) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('refreshListingFreshness').call({
        'listingId': listing.id,
      });
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listing refreshed successfully'.tr())),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _refreshMultipleListings(BuildContext context, List<ListingModel> listings) async {
    try {
      await FirebaseFunctions.instance.httpsCallable('bulkRefreshListings').call({
        'listingIds': listings.map((l) => l.id).toList(),
      });
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listings refreshed successfully'.tr())),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
}
