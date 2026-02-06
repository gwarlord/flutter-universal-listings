import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:instaflutter/core/ui/chat/conversation/conversations_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/container/container_bloc.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/categories/categories_screen.dart';
import 'package:instaflutter/listings/listings_module/home/home_screen.dart';
import 'package:instaflutter/listings/listings_module/map_view/map_view_screen.dart';
import 'package:instaflutter/listings/listings_module/search/search_screen.dart';
import 'package:instaflutter/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:instaflutter/listings/listings_module/booking_services/booking_services_screen.dart';
import 'package:instaflutter/listings/listings_module/booking/my_bookings_screen.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_management_screen.dart';
import 'package:instaflutter/listings/ui/rentals/rental_orders_hub_screen.dart';
import 'package:instaflutter/listings/ui/subscription/paywall_screen.dart';
import 'package:instaflutter/listings/ui/subscription/customer_center_screen.dart';
import 'package:instaflutter/listings/utils/subscription_helper.dart';
import 'package:instaflutter/screens/store/orders_management_screen.dart';
import 'package:instaflutter/screens/store/customer_orders_screen.dart';
import 'package:instaflutter/listings/listings_module/analytics/analytics_screen.dart';
import 'package:instaflutter/listings/listings_module/analytics/advanced_analytics_screen.dart';
import 'package:instaflutter/listings/listings_module/chat_settings/chat_settings_screen.dart';
import 'package:instaflutter/listings/ui/profile/profile/profile_screen.dart';
import '../deals/deals_promotion_screen.dart';
import '../deals/ad_review_approval_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart' as listings_api; // Corrected import with alias
import 'package:provider/provider.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';

enum DrawerSelection { home, conversations, categories, search, orders, rentalOrders, profile }

class ContainerWrapperWidget extends StatelessWidget {
  final ListingsUser currentUser;

