import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:caribtap/core/ui/chat/chat/chat_screen.dart';
import 'package:caribtap/core/ui/chat/player_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:caribtap/core/model/channel_data_model.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/core/ui/theme/app_theme.dart';
import 'package:caribtap/core/ui/theme/theme_cubit.dart';
import 'package:caribtap/core/localization/ht_fallback_localizations.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/ui/auth/api/auth_api_manager.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/auth/launcher/launcher_screen.dart';
import 'package:caribtap/listings/ui/profile/api/profile_api_manager.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/main.dart' as entry;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added import
import 'package:caribtap/listings/ui/auth/api/firebase/auth_firebase.dart';
import 'package:caribtap/listings/ui/table_mode/customer_table_mode_screen.dart';
import 'package:caribtap/listings/ui/table_mode/staff_table_sessions_screen.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/services/attention_service.dart';
import 'package:caribtap/listings/ui/attention/attention_cubit.dart';
import 'package:caribtap/listings/listings_module/booking/booking_management_screen.dart';
import 'package:caribtap/listings/location/location_scope_cubit.dart';
import 'package:caribtap/listings/location/location_scope_service.dart';
import 'package:caribtap/core/utils/helper.dart';

runListings() {
  appName = 'Flutter Universal Listings';
  colorAccent = 0xFFC16A26;
  colorPrimaryDark = 0xFF375872;
  colorPrimary = 0xFF2A9EB8;
  categoriesCollection = 'categories';
  listingsCollection = 'listings';
  reviewCollection = 'reviews';
  filtersCollection = 'filters';

  googleMapsApiKey = placesApiKey;

  return EasyLocalization(
    supportedLocales: const [
      Locale('en'), 
      Locale('es'), 
      Locale('fr'), 
      Locale('nl'), 
      Locale('ht')
    ],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    useFallbackTranslations: true,
    useOnlyLangCode: true,
    child: MultiRepositoryProvider(
      providers: [
        BlocProvider(
            create: (_) =>
                AuthenticationBloc(authenticationRepository: authApiManager)),
        BlocProvider(create: (_) => LoadingCubit()),
        BlocProvider(create: (_) => ThemeCubit()),
        // Attention Cubit for badges/dots
        BlocProvider(
          create: (_) => AttentionCubit(
            attentionService: AttentionService(),
          ),
        ),
        // Location Scope Cubit for managing geographic filtering
        BlocProvider(
          create: (_) {
            final service = LocationScopeService();
            service.init(); // Initialize SharedPreferences
            return LocationScopeCubit(
              service: service,
              userId: null, // Will be set after authentication
            );
          },
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<String>? tokenStream;
  bool _initialized = false;
  bool _error = false;

  initializeFlutterFire() async {
    try {
      // Use the entry-level navigatorKey
      final navKey = entry.navigatorKey;

      RemoteMessage? initialMessage =
          await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        if (!mounted) return;
        _handleNotification(initialMessage.data, navKey, context);
      }
      FirebaseMessaging.onMessageOpenedApp
          .listen((RemoteMessage? remoteMessage) {
        if (remoteMessage != null) {
          _handleNotification(remoteMessage.data, navKey, context);
        }
      });

      tokenStream = FirebaseMessaging.instance.onTokenRefresh.listen((event) {
        if (BlocProvider.of<AuthenticationBloc>(context).user != null) {
          BlocProvider.of<AuthenticationBloc>(context).user!.pushToken = event;
          profileApiManager.updateCurrentUser(
              BlocProvider.of<AuthenticationBloc>(context).user!);
        }
      });

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = true;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
        SystemUiOverlayStyle(statusBarColor: Color(colorPrimaryDark)));
    initializeFlutterFire();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        color: Colors.white,
        child: const Center(
            child: Column(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 25),
            SizedBox(height: 16),
            Text('Failed to initialise firebase!', style: TextStyle(color: Colors.red, fontSize: 25)),
          ],
        )),
      );
    }

    if (!_initialized) {
      return Container(
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator.adaptive()),
      );
    }

    return BlocBuilder<ThemeCubit, ThemeState>(
      builder: (context, themeState) {
        final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        final appPrimary = Color(colorPrimary);
        final appAccent = Color(colorAccent);
        return MaterialApp(
            navigatorKey: entry.navigatorKey, // Use global entry key
          scaffoldMessengerKey: appScaffoldMessengerKey,
            localizationsDelegates: [
              ...context.localizationDelegates,
              FlutterQuillLocalizations.delegate,
              const HtMaterialLocalizationsDelegate(),
              const HtCupertinoLocalizationsDelegate(),
              const HtFlutterQuillLocalizationsDelegate(),
            ],
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            themeMode: themeState.themeMode,
        builder: EasyLoading.init(),
        title: appName.tr(),
        theme: AppTheme.light(
          primary: appPrimary,
          accent: appAccent,
          isIos: isIos,
        ).copyWith(
          sliderTheme: SliderThemeData(
            trackShape: CustomTrackShape(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
          ),
          textSelectionTheme: TextSelectionThemeData(
            cursorColor: Color(colorPrimaryDark),
          ),
          appBarTheme: AppTheme.light(
            primary: appPrimary,
            accent: appAccent,
            isIos: isIos,
          ).appBarTheme.copyWith(
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
        ),
        darkTheme: AppTheme.dark(
          primary: appPrimary,
          accent: appAccent,
        ).copyWith(
          appBarTheme: AppTheme.dark(
            primary: appPrimary,
            accent: appAccent,
          ).appBarTheme.copyWith(
                systemOverlayStyle: SystemUiOverlayStyle.light,
              ),
        ),
        debugShowCheckedModeBanner: false,
            color: Color(colorPrimary),
            home: const LauncherScreen());
      },
    );
  }

  @override
  void dispose() {
    tokenStream?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (auth.FirebaseAuth.instance.currentUser != null &&
        BlocProvider.of<AuthenticationBloc>(context).user != null) {
      if (state == AppLifecycleState.paused) {
        tokenStream?.pause();
        BlocProvider.of<AuthenticationBloc>(context).user!.active = false;
        profileApiManager.updateCurrentUser(BlocProvider.of<AuthenticationBloc>(context).user!);
      } else if (state == AppLifecycleState.resumed) {
        tokenStream?.resume();
        BlocProvider.of<AuthenticationBloc>(context).user!.active = true;
        profileApiManager.updateCurrentUser(BlocProvider.of<AuthenticationBloc>(context).user!);
      }
    }
  }

  @override
  void didHaveMemoryPressure() {
    painting.imageCache.clear();
    painting.imageCache.clearLiveImages();
    print('⚠️ iOS memory pressure detected: cleared Flutter image cache.');
    super.didHaveMemoryPressure();
  }
}

