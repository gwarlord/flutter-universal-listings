import 'dart:io';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/ui/container/container_bloc.dart';
import 'package:instaflutter/core/ui/chat/conversation/conversations_screen.dart';
import 'package:instaflutter/core/ui/chat/premium_unlock_chat_screen.dart';
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/categories/categories_screen.dart';
import 'package:instaflutter/listings/listings_module/home/home_screen.dart';
import 'package:instaflutter/listings/listings_module/map_view/map_view_screen.dart';
import 'package:instaflutter/listings/listings_module/search/search_screen.dart';
import 'package:instaflutter/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:instaflutter/listings/listings_module/booking_services/booking_services_screen.dart';
import 'package:instaflutter/listings/listings_module/booking/my_bookings_screen.dart';
import 'package:instaflutter/listings/listings_module/booking/booking_management_screen.dart';
import 'package:instaflutter/listings/ui/subscription/paywall_screen.dart';
import 'package:instaflutter/listings/ui/subscription/customer_center_screen.dart';
import 'package:instaflutter/listings/listings_module/analytics/analytics_screen.dart';
import 'package:instaflutter/listings/listings_module/analytics/advanced_analytics_screen.dart';
import 'package:instaflutter/listings/listings_module/chat_settings/chat_settings_screen.dart';
import 'package:instaflutter/listings/ui/profile/profile/profile_screen.dart';
import 'package:instaflutter/listings/listings_module/api/listings_api_manager.dart';
import 'package:provider/provider.dart';

