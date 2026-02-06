import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:app_links/app_links.dart';
import 'package:instaflutter/listings/main.dart' as listings_app; // Added alias
import 'package:instaflutter/core/utils/helper.dart';

// Global navigator key for navigation without context
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel chatChannel = AndroidNotificationChannel(
  'chat_messages', 
  'Chat Messages', 
  description: 'Notifications for new chat messages.', 
  importance: Importance.max,
);

// Handle Firebase email verification deep links
Future<void> _handleFirebaseEmailVerificationLink(String? link) async {
  if (link == null) return;
  
  try {
    // Extract query parameters
    final uri = Uri.parse(link);
    final mode = uri.queryParameters['mode'];
    final oobCode = uri.queryParameters['oobCode'];
    
    // Check if this is an email verification link
    if (mode == 'verifyEmail' && oobCode != null) {
      print('🔐 Processing Firebase email verification code...');
      // Apply the verification code
      await FirebaseAuth.instance.applyActionCode(oobCode);
      // Refresh the current user
      await FirebaseAuth.instance.currentUser?.reload();
      print('✅ Email verified successfully via deep link!');
      // Show success message
      if (navigatorKey.currentContext != null) {
        showSnackBar(navigatorKey.currentContext!, 'Email verified successfully!'.tr());
      }
    }
  } catch (e) {
    print('❌ Error processing verification link: $e');
    if (navigatorKey.currentContext != null) {
      showSnackBar(navigatorKey.currentContext!, 'Verification failed: $e'.tr());
    }
  }
}

// Show snackbar
void showSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [BACKGROUND] Handling background message: ${message.messageId}');
}

// Show local notification manually
Future<void> _showLocalNotification(RemoteMessage message) async {
  final notification = message.notification;
  final data = message.data;

  // Determine notification channel based on type
  final notificationType = data['type'] ?? 'chat';
  
  String channelId;
  String channelName;
  String channelDescription;
  
  if (notificationType.contains('order')) {
    channelId = 'orders';
    channelName = 'Orders';
    channelDescription = 'Notifications for order updates';
  } else if (notificationType.contains('rental')) {
    channelId = 'rental_bookings';
    channelName = 'Rental Bookings';
    channelDescription = 'Notifications for rental booking updates';
  } else {
    channelId = 'chat_messages';
    channelName = 'Chat Messages';
    channelDescription = 'Notifications for new chat messages';
  }

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  final NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  await flutterLocalNotificationsPlugin.show(
    message.hashCode,
    notification?.title ?? data['title'] ?? 'New Message',
    notification?.body ?? data['body'] ?? 'You received a new message',
    notificationDetails,
    payload: data.containsKey('channelID') ? data['channelID'] : null,
  );
}

void _handleNotificationClick(RemoteMessage message) {
  print('🔔 Notification clicked with data: ${message.data}');
  final notificationType = message.data['type'];
  
  if (notificationType == 'chat' && message.data['channelID'] != null) {
    // Navigation logic handled in listings/main.dart or here
    // Note: We'll need a mechanism to pass this to the UI after app is ready
  } else if (notificationType == 'new_order' || notificationType == 'order_status_changed') {
    // Store order notification data for navigation after app is ready
    print('🛒 Order notification: orderId=${message.data['orderId']}, status=${message.data['status']}');
    // Navigation will be handled by the app once it's ready
  } else if (notificationType == 'new_rental_booking' || 
             notificationType == 'rental_confirmed' || 
             notificationType == 'rental_cancelled' ||
             notificationType == 'rental_started' ||
             notificationType == 'rental_completed') {
    // Store rental booking notification data for navigation after app is ready
    print('🚗 Rental booking notification: bookingId=${message.data['bookingId']}, type=$notificationType');
    // Navigation will be handled by the app once it's ready
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.debug,
  );
  await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);

  // Handle deep links for Firebase email verification
  final appLinks = AppLinks();
  
  // Listen for incoming links while app is running
  appLinks.uriLinkStream.listen((uri) {
    print('🔗 Deep link received: $uri');
    _handleFirebaseEmailVerificationLink(uri.toString());
  }, onError: (err) {
    print('❌ Deep link error: $err');
  });

  // Handle initial link when app is launched from a terminated state
  try {
    final initialUri = await appLinks.getInitialAppLink();
    if (initialUri != null) {
      print('🔗 Initial deep link: $initialUri');
      await _handleFirebaseEmailVerificationLink(initialUri.toString());
    }
  } catch (err) {
    print('❌ Error getting initial link: $err');
  }

  // Initialize local notifications
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  
  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('🔔 Notification tapped: ${response.payload}');
      // Custom payload handling if needed
    },
  );

  // Create Android notification channel
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(chatChannel);

  // Set up FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Handle notification clicks while app is in background or terminated
  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationClick);

  // Check if app was launched from a notification (terminated state)
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationClick(initialMessage);
  }
  
  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('🔔 [FOREGROUND] Got a message whilst in the foreground!');
    // If it's a notification message, don't show local notification manually
    // because Firebase shows it automatically if correctly configured.
    // However, for data-only or specific behavior:
    await _showLocalNotification(message);
  });
  
  // Request permissions
  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('🔔 [FCM] Token: $fcmToken');

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
  
  EasyLocalization.logger.enableBuildModes = [];
  await MobileAds.instance.initialize();

  runApp(listings_app.runListings()); // Called with alias
}
