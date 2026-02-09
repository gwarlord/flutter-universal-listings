import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';

/// Service to manage deal notifications and user preferences
class DealNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initialize notifications (call once at app startup)
  static Future<void> initializeNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  /// Handle notification tap
  static void _handleNotificationResponse(
      NotificationResponse response) {
    // Navigate to deal or saved deals screen based on notification data
    print('Notification clicked: ${response.payload}');
  }

  /// Schedule notification for deal ending soon
  static Future<void> scheduleDealEndingSoonNotification(
    DealAdModel deal,
    String userId,
  ) async {
    try {
      final now = DateTime.now();
      final scheduleTime = deal.expireAt.subtract(const Duration(hours: 24));

      // If notification time is in the past, schedule for 1 minute from now as test
      final finalScheduleTime = scheduleTime.isBefore(now)
          ? now.add(const Duration(minutes: 1))
          : scheduleTime;

      await _notificationsPlugin.zonedSchedule(
        deal.id.hashCode, // Use deal ID as unique notification ID
        'Deal Ending Soon!',
        '${deal.caption} expires in 24 hours',
        tz.TZDateTime.from(finalScheduleTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'deal_notifications',
            'Deal Notifications',
            channelDescription: 'Notifications about expiring deals',
            importance: Importance.high,
            priority: Priority.high,
            enableVibration: true,
            enableLights: true,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default.wav',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: deal.id,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  /// Cancel notification for a deal
  static Future<void> cancelDealNotification(String dealId) async {
    try {
      await _notificationsPlugin.cancel(dealId.hashCode);
    } catch (e) {
      print('Error canceling notification: $e');
    }
  }

  /// Show immediate notification
  static Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _notificationsPlugin.show(
        DateTime.now().hashCode,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'deal_notifications',
            'Deal Notifications',
            channelDescription: 'Notifications about deals',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            sound: 'default.wav',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  /// Check and schedule notifications for all user's saved deals ending soon
  static Future<void> checkAndScheduleEndingSoonNotifications(
    String userId,
  ) async {
    try {
      final dealsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('savedDeals')
          .where('notifyBefore', isEqualTo: true)
          .get();

      for (var doc in dealsSnapshot.docs) {
        final dealId = doc['dealId'] as String;
        try {
          final dealDoc = await FirebaseFirestore.instance
              .collection('deal_ads')
              .doc(dealId)
              .get();

          if (dealDoc.exists) {
            final deal = DealAdModel.fromDoc(dealDoc);
            
            // Check if deal expires within 24 hours
            final now = DateTime.now();
            final in24Hours = now.add(const Duration(hours: 24));
            
            if (deal.expireAt.isAfter(now) && 
                deal.expireAt.isBefore(in24Hours)) {
              await scheduleDealEndingSoonNotification(deal, userId);
            }
          }
        } catch (e) {
          print('Error processing saved deal $dealId: $e');
        }
      }
    } catch (e) {
      print('Error checking saved deals: $e');
    }
  }

  /// Request notification permissions (iOS/Android 13+)
  static Future<bool> requestNotificationPermissions() async {
    try {
      final isAllowed = await _notificationsPlugin
              .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin>()
              ?.requestPermissions(
                alert: true,
                badge: true,
                sound: true,
              ) ??
          false;
      return isAllowed;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }
}

/// Service for managing deal notification preferences
class DealNotificationPreferences {
  final _firestore = FirebaseFirestore.instance;

  /// Get user's notification preferences
  Future<NotificationPreferences> getPreferences(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('dealNotifications')
          .get();

      if (doc.exists) {
        return NotificationPreferences.fromMap(doc.data()!);
      }

      return NotificationPreferences.defaults();
    } catch (e) {
      print('Error getting preferences: $e');
      return NotificationPreferences.defaults();
    }
  }

  /// Update notification preferences
  Future<void> updatePreferences(
    String userId,
    NotificationPreferences preferences,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('dealNotifications')
          .set(preferences.toMap(), SetOptions(merge: true));
    } catch (e) {
      print('Error updating preferences: $e');
      rethrow;
    }
  }

  /// Toggle deal ending alerts
  Future<void> toggleDealEndingAlerts(String userId, bool enabled) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('preferences')
          .doc('dealNotifications')
          .set(
        {'dealEndingAlerts': enabled},
        SetOptions(merge: true),
      );
    } catch (e) {
      print('Error toggling deal ending alerts: $e');
      rethrow;
    }
  }

  /// Stream user's notification preferences
  Stream<NotificationPreferences> streamPreferences(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('preferences')
        .doc('dealNotifications')
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return NotificationPreferences.fromMap(doc.data()!);
      }
      return NotificationPreferences.defaults();
    });
  }
}

/// Model for notification preferences
class NotificationPreferences {
  final bool dealEndingAlerts; // Notify 24h before deal expires
  final bool categoryAlerts; // Notify for new deals in followed categories
  final bool saveDealReminders; // Remind about saved deals
  final int reminderHourBefore; // Hours before expiry to remind (default 24)

  NotificationPreferences({
    required this.dealEndingAlerts,
    required this.categoryAlerts,
    required this.saveDealReminders,
    required this.reminderHourBefore,
  });

  factory NotificationPreferences.defaults() {
    return NotificationPreferences(
      dealEndingAlerts: true,
      categoryAlerts: false,
      saveDealReminders: true,
      reminderHourBefore: 24,
    );
  }

  factory NotificationPreferences.fromMap(Map<String, dynamic> data) {
    return NotificationPreferences(
      dealEndingAlerts: data['dealEndingAlerts'] ?? true,
      categoryAlerts: data['categoryAlerts'] ?? false,
      saveDealReminders: data['saveDealReminders'] ?? true,
      reminderHourBefore: data['reminderHourBefore'] ?? 24,
    );
  }

  Map<String, dynamic> toMap() => {
    'dealEndingAlerts': dealEndingAlerts,
    'categoryAlerts': categoryAlerts,
    'saveDealReminders': saveDealReminders,
    'reminderHourBefore': reminderHourBefore,
  };
}
