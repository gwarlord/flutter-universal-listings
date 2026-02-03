import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:instaflutter/core/ui/chat/chat/chat_screen.dart';
import 'package:instaflutter/core/ui/chat/player_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:instaflutter/core/model/channel_data_model.dart';
import 'package:instaflutter/core/ui/loading/loading_cubit.dart';
import 'package:instaflutter/core/ui/theme/theme_cubit.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/ui/auth/api/auth_api_manager.dart';
import 'package:instaflutter/listings/ui/auth/authentication_bloc.dart';
import 'package:instaflutter/listings/ui/auth/launcher/launcher_screen.dart';
import 'package:instaflutter/listings/ui/profile/api/profile_api_manager.dart';
import 'package:instaflutter/main.dart' as entry;
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Added import
import 'package:instaflutter/listings/ui/auth/api/firebase/auth_firebase.dart';

runListings() {
  appName = 'Flutter Universal Listings';
  colorAccent = 0xFFff8e94;
  colorPrimaryDark = 0xFFc61f3c;
  colorPrimary = 0xFFff5a66;
  categoriesCollection = 'categories';
  listingsCollection = 'listings';
  reviewCollection = 'reviews';
  filtersCollection = 'filters';

  googleMapsApiKey = dotenv.env['GOOGLE_API_KEY'] ?? ''; // Updated to use dotenv

  return EasyLocalization(
    supportedLocales: const [Locale('en'), Locale('ar')],
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
  late StreamSubscription tokenStream;
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
        return MaterialApp(
            navigatorKey: entry.navigatorKey, // Use global entry key
            localizationsDelegates: [
              ...context.localizationDelegates,
              FlutterQuillLocalizations.delegate,
            ],
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            themeMode: themeState.themeMode,
        builder: EasyLoading.init(),
        title: appName.tr(),
        theme: ThemeData(
          snackBarTheme: const SnackBarThemeData(contentTextStyle: TextStyle(color: Colors.white)),
          sliderTheme: SliderThemeData(trackShape: CustomTrackShape(), thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5)),
          brightness: Brightness.light,
          textSelectionTheme: TextSelectionThemeData(cursorColor: Color(colorPrimaryDark)),
          primaryColor: Color(colorPrimary),
          colorScheme: ColorScheme.fromSwatch().copyWith(
              primary: Color(colorPrimary),
              secondary: Color(colorAccent),
              surface: Colors.white,
              onSurface: Colors.black,
              brightness: Brightness.light
          ),
          appBarTheme: AppBarTheme(
            centerTitle: true,
            color: Platform.isIOS ? Colors.transparent : Color(colorPrimary),
            elevation: Platform.isIOS ? 0 : null,
            iconTheme: const IconThemeData(color: Colors.white),
            titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.w500),
            systemOverlayStyle: SystemUiOverlayStyle.light,
          ),
        ),
        darkTheme: ThemeData(
          primaryColor: Color(colorPrimary),
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF121212),
          colorScheme: ColorScheme.fromSwatch().copyWith(
            primary: Color(colorPrimary),
            secondary: Color(colorAccent),
            surface: const Color(0xFF1E1E1E),
            onSurface: Colors.white,
            brightness: Brightness.dark,
          ),
          appBarTheme: AppBarTheme( // Removed color property
            centerTitle: true,
            color: Color(colorPrimary), // This line is removed
            titleTextStyle: TextStyle(color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.w500),
            systemOverlayStyle: SystemUiOverlayStyle.light,
            iconTheme: IconThemeData(color: Colors.white), // Added for consistency
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
    tokenStream.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (auth.FirebaseAuth.instance.currentUser != null &&
        BlocProvider.of<AuthenticationBloc>(context).user != null) {
      if (state == AppLifecycleState.paused) {
        tokenStream.pause();
        BlocProvider.of<AuthenticationBloc>(context).user!.active = false;
        profileApiManager.updateCurrentUser(BlocProvider.of<AuthenticationBloc>(context).user!);
      } else if (state == AppLifecycleState.resumed) {
        tokenStream.resume();
        BlocProvider.of<AuthenticationBloc>(context).user!.active = true;
        profileApiManager.updateCurrentUser(BlocProvider.of<AuthenticationBloc>(context).user!);
      }
    }
  }
}

void _handleNotification(Map<String, dynamic> data, GlobalKey<NavigatorState> navigatorKey, BuildContext context) async {
  try {
    String? channelID = data['channelID'];
    if (channelID == null) return;

    // Get current user from Bloc
    final user = BlocProvider.of<AuthenticationBloc>(navigatorKey.currentContext!).user;
    if (user == null) return;

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
