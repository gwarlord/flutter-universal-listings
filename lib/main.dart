import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'chat_messages',
    'Chat Messages',
    channelDescription: 'Notifications for new chat messages.',
    importance: Importance.max,
    priority: Priority.high,
    showWhen: true,
  );

  const NotificationDetails notificationDetails = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(
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
  if (message.data['type'] == 'chat' && message.data['channelID'] != null) {
    // Navigation logic handled in listings/main.dart or here
    // Note: We'll need a mechanism to pass this to the UI after app is ready
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await dotenv.load(fileName: ".env");
  await EasyLocalization.ensureInitialized();
  await Firebase.initializeApp();

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
