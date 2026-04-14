import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/my_listings/my_listings_bloc.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:caribtap/listings/ui/collaboration/collaborators_management_screen.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';

class ManageCollaboratorsHubScreen extends StatelessWidget {
  final ListingsUser currentUser;

  const ManageCollaboratorsHubScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyListingsBloc(
        listingsRepository: listingApiManager,
        currentUser: currentUser,
        profileRepository: profileApiManager,
      )..add(GetMyListingsEvent()),
      child: _ManageCollaboratorsHubBody(currentUser: currentUser),
    );
  }
}

class _ManageCollaboratorsHubBody extends StatefulWidget {
  final ListingsUser currentUser;

  const _ManageCollaboratorsHubBody({required this.currentUser});

  @override
  State<_ManageCollaboratorsHubBody> createState() =>
      _ManageCollaboratorsHubBodyState();
}

class _ManageCollaboratorsHubBodyState
    extends State<_ManageCollaboratorsHubBody> {
  final Map<String, int> _collaboratorCounts = {};

  bool get _hasPremium =>
      widget.currentUser.isAdmin ||
      ((widget.currentUser.isProfessional || widget.currentUser.isPremium) &&
          widget.currentUser.isSubscriptionActive);

  void _loadCountsForListings(List<ListingModel> listings) {
    for (final listing in listings) {
      if (!_collaboratorCounts.containsKey(listing.id)) {
        collaborationApiManager
            .getListingCollaborators(listingId: listing.id)
            .then((collaborators) {
          if (mounted) {
            setState(() {
              _collaboratorCounts[listing.id] = collaborators.length;
            });
          }
        }).catchError((_) {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Color(cfg.colorPrimary);

    return Scaffold(
      appBar: AppBar(
        title: Text('Manage Collaborators'.tr()),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: BlocBuilder<MyListingsBloc, MyListingsState>(
        builder: (context, state) {
          if (state is MyListingsInitial || state is LoadingState) {
            return const Center(child: CircularProgressIndicator());
          }

          List<ListingModel> listings = [];
          if (state is MyListingsReadyState) {
            listings = state.myListings;
            _loadCountsForListings(listings);
          }

          if (listings.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.list_alt_outlined,
                      size: 64,
                      color: isDark ? Colors.white38 : Colors.black26),
                  const SizedBox(height: 16),
                  Text(
                    'No listings found'.tr(),
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create a listing first to manage its collaborators.'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 0),
            itemCount: listings.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final listing = listings[index];
              final count = _collaboratorCounts[listing.id];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: listing.photo.isNotEmpty
                      ? Image.network(
                          listing.photo,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderIcon(isDark),
                        )
                      : _placeholderIcon(isDark),
                ),
                title: Text(
                  listing.title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (count != null && count > 0)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Icon(Icons.chevron_right,
                        color: isDark ? Colors.white38 : Colors.black38),
                  ],
                ),
                onTap: () async {
                  await push(
                    context,
                    CollaboratorsManagementScreen(
                      listingId: listing.id,
                      listingOwnerId: listing.authorID,
                      currentUserId: widget.currentUser.userID,
                      isOwner:
                          widget.currentUser.userID == listing.authorID,
                      hasPremium: _hasPremium,
                    ),
                  );
                  // Refresh count when returning from collaborators screen
                  if (mounted) {
                    collaborationApiManager
                        .getListingCollaborators(listingId: listing.id)
                        .then((collaborators) {
                      if (mounted) {
                        setState(() {
                          _collaboratorCounts[listing.id] =
                              collaborators.length;
                        });
                      }
                    }).catchError((_) {});
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _placeholderIcon(bool isDark) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: isDark ? Colors.white12 : Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.storefront_outlined,
          color: isDark ? Colors.white38 : Colors.black38),
    );
  }
}
