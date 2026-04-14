import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' as painting;
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caribtap/core/config/app_env.dart';
import 'package:caribtap/listings/main.dart' as listings_app; // Added alias
import 'package:caribtap/listings/services/deep_link_service.dart';
import 'package:caribtap/listings/services/deal_notification_service.dart';
import 'package:caribtap/core/utils/helper.dart' show appScaffoldMessengerKey;

const String _startupStageKey = 'startup_stage';
const String _startupStageAtKey = 'startup_stage_at';
const String _startupErrorKey = 'startup_error';
bool _startupPersistenceReady = false;
bool _loggedWebImageNoiseSuppression = false;

bool _isIgnorableWebStorageImageError(Object error) {
  if (!kIsWeb) return false;
  final text = error.toString();
  return text.contains('HTTP request failed, statusCode: 0') &&
      text.contains('firebasestorage.googleapis.com');
}

bool _isIgnorableWebTrackpadPointerAssertion(Object error) {
  if (!kIsWeb) return false;
  final text = error.toString();
  return text.contains('PointerDeviceKind.trackpad') &&
      text.contains('events.dart') &&
      text.contains('Assertion failed');
}

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyD_qHAIpnPymA4X_h0BtJYqxAwk1UG_mTg',
  authDomain: 'caribtap.firebaseapp.com',
  projectId: 'caribtap',
  storageBucket: 'caribtap.firebasestorage.app',
  messagingSenderId: '17296052844',
  appId: '1:17296052844:web:e4f14e33763ac26931fe49',
  measurementId: 'G-GCEVP9HB0B',
);

Future<void> _initializeFirebaseApp() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  if (kIsWeb) {
    await Firebase.initializeApp(options: _webFirebaseOptions);
    return;
  }

  await Firebase.initializeApp();
}

Future<void> _setStartupStage(String stage) async {
  if (!_startupPersistenceReady) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startupStageKey, stage);
    await prefs.setString(_startupStageAtKey, DateTime.now().toIso8601String());
  } catch (e) {
    print('⚠️ Failed to persist startup stage: $e');
  }
}

Future<void> _setStartupError(String source, Object error, [StackTrace? stack]) async {
  if (!_startupPersistenceReady) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    final stackText = stack?.toString() ?? '';
    final payload = '$source | $error${stackText.isNotEmpty ? '\n$stackText' : ''}';
    await prefs.setString(_startupErrorKey, payload);
  } catch (e) {
    print('⚠️ Failed to persist startup error: $e');
  }
}

Future<void> _printPreviousStartupBreadcrumb() async {
  if (!_startupPersistenceReady) return;

  final prefs = await SharedPreferences.getInstance();
  final stage = prefs.getString(_startupStageKey);
  final at = prefs.getString(_startupStageAtKey);
  final lastError = prefs.getString(_startupErrorKey);

  if (stage != null) {
    print('🧭 Previous startup stage: $stage${at != null ? ' at $at' : ''}');
  }

  if (lastError != null && lastError.isNotEmpty) {
    print('🧨 Previous startup error:\n$lastError');
  }
}

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

const AndroidNotificationChannel ordersChannel = AndroidNotificationChannel(
  'orders',
  'Orders',
  description: 'Notifications for order updates.',
  importance: Importance.max,
);

const AndroidNotificationChannel bookingsChannel = AndroidNotificationChannel(
  'bookings',
  'Bookings',
  description: 'Notifications for booking updates.',
  importance: Importance.max,
);

const AndroidNotificationChannel rentalBookingsChannel = AndroidNotificationChannel(
  'rental_bookings',
  'Rental Bookings',
  description: 'Notifications for rental booking updates.',
  importance: Importance.max,
);

const AndroidNotificationChannel bookingRemindersChannel = AndroidNotificationChannel(
  'booking_reminders',
  'Booking Reminders',
  description: 'Reminders for upcoming bookings.',
  importance: Importance.max,
);

