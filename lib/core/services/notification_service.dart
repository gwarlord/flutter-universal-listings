import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  // Callbacks for notification handling
  Function(RemoteMessage)? onMessageCallback;
  Function(RemoteMessage)? onMessageOpenedCallback;

  Future<void> initialize() async {
    // Handle foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
      
      if (onMessageCallback != null) {
        onMessageCallback!(message);
      }

      // Show local notification when message arrives (optional)
      _showLocalNotification(message);
    });

    // Handle message when app is opened from notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened app: ${message.notification?.title}');
      
      if (onMessageOpenedCallback != null) {
        onMessageOpenedCallback!(message);
      }
    });

    // Check if app was opened by notification
    final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      print('App opened from notification: ${initialMessage.notification?.title}');
      
      if (onMessageOpenedCallback != null) {
        onMessageOpenedCallback!(initialMessage);
      }
    }
  }

  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  Future<void> subscribeTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  Future<void> unsubscribeTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  // Simple local notification display (you can enhance this)
  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      // You can use flutter_local_notifications for a better UX
      print('Local notification: ${notification.title}');
      print('Body: ${notification.body}');
    }
  }

  // Handle notification click
  void setNotificationClickHandler(Function(RemoteMessage) onNotificationClick) {
    onMessageOpenedCallback = onNotificationClick;
  }

  // Handle foreground notification
  void setForegroundMessageHandler(Function(RemoteMessage) onForegroundMessage) {
    onMessageCallback = onForegroundMessage;
  }
}
