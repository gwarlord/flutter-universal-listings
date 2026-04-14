import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/suspension_info.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/listings_module/my_listings/my_listings_bloc.dart';
import 'package:caribtap/listings/utils/suspension_reason_details.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:caribtap/listings/ui/collaboration/assigned_listings_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:caribtap/listings/widgets/freshness_indicators.dart';
import 'package:caribtap/listings/ui/phone_verification/booking_phone_gate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/event_model.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';

class MyListingsWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;
  final String? initialListingId;

  const MyListingsWrapperWidget({
    Key? key,
    required this.currentUser,
    this.initialListingId,
  })
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MyListingsBloc(
        listingsRepository: listingApiManager,
        currentUser: currentUser,
        profileRepository: profileApiManager,
      ),
      child: MyListingsScreen(
        currentUser: currentUser,
        initialListingId: initialListingId,
      ),
    );
  }
}

class MyListingsScreen extends StatefulWidget {
  final ListingsUser currentUser;
  final String? initialListingId;

  const MyListingsScreen({
    Key? key,
    required this.currentUser,
    this.initialListingId,
  })
      : super(key: key);

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  List<ListingModel> _listings = [];
  late ListingsUser currentUser;
  bool isLoading = true;
  bool _initialListingHandled = false;
  String? _initialListingId;
  List<EventModel> _events = [];
  bool _eventsLoading = true;

  @override
  void initState() {
    super.initState();
    currentUser = widget.currentUser;
    _initialListingId = widget.initialListingId;
    context.read<MyListingsBloc>().add(GetMyListingsEvent());
    _loadMyEvents();
  }