final Set<String> _processedFirebaseActionCodes = <String>{};

Map<String, String?> _extractFirebaseActionParams(Uri uri) {
  String? mode = uri.queryParameters['mode'];
  String? oobCode = uri.queryParameters['oobCode'];

  if (mode != null && oobCode != null && oobCode.isNotEmpty) {
    return {'mode': mode, 'oobCode': oobCode};
  }

  final nestedLink = uri.queryParameters['link'] ??
      uri.queryParameters['continueUrl'] ??
      uri.queryParameters['deep_link_id'];

  if (nestedLink != null && nestedLink.isNotEmpty) {
    try {
      final nestedUri = Uri.parse(Uri.decodeFull(nestedLink));
      mode = nestedUri.queryParameters['mode'];
      oobCode = nestedUri.queryParameters['oobCode'];
      if (mode != null && oobCode != null && oobCode.isNotEmpty) {
        return {'mode': mode, 'oobCode': oobCode};
      }
    } catch (_) {
      // Keep fallback empty if nested URL cannot be parsed.
    }
  }

  return {'mode': mode, 'oobCode': oobCode};
}


// Handle Firebase auth action deep links (email verification + password reset)
Future<void> _handleFirebaseAuthActionLink(String? link) async {
  if (link == null) return;
  
  try {
    // Extract query parameters
    final uri = Uri.parse(link);
    final actionParams = _extractFirebaseActionParams(uri);
    final mode = actionParams['mode'];
    final oobCode = actionParams['oobCode'];
    if (oobCode == null || oobCode.isEmpty) return;

    // Some devices deliver the same deep link twice (initial + stream).
    if (_processedFirebaseActionCodes.contains(oobCode)) {
      print('ℹ️ Firebase action code already processed, skipping duplicate: $mode');
      return;
    }
    
    if (mode == 'verifyEmail') {
      print('🔐 Processing Firebase email verification code...');
      // Apply the verification code
      await FirebaseAuth.instance.applyActionCode(oobCode);
      _processedFirebaseActionCodes.add(oobCode);
      // Refresh the current user
      await FirebaseAuth.instance.currentUser?.reload();
      print('✅ Email verified successfully via deep link!');
      // Show success message
      if (navigatorKey.currentContext != null) {
        showSnackBar(navigatorKey.currentContext!, 'Email verified successfully!'.tr());
      }
    } else if (mode == 'resetPassword') {
      print('🔐 Processing Firebase reset password code...');
      final accountEmail =
          await FirebaseAuth.instance.verifyPasswordResetCode(oobCode);

      final context = navigatorKey.currentContext;
      if (context == null) {
        print('⚠️ Navigator context unavailable for password reset dialog.');
        return;
      }

      final newPasswordController = TextEditingController();
      final confirmPasswordController = TextEditingController();
      String? validationError;
      bool submitting = false;

      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text('Reset Password'.tr()),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create a new password for'.tr(args: [accountEmail]),
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: newPasswordController,
                      obscureText: true,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'New Password'.tr(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Confirm Password'.tr(),
                      ),
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        validationError!,
                        style: TextStyle(
                          color: Theme.of(dialogContext).colorScheme.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.of(dialogContext).pop(),
                    child: Text('Cancel'.tr()),
                  ),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final password = newPasswordController.text.trim();
                            final confirm = confirmPasswordController.text.trim();

                            if (password.length < 6) {
                              setDialogState(() {
                                validationError =
                                    'Password must be at least 6 characters.'.tr();
                              });
                              return;
                            }

                            if (password != confirm) {
                              setDialogState(() {
                                validationError = 'Passwords do not match.'.tr();
                              });
                              return;
                            }

                            setDialogState(() {
                              validationError = null;
                              submitting = true;
                            });

                            try {
                              await FirebaseAuth.instance.confirmPasswordReset(
                                code: oobCode,
                                newPassword: password,
                              );
                              _processedFirebaseActionCodes.add(oobCode);

                              if (navigatorKey.currentContext != null) {
                                showSnackBar(
                                  navigatorKey.currentContext!,
                                  'Password has been reset successfully. Please sign in.'.tr(),
                                );
                              }
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop();
                              }
                            } on FirebaseAuthException catch (e) {
                              setDialogState(() {
                                validationError = e.message ??
                                    'Unable to reset password. Please request a new reset link.'.tr();
                                submitting = false;
                              });
                            } catch (_) {
                              setDialogState(() {
                                validationError =
                                    'Unable to reset password. Please request a new reset link.'.tr();
                                submitting = false;
                              });
                            }
                          },
                    child: Text(submitting ? 'Saving...'.tr() : 'Update Password'.tr()),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  } catch (e) {
    print('❌ Error processing auth action link: $e');
    if (navigatorKey.currentContext != null) {
      showSnackBar(
        navigatorKey.currentContext!,
        'This password reset link is invalid, expired, or has already been used. Please request a new one.'.tr(),
      );
    }
  }
}