enum DrawerSelection { home, conversations, categories, search, profile }

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
  late ListingsUser currentUser;
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
    currentUser = widget.user;
    _currentWidget = HomeWrapperWidget(
      currentUser: currentUser,
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
    push(context, BookingServicesWrapperWidget(currentUser: currentUser));
  }

  void _showPremiumUnlockDialog(BuildContext context, String featureName, String description) {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.lock, color: Color(colorPrimary)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                featureName,
                style: TextStyle(color: dark ? Colors.white : Colors.black),
              ),
            ),
          ],
        ),
        content: Text(
          description,
          style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel'.tr(),
              style: TextStyle(color: dark ? Colors.white70 : Colors.black87),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(colorPrimary),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaywallScreen(
                    currentUser: currentUser,
                  ),
                ),
              );
              if (result == true) {
                setState(() {
                  _selectedTapIndex = 2;
                });
              }
            },
            child: Text('Upgrade to Premium'.tr()),
          ),
        ],
      ),
    );
  }

  void _showUpgradeDialog(BuildContext context, String featureName, String requiredTier) {
    final dark = isDarkMode(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dark ? Colors.grey[900] : Colors.white,
        title: Row(
          children: [
            Icon(Icons.lock, color: Color(colorPrimary)),
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
              backgroundColor: Color(colorPrimary),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              // Open RevenueCat Paywall
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PaywallScreen(
                    currentUser: currentUser,
                  ),
                ),
              );
              
              // If user successfully subscribed, refresh the UI
              if (result == true) {
                // Subscription successful - could refresh user data here
                print('🎉 User successfully subscribed!');
              }
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
      child: ChangeNotifierProvider<ListingsUser>.value(
        value: currentUser,
        child: BlocConsumer<ContainerBloc, ContainerState>(
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
            Widget sectionLabel(String title) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 0.2,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                );
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
                            // Direct Messaging
                            context.read<ContainerBloc>().add(TabSelectedEvent(
                                  appBarTitle: 'Chats'.tr(),
                                  currentTabIndex: 2,
                                  drawerSelection:
                                      DrawerSelection.conversations,
                                  currentWidget: ConversationsWrapperWidget(user: currentUser),
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
                      selectedItemColor: Color(colorPrimary),
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
              drawer: Platform.isAndroid
                  ? SafeArea(
                      child: Drawer(
                        child: ListTileTheme(
                          data: ListTileThemeData(
                            style: ListTileStyle.drawer,
                            dense: true,
                            selectedColor: Color(colorPrimary),
                            iconColor: isDark ? Colors.white : Colors.black87,
                            textColor: isDark ? Colors.white : Colors.black87,
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Consumer<ListingsUser>(
                                  builder: (context, user, _) {
                                    return DrawerHeader(
                                      decoration: BoxDecoration(
                                        color: Color(colorPrimary),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          displayCircleImage(
                                              user.profilePictureURL, 50, false),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4.0),
                                            child: Text(
                                              user.fullName(),
                                              style: const TextStyle(color: Colors.white),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2.0),
                                            child: Text(
                                              user.email,
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: 8),
                                sectionLabel('Browse'.tr()),
                                ListTile(
                                  selected: _drawerSelection == DrawerSelection.home,
                                  title: Text('Home'.tr()),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.read<ContainerBloc>().add(
                                          TabSelectedEvent(
                                            appBarTitle: 'Home'.tr(),
                                            currentTabIndex: 0,
                                            drawerSelection: DrawerSelection.home,
                                            currentWidget: HomeWrapperWidget(
                                              homeKey: homeKey,
                                              currentUser: currentUser,
                                            ),
                                          ),
                                        );
                                  },
                                  leading: const Icon(Icons.home),
                                ),
                                ListTile(
                                  selected: _drawerSelection == DrawerSelection.categories,
                                  leading: const Icon(Icons.category),
                                  title: Text('Categories'.tr()),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.read<ContainerBloc>().add(
                                          TabSelectedEvent(
                                            appBarTitle: 'Categories'.tr(),
                                            currentTabIndex: 1,
                                            drawerSelection: DrawerSelection.categories,
                                            currentWidget: CategoriesWrapperWidget(
                                                currentUser: currentUser),
                                          ),
                                        );
                                  },
                                ),
                                ListTile(
                                  selected: _drawerSelection == DrawerSelection.conversations,
                                  leading: const Icon(Icons.message),
                                  title: Text('Conversations'.tr()),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.read<ContainerBloc>().add(
                                          TabSelectedEvent(
                                            appBarTitle: 'Conversations'.tr(),
                                            currentTabIndex: 2,
                                            drawerSelection: DrawerSelection.conversations,
                                            currentWidget: ConversationsWrapperWidget(user: currentUser),
                                          ),
                                        );
                                  },
                                ),
                                ListTile(
                                  selected: _drawerSelection == DrawerSelection.search,
                                  title: Text('Search'.tr()),
                                  leading: const Icon(Icons.search),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.read<ContainerBloc>().add(
                                          TabSelectedEvent(
                                            appBarTitle: 'Search'.tr(),
                                            currentTabIndex: 3,
                                            drawerSelection: DrawerSelection.search,
                                            currentWidget: SearchWrapperWidget(
                                                currentUser: currentUser),
                                          ),
                                        );
                                  },
                                ),
                                const Divider(height: 16),
                                sectionLabel('Account'.tr()),
                                ListTile(
                                  selected: _drawerSelection == DrawerSelection.profile,
                                  title: Text('Profile'.tr()),
                                  leading: const Icon(Icons.account_circle),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.read<ContainerBloc>().add(
                                          TabSelectedEvent(
                                            appBarTitle: 'Profile'.tr(),
                                            currentTabIndex: 3,
                                            drawerSelection: DrawerSelection.profile,
                                            currentWidget: ProfileScreen(currentUser: currentUser),
                                          ),
                                        );
                                  },
                                ),
                                const Divider(height: 16),
                                sectionLabel('Your Activity'.tr()),
                                ListTile(
                                  title: Text('My Listings'.tr()),
                                  leading: Image.asset(
                                    'assets/images/listings_welcome_image.png',
                                    height: 22,
                                    width: 22,
                                    color: Color(colorPrimary),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    push(
                                      context,
                                      MyListingsWrapperWidget(currentUser: currentUser),
                                    );
                                  },
                                ),
                                ListTile(
                                  title: Text('My Bookings'.tr()),
                                  leading: Icon(
                                    Icons.calendar_month,
                                    color: Color(colorPrimary),
                                  ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    push(
                                      context,
                                      MyBookingsWrapperWidget(currentUser: currentUser),
                                    );
                                  },
                                ),
                                if (currentUser.isAdmin ||
                                    const ['professional', 'premium']
                                        .contains(currentUser.subscriptionTier.toLowerCase()))
                                  ListTile(
                                    title: Text('Booking Requests'.tr()),
                                    leading: const Icon(Icons.event_note),
                                    onTap: () {
                                      Navigator.pop(context);
                                      push(
                                        context,
                                        BookingManagementWrapperWidget(currentUser: currentUser),
                                      );
                                    },
                                  ),
                                if (currentUser.subscriptionTier.toLowerCase() != 'free')
                                  ListTile(
                                    title: Text('Manage Subscription'.tr()),
                                    leading: const Icon(Icons.card_membership),
                                    onTap: () {
                                      Navigator.pop(context);
                                      push(
                                        context,
                                        CustomerCenterScreen(currentUser: currentUser),
                                      );
                                    },
                                  ),
                                const Divider(height: 16),
                                sectionLabel('Upgrades'.tr()),
                                ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                                  title: Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.amber, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Professional'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  initiallyExpanded: _showProfessionalFeatures,
                                  onExpansionChanged: (expanded) {
                                    setState(() => _showProfessionalFeatures = expanded);
                                  },
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ListTile(
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Text('Booking Services'.tr()),
                                                if (!currentUser.hasBookingServices) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                                                ],
                                              ],
                                            ),
                                            leading: const Icon(Icons.room_service, size: 20),
                                            trailing: !currentUser.hasBookingServices
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'PRO'.tr(),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                            onTap: () {
                                              if (currentUser.hasBookingServices) {
                                                _navigateToListingServices(context);
                                              } else {
                                                Navigator.pop(context);
                                                _showUpgradeDialog(context, 'Booking Services', 'Professional');
                                              }
                                            },
                                          ),
                                          ListTile(
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Text('Analytics'.tr()),
                                                if (!currentUser.hasBookingServices) ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                                                ],
                                              ],
                                            ),
                                            leading: const Icon(Icons.bar_chart, size: 20),
                                            trailing: !currentUser.hasBookingServices
                                                ? Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'PRO'.tr(),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  )
                                                : null,
                                            onTap: () {
                                              if (currentUser.hasBookingServices) {
                                                Navigator.pop(context);
                                                push(context, AnalyticsScreen(currentUser: currentUser));
                                              } else {
                                                Navigator.pop(context);
                                                _showUpgradeDialog(context, 'Analytics', 'Professional');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                                  title: Row(
                                    children: [
                                      Icon(Icons.diamond, color: Colors.purple, size: 20),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Premium'.tr(),
                                        style: const TextStyle(fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  initiallyExpanded: _showPremiumFeatures,
                                  onExpansionChanged: (expanded) {
                                    setState(() => _showPremiumFeatures = expanded);
                                  },
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          ListTile(
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Chat Settings'.tr(),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!currentUser.hasDirectMessaging)
                                                  const SizedBox(width: 8),
                                                if (!currentUser.hasDirectMessaging)
                                                  Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                                              ],
                                            ),
                                            leading: const Icon(Icons.chat, size: 20),
                                            trailing: currentUser.hasDirectMessaging
                                                ? null
                                                : Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple,
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      'PREMIUM'.tr(),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              if (currentUser.hasDirectMessaging) {
                                                // Navigate to chat settings screen for managing listing chat toggles
                                                push(
                                                  context,
                                                  ChatSettingsScreen(
                                                    currentUser: currentUser,
                                                    listingsRepository: listingsApiManager,
                                                  ),
                                                );
                                              } else {
                                                _showUpgradeDialog(context, 'Chat Settings', 'Premium');
                                              }
                                            },
                                          ),
                                          ListTile(
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Advanced Analytics'.tr(),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (!currentUser.isAdmin && !['premium', 'business'].contains(currentUser.subscriptionTier.toLowerCase()))
                                                  const SizedBox(width: 8),
                                                if (!currentUser.isAdmin && !['premium', 'business'].contains(currentUser.subscriptionTier.toLowerCase()))
                                                  Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                                              ],
                                            ),
                                            leading: const Icon(Icons.analytics, size: 20),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.purple,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'PREMIUM'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              if (currentUser.isAdmin || ['premium', 'business'].contains(currentUser.subscriptionTier.toLowerCase())) {
                                                push(context, AdvancedAnalyticsScreen(currentUser: currentUser));
                                              } else {
                                                _showUpgradeDialog(context, 'Advanced Analytics', 'Premium');
                                              }
                                            },
                                          ),
                                          ListTile(
                                            dense: true,
                                            title: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    'Priority Support'.tr(),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Icon(Icons.lock, size: 16, color: Colors.grey[600]),
                                              ],
                                            ),
                                            leading: const Icon(Icons.support_agent, size: 20),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.purple,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'PREMIUM'.tr(),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.pop(context);
                                              _showUpgradeDialog(context, 'Priority Support', 'Premium');
                                            },
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Text(
                                              '...and more premium features!'.tr(),
                                              style: TextStyle(
                                                color: isDark ? Colors.grey[400] : Colors.grey[600],
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              appBar: AppBar(
                leading: Platform.isIOS
                    ? Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: GestureDetector(
                            onTap: () => push(context,
                                ProfileScreen(currentUser: currentUser)),
                            child: displayCircleImage(
                                currentUser.profilePictureURL, 2, false)),
                      )
                    : null,
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
              ),
              body: _currentWidget,
            );
          },
        ),
      ),
    );
  }
}