  Future<void> _loadMyEvents() async {
    if (!mounted) return;
    setState(() => _eventsLoading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('createdBy', isEqualTo: currentUser.userID)
          .get();
      final events = snap.docs.map((doc) {
        final e = EventModel.fromJson(doc.data());
        e.id = doc.id;
        return e;
      }).toList();
      if (mounted) setState(() { _events = events; _eventsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _eventsLoading = false);
    }
  }

  Future<void> _openAssignedListings() async {
    await push(
      context,
      AssignedListingsScreen(
        userId: currentUser.userID,
        onListingSelected: (listingId) async {
          final listing = await listingApiManager.getListing(
            listingID: listingId,
          );
          if (listing == null) {
            if (mounted) {
              showSnackBar(context, 'Listing not found'.tr());
            }
            return;
          }
          if (!mounted) return;
          await push(
            context,
            ListingDetailsWrappingWidget(
              listing: listing,
              currentUser: currentUser,
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'My Listings'.tr(),
        ),
        actions: [
          IconButton(
            tooltip: 'Assigned Listings'.tr(),
            icon: const Icon(Icons.group_outlined),
            onPressed: _openAssignedListings,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            context.read<MyListingsBloc>().add(LoadingEvent());
            context.read<MyListingsBloc>().add(GetMyListingsEvent());
            _loadMyEvents();
          },
          child: BlocConsumer<MyListingsBloc, MyListingsState>(
            listener: (context, state) {
              if (state is MyListingsReadyState) {
                isLoading = false;
                _listings = state.myListings;

                if (!_initialListingHandled && _initialListingId != null) {
                  final target = _listings.firstWhere(
                    (element) => element.id == _initialListingId,
                    orElse: () => ListingModel(),
                  );

                  _initialListingHandled = true;
                  if (target.id.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) async {
                      await push(
                        context,
                        ListingDetailsWrappingWidget(
                          listing: target,
                          currentUser: currentUser,
                        ),
                      );
                    });
                  }
                }
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
              if (isLoading || _eventsLoading) {
                return const Center(
                    child: CircularProgressIndicator.adaptive());
              }
              if (_listings.isEmpty && _events.isEmpty) {
                return Stack(
                  children: [
                    ListView(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: showEmptyState(
                        'No Listings'.tr(),
                        'Add a new listing to show up here.'.tr(),
                        action: () async {
                          final allowed = await checkAndHandleBookingAccess(
                            context: context,
                            listerId: currentUser.userID,
                          );
                          if (!allowed || !context.mounted) return;
                          push(
                            context,
                            AddListingWrappingWidget(currentUser: currentUser),
                          );
                        },
                        colorPrimary: Color(colorPrimary),
                        isDarkMode: isDarkMode(context),
                        buttonTitle: 'Add Listing'.tr(),
                      ),
                    ),
                  ],
                );
              } else {
                return CustomScrollView(
                  slivers: [
                    if (_listings.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 24,
                              crossAxisSpacing: 16),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => MyListingCard(
                              listing: _listings[index],
                              currentUser: currentUser,
                            ),
                            childCount: _listings.length,
                          ),
                        ),
                      ),
                    if (_events.isNotEmpty) ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: Text(
                            'My Events'.tr(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => MyEventCard(
                            event: _events[index],
                            currentUser: currentUser,
                            onRefresh: _loadMyEvents,
                          ),
                          childCount: _events.length,
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 16)),
                    ],
                  ],
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
  bool _isRefreshing = false;

  Future<void> _refreshFreshness(String successMessage) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await listingApiManager.refreshListingFreshness(
        listingId: widget.listing.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage.tr())),
        );
        context.read<MyListingsBloc>().add(GetMyListingsEvent());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

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
                          FutureBuilder<String?>(
                            future: SuspensionReasonDetailsResolver.resolve(
                              reasonText: widget.listing.suspensionInfo!.reasonText!,
                              listingId: widget.listing.id,
                            ),
                            builder: (context, snapshot) => SelectableText(
                              snapshot.data ?? widget.listing.suspensionInfo!.reasonText!,
                              style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                              enableInteractiveSelection: true,
                            ),
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
    final freshness = widget.listing.freshness;
    final freshnessEnabled = freshness.enabled && !freshness.exempt;
    final daysRemaining = freshness.daysRemaining;
    final showExpiryBadge = freshnessEnabled &&
      daysRemaining != null &&
      daysRemaining > 0 &&
      daysRemaining <= 14;
    final isHiddenExpired = widget.listing.hidden &&
      freshness.status == 'HIDDEN_EXPIRED';
    
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
            flex: 6,
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
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
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
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility_off,
                                    color: Colors.grey, size: 32),
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
          const SizedBox(height: 2),
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.listing.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 16,
                        color: isDarkMode(context)
                            ? Colors.grey.shade400
                            : Colors.grey.shade800,
                        fontWeight: FontWeight.bold),
                  ),
                  // Freshness Status Badge
                  if (!isSuspended && widget.listing.freshness.enabled && !widget.listing.freshness.exempt)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: FreshnessStatusBadge(listing: widget.listing, compact: true),
                    ),
                  // In compact card mode, the FreshnessStatusBadge already shows
                  // remaining days. Avoid rendering a duplicate expiry chip.
                  if (!isSuspended && isHiddenExpired)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.red, width: 1),
                        ),
                        child: Text(
                          'Hidden (expired)'.tr(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ),
                  if (isSuspended && !suspensionRequested)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
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
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
                      child: Text(
                        widget.listing.place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHiddenExpired)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(colorPrimary),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          icon: _isRefreshing
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text('Reactivate / Reset'.tr(),
                              style: const TextStyle(fontSize: 11)),
                          onPressed: _isRefreshing
                              ? null
                              : () => _refreshFreshness(
                                    'Listing reactivated and refreshed',
                                  ),
                        ),
                      ),
                    if (!isHiddenExpired && showExpiryBadge)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            side: BorderSide(color: Color(colorPrimary)),
                          ),
                          icon: _isRefreshing
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 16),
                          label: Text('Reset counter'.tr(),
                              style: const TextStyle(fontSize: 11)),
                          onPressed: _isRefreshing
                              ? null
                              : () => _refreshFreshness('Listing freshness refreshed'),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.0),
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
                                  .add(ListingHiddenToggled(
                                    listing: widget.listing,
                                    setHidden: !value,
                                  )),
                            ),
                          ),
                        ],
                      ),
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

class MyEventCard extends StatelessWidget {
  final EventModel event;
  final ListingsUser currentUser;
  final VoidCallback onRefresh;

  const MyEventCard({
    Key? key,
    required this.event,
    required this.currentUser,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final startDate = DateTime.fromMillisecondsSinceEpoch(event.startAtSeconds * 1000);
    final formattedDate = '${startDate.day}/${startDate.month}/${startDate.year}';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        onTap: () async {
          await push(context, EventDetailsScreen(event: event));
          onRefresh();
        },
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: event.posterImageUrl.isNotEmpty
                ? displayImage(event.posterImageUrl)
                : Container(
                    color: Color(colorPrimary).withOpacity(0.15),
                    child: Icon(Icons.event, color: Color(colorPrimary)),
                  ),
          ),
        ),
        title: Text(
          event.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          formattedDate,
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