// Handle listing deep links
Future<void> _handleListingDeepLink(String? link) async {
  if (link == null) return;
  
  try {
    print('🔗 Processing listing deep link: $link');
    
    // Parse the listing ID from the URL
    final listingId = DeepLinkService.parseListingIdFromUrl(link);
    
    if (listingId == null) {
      print('⚠️ No listing ID found in deep link: $link');
      return;
    }
    
    print('📋 Listing ID extracted: $listingId');
    
    // Import needed for navigation
    final deepLinkService = DeepLinkService();
    
    // Fetch the listing by ID
    final listing = await deepLinkService.getListingById(listingId);
    
    if (listing == null) {
      print('❌ Listing not found: $listingId');
      if (navigatorKey.currentContext != null) {
        showSnackBar(
          navigatorKey.currentContext!, 
          'Listing not found or has been removed.'.tr()
        );
      }
      return;
    }
    
    print('✅ Listing found: ${listing.title}');
    
    // Navigate to listing details screen
    // Note: This requires the user to be logged in and the app to be initialized
    // The navigation will be handled after the app is fully loaded
    
    // Store the pending navigation to be handled after app initialization
    _pendingListingId = listingId;
    
  } catch (e) {
    print('❌ Error processing listing deep link: $e');
    if (navigatorKey.currentContext != null) {
      showSnackBar(
        navigatorKey.currentContext!, 
        'Failed to open listing. Please try again.'.tr()
      );
    }
  }
}

// Handle event deep links
Future<void> _handleEventDeepLink(String? link) async {
  if (link == null) return;

  try {
    print('🔗 Processing event deep link: $link');

    final eventId = DeepLinkService.parseEventIdFromUrl(link);
    if (eventId == null) {
      print('⚠️ No event ID found in deep link: $link');
      return;
    }

    print('🎫 Event ID extracted: $eventId');
    _pendingEventId = eventId;
  } catch (e) {
    print('❌ Error processing event deep link: $e');
    if (navigatorKey.currentContext != null) {
      showSnackBar(
        navigatorKey.currentContext!,
        'Failed to open event. Please try again.'.tr(),
      );
    }
  }
}

// Handle listing management deep links
Future<void> _handleListingManageDeepLink(String? link) async {
  if (link == null) return;

  try {
    print('🔗 Processing listing management deep link: $link');

    final listingId = DeepLinkService.parseListingManageIdFromUrl(link);
    if (listingId == null) {
      print('⚠️ No listing ID found in manage deep link: $link');
      return;
    }

    print('📋 Manage listing ID extracted: $listingId');
    _pendingListingManageId = listingId;
  } catch (e) {
    print('❌ Error processing listing manage deep link: $e');
    if (navigatorKey.currentContext != null) {
      showSnackBar(
        navigatorKey.currentContext!,
        'Failed to open listing management. Please try again.'.tr(),
      );
    }
  }
}

