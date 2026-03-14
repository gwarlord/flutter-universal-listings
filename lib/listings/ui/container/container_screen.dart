import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/ui/chat/api/chat_api_manager.dart';
import 'package:caribtap/core/ui/chat/conversation/archived_conversations_screen.dart';
import 'package:caribtap/core/ui/chat/conversation/conversation_bloc.dart';
import 'package:caribtap/core/ui/chat/conversation/conversations_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart' as cfg;
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/ui/container/container_bloc.dart';
import 'package:caribtap/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:caribtap/listings/listings_module/categories/categories_screen.dart';
import 'package:caribtap/listings/listings_module/home/home_screen.dart';
import 'package:caribtap/listings/listings_module/map_view/map_view_screen.dart';
import 'package:caribtap/listings/listings_module/search/search_screen.dart';
import 'package:caribtap/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:caribtap/listings/listings_module/events/create_event_screen.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
import 'package:caribtap/listings/listings_module/booking_services/booking_services_screen.dart';
import 'package:caribtap/listings/listings_module/booking/my_bookings_screen.dart';
import 'package:caribtap/listings/listings_module/booking/booking_management_screen.dart';
import 'package:caribtap/listings/ui/rentals/rental_orders_hub_screen.dart';
import 'package:caribtap/listings/ui/subscription/pro_upgrade_screen.dart';
import 'package:caribtap/listings/utils/subscription_helper.dart';
import 'package:caribtap/screens/store/orders_management_screen.dart';
import 'package:caribtap/screens/store/customer_orders_screen.dart';
import 'package:caribtap/listings/listings_module/analytics/analytics_screen.dart';
import 'package:caribtap/listings/listings_module/analytics/advanced_analytics_screen.dart';
import 'package:caribtap/listings/listings_module/chat_settings/chat_settings_screen.dart';
import 'package:caribtap/listings/ui/profile/profile/profile_screen.dart';
import 'package:caribtap/listings/listings_module/listing_details/listing_details_screen.dart';
import 'package:caribtap/listings/services/deep_link_service.dart';
import 'package:caribtap/listings/ui/pro_docs/public_invoice_view_screen.dart';
import 'package:caribtap/listings/ui/pro_docs/public_quote_view_screen.dart';
import 'package:caribtap/listings/ui/pro_docs/quote_list_screen.dart';
import 'package:caribtap/listings/ui/help/tutorials_hub_screen.dart';
import 'package:caribtap/listings/ui/legal/legal_center_screen.dart';
import 'package:caribtap/screens/brand/my_brands_screen.dart';
import 'package:caribtap/main.dart' as main_entry;
import 'package:caribtap/listings/ui/widgets/attention_badge.dart'; // Import the new widget
import '../deals/deals_promotion_screen.dart';
import '../deals/ad_review_approval_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart'
    as listings_api; // Corrected import with alias
import 'package:provider/provider.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/services/attention_service.dart';
import 'package:caribtap/listings/ui/attention/attention_cubit.dart';
import 'package:caribtap/listings/model/attention_state_model.dart';
import 'package:caribtap/listings/model/feed_item.dart';
import 'package:caribtap/listings/ui/phone_verification/booking_phone_gate.dart';

enum DrawerSelection {
  home,
  conversations,
  categories,
  search,
  orders,
  rentalOrders,
  profile
}

class ContainerWrapperWidget extends StatefulWidget {
  final ListingsUser currentUser;

  const ContainerWrapperWidget({super.key, required this.currentUser});

  @override
  State<ContainerWrapperWidget> createState() => _ContainerWrapperState();
}

class _ContainerWrapperState extends State<ContainerWrapperWidget> {
  late final AttentionCubit _attentionCubit;

  @override
  void initState() {
    super.initState();
    // Initialize attention service with user ID
    _attentionCubit = context.read<AttentionCubit>();
    _attentionCubit.attentionService.initialize(widget.currentUser.userID);
    // Start listening to attention state
    _attentionCubit.startListening();

    // Set user's preferred language
    _setUserLanguage();
  }

  void _setUserLanguage() {
    final languageCode = widget.currentUser.settings.languageCode;
    if (languageCode != null && languageCode.isNotEmpty) {
      // User has a language preference, apply it
      context.setLocale(Locale(languageCode));
    }
    // If languageCode is null, use system default (already set by EasyLocalization)
  }

