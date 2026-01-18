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
import 'package:instaflutter/listings/listings_module/add_listing/add_listing_screen.dart';
import 'package:instaflutter/listings/listings_module/categories/categories_screen.dart';
import 'package:instaflutter/listings/listings_module/home/home_screen.dart';
import 'package:instaflutter/listings/listings_module/map_view/map_view_screen.dart';
import 'package:instaflutter/listings/listings_module/search/search_screen.dart';
import 'package:instaflutter/listings/listings_module/my_listings/my_listings_screen.dart';
import 'package:instaflutter/listings/listings_module/booking_services/booking_services_screen.dart';
import 'package:instaflutter/listings/ui/profile/profile/profile_screen.dart';
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
  
  bool _showProfessionalFeatures = true;
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
                                  drawerSelection:
                                      DrawerSelection.conversations,
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
                      selectedItemColor: Color(colorPrimary),
                      items: [
                        BottomNavigationBarItem(
                            icon: const Icon(Icons.home), label: 'Home'.tr()),
                        BottomNavigationBarItem(
                            icon: const Icon(Icons.category),
                            label: 'Categories'.tr()),
                        BottomNavigationBarItem(
                            icon: const Icon(Icons.message),
                            label: 'Conversations'.tr()),
                        BottomNavigationBarItem(
                            icon: const Icon(Icons.search),
                            label: 'Search'.tr()),
                      ],
                    )
                  : null,
              drawer: Platform.isAndroid
                  ? Drawer(
                      child: ListTileTheme(
                        data: ListTileThemeData(
                          style: ListTileStyle.drawer,
                          selectedColor: Color(colorPrimary),
                          iconColor: isDark ? Colors.white : Colors.black87,
                          textColor: isDark ? Colors.white : Colors.black87,
                        ),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            Consumer<ListingsUser>(
                              builder: (context, user, _) {
                                return DrawerHeader(
                                  decoration: BoxDecoration(
                                    color: Color(colorPrimary),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      displayCircleImage(
                                          user.profilePictureURL, 65, false),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          user.fullName(),
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(top: 8.0),
                                        child: Text(
                                          user.email,
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            ListTile(
                              selected:
                                  _drawerSelection == DrawerSelection.home,
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
                              selected: _drawerSelection ==
                                  DrawerSelection.categories,
                              leading: const Icon(Icons.category),
                              title: Text('Categories'.tr()),
                              onTap: () {
                                Navigator.pop(context);
                                context.read<ContainerBloc>().add(
                                      TabSelectedEvent(
                                        appBarTitle: 'Categories'.tr(),
                                        currentTabIndex: 1,
                                        drawerSelection:
                                            DrawerSelection.categories,
                                        currentWidget: CategoriesWrapperWidget(
                                            currentUser: currentUser),
                                      ),
                                    );
                              },
                            ),
                            ListTile(
                              selected: _drawerSelection ==
                                  DrawerSelection.conversations,
                              leading: const Icon(Icons.message),
                              title: Text('Conversations'.tr()),
                              onTap: () {
                                Navigator.pop(context);
                                context.read<ContainerBloc>().add(
                                      TabSelectedEvent(
                                        appBarTitle: 'Conversations'.tr(),
                                        currentTabIndex: 2,
                                        drawerSelection:
                                            DrawerSelection.conversations,
                                        currentWidget:
                                            ConversationsWrapperWidget(
                                                user: currentUser),
                                      ),
                                    );
                              },
                            ),
                            ListTile(
                              selected:
                                  _drawerSelection == DrawerSelection.search,
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
                            ListTile(
                              selected:
                                  _drawerSelection == DrawerSelection.profile,
                              title: Text('Profile'.tr()),
                              leading: const Icon(Icons.account_circle),
                              onTap: () {
                                Navigator.pop(context);
                                context.read<ContainerBloc>().add(
                                      TabSelectedEvent(
                                        appBarTitle: 'Profile'.tr(),
                                        currentTabIndex: 3,
                                        drawerSelection: DrawerSelection.profile,
                                        currentWidget: ProfileScreen(
                                            currentUser: currentUser),
                                      ),
                                    );
                              },
                            ),
                            const Divider(height: 16),
                            
                            // Professional Features Section
                            ExpansionTile(
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
                                        title: Text('Booking Services'.tr()),
                                        leading: const Icon(Icons.room_service, size: 20),
                                        enabled: currentUser.subscriptionTier == 'professional' || 
                                                currentUser.subscriptionTier == 'premium' ||
                                                currentUser.isAdmin,
                                        onTap: currentUser.subscriptionTier == 'professional' || 
                                               currentUser.subscriptionTier == 'premium' ||
                                               currentUser.isAdmin
                                            ? () => _navigateToListingServices(context)
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            // Premium Features Section
                            ExpansionTile(
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
                                      Text(
                                        'Coming soon...'.tr(),
                                        style: TextStyle(
                                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
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