// Handle pro doc deep links
Future<void> _handleProDocDeepLink(String? link) async {
  if (link == null) return;

  try {
    print('🔗 Processing pro doc deep link: $link');
    final proDoc = DeepLinkService.parseProDocFromUrl(link);
    if (proDoc == null) {
      print('⚠️ Invalid pro doc link: $link');
      return;
    }

    _pendingProDocType = proDoc.type;
    _pendingProDocToken = proDoc.token;
  } catch (e) {
    print('❌ Error processing pro doc deep link: $e');
    if (navigatorKey.currentContext != null) {
      showSnackBar(
        navigatorKey.currentContext!,
        'Failed to open shared document. Please try again.'.tr(),
      );
    }
  }
}

// Store pending listing navigation
String? _pendingListingId;
String? _pendingEventId;
String? _pendingListingManageId;
String? _pendingProDocType;
String? _pendingProDocToken;

// Get and clear pending listing ID
String? getPendingListingId() {
  final id = _pendingListingId;
  _pendingListingId = null;
  return id;
}

String? getPendingEventId() {
  final id = _pendingEventId;
  _pendingEventId = null;
  return id;
}

String? getPendingListingManageId() {
  final id = _pendingListingManageId;
  _pendingListingManageId = null;
  return id;
}

String? getPendingProDocType() {
  final value = _pendingProDocType;
  _pendingProDocType = null;
  return value;
}

String? getPendingProDocToken() {
  final value = _pendingProDocToken;
  _pendingProDocToken = null;
  return value;
}

// Show snackbar
void showSnackBar(BuildContext context, String message) {
  final rootMessenger = appScaffoldMessengerKey.currentState;
  if (rootMessenger != null) {
    rootMessenger
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return;
  }

  if (!context.mounted) return;
  final localMessenger = ScaffoldMessenger.maybeOf(context);
  if (localMessenger == null) return;

  localMessenger
    ..removeCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

// Update notification badge (deprecated - flutter_app_badger removed)
Future<void> _updateBadge(RemoteMessage message) async {
  // Badge functionality removed due to package discontinuation
}

// Handle background messages
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await _initializeFirebaseApp();
  await _updateBadge(message);
  print('🔔 [BACKGROUND] Handling background message: ${message.messageId}');
  print('🔔 [BACKGROUND] Message data: ${message.data}');
  if (message.notification != null) {
    print('🔔 [BACKGROUND] Message notification: ${message.notification?.title}');
  }
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
  } else if (notificationType == 'new_booking' || notificationType == 'booking_status') {
    channelId = 'bookings';
    channelName = 'Bookings';
    channelDescription = 'Notifications for booking updates';
  } else if (notificationType.contains('rental')) {
    channelId = 'rental_bookings';
    channelName = 'Rental Bookings';
    channelDescription = 'Notifications for rental booking updates';
  } else if (notificationType == 'booking_reminder') {
    channelId = 'booking_reminders';
    channelName = 'Booking Reminders';
    channelDescription = 'Reminders for upcoming bookings';
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
  } else if (notificationType == 'booking_reminder') {
    // Handle booking reminder notification
    print('⏰ Booking reminder notification: bookingId=${message.data['bookingId']}, reminderType=${message.data['reminderType']}');
    // Navigation will be handled by the app once it's ready - navigate to booking detail
  }
}

Future<String?> _getFcmTokenSafely() async {
  final messaging = FirebaseMessaging.instance;

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    print('🔍 [FCM] Fetching APNs token (Dart)...');
    String? apnsToken = await messaging.getAPNSToken();
    int attempts = 0;

    while (apnsToken == null && attempts < 10) {
      print('🔍 [FCM] APNs token is null, retrying (attempt ${attempts + 1})...');
      await Future.delayed(const Duration(seconds: 1));
      apnsToken = await messaging.getAPNSToken();
      attempts++;
    }

    if (apnsToken == null) {
      print('⚠️ [FCM] CRITICAL: APNS token not available after 10 seconds. FCM will NOT work.');
      return null;
    } else {
      print('✅ [FCM] APNS token received (Dart): $apnsToken');
    }
  }

  try {
    print('🔍 [FCM] Requesting FCM token...');
    final token = await messaging.getToken();
    if (token != null) {
      print('✅ [FCM] FCM Token received: $token');
    } else {
      print('⚠️ [FCM] FCM Token is null');
    }
    return token;
  } catch (e) {
    print('⚠️ [FCM] Failed to fetch FCM token: $e');
    return null;
  }
}

