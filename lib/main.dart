import 'package:easy_localization/easy_localization.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'package:instaflutter/listings/main.dart';

// Initialize local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('🔔 [BACKGROUND] Handling background message: ${message.messageId}');
  print('🔔 [BACKGROUND] Title: ${message.notification?.title}');
  print('🔔 [BACKGROUND] Body: ${message.notification?.body}');
  print('🔔 [BACKGROUND] Data: ${message.data}');
  
  // Show local notification for background messages
  await _showNotification(message);
}

// Show local notification
Future<void> _showNotification(RemoteMessage message) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'booking_channel',
    'Booking Notifications',
    channelDescription: 'Notifications for booking requests and updates',
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
    message.notification?.title ?? 'New Notification',
    message.notification?.body ?? '',
    notificationDetails,
    payload: message.data.toString(),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    },
  );

  // Create Android notification channel
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'booking_channel',
    'Booking Notifications',
    description: 'Notifications for booking requests and updates',
    importance: Importance.max,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Initialize FCM
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Handle foreground messages
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('🔔 [FOREGROUND] Got a message whilst in the foreground!');
    print('🔔 [FOREGROUND] Message ID: ${message.messageId}');
    print('🔔 [FOREGROUND] Title: ${message.notification?.title}');
    print('🔔 [FOREGROUND] Body: ${message.notification?.body}');
    print('🔔 [FOREGROUND] Data: ${message.data}');
    
    // Show local notification for foreground messages
    await _showNotification(message);
  });
  
  // Request notification permissions (iOS 13+)
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );
  print('🔔 [FCM] Permission status: ${settings.authorizationStatus}');

  // Get FCM token
  String? fcmToken = await FirebaseMessaging.instance.getToken();
  print('🔔 [FCM] Token: $fcmToken');

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);
  EasyLocalization.logger.enableBuildModes = [];
  await MobileAds.instance.initialize();

  runApp(runListings());
}
