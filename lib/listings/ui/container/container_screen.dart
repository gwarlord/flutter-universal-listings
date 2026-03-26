import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'package:caribtap/map_explorer/services/map_explorer_navigation_service.dart';
import 'package:caribtap/listings/listings_module/search/search_screen.dart';
import 'package:caribtap/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:caribtap/listings/listings_module/events/create_event_screen.dart';
import 'package:caribtap/listings/listings_module/events/event_details_screen.dart';
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
import 'package:caribtap/listings/ui/suggestion/suggestion_box_screen.dart';
import 'package:caribtap/listings/ui/demo/demo_listings_screen.dart';
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
  myRentals,
  manageRentals,
  profile
}

class ContainerWrapperWidget extends StatefulWidget {
  final ListingsUser currentUser;

  const ContainerWrapperWidget({super.key, required this.currentUser});

  @override
  State<ContainerWrapperWidget> createState() => _ContainerWrapperState();
}

class _ContainerWrapperState extends State<ContainerWrapperWidget>
    with WidgetsBindingObserver {
  late final AttentionCubit _attentionCubit;
  bool _didApplyUserLanguage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize attention service with user ID
    _attentionCubit = context.read<AttentionCubit>();
    _attentionCubit.attentionService.initialize(widget.currentUser.userID);
    // Start listening to attention state
    _attentionCubit.startListening();
    _attentionCubit.refreshOnce();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _attentionCubit.refreshOnce();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didApplyUserLanguage) return;
    _didApplyUserLanguage = true;
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
    WidgetsBinding.instance.removeObserver(this);
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
  final MapExplorerNavigationService _mapExplorerNavigationService =
      const MapExplorerNavigationService();

  bool _showProfessionalFeatures = false;
  bool _showPremiumFeatures = false;
  bool _accountExpanded = false;
  bool _browseExpanded = false;
  bool _managementExpanded = false;
  bool _shoppingExpanded = false;
  bool _advertisingExpanded = false;
  bool _analyticsExpanded = false;
  bool _supportExpanded = false;

  Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    final adjusted = (hsl.lightness + delta).clamp(0.0, 1.0).toDouble();
    return hsl.withLightness(adjusted).toColor();
  }

  String _drawerSectionPrefKey(String section) =>
      'drawer_section_${widget.user.userID}_$section';

  Future<void> _loadDrawerSectionState() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    setState(() {
      _accountExpanded =
          prefs.getBool(_drawerSectionPrefKey('account')) ?? false;
      _browseExpanded = prefs.getBool(_drawerSectionPrefKey('browse')) ?? false;
      _managementExpanded =
          prefs.getBool(_drawerSectionPrefKey('management')) ?? false;
      _shoppingExpanded =
          prefs.getBool(_drawerSectionPrefKey('shopping')) ?? false;
      _advertisingExpanded =
          prefs.getBool(_drawerSectionPrefKey('advertising')) ?? false;
      _analyticsExpanded =
          prefs.getBool(_drawerSectionPrefKey('analytics')) ?? false;
      _supportExpanded =
          prefs.getBool(_drawerSectionPrefKey('support')) ?? false;
    });
  }

  Future<void> _saveDrawerSectionState(String section, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_drawerSectionPrefKey(section), value);
  }

  void _toggleDrawerSection(String section) {
    bool updatedValue = false;

    setState(() {
      switch (section) {
        case 'account':
          _accountExpanded = !_accountExpanded;
          updatedValue = _accountExpanded;
          break;
        case 'browse':
          _browseExpanded = !_browseExpanded;
          updatedValue = _browseExpanded;
          break;
        case 'management':
          _managementExpanded = !_managementExpanded;
          updatedValue = _managementExpanded;
          break;
        case 'shopping':
          _shoppingExpanded = !_shoppingExpanded;
          updatedValue = _shoppingExpanded;
          break;
        case 'advertising':
          _advertisingExpanded = !_advertisingExpanded;
          updatedValue = _advertisingExpanded;
          break;
        case 'analytics':
          _analyticsExpanded = !_analyticsExpanded;
          updatedValue = _analyticsExpanded;
          break;
        case 'support':
          _supportExpanded = !_supportExpanded;
          updatedValue = _supportExpanded;
          break;
      }
    });

    _saveDrawerSectionState(section, updatedValue);
  }

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

    _loadDrawerSectionState();
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

  Future<void> _showCreateOptions(ListingsUser currentUser) async {
    final isDark = isDarkMode(context);
    final primaryColor = Color(cfg.colorPrimary);
    final backgroundColor = isDark ? const Color(0xFF11161B) : Colors.white;
    final cardColor = isDark ? const Color(0xFF182028) : const Color(0xFFF7FBFD);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFD9E6EC);
    final titleColor = isDark ? Colors.white : const Color(0xFF16222B);
    final subtitleColor = isDark ? Colors.white70 : const Color(0xFF5E7482);
    final screenHeight = MediaQuery.of(context).size.height;
    final compactSheet = screenHeight < 760;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              compactSheet ? 6 : 12,
              12,
              compactSheet ? 8 : 12,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.35 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -8),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  16,
                  compactSheet ? 10 : 12,
                  16,
                  compactSheet ? 16 : 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: compactSheet ? 42 : 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    SizedBox(height: compactSheet ? 12 : 18),
                    Row(
                      children: [
                        Container(
                          width: compactSheet ? 40 : 44,
                          height: compactSheet ? 40 : 44,
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(isDark ? 0.18 : 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.add_circle_outline_rounded,
                              color: primaryColor, size: compactSheet ? 22 : 24),
                        ),
                        SizedBox(width: compactSheet ? 10 : 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create'.tr(),
                                style: TextStyle(
                                  fontSize: compactSheet ? 20 : 22,
                                  fontWeight: FontWeight.w800,
                                  color: titleColor,
                                ),
                              ),
                              SizedBox(height: compactSheet ? 1 : 2),
                              Text(
                                'Choose what you want to publish next.'.tr(),
                                style: TextStyle(
                                  fontSize: compactSheet ? 12 : 13,
                                  color: subtitleColor,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compactSheet ? 14 : 18),
                    _buildCreateOptionAction(
                      context: sheetContext,
                      title: 'Add Listing'.tr(),
                      subtitle: 'Create a new listing for your business or service.'.tr(),
                      icon: Icons.add_business_outlined,
                      accentColor: primaryColor,
                      cardColor: cardColor,
                      borderColor: borderColor,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      compact: compactSheet,
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
                    SizedBox(height: compactSheet ? 10 : 12),
                    _buildCreateOptionAction(
                      context: sheetContext,
                      title: 'Post Event'.tr(),
                      subtitle: 'Publish an event and drive visibility quickly.'.tr(),
                      icon: Icons.event_outlined,
                      accentColor: const Color(0xFF1C9A77),
                      badgeText: 'PRO',
                      badgeColor: const Color(0xFF1C9A77),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      compact: compactSheet,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openCreateEventScreen(currentUser);
                      },
                    ),
                    SizedBox(height: compactSheet ? 10 : 12),
                    _buildCreateOptionAction(
                      context: sheetContext,
                      title: 'Upload New Ad'.tr(),
                      subtitle: 'Launch a promotion to reach more customers.'.tr(),
                      icon: Icons.campaign_outlined,
                      accentColor: const Color(0xFFE67E22),
                      badgeText: 'BOOST',
                      badgeColor: const Color(0xFFE67E22),
                      cardColor: cardColor,
                      borderColor: borderColor,
                      titleColor: titleColor,
                      subtitleColor: subtitleColor,
                      compact: compactSheet,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateOptionAction({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required Color cardColor,
    required Color borderColor,
    required Color titleColor,
    required Color subtitleColor,
    required VoidCallback onTap,
    bool compact = false,
    String? badgeText,
    Color? badgeColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 14),
            child: Row(
              children: [
                Container(
                  width: compact ? 46 : 52,
                  height: compact ? 46 : 52,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accentColor, size: compact ? 24 : 26),
                ),
                SizedBox(width: compact ? 12 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: compact ? 16 : 18,
                                fontWeight: FontWeight.w700,
                                color: titleColor,
                              ),
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (badgeColor ?? accentColor).withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  color: badgeColor ?? accentColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: compact ? 12 : 13,
                          height: 1.3,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: compact ? 8 : 10),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: compact ? 14 : 16,
                  color: subtitleColor,
                ),
              ],
            ),
          ),
        ),
      ),
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
              final theme = Theme.of(context);
              final appBarBase = theme.appBarTheme.backgroundColor ?? theme.colorScheme.primary;
              final appBarTop = isDark
                  ? _shiftLightness(appBarBase, 0.05)
                  : _shiftLightness(appBarBase, 0.08);
              final appBarBottom = isDark
                  ? _shiftLightness(appBarBase, -0.03)
                  : _shiftLightness(appBarBase, -0.04);

              return Scaffold(
                drawer: _buildModernDrawer(context, currentUser, isDark),
                appBar: AppBar(
                  surfaceTintColor: Colors.transparent,
                  flexibleSpace: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [appBarTop, appBarBottom],
                      ),
                      border: Border(
                        bottom: BorderSide(
                          color: isDark ? Colors.white10 : Colors.black12,
                          width: 0.6,
                        ),
                      ),
                    ),
                  ),
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
                        onPressed: () => _showMapEntryOptions(currentUser),
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

  Future<void> _showMapEntryOptions(ListingsUser currentUser) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Choose Map Experience'.tr(),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.public),
                  title: Text('Caribbean Explorer'.tr()),
                  subtitle: Text('Browse and discover islands across the Caribbean'.tr()),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _mapExplorerNavigationService.openRegionExplorer(
                      context,
                      currentUser: currentUser,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: Text('Spotlight Map'.tr()),
                  subtitle: Text('Explore listings in your current location'.tr()),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    final homeState = homeKey.currentState;
                    if (homeState == null) return;
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
                  },
                ),
              ],
            ),
          ),
        );
      },
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
                  // HOME (standalone)
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

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // ACCOUNT SECTION
                  _drawerSectionLabel(
                    'Account'.tr(),
                    isDark,
                    primaryColorValue,
                    _accountExpanded,
                    () => _toggleDrawerSection('account'),
                  ),
                  if (_accountExpanded) ...[
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
                    title: 'My Brands/Branches'.tr(),
                    icon: Icons.storefront_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, MyBrandsScreen(currentUser: currentUser));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  ],

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // BROWSE SECTION
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final browseBadgeCount = state.attentionState
                              ?.getCountForModule(
                                  AttentionModule.conversations) ??
                          0;
                      return _drawerSectionLabel(
                        'Browse'.tr(),
                        isDark,
                        primaryColorValue,
                        _browseExpanded,
                        () => _toggleDrawerSection('browse'),
                        badgeCount: browseBadgeCount,
                      );
                    },
                  ),
                  if (_browseExpanded) ...[
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
                  ],

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // MANAGEMENT SECTION
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final attentionState = state.attentionState;
                      final managementBadgeCount =
                          (attentionState?.getCountForModule(
                                      AttentionModule.bookingRequests) ??
                                  0) +
                              (attentionState?.getCountForModule(
                                      AttentionModule.orderRequests) ??
                                  0) +
                              (attentionState?.getCountForModule(
                                      AttentionModule.rentals) ??
                                  0);
                      return _drawerSectionLabel(
                        'Management'.tr(),
                        isDark,
                        primaryColorValue,
                        _managementExpanded,
                        () => _toggleDrawerSection('management'),
                        badgeCount: managementBadgeCount,
                      );
                    },
                  ),
                  if (_managementExpanded) ...[
                  _drawerTile(
                    title: 'Activate Chat'.tr(),
                    icon: Icons.chat_rounded,
                    trailing: !isProfessionalUser(currentUser)
                        ? _lockIcon()
                        : _tierBadge('PRO', Colors.blue),
                    onTap: () {
                      Navigator.pop(context);
                      if (isProfessionalUser(currentUser)) {
                        push(
                            context,
                            ChatSettingsScreen(
                                currentUser: currentUser,
                                listingsRepository:
                                    listings_api.listingApiManager));
                      } else {
                        _showUpgradeDialog(
                            context, 'Activate Chat', 'Professional');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Manage Rentals'.tr(),
                    icon: Icons.manage_accounts_rounded,
                    isSelected:
                        _drawerSelection == DrawerSelection.manageRentals,
                    trailing: !isProfessionalUser(currentUser)
                        ? _lockIcon()
                        : _tierBadge('PRO', Colors.blue),
                    onTap: () {
                      if (!isProfessionalUser(currentUser)) {
                        Navigator.pop(context);
                        _showUpgradeDialog(
                            context, 'Manage Rentals', 'Professional');
                        return;
                      }

                      context
                          .read<AttentionCubit>()
                          .markModuleAsSeen(AttentionModule.rentals);
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                            appBarTitle: 'Manage Rentals'.tr(),
                            currentTabIndex: 4,
                            drawerSelection: DrawerSelection.manageRentals,
                            currentWidget: ManageRentalsScreen(
                              currentUser: currentUser,
                              showAppBar: false,
                            ),
                          ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  if (currentUser.isAdmin || currentUser.hasBookingServices)
                    BlocBuilder<AttentionCubit, AttentionState>(
                      builder: (context, state) {
                        final badgeCount = state.attentionState
                                ?.getCountForModule(
                                    AttentionModule.bookingRequests) ??
                            0;
                        return _drawerTile(
                          title: 'Manage Bookings'.tr(),
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
                  if (isPremiumUser(currentUser))
                    BlocBuilder<AttentionCubit, AttentionState>(
                      builder: (context, state) {
                        final badgeCount = state.attentionState
                                ?.getCountForModule(
                                    AttentionModule.orderRequests) ??
                            0;
                        return _drawerTile(
                          title: 'Manage Orders'.tr(),
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
                  ],

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // SHOPPING SECTION
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final attentionState = state.attentionState;
                      final shoppingBadgeCount =
                          (attentionState?.getCountForModule(
                                      AttentionModule.myOrders) ??
                                  0) +
                              (attentionState?.getCountForModule(
                                      AttentionModule.myBookings) ??
                                  0) +
                              (attentionState?.getCountForModule(
                                      AttentionModule.rentals) ??
                                  0);
                      return _drawerSectionLabel(
                        'Shopping'.tr(),
                        isDark,
                        primaryColorValue,
                        _shoppingExpanded,
                        () => _toggleDrawerSection('shopping'),
                        badgeCount: shoppingBadgeCount,
                      );
                    },
                  ),
                  if (_shoppingExpanded) ...[
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
                  BlocBuilder<AttentionCubit, AttentionState>(
                    builder: (context, state) {
                      final badgeCount = state.attentionState
                              ?.getCountForModule(AttentionModule.rentals) ??
                          0;
                      return _drawerTile(
                        title: 'My Rentals'.tr(),
                        icon: Icons.calendar_month_rounded,
                        isSelected:
                            _drawerSelection == DrawerSelection.myRentals,
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
                                appBarTitle: 'My Rentals'.tr(),
                                currentTabIndex: 4,
                                drawerSelection: DrawerSelection.myRentals,
                                currentWidget: MyRentalsScreen(
                                    currentUser: currentUser,
                                    showAppBar: false),
                              ));
                        },
                        isDark: isDark,
                        primaryColor: primaryColorValue,
                      );
                    },
                  ),
                  ],

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // SELLING SECTION
                  _drawerSectionLabel(
                    'Advertising'.tr(),
                    isDark,
                    primaryColorValue,
                    _advertisingExpanded,
                    () => _toggleDrawerSection('advertising'),
                  ),
                  if (_advertisingExpanded) ...[
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
                  ],

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // ANALYTICS SECTION
                  _drawerSectionLabel(
                    'Analytics'.tr(),
                    isDark,
                    primaryColorValue,
                    _analyticsExpanded,
                    () => _toggleDrawerSection('analytics'),
                  ),
                  if (_analyticsExpanded) ...[
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
                            ['premium'].contains(
                                currentUser.subscriptionTier.toLowerCase()))
                        ? _tierBadge('PREMIUM', Colors.purple)
                        : _lockIcon(),
                    onTap: () {
                      if (currentUser.isAdmin ||
                          ['premium'].contains(
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
                  ],

                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider()),
                  // SUPPORT & SUBSCRIPTION SECTION
                  _drawerSectionLabel(
                    'Support & Subscription'.tr(),
                    isDark,
                    primaryColorValue,
                    _supportExpanded,
                    () => _toggleDrawerSection('support'),
                  ),
                  if (_supportExpanded) ...[
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
                  _drawerTile(
                    title: 'Suggestion Box'.tr(),
                    icon: Icons.lightbulb_outline_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, SuggestionBoxScreen(currentUser: currentUser));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Demo Listings'.tr(),
                    icon: Icons.storefront_outlined,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, DemoListingsScreen(currentUser: currentUser));
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
                  ],

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
    final List<Color> headerGradient = isDark
        ? [
            const Color(0xFF0A1A28),
            Color(cfg.colorPrimaryDark),
            const Color(0xFF18435F),
          ]
        : [
            const Color(0xFF1E8FB2),
            primaryColor,
            const Color(0xFF56C1EC),
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: headerGradient,
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

  Widget _drawerSectionLabel(
    String title,
    bool isDark,
    Color primaryColor,
    bool isExpanded,
    VoidCallback onTap,
    {int badgeCount = 0}
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black87,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            if (badgeCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _drawerCountBadge(badgeCount),
              ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: primaryColor,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerCountBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Color(cfg.colorPrimary),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
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