void _handleNotification(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey, BuildContext context) async {
  try {
    final navContext = navigatorKey.currentContext;
    if (navContext == null) {
      print('⚠️ Notification received before navigator context is ready; skipping immediate handling.');
      return;
    }

    // Get current user from Bloc
    final user = BlocProvider.of<AuthenticationBloc>(navContext).user;
    if (user == null) return;

    // Handle table_session notifications
    if (data['type'] == 'table_session') {
      final sessionId = data['sessionId'];
      final listingId = data['listingId'];
      final scope = data['scope']; // LISTING_TABLE_MODE
      
      if (sessionId == null || listingId == null) return;

      print('🔔 Table session notification: sessionId=$sessionId, listingId=$listingId, scope=$scope');

      showDialog(
        context: navContext,
        builder: (context) => AlertDialog(
          title: Text(data['title'] ?? 'Table Notification'),
          content: Text(data['body'] ?? ''),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                
                // Fetch listing to navigate
                final listing = await listingApiManager.getListing(listingID: listingId);
                if (listing == null) return;
                
                // Determine if user is staff (owner for now)
                final isStaff = listing.authorID == user.userID;

                if (isStaff) {
                  // Navigate to staff session dashboard
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => StaffTableSessionsScreen(
                        listing: listing,
                        currentUser: user,
                      ),
                    ),
                  );
                } else {
                  // Navigate to customer table mode screen
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => CustomerTableModeScreen(
                        listing: listing,
                        currentUser: user,
                      ),
                    ),
                  );
                }
              },
              child: const Text('View'),
            ),
          ],
        ),
      );
      return;
    }

    // Handle booking notifications
    if (data['type'] == 'new_booking' || data['type'] == 'booking_status_changed') {
      debugPrint('🔔 Booking notification: ${data['bookingNumber']} - ${data['status']}');
      
      try {
        // Navigate to booking management screen
        navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (_) => BookingManagementScreen(
              currentUser: user,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error navigating to booking screen: $e');
      }
      return;
    }

    // Handle chat notifications (existing logic)
    String? channelID = data['channelID'];
    if (channelID == null) return;

    // Fetch channel details to populate the screen
    final channelSnap = await FirebaseFirestore.instance.collection('channels').doc(channelID).get();
    if (!channelSnap.exists) return;

    final channelData = ChannelDataModel.fromJson(channelSnap.data()!, user.userID);

    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => ChatWrapperWidget(
          channelDataModel: channelData,
          currentUser: user,
          colorPrimary: Color(colorPrimary),
          colorAccent: Color(colorAccent),
        ),
      ),
    );
  } catch (e, s) {
    debugPrint('MyAppState._handleNotification $e $s');
  }
}