  @override
  void dispose() {
    // Stop listening when widget is disposed - use saved reference
    _attentionCubit.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ContainerBloc(),
        ),
      ],
      child: ContainerScreen(user: widget.currentUser),
    );
  }
}

class ContainerScreen extends StatefulWidget {
  final ListingsUser user;

  const ContainerScreen({super.key, required this.user});

  @override
  State<ContainerScreen> createState() {
    return _ContainerState();
  }
}

class _ContainerState extends State<ContainerScreen> {
  DateTime? _lastBackPressed;
  DrawerSelection _drawerSelection = DrawerSelection.home;
  String _appBarTitle = 'Home'.tr();

  int _selectedTapIndex = 0;
  GlobalKey<HomeScreenState> homeKey = GlobalKey();
  late Widget _currentWidget;

  bool _showProfessionalFeatures = false;
  bool _showPremiumFeatures = false;

  @override
  void initState() {
    super.initState();
    _currentWidget = HomeWrapperWidget(
      currentUser: widget.user,
      homeKey: homeKey,
    );
    FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    // Handle pending deep link navigation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handlePendingDeepLink();
    });
  }

  /// Handle pending deep link after the screen is built
  Future<void> _handlePendingDeepLink() async {
    final pendingManageId = main_entry.getPendingListingManageId();
    if (pendingManageId != null) {
      print('🔗 Navigating to manage listing: $pendingManageId');
      await push(
        context,
        MyListingsWrapperWidget(
          currentUser: widget.user,
          initialListingId: pendingManageId,
        ),
      );
      return;
    }

    final pendingProDocType = main_entry.getPendingProDocType();
    final pendingProDocToken = main_entry.getPendingProDocToken();
    if (pendingProDocType != null && pendingProDocToken != null) {
      if (pendingProDocType == 'quote') {
        await push(
          context,
          PublicQuoteViewScreen(token: pendingProDocToken),
        );
      } else if (pendingProDocType == 'invoice') {
        await push(
          context,
          PublicInvoiceViewScreen(token: pendingProDocToken),
        );
      }
      return;
    }

    final pendingListingId = main_entry.getPendingListingId();

    if (pendingListingId != null) {
      print('🔗 Navigating to pending listing: $pendingListingId');

      try {
        // Fetch the listing
        final deepLinkService = DeepLinkService();
        final listing = await deepLinkService.getListingById(pendingListingId);

        if (listing != null && mounted) {
          // Navigate to listing details
          await push(
            context,
            ListingDetailsWrappingWidget(
              listing: listing,
              currentUser: widget.user,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Listing not found or has been removed.'.tr()),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print('❌ Error navigating to listing: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open listing. Please try again.'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
      return;
    }

    final pendingEventId = main_entry.getPendingEventId();

    if (pendingEventId != null) {
      print('🔗 Navigating to pending event: $pendingEventId');

      try {
        final deepLinkService = DeepLinkService();
        final event = await deepLinkService.getEventById(pendingEventId);

        if (event != null && mounted) {
          await push(
            context,
            EventDetailsScreen(event: event),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Event not found or has been removed.'.tr()),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } catch (e) {
        print('❌ Error navigating to event: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to open event. Please try again.'.tr()),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _navigateToListingServices(BuildContext context) {
    Navigator.pop(context); // Close drawer
    final currentUser =
        context.read<AuthenticationBloc>().state.user ?? widget.user;
    push(context, BookingServicesWrapperWidget(currentUser: currentUser));
  }

  Future<void> _showCreateOptions(ListingsUser currentUser) async {
    final isDark = isDarkMode(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.add_business_outlined),
                  title: Text('Add Listing'.tr()),
                  onTap: () async {
                    Navigator.pop(sheetContext);
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
                ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text('Post Event'.tr()),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openCreateEventScreen(currentUser);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text('Upload New Ad'.tr()),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final allowed = await checkAndHandleBookingAccess(
                      context: context,
                      listerId: currentUser.userID,
                    );
                    if (!allowed || !context.mounted) return;
                    push(context, DealsPromotionScreen());
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openCreateEventScreen(ListingsUser currentUser) async {
    if (currentUser.isAdmin || currentUser.hasBookingServices) {
      final allowed = await checkAndHandleBookingAccess(
        context: context,
        listerId: currentUser.userID,
      );
      if (!allowed || !mounted) return;

      final bool? created = await push(
        context,
        CreateEventScreen(currentUser: currentUser),
      );
      if (created == true) {
        homeKey.currentState?.refreshFeed();
        if (mounted) {
          showSnackBar(context, 'Event posted successfully.'.tr());
        }
      }
      return;
    }

    _showUpgradeDialog(context, 'Post Event', 'Professional');
  }

  void _showUpgradeDialog(
      BuildContext context, String featureName, String requiredTier) {
    final dark = isDarkMode(context);
    final currentUser =
        context.read<AuthenticationBloc>().state.user ?? widget.user;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.lock, color: Color(cfg.colorPrimary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Upgrade Required'.tr(),
                style: TextStyle(color: dark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
        content: Text(
          'This feature requires a $requiredTier subscription. Upgrade now to unlock $featureName and other exclusive features!'
              .tr(),
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Maybe Later'.tr(),
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(cfg.colorPrimary),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProUpgradeScreen(
                    currentUser: currentUser,
                  ),
                ),
              );
            },
            child: Text('Upgrade Now'.tr()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final now = DateTime.now();
        if (_lastBackPressed == null ||
            now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
          _lastBackPressed = now;
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Press back again to exit'.tr()),
              duration: const Duration(seconds: 2),
            ),
          );
          return false;
        }
        return true;
      },
      child: BlocBuilder<AuthenticationBloc, AuthenticationState>(
        builder: (context, authState) {
          final currentUser = authState.user ?? widget.user;
          return BlocConsumer<ContainerBloc, ContainerState>(
            listener: (context, state) {
              if (state is TabSelectedState) {
                _currentWidget = state.currentWidget;
                _selectedTapIndex = state.currentTabIndex;
                _appBarTitle = state.appBarTitle;
                _drawerSelection = state.drawerSelection;
              }
            },
            builder: (context, state) {
              final isDark = isDarkMode(context);
              return Scaffold(
                drawer: _buildModernDrawer(context, currentUser, isDark),
                appBar: AppBar(
                  leadingWidth: 96,
                  leading: SizedBox(
                    width: 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) =>
                              BlocBuilder<AttentionCubit, AttentionState>(
                            builder: (context, attentionState) {
                              final hasAttention = attentionState
                                      .attentionState?.globalHasAttention ??
                                  false;
                              return Stack(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.menu),
                                    onPressed: () =>
                                        Scaffold.of(context).openDrawer(),
                                  ),
                                  Positioned(
                                    right:
                                        2, // Adjusted position for visibility
                                    top: 6, // Adjusted position for visibility
                                    child: AttentionDot(
                                        hasAttention: hasAttention,
                                        dotSize: 12),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        GestureDetector(
                          onTap: () => push(
                              context, ProfileScreen(currentUser: currentUser)),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: currentUser.profilePictureURL.isNotEmpty
                                ? displayCircleImage(
                                    currentUser.profilePictureURL,
                                    36,
                                    false,
                                  )
                                : CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.grey[300],
                                    child: Icon(Icons.person,
                                        color: Colors.grey[700]),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (_currentWidget is HomeWrapperWidget)
                      IconButton(
                        tooltip: 'Create'.tr(),
                        icon: const Icon(
                          Icons.add,
                        ),
                        onPressed: () => _showCreateOptions(currentUser),
                      ),
                    if (_currentWidget is HomeWrapperWidget)
                      IconButton(
                        tooltip: 'Map'.tr(),
                        icon: const Icon(
                          Icons.map,
                        ),
                        onPressed: () {
                          final homeState = homeKey.currentState;
                          if (homeState != null) {
                            final items = homeState.listingsWithAds
                                .where((e) => e != null)
                                .cast<FeedItem>()
                                .toList();
                            push(
                              context,
                              MapViewScreen(
                                items: items,
                                fromHome: true,
                                currentUser: currentUser,
                              ),
                            );
                          }
                        },
                      ),
                    if (_currentWidget is ConversationsWrapperWidget)
                      IconButton(
                        tooltip: 'Chat Hours'.tr(),
                        icon: const Icon(Icons.settings),
                        onPressed: () => push(
                          context,
                          ChatSettingsScreen(
                            currentUser: currentUser,
                            listingsRepository: listings_api.listingApiManager,
                          ),
                        ),
                      ),
                    if (_currentWidget is ConversationsWrapperWidget)
                      IconButton(
                        tooltip: 'Archived'.tr(),
                        icon: const Icon(Icons.archive),
                        onPressed: () {
                          push(
                            context,
                            BlocProvider(
                              create: (_) => ConversationsBloc(
                                chatRepository: chatApiManager,
                                currentUser: currentUser,
                              ),
                              child: ArchivedConversationsScreen(
                                  user: currentUser),
                            ),
                          );
                        },
                      ),
                  ],
                  title: Text(
                    _appBarTitle,
                  ),
                  centerTitle: true,
                ),
                body: LayoutBuilder(
                  builder: (context, constraints) {
                    final maxBodyWidth =
                        constraints.maxWidth >= 1280 ? 1240.0 : double.infinity;
                    if (maxBodyWidth == double.infinity) {
                      return _currentWidget;
                    }
                    return Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: maxBodyWidth,
                        child: _currentWidget,
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildModernDrawer(
      BuildContext context, ListingsUser currentUser, bool isDark) {
    final primaryColorValue = Color(cfg.colorPrimary);
    final selectedBgColor = primaryColorValue.withOpacity(0.1);

    final drawerWidth = (MediaQuery.of(context).size.width * 0.85)
        .clamp(280.0, 380.0)
        .toDouble();

    return Drawer(
      width: drawerWidth,
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      child: Column(
        children: [
          // Modern Header
          _buildDrawerHeader(currentUser, isDark, primaryColorValue),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // BROWSE SECTION
                  _drawerSectionLabel('Browse'.tr(), isDark),
                  _drawerTile(
                    title: 'Home'.tr(),
                    icon: Icons.home_rounded,
                    isSelected: _drawerSelection == DrawerSelection.home,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                            appBarTitle: 'Home'.tr(),
                            currentTabIndex: 0,
                            drawerSelection: DrawerSelection.home,
                            currentWidget: HomeWrapperWidget(
                                homeKey: homeKey, currentUser: currentUser),
                          ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Categories'.tr(),
                    icon: Icons.category_rounded,
                    isSelected: _drawerSelection == DrawerSelection.categories,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                            appBarTitle: 'Categories'.tr(),
                            currentTabIndex: 1,
                            drawerSelection: DrawerSelection.categories,
                            currentWidget: CategoriesWrapperWidget(
                                currentUser: currentUser),
                          ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final badgeCount = state.attentionState
                              ?.getCountForModule(
                                  AttentionModule.conversations) ??
                          0;
                      return _drawerTile(
                        title: 'Conversations'.tr(),
                        icon: Icons.chat_bubble_rounded,
                        isSelected:
                            _drawerSelection == DrawerSelection.conversations,
                        trailing: badgeCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Color(cfg.colorPrimary),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  badgeCount > 99
                                      ? '99+'
                                      : badgeCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () {
                          // NOTE: markModuleAsSeen is now handled in ConversationsScreen initState
                          Navigator.pop(context);
                          context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'Conversations'.tr(),
                                currentTabIndex: 2,
                                drawerSelection: DrawerSelection.conversations,
                                currentWidget: ConversationsWrapperWidget(
                                    user: currentUser),
                              ));
                        },
                        isDark: isDark,
                        primaryColor: primaryColorValue,
                      );
                    },
                  ),
                  _drawerTile(
                    title: 'Search'.tr(),
                    icon: Icons.search_rounded,
                    isSelected: _drawerSelection == DrawerSelection.search,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                            appBarTitle: 'Search'.tr(),
                            currentTabIndex: 3,
                            drawerSelection: DrawerSelection.search,
                            currentWidget:
                                SearchWrapperWidget(currentUser: currentUser),
                          ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // SHOPPING SECTION
                  _drawerSectionLabel('Shopping'.tr(), isDark),
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final badgeCount = state.attentionState
                              ?.getCountForModule(AttentionModule.myOrders) ??
                          0;
                      return _drawerTile(
                        title: 'My Orders'.tr(),
                        icon: Icons.shopping_bag_rounded,
                        isSelected: _drawerSelection == DrawerSelection.orders,
                        trailing: badgeCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Color(cfg.colorPrimary),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  badgeCount > 99
                                      ? '99+'
                                      : badgeCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () {
                          context
                              .read<AttentionCubit>()
                              .markModuleAsSeen(AttentionModule.myOrders);
                          Navigator.pop(context);
                          context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'My Orders'.tr(),
                                currentTabIndex: 4,
                                drawerSelection: DrawerSelection.orders,
                                currentWidget: CustomerOrdersScreen(
                                    currentUser: currentUser),
                              ));
                        },
                        isDark: isDark,
                        primaryColor: primaryColorValue,
                      );
                    },
                  ),
                  if (isPremiumUser(currentUser))
                    BlocBuilder<AttentionCubit, AttentionState>(
                      builder: (context, state) {
                        final badgeCount = state.attentionState
                                ?.getCountForModule(
                                    AttentionModule.orderRequests) ??
                            0;
                        return _drawerTile(
                          title: 'Order Requests'.tr(),
                          icon: Icons.event_note_rounded,
                          trailing: badgeCount > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Color(cfg.colorPrimary),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text(
                                        badgeCount > 99
                                            ? '99+'
                                            : badgeCount.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    _tierBadge('PREMIUM', Colors.purple),
                                  ],
                                )
                              : _tierBadge('PREMIUM', Colors.purple),
                          onTap: () {
                            context.read<AttentionCubit>().markModuleAsSeen(
                                AttentionModule.orderRequests);
                            Navigator.pop(context);
                            push(
                                context,
                                OrdersManagementScreen(
                                    currentUser: currentUser));
                          },
                          isDark: isDark,
                          primaryColor: primaryColorValue,
                        );
                      },
                    ),
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final badgeCount = state.attentionState
                              ?.getCountForModule(AttentionModule.rentals) ??
                          0;
                      return _drawerTile(
                        title: 'Rentals'.tr(),
                        icon: Icons.calendar_month_rounded,
                        isSelected:
                            _drawerSelection == DrawerSelection.rentalOrders,
                        trailing: badgeCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Color(cfg.colorPrimary),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  badgeCount > 99
                                      ? '99+'
                                      : badgeCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () {
                          context
                              .read<AttentionCubit>()
                              .markModuleAsSeen(AttentionModule.rentals);
                          Navigator.pop(context);
                          context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'Rentals'.tr(),
                                currentTabIndex: 4,
                                drawerSelection: DrawerSelection.rentalOrders,
                                currentWidget: RentalOrdersHubScreen(
                                    currentUser: currentUser,
                                    showAppBar: false),
                              ));
                        },
                        isDark: isDark,
                        primaryColor: primaryColorValue,
                      );
                    },
                  ),

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // SELLING SECTION
                  _drawerSectionLabel('Selling'.tr(), isDark),
                  _drawerTile(
                    title: 'My Listings'.tr(),
                    icon: Icons.list_alt_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context,
                          MyListingsWrapperWidget(currentUser: currentUser));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Post Event'.tr(),
                    icon: Icons.event_rounded,
                    trailing:
                        (currentUser.isAdmin || currentUser.hasBookingServices)
                            ? _tierBadge('PRO', Colors.blue)
                            : _lockIcon(),
                    onTap: () async {
                      Navigator.pop(context);
                      await _openCreateEventScreen(currentUser);
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'My Brands/Branches'.tr(),
                    icon: Icons.storefront_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, MyBrandsScreen(currentUser: currentUser));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final badgeCount = state.attentionState
                              ?.getCountForModule(AttentionModule.myBookings) ??
                          0;
                      return _drawerTile(
                        title: 'My Bookings'.tr(),
                        icon: Icons.calendar_today_rounded,
                        trailing: badgeCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: Color(cfg.colorPrimary),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Text(
                                  badgeCount > 99
                                      ? '99+'
                                      : badgeCount.toString(),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                            : null,
                        onTap: () {
                          context
                              .read<AttentionCubit>()
                              .markModuleAsSeen(AttentionModule.myBookings);
                          Navigator.pop(context);
                          push(
                              context,
                              MyBookingsWrapperWidget(
                                  currentUser: currentUser));
                        },
                        isDark: isDark,
                        primaryColor: primaryColorValue,
                      );
                    },
                  ),
                  if (currentUser.isAdmin ||
                      const ['professional', 'premium']
                          .contains(currentUser.subscriptionTier.toLowerCase()))
                    BlocBuilder<AttentionCubit, AttentionState>(
                      builder: (context, state) {
                        final badgeCount = state.attentionState
                                ?.getCountForModule(
                                    AttentionModule.bookingRequests) ??
                            0;
                        return _drawerTile(
                          title: 'Booking Requests'.tr(),
                          icon: Icons.event_note_rounded,
                          trailing: badgeCount > 0
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: Color(cfg.colorPrimary),
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                      child: Text(
                                        badgeCount > 99
                                            ? '99+'
                                            : badgeCount.toString(),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    _tierBadge('PRO', Colors.blue),
                                  ],
                                )
                              : _tierBadge('PRO', Colors.blue),
                          onTap: () {
                            context.read<AttentionCubit>().markModuleAsSeen(
                                AttentionModule.bookingRequests);
                            Navigator.pop(context);
                            push(
                                context,
                                BookingManagementWrapperWidget(
                                    currentUser: currentUser));
                          },
                          isDark: isDark,
                          primaryColor: primaryColorValue,
                        );
                      },
                    ),
                  _drawerTile(
                    title: 'Activate Booking'.tr(),
                    icon: Icons.room_service_rounded,
                    trailing: !currentUser.hasBookingServices
                        ? _lockIcon()
                        : _tierBadge('PRO', Colors.blue),
                    onTap: () {
                      if (currentUser.hasBookingServices) {
                        _navigateToListingServices(context);
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(
                            context, 'Activate Booking', 'Professional');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Deals & Promotions'.tr(),
                    icon: Icons.local_offer_rounded,
                    onTap: () async {
                      Navigator.pop(context);
                      final allowed = await checkAndHandleBookingAccess(
                        context: context,
                        listerId: currentUser.userID,
                      );
                      if (!allowed || !context.mounted) return;
                      push(context, DealsPromotionScreen());
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Quotes & Invoices'.tr(),
                    icon: Icons.receipt_long_rounded,
                    trailing: isPremiumUser(currentUser)
                        ? _tierBadge('PREMIUM', Colors.purple)
                        : _lockIcon(),
                    onTap: () {
                      if (isPremiumUser(currentUser)) {
                        Navigator.pop(context);
                        push(
                            context, QuoteListScreen(currentUser: currentUser));
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(
                            context, 'Quotes & Invoices', 'Premium');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // ANALYTICS SECTION
                  _drawerSectionLabel('Analytics'.tr(), isDark),
                  _drawerTile(
                    title: 'Analytics'.tr(),
                    icon: Icons.bar_chart_rounded,
                    trailing: !currentUser.hasBookingServices
                        ? _lockIcon()
                        : _tierBadge('PRO', Colors.blue),
                    onTap: () {
                      if (currentUser.hasBookingServices) {
                        Navigator.pop(context);
                        push(
                            context, AnalyticsScreen(currentUser: currentUser));
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(
                            context, 'Analytics', 'Professional');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Advanced Analytics'.tr(),
                    icon: Icons.analytics_rounded,
                    trailing: (currentUser.isAdmin ||
                            ['premium', 'business'].contains(
                                currentUser.subscriptionTier.toLowerCase()))
                        ? _tierBadge('PREMIUM', Colors.purple)
                        : _lockIcon(),
                    onTap: () {
                      if (currentUser.isAdmin ||
                          ['premium', 'business'].contains(
                              currentUser.subscriptionTier.toLowerCase())) {
                        Navigator.pop(context);
                        push(context,
                            AdvancedAnalyticsScreen(currentUser: currentUser));
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(
                            context, 'Advanced Analytics', 'Premium');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // ACCOUNT SECTION
                  _drawerSectionLabel('Account'.tr(), isDark),
                  _drawerTile(
                    title: 'Profile'.tr(),
                    icon: Icons.person_rounded,
                    isSelected: _drawerSelection == DrawerSelection.profile,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                            appBarTitle: 'Profile'.tr(),
                            currentTabIndex: 3,
                            drawerSelection: DrawerSelection.profile,
                            currentWidget: ProfileScreen(
                              currentUser: currentUser,
                              showAppBar: false,
                            ),
                          ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Activate Chat'.tr(),
                    icon: Icons.chat_rounded,
                    trailing: !currentUser.hasDirectMessaging
                        ? _lockIcon()
                        : _tierBadge('PREMIUM', Colors.purple),
                    onTap: () {
                      Navigator.pop(context);
                      if (currentUser.hasDirectMessaging) {
                        push(
                            context,
                            ChatSettingsScreen(
                                currentUser: currentUser,
                                listingsRepository:
                                    listings_api.listingApiManager));
                      } else {
                        _showUpgradeDialog(context, 'Activate Chat', 'Premium');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Help & Tutorials'.tr(),
                    icon: Icons.menu_book_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, const TutorialsHubScreen());
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Legal'.tr(),
                    icon: Icons.gavel_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, const LegalCenterScreen());
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  if (currentUser.subscriptionTier.toLowerCase() != 'free')
                    _drawerTile(
                      title: 'Manage Subscription'.tr(),
                      icon: Icons.card_membership_rounded,
                      onTap: () {
                        Navigator.pop(context);
                        push(context,
                            ProUpgradeScreen(currentUser: currentUser));
                      },
                      isDark: isDark,
                      primaryColor: primaryColorValue,
                    ),

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // UPGRADE PLAN CARD
                  if (currentUser.subscriptionTier.toLowerCase() == 'free')
                    _buildUpgradePlanCard(
                        isDark, primaryColorValue, context, currentUser),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(
      ListingsUser user, bool isDark, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        color: primaryColor,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor
                .withBlue(primaryColor.blue + 30)
                .withRed(primaryColor.red + 20),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              push(context, ProfileScreen(currentUser: user));
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              ),
              child: displayCircleImage(user.profilePictureURL, 64, false),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName(),
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  user.email,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.8), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.isAdmin || user.subscriptionTier.toLowerCase() != 'free')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    user.isAdmin
                        ? 'ADMIN'
                        : user.subscriptionTier.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _drawerSectionLabel(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: isDark ? Colors.white38 : Colors.black45,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _drawerTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false,
    bool isCompact = false,
    bool isDark = false,
    required Color primaryColor,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: onTap,
        dense: isCompact,
        visualDensity: isCompact ? VisualDensity.compact : null,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(
          icon,
          color: isSelected
              ? primaryColor
              : (iconColor ?? (isDark ? Colors.white70 : Colors.black54)),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected
                ? primaryColor
                : (textColor ?? (isDark ? Colors.white : Colors.black87)),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 15,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _expansionTile({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool isDark,
    Color? iconColor,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        unselectedWidgetColor: isDark ? Colors.white : Colors.black54,
        colorScheme: Theme.of(context).colorScheme.copyWith(
              onSurface: isDark ? Colors.white : Colors.black54,
            ),
      ),
      child: ExpansionTile(
        leading: Icon(icon,
            color: iconColor ?? (isDark ? Colors.white70 : Colors.black54),
            size: 22),
        title: Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        shape: const RoundedRectangleBorder(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
        childrenPadding: const EdgeInsets.only(left: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: isDark ? Colors.white : Colors.black54,
        collapsedIconColor: isDark ? Colors.white : Colors.black54,
        children: children,
      ),
    );
  }

  Widget _tierBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5), width: 0.5),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _lockIcon() {
    return const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey);
  }

  Widget _buildUpgradePlanCard(bool isDark, Color primaryColor,
      BuildContext context, ListingsUser currentUser) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withOpacity(0.15),
            primaryColor.withOpacity(0.05),
          ],
        ),
        border: Border.all(
          color: primaryColor.withOpacity(0.3),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
            push(context, ProUpgradeScreen(currentUser: currentUser));
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.star_rounded,
                      color: primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Unlock Premium Features'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Access Pro & Premium tools'.tr(),
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: primaryColor,
                      size: 20,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