Future<void> _persistPushTokenIfPossible(String? token) async {
  if (token == null || token.isEmpty) return;

  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    print('ℹ️ [FCM] Token available, but no signed-in user to persist it for yet.');
    return;
  }

  try {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser.uid)
        .set({
      'pushToken': token,
      'fcmTokens': FieldValue.arrayUnion([token]),
    }, SetOptions(merge: true));
    print('✅ [FCM] pushToken + fcmTokens saved for user: ${currentUser.uid}');

    // Subscribe to global topic so admin broadcasts reach this device
    try {
      await FirebaseMessaging.instance.subscribeToTopic('all_users');
      print('✅ [FCM] Subscribed to topic: all_users');
    } catch (e) {
      print('⚠️ [FCM] Failed to subscribe to all_users topic: $e');
    }
  } catch (e) {
    print('⚠️ [FCM] Failed to persist pushToken: $e');
  }
}

Future<void> _retryFetchAndPersistFcmToken() async {
  final messaging = FirebaseMessaging.instance;

  for (int attempt = 1; attempt <= 15; attempt++) {
    print('🔍 [FCM] Retry attempt $attempt to fetch tokens...');
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final apnsToken = await messaging.getAPNSToken();
      if (apnsToken == null || apnsToken.isEmpty) {
        print('🔍 [FCM] APNs token still null at attempt $attempt');
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }
      print('✅ [FCM] APNs token finally available at attempt $attempt: $apnsToken');
    }

    try {
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        print('✅ [FCM] FCM Token (retry) obtained at attempt $attempt: $token');
        await _persistPushTokenIfPossible(token);
        return;
      }
    } catch (e) {
      print('⚠️ [FCM] Retry token fetch failed at attempt $attempt: $e');
    }

    await Future.delayed(const Duration(seconds: 2));
  }

  print('⚠️ [FCM] CRITICAL: Retry flow could not obtain token after 30 seconds.');
}

void _installGlobalCrashLogging() {
  FlutterError.onError = (FlutterErrorDetails details) {
    if (_isIgnorableWebStorageImageError(details.exception)) {
      if (!_loggedWebImageNoiseSuppression) {
        _loggedWebImageNoiseSuppression = true;
        print('ℹ️ Suppressing repetitive web image fetch errors from Firebase Storage (statusCode: 0).');
      }
      return;
    }

    if (_isIgnorableWebTrackpadPointerAssertion(details.exception)) {
      print('ℹ️ Suppressing Flutter Web trackpad pointer assertion from the framework.');
      return;
    }

    FlutterError.presentError(details);
    print('💥 [FlutterError] ${details.exceptionAsString()}');
    if (details.stack != null) {
      print(details.stack);
    }
    unawaited(_setStartupError(
      'FlutterError',
      details.exception,
      details.stack,
    ));
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (_isIgnorableWebStorageImageError(error)) {
      if (!_loggedWebImageNoiseSuppression) {
        _loggedWebImageNoiseSuppression = true;
        print('ℹ️ Suppressing repetitive web image fetch errors from Firebase Storage (statusCode: 0).');
      }
      return true;
    }

    if (_isIgnorableWebTrackpadPointerAssertion(error)) {
      print('ℹ️ Suppressing Flutter Web trackpad pointer assertion from the framework.');
      return true;
    }

    print('💥 [PlatformDispatcher] $error');
    print(stack);
    unawaited(_setStartupError('PlatformDispatcher', error, stack));
    return false;
  };
}

