import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/suspension_info.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:instaflutter/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:instaflutter/listings/listings_module/my_listings/my_listings_bloc.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class MyListingsWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const MyListingsWrapperWidget({Key? key, required this.currentUser})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MyListingsBloc(
        listingsRepository: listingApiManager,
        currentUser: currentUser,
        profileRepository: profileApiManager,
      ),
      child: MyListingsScreen(currentUser: currentUser),
    );
  }
}

class MyListingsScreen extends StatefulWidget {
  final ListingsUser currentUser;

  const MyListingsScreen({Key? key, required this.currentUser})
      : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<ListingModel> _listings = [];
  late ListingsUser currentUser;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    context.read<MyListingsBloc>().add(GetMyListingsEvent());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Listings'.tr(),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<MyListingsBloc>().add(LoadingEvent());
            context.read<MyListingsBloc>().add(GetMyListingsEvent());
          },
          child: BlocConsumer<MyListingsBloc, MyListingsState>(
            listener: (context, state) {
              if (state is MyListingsReadyState) {
                isLoading = false;
                _listings = state.myListings;
              } else if (state is ListingFavToggleState) {
                currentUser = state.updatedUser;
                context.read<AuthenticationBloc>().user = state.updatedUser;
                _listings
                    .firstWhere((element) => element.id == state.listing.id)
                    .isFav = state.listing.isFav;
              } else if (state is ListingHiddenToggleState) {
                _listings
                    .firstWhere((element) => element.id == state.listing.id)
                    .hidden = state.listing.hidden;
              } else if (state is LoadingState) {
                isLoading = true;
              }
            },
            builder: (context, state) {
              if (isLoading) {
                return const Center(
                    child: CircularProgressIndicator.adaptive());
              }
              if (_listings.isEmpty) {
                return Stack(
                  children: [
                    ListView(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: showEmptyState(
                        'No Listings'.tr(),
                        'Add a new listing to show up here.'.tr(),
                        action: () => push(
                          context,
                          AddListingWrappingWidget(currentUser: currentUser),
                        ),
                        colorPrimary: Color(colorPrimary),
                        isDarkMode: isDarkMode(context),
                        buttonTitle: 'Add Listing'.tr(),
                      ),
                    ),
                  ],
                );
              } else {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 24,
                      crossAxisSpacing: 16),
                  itemCount: _listings.length,
                  itemBuilder: (context, index) => MyListingCard(
                    listing: _listings[index],
                    currentUser: currentUser,
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}

class MyListingCard extends StatefulWidget {
  final ListingModel listing;
  final ListingsUser currentUser;

  const MyListingCard(
      {Key? key, required this.listing, required this.currentUser})
      : super(key: key);

  @override
  State<MyListingCard> createState() => _MyListingCardState();
}

class _MyListingCardState extends State<MyListingCard> {
  void _showRequestUnsuspensionDialog() {
    final TextEditingController controller = TextEditingController();
    final isDark = isDarkMode(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Request Unsuspension'.tr(),
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.listing.suspensionInfo?.reason != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Suspension Reason:'.tr(),
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.listing.suspensionInfo!.reason!.displayName,
                          style: TextStyle(color: Colors.red, fontSize: 13),
                        ),
                        if (widget.listing.suspensionInfo!.reasonText != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.listing.suspensionInfo!.reasonText!,
                            style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Explain why this listing should be unsuspended:'.tr(),
                  style: TextStyle(fontSize: 14, color: isDark ? Colors.grey[400] : Colors.grey[700]),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Provide details about your response...'.tr(),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel'.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(colorPrimary),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please provide a response'.tr())),
                );
                return;
              }
              
              Navigator.pop(dialogContext);
              
              try {
                await listingApiManager.requestUnsuspension(
                  listing: widget.listing,
                  requestText: controller.text.trim(),
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Unsuspension request submitted'.tr())),
                  );
                  // Refresh listings
                  context.read<MyListingsBloc>().add(GetMyListingsEvent());
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text('Submit Request'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSuspended = widget.listing.suspended;
    final suspensionRequested = widget.listing.suspensionInfo?.unsuspensionRequested ?? false;
    
    return GestureDetector(
      onTap: () async {
        bool? isListingDeleted = await push(
            context,
            ListingDetailsWrappingWidget(
                listing: widget.listing, currentUser: widget.currentUser));
        if (isListingDeleted != null && isListingDeleted) {
          if (!mounted) return;
          context
              .read<MyListingsBloc>()
              .add(ListingDeletedByUserEvent(listing: widget.listing));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                displayImage(widget.listing.photo),
                if (isSuspended)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.block, color: Colors.red, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'SUSPENDED'.tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (suspensionRequested)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Request Pending'.tr(),
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (!isSuspended && widget.listing.hidden)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_off, color: Colors.grey, size: 32),
                          const SizedBox(height: 4),
                          Text(
                            'HIDDEN'.tr(),
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!isSuspended)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      tooltip: widget.listing.isFav
                          ? 'Remove From Favorites'.tr()
                          : 'Add To Favorites'.tr(),
                      icon: Icon(
                        Icons.favorite,
                        color: widget.listing.isFav
                            ? Color(colorPrimary)
                            : Colors.white,
                      ),
                      onPressed: () => context
                          .read<MyListingsBloc>()
                          .add(ListingFavUpdated(listing: widget.listing)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.listing.title,
            maxLines: 1,
            style: TextStyle(
                fontSize: 16,
                color: isDarkMode(context)
                    ? Colors.grey.shade400
                    : Colors.grey.shade800,
                fontWeight: FontWeight.bold),
          ),
          if (isSuspended && !suspensionRequested)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                ),
                icon: Icon(Icons.feedback, size: 16),
                label: Text('Request Unsuspension'.tr(), style: TextStyle(fontSize: 11)),
                onPressed: _showRequestUnsuspensionDialog,
              ),
            ),
          if (!isSuspended) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(widget.listing.place, maxLines: 1),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.listing.hidden ? 'Hidden'.tr() : 'Visible'.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.listing.hidden
                            ? Colors.orange
                            : Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: !widget.listing.hidden,
                      activeColor: Color(colorPrimary),
                      activeTrackColor: Color(colorPrimary).withOpacity(0.5),
                      inactiveThumbColor: isDarkMode(context) 
                          ? Colors.grey.shade600 
                          : Colors.grey.shade400,
                      inactiveTrackColor: isDarkMode(context) 
                          ? Colors.grey.shade800 
                          : Colors.grey.shade300,
                      onChanged: (value) => context
                          .read<MyListingsBloc>()
                          .add(ListingHiddenToggled(listing: widget.listing)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