  const ContainerWrapperWidget({super.key, required this.currentUser});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => ContainerBloc(),
        ),
      ],
      child: ContainerScreen(user: currentUser),
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
  }

  void _navigateToListingServices(BuildContext context) {
    Navigator.pop(context); // Close drawer
    final currentUser = context.read<AuthenticationBloc>().state.user ?? widget.user;
    push(context, BookingServicesWrapperWidget(currentUser: currentUser));
  }

  void _showUpgradeDialog(BuildContext context, String featureName, String requiredTier) {
    final dark = isDarkMode(context);
    final currentUser = context.read<AuthenticationBloc>().state.user ?? widget.user;
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
          'This feature requires a $requiredTier subscription. Upgrade now to unlock $featureName and other exclusive features!'.tr(),
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
                  builder: (context) => PaywallScreen(
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
                bottomNavigationBar: Platform.isIOS
                    ? BottomNavigationBar(
                        currentIndex: _selectedTapIndex,
                        onTap: (index) {
                          switch (index) {
                            case 0:
                              context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'Home'.tr(),
                                currentTabIndex: 0,
                                drawerSelection: DrawerSelection.home,
                                currentWidget: HomeWrapperWidget(
                                  currentUser: currentUser,
                                  homeKey: homeKey,
                                ),
                              ));
                              break;
                            case 1:
                              context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'Categories'.tr(),
                                currentTabIndex: 1,
                                drawerSelection: DrawerSelection.categories,
                                currentWidget: CategoriesWrapperWidget(
                                  currentUser: currentUser,
                                ),
                              ));
                              break;
                            case 2:
                              context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'Conversations'.tr(),
                                currentTabIndex: 2,
                                drawerSelection: DrawerSelection.conversations,
                                currentWidget: ConversationsWrapperWidget(
                                  user: currentUser,
                                ),
                              ));
                              break;
                            case 3:
                              context.read<ContainerBloc>().add(TabSelectedEvent(
                                appBarTitle: 'Search'.tr(),
                                currentTabIndex: 3,
                                drawerSelection: DrawerSelection.search,
                                currentWidget: SearchWrapperWidget(
                                    currentUser: currentUser),
                              ));
                              break;
                          }
                        },
                        unselectedItemColor: Colors.grey,
                        selectedItemColor: Color(cfg.colorPrimary),
                        items: [
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.home), label: 'Home'.tr()),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.category),
                              label: 'Categories'.tr()),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.message),
                              label: 'Chats'.tr()),
                          BottomNavigationBarItem(
                              icon: const Icon(Icons.search),
                              label: 'Search'.tr()),
                        ],
                      )
                    : null,
                drawer: _buildModernDrawer(context, currentUser, isDark),
                appBar: AppBar(
                  leadingWidth: 96,
                  leading: SizedBox(
                    width: 96,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Builder(
                          builder: (context) => IconButton(
                            icon: const Icon(Icons.menu),
                            onPressed: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => push(context, ProfileScreen(currentUser: currentUser)),
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8, right: 4),
                            child: CircleAvatar(
                              radius: 18,
                              backgroundImage: currentUser.profilePictureURL.isNotEmpty
                                  ? NetworkImage(currentUser.profilePictureURL)
                                  : null,
                              backgroundColor: Colors.grey[300],
                              child: currentUser.profilePictureURL.isEmpty
                                  ? Icon(Icons.person, color: Colors.grey[700])
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    if (_currentWidget is HomeWrapperWidget)
                      IconButton(
                        tooltip: 'Add Listing'.tr(),
                        icon: const Icon(
                          Icons.add,
                        ),
                        onPressed: () => push(
                            context,
                            AddListingWrappingWidget(currentUser: currentUser)),
                      ),
                    if (_currentWidget is HomeWrapperWidget)
                      IconButton(
                        tooltip: 'Map'.tr(),
                        icon: const Icon(
                          Icons.map,
                        ),
                        onPressed: () => push(
                          context,
                          MapViewScreen(
                            listings: homeKey.currentState?.listings ?? [],
                            fromHome: true,
                            currentUser: currentUser,
                          ),
                        ),
                      ),
                  ],
                  title: Text(
                    _appBarTitle,
                  ),
                  centerTitle: true,
                ),
                body: _currentWidget,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildModernDrawer(BuildContext context, ListingsUser currentUser, bool isDark) {
    final primaryColorValue = Color(cfg.colorPrimary);
    final selectedBgColor = primaryColorValue.withOpacity(0.1);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.85,
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
                        currentWidget: HomeWrapperWidget(homeKey: homeKey, currentUser: currentUser),
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
                        currentWidget: CategoriesWrapperWidget(currentUser: currentUser),
                      ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Conversations'.tr(),
                    icon: Icons.chat_bubble_rounded,
                    isSelected: _drawerSelection == DrawerSelection.conversations,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                        appBarTitle: 'Conversations'.tr(),
                        currentTabIndex: 2,
                        drawerSelection: DrawerSelection.conversations,
                        currentWidget: ConversationsWrapperWidget(user: currentUser),
                      ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
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
                        currentWidget: SearchWrapperWidget(currentUser: currentUser),
                      ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  // SHOPPING SECTION
                  _drawerSectionLabel('Shopping'.tr(), isDark),
                  _drawerTile(
                    title: 'My Orders'.tr(),
                    icon: Icons.shopping_bag_rounded,
                    isSelected: _drawerSelection == DrawerSelection.orders,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                        appBarTitle: 'My Orders'.tr(),
                        currentTabIndex: 4,
                        drawerSelection: DrawerSelection.orders,
                        currentWidget: CustomerOrdersScreen(currentUser: currentUser),
                      ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  if (isPremiumUser(currentUser))
                    _drawerTile(
                      title: 'Order Requests'.tr(),
                      icon: Icons.event_note_rounded,
                      trailing: _tierBadge('PREMIUM', Colors.purple),
                      onTap: () {
                        Navigator.pop(context);
                        push(context, OrdersManagementScreen(currentUser: currentUser));
                      },
                      isDark: isDark,
                      primaryColor: primaryColorValue,
                    ),
                  _drawerTile(
                    title: 'Rentals'.tr(),
                    icon: Icons.calendar_month_rounded,
                    isSelected: _drawerSelection == DrawerSelection.rentalOrders,
                    onTap: () {
                      Navigator.pop(context);
                      context.read<ContainerBloc>().add(TabSelectedEvent(
                        appBarTitle: 'Rentals'.tr(),
                        currentTabIndex: 4,
                        drawerSelection: DrawerSelection.rentalOrders,
                        currentWidget: RentalOrdersHubScreen(
                          currentUser: currentUser,
                          showAppBar: false,
                        ),
                      ));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  // SELLING SECTION
                  _drawerSectionLabel('Selling'.tr(), isDark),
                  _drawerTile(
                    title: 'My Listings'.tr(),
                    icon: Icons.list_alt_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, MyListingsWrapperWidget(currentUser: currentUser));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'My Bookings'.tr(),
                    icon: Icons.calendar_today_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, MyBookingsWrapperWidget(currentUser: currentUser));
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  if (currentUser.isAdmin || const ['professional', 'premium'].contains(currentUser.subscriptionTier.toLowerCase()))
                    _drawerTile(
                      title: 'Booking Requests'.tr(),
                      icon: Icons.event_note_rounded,
                      trailing: _tierBadge('PRO', Colors.blue),
                      onTap: () {
                        Navigator.pop(context);
                        push(context, BookingManagementWrapperWidget(currentUser: currentUser));
                      },
                      isDark: isDark,
                      primaryColor: primaryColorValue,
                    ),
                  _drawerTile(
                    title: 'Activate Booking'.tr(),
                    icon: Icons.room_service_rounded,
                    trailing: !currentUser.hasBookingServices ? _lockIcon() : _tierBadge('PRO', Colors.blue),
                    onTap: () {
                      if (currentUser.hasBookingServices) {
                        _navigateToListingServices(context);
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(context, 'Activate Booking', 'Professional');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Deals & Promotions'.tr(),
                    icon: Icons.local_offer_rounded,
                    onTap: () {
                      Navigator.pop(context);
                      push(context, DealsPromotionScreen());
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  // ANALYTICS SECTION
                  _drawerSectionLabel('Analytics'.tr(), isDark),
                  _drawerTile(
                    title: 'Analytics'.tr(),
                    icon: Icons.bar_chart_rounded,
                    trailing: !currentUser.hasBookingServices ? _lockIcon() : _tierBadge('PRO', Colors.blue),
                    onTap: () {
                      if (currentUser.hasBookingServices) {
                        Navigator.pop(context);
                        push(context, AnalyticsScreen(currentUser: currentUser));
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(context, 'Analytics', 'Professional');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),
                  _drawerTile(
                    title: 'Advanced Analytics'.tr(),
                    icon: Icons.analytics_rounded,
                    trailing: (currentUser.isAdmin || ['premium', 'business'].contains(currentUser.subscriptionTier.toLowerCase())) ? _tierBadge('PREMIUM', Colors.purple) : _lockIcon(),
                    onTap: () {
                      if (currentUser.isAdmin || ['premium', 'business'].contains(currentUser.subscriptionTier.toLowerCase())) {
                        Navigator.pop(context);
                        push(context, AdvancedAnalyticsScreen(currentUser: currentUser));
                      } else {
                        Navigator.pop(context);
                        _showUpgradeDialog(context, 'Advanced Analytics', 'Premium');
                      }
                    },
                    isDark: isDark,
                    primaryColor: primaryColorValue,
                  ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
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
                    trailing: !currentUser.hasDirectMessaging ? _lockIcon() : _tierBadge('PREMIUM', Colors.purple),
                    onTap: () {
                      Navigator.pop(context);
                      if (currentUser.hasDirectMessaging) {
                        push(context, ChatSettingsScreen(currentUser: currentUser, listingsRepository: listings_api.listingApiManager));
                      } else {
                        _showUpgradeDialog(context, 'Activate Chat', 'Premium');
                      }
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
                        push(context, CustomerCenterScreen(currentUser: currentUser));
                      },
                      isDark: isDark,
                      primaryColor: primaryColorValue,
                    ),

                  const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
                  // UPGRADE PLAN CARD
                  if (currentUser.subscriptionTier.toLowerCase() == 'free')
                    _buildUpgradePlanCard(isDark, primaryColorValue, context, currentUser),
                ],
              ),
            ),
          ),

          // Logout at the bottom
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: _drawerTile(
              title: 'Log Out'.tr(),
              icon: Icons.logout_rounded,
              iconColor: Colors.redAccent,
              textColor: Colors.redAccent,
              onTap: () {
                Navigator.pop(context);
                context.read<AuthenticationBloc>().add(LogoutEvent(currentUser));
              },
              isDark: isDark,
              primaryColor: primaryColorValue,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(ListingsUser user, bool isDark, Color primaryColor) {
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
            primaryColor.withBlue(primaryColor.blue + 30).withRed(primaryColor.red + 20),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: displayCircleImage(user.profilePictureURL, 64, false),
          ),
          const SizedBox(height: 16),
          Text(
            user.fullName(),
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  user.email,
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (user.isAdmin || user.subscriptionTier.toLowerCase() != 'free')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    user.isAdmin ? 'ADMIN' : user.subscriptionTier.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
          color: isSelected ? primaryColor : (iconColor ?? (isDark ? Colors.white70 : Colors.black54)),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? primaryColor : (textColor ?? (isDark ? Colors.white : Colors.black87)),
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
        leading: Icon(icon, color: iconColor ?? (isDark ? Colors.white70 : Colors.black54), size: 22),
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
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _lockIcon() {
    return const Icon(Icons.lock_outline_rounded, size: 16, color: Colors.grey);
  }

  Widget _buildUpgradePlanCard(bool isDark, Color primaryColor, BuildContext context, ListingsUser currentUser) {
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
            push(context, PaywallScreen(currentUser: currentUser));
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