Future<void> _initializeNotificationsAndMessaging() async {
  print('🚀 [FCM] Initializing Notifications and Messaging...');

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
      print('🔔 [LOCAL] Notification tapped: ${response.payload}');
    },
  );

  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await androidImplementation?.createNotificationChannel(chatChannel);
  await androidImplementation?.createNotificationChannel(ordersChannel);
  await androidImplementation?.createNotificationChannel(bookingsChannel);
  await androidImplementation?.createNotificationChannel(rentalBookingsChannel);
  await androidImplementation?.createNotificationChannel(bookingRemindersChannel);
  await _setStartupStage('local_notifications_ready');

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('🔔 [FCM] onMessageOpenedApp triggered');
    _handleNotificationClick(message);
  });

  print('🔍 [FCM] Checking for Initial Message...');
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    print('🔔 [FCM] Initial Message found: ${initialMessage.messageId}');
    _handleNotificationClick(initialMessage);
  } else {
    print('ℹ️ [FCM] No Initial Message found');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('🔔 [FOREGROUND] Got a message whilst in the foreground!');
    print('🔔 [FOREGROUND] Message ID: ${message.messageId}');
    print('🔔 [FOREGROUND] Data: ${message.data}');
    await _updateBadge(message);

    // iOS already shows alert/sound in foreground via presentation options.
    // Avoid showing a second local notification for the same push payload.
    if (defaultTargetPlatform == TargetPlatform.iOS && message.notification != null) {
      return;
    }

    await _showLocalNotification(message);
  });

  print('🔍 [FCM] Requesting iOS Permissions...');
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
    provisional: false,
  );
  print('🔔 [FCM] iOS authorizationStatus: ${settings.authorizationStatus.name}');

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
    print('🔔 [FCM] APNs token presence in initialization: ${apnsToken != null && apnsToken.isNotEmpty}');
  }

  FirebaseMessaging.instance.onTokenRefresh.listen((token) {
    print('🔄 [FCM] Refreshed token: $token');
    _persistPushTokenIfPossible(token);
  }, onError: (error) {
    print('⚠️ [FCM] Token refresh listener error: $error');
  });

  final fcmToken = await _getFcmTokenSafely();
  if (fcmToken != null && fcmToken.isNotEmpty) {
    print('✅ [FCM] Final Token for persistence: $fcmToken');
    await _persistPushTokenIfPossible(fcmToken);
  } else {
    print('⚠️ [FCM] No FCM token available at end of init logic');
  }

  if ((fcmToken == null || fcmToken.isEmpty) &&
      defaultTargetPlatform == TargetPlatform.iOS) {
    print('🔄 [FCM] Starting retry loop for iOS token...');
    unawaited(_retryFetchAndPersistFcmToken());
  }
  await _setStartupStage('fcm_ready');
}

Future<void> _initializePostLaunchServices() async {
  await _setStartupStage('post_launch_init_start');

  final isIosDebug =
      defaultTargetPlatform == TargetPlatform.iOS && kDebugMode;
  if (isIosDebug) {
    await _initializeNotificationsAndMessaging();
    print('ℹ️ iOS debug lightweight startup enabled: skipping heavy post-launch services.');
    await _setStartupStage('post_launch_init_skipped_ios_debug');
    return;
  }

  await _setStartupStage('app_check_already_initialized');

  try {
    await DealNotificationService.initializeNotifications();
    print('✅ Deal notification service initialized');
    await _setStartupStage('deal_notifications_initialized');
  } catch (e) {
    print('⚠️ Deal notification service initialization error: $e');
    await _setStartupError('DealNotificationService.initializeNotifications', e);
  }

  final appLinks = AppLinks();
  appLinks.uriLinkStream.listen((uri) {
    print('🔗 Deep link received: $uri');
    final url = uri.toString();
    if (DeepLinkService.isProDocDeepLink(url)) {
      _handleProDocDeepLink(url);
    } else if (DeepLinkService.isListingManageDeepLink(url)) {
      _handleListingManageDeepLink(url);
    } else if (DeepLinkService.isEventDeepLink(url)) {
      _handleEventDeepLink(url);
    } else if (DeepLinkService.isListingDeepLink(url)) {
      _handleListingDeepLink(url);
    } else {
      _handleFirebaseAuthActionLink(url);
    }
  }, onError: (err) {
    print('❌ Deep link error: $err');
  });

  try {
    final initialUri = await appLinks.getInitialAppLink();
    if (initialUri != null) {
      print('🔗 Initial deep link: $initialUri');
      final url = initialUri.toString();
      if (DeepLinkService.isProDocDeepLink(url)) {
        await _handleProDocDeepLink(url);
      } else if (DeepLinkService.isListingManageDeepLink(url)) {
        await _handleListingManageDeepLink(url);
      } else if (DeepLinkService.isEventDeepLink(url)) {
        await _handleEventDeepLink(url);
      } else if (DeepLinkService.isListingDeepLink(url)) {
        await _handleListingDeepLink(url);
      } else {
        await _handleFirebaseAuthActionLink(url);
      }
    }
  } catch (err) {
    print('❌ Error getting initial link: $err');
  }

  await _initializeNotificationsAndMessaging();

  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
      overlays: [SystemUiOverlay.bottom, SystemUiOverlay.top]);

  EasyLocalization.logger.enableBuildModes = [];
  if (!kIsWeb) {
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: <String>[
          // Add Android/iOS test device IDs here after first run.
        ],
      ),
    );
    await MobileAds.instance.initialize();
    debugPrint('Mobile Ads initialized.');
    await _setStartupStage('mobile_ads_initialized');
  } else {
    await _setStartupStage('mobile_ads_skipped_web');
  }
  await _setStartupStage('post_launch_init_done');
}

Future<void> _initializeAppCheckEarly() async {
  if (!kIsWeb) {
    try {
      final forceDebugAppCheck =
          AppEnv.appCheckForceDebugProvider;
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      // iOS attestation often fails on local/profile builds; use debug provider unless this is a release build.
      final useDebugProvider =
          forceDebugAppCheck || kDebugMode || (isIos && !kReleaseMode);
      print(
          '🔐 App Check config -> debugMode=$kDebugMode, releaseMode=$kReleaseMode, forceDebug=$forceDebugAppCheck');

      await FirebaseAppCheck.instance.activate(
        androidProvider: useDebugProvider
            ? AndroidProvider.debug
            : AndroidProvider.playIntegrity,
        appleProvider: useDebugProvider
            ? AppleProvider.debug
            : AppleProvider.appAttestWithDeviceCheckFallback,
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      final token = await FirebaseAppCheck.instance.getToken(true);
      print('✅ Firebase App Check activated early');
      if (useDebugProvider) {
        print('🔐 AppCheck token fetched early (debug): $token');
      } else {
        print('🔐 AppCheck token fetched early');
      }
      FirebaseAppCheck.instance.onTokenChange.listen((token) {
        print('🔐 AppCheck Token changed: $token');
      });
      await _setStartupStage('app_check_initialized');
    } catch (e) {
      print('⚠️ Firebase App Check early activation error: $e');
      await _setStartupError('FirebaseAppCheck.activate.early', e);

      final errorText = e.toString().toLowerCase();
      final isIos = defaultTargetPlatform == TargetPlatform.iOS;
      final isAttestationFailure =
          errorText.contains('app attestation failed') ||
          errorText.contains('devicheck') ||
          errorText.contains('exchangeDeviceCheckToken'.toLowerCase()) ||
          errorText.contains('permission_denied');

      // Developer fallback: if iOS attestation fails in non-release builds,
      // retry with debug provider so local testing can continue.
      if (isIos && !kReleaseMode && isAttestationFailure) {
        try {
          print('⚠️ iOS App Check attestation failed; retrying with Apple debug provider for dev build.');
          await FirebaseAppCheck.instance.activate(
            androidProvider: AndroidProvider.debug,
            appleProvider: AppleProvider.debug,
          );
          await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
          final debugToken = await FirebaseAppCheck.instance.getToken(true);
          print('✅ Firebase App Check fallback to debug provider succeeded.');
          print('🔐 AppCheck token fetched early (debug fallback): $debugToken');
          await _setStartupStage('app_check_initialized_debug_fallback');
        } catch (fallbackError) {
          print('❌ Firebase App Check debug fallback failed: $fallbackError');
          await _setStartupError('FirebaseAppCheck.activate.early.debugFallback', fallbackError);
        }
      }
    }
    return;
  }

  final webRecaptchaSiteKey = AppEnv.webRecaptchaSiteKey;
  if (webRecaptchaSiteKey.isNotEmpty) {
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: ReCaptchaV3Provider(webRecaptchaSiteKey),
      );
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      print('✅ Firebase App Check activated early (web)');
      await _setStartupStage('app_check_initialized_web');
    } catch (e) {
      print('⚠️ Firebase App Check early activation error (web): $e');
      await _setStartupError('FirebaseAppCheck.activate.web.early', e);
    }
  } else {
    print('ℹ️ WEB_RECAPTCHA_SITE_KEY not set. Skipping App Check on web.');
    await _setStartupStage('app_check_skipped_web');
  }
}

Future<void> _initializeDeferredStartup() async {
  final dotenvLoaded = await AppEnv.loadDotEnvIfPresent();
  if (dotenvLoaded) {
    await _setStartupStage('dotenv_loaded');
  } else {
    print('ℹ️ .env not loaded; relying on dart-defines and native config.');
    await _setStartupStage('dotenv_skipped');
  }

  await AppEnv.loadNativePlatformConfig();
  await _setStartupStage('native_env_loaded');

  await _initializeAppCheckEarly();
}

void main() async {
  _installGlobalCrashLogging();

  await (runZonedGuarded<Future<void>>(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
    _startupPersistenceReady = true;

    // Fix blank map on Android caused by SurfaceProducer backend.
    // Must be called before the first GoogleMap widget is built.
    // Guarded with try-catch because the renderer can only be initialized once
    // per process; a second call (e.g. hot restart) throws "already initialized".
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final platform = GoogleMapsFlutterPlatform.instance;
      if (platform is GoogleMapsFlutterAndroid) {
        try {
          await platform.initializeWithRenderer(AndroidMapRenderer.legacy);
        } catch (_) {
          // Already initialized — safe to ignore.
        }
      }
    }

    await _initializeFirebaseApp();

    await _setStartupStage('main_entered');
    await _setStartupStage('binding_ready');
    await _printPreviousStartupBreadcrumb();

    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;
    painting.imageCache.maximumSize = isIOS ? (kDebugMode ? 50 : 80) : 200;
    painting.imageCache.maximumSizeBytes = isIOS
      ? (kDebugMode ? 20 << 20 : 60 << 20)
        : (kDebugMode ? 60 << 20 : 100 << 20);

  await EasyLocalization.ensureInitialized();
  await _setStartupStage('localization_ready');
  await _setStartupStage('firebase_initialized');

    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await _setStartupStage('orientation_locked_portrait');
    }

    runApp(listings_app.runListings()); // Called with alias
    await _setStartupStage('run_app_called');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_setStartupStage('first_frame_rendered'));
    });
    unawaited(_initializeDeferredStartup());
    unawaited(_initializePostLaunchServices());
  }, (Object error, StackTrace stack) {
    print('💥 [runZonedGuarded] Uncaught async startup error: $error');
    print(stack);
    unawaited(_setStartupError('runZonedGuarded', error, stack));
  }) ?? Future<void>.value());
}
