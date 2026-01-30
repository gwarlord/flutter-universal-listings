import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/core/model/user.dart';
import 'package:instaflutter/listings/listings_app_config.dart';

class ListingsUser extends User {
  bool isAdmin;
  String subscriptionTier;
  bool suspended;
  DateTime? subscriptionExpiresAt;
  String? revenueCatCustomerId;
  String countryCode;

  List<String> likedListingsIDs;

  ListingsUser({
    email = '',
    userID = '',
    profilePictureURL = '',
    firstName = '',
    phoneNumber = '',
    lastName = '',
    active = false,
    lastOnlineTimestamp,
    settings,
    pushToken = '',
    this.isAdmin = false,
    this.subscriptionTier = 'free',
    this.suspended = false,
    this.subscriptionExpiresAt,
    this.revenueCatCustomerId,
    this.countryCode = '',
    this.likedListingsIDs = const [],
  }) : super(
          firstName: firstName,
          lastName: lastName,
          userID: userID,
          active: active,
          email: email,
          pushToken: pushToken,
          phoneNumber: phoneNumber,
          profilePictureURL: profilePictureURL,
          settings: settings ?? UserSettings(),
          lastOnlineTimestamp: lastOnlineTimestamp is int
              ? lastOnlineTimestamp
              : Timestamp.now().seconds,
          appIdentifier: '$appName ${Platform.operatingSystem}',
        );

  factory ListingsUser.fromJson(Map<String, dynamic> parsedJson) {
    return ListingsUser(
      email: parsedJson['email'] ?? '',
      firstName: parsedJson['firstName'] ?? '',
      lastName: parsedJson['lastName'] ?? '',
      active: parsedJson['active'] ?? false,
      lastOnlineTimestamp: parsedJson['lastOnlineTimestamp'] is Timestamp
          ? (parsedJson['lastOnlineTimestamp'] as Timestamp).seconds
          : parsedJson['lastOnlineTimestamp'],
      settings: parsedJson.containsKey('settings')
          ? UserSettings.fromJson(parsedJson['settings'])
          : UserSettings(),
      phoneNumber: parsedJson['phoneNumber'] ?? '',
      userID: parsedJson['id'] ?? parsedJson['userID'] ?? '',
      profilePictureURL: parsedJson['profilePictureURL'] ?? '',
      pushToken: parsedJson['pushToken'] ?? '',
      isAdmin: parsedJson['isAdmin'] ?? false,
      subscriptionTier: parsedJson['subscriptionTier']?.toString() ?? 'free',
      suspended: parsedJson['suspended'] ?? false,
      subscriptionExpiresAt: parsedJson['subscriptionExpiresAt'] != null
          ? (parsedJson['subscriptionExpiresAt'] is Timestamp
              ? (parsedJson['subscriptionExpiresAt'] as Timestamp).toDate()
              : DateTime.tryParse(parsedJson['subscriptionExpiresAt'].toString()))
          : null,
      revenueCatCustomerId: parsedJson['revenueCatCustomerId']?.toString(),
      countryCode: parsedJson['countryCode'] ?? '',
      likedListingsIDs:
          List<String>.from(parsedJson['likedListingsIDs'] ?? const []),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'settings': settings.toJson(),
      'phoneNumber': phoneNumber,
      'id': userID,
      'active': active,
      'lastOnlineTimestamp': lastOnlineTimestamp,
      'subscriptionExpiresAt': subscriptionExpiresAt != null
          ? Timestamp.fromDate(subscriptionExpiresAt!)
          : null,
      'revenueCatCustomerId': revenueCatCustomerId,
      'profilePictureURL': profilePictureURL,
      'appIdentifier': appIdentifier,
      'pushToken': pushToken,
      'isAdmin': isAdmin,
      'subscriptionTier': subscriptionTier,
      'suspended': suspended,
      'countryCode': countryCode,
      'likedListingsIDs': likedListingsIDs,
    };
  }

  // Subscription helper methods
  String get _normalizedTier => subscriptionTier.trim().toLowerCase();

  bool get isFree => _normalizedTier == 'free';
  bool get isProfessional => _normalizedTier == 'professional';
  bool get isPremium => _normalizedTier == 'premium';
  bool get isBusiness => _normalizedTier == 'business';
  
  bool get isSubscriptionActive {
    // Admins always have active access
    if (isAdmin) return true;
    
    // Free tier is always active
    if (isFree) return true;
    
    // For paid tiers without expiration date (legacy or manually set), treat as active
    // This handles users set to professional/premium in Firestore before RevenueCat integration
    if (subscriptionExpiresAt == null && !isFree) return true;
    
    // Allow a small grace window on expiration to tolerate timezone and clock drift
    final graceExpiry = subscriptionExpiresAt!.add(const Duration(hours: 24));
    final now = DateTime.now();
    return now.isBefore(graceExpiry) || now.isAtSameMomentAs(graceExpiry);
  }

  // Feature access helpers
  // Note: Premium users get ALL professional features plus premium-only features
  bool get hasBookingServices {
    if (isAdmin) return true;
    final paidTier = isProfessional || isPremium || isBusiness;
    return paidTier && isSubscriptionActive;
  }
  bool get hasAdvancedAnalytics => (isPremium && isSubscriptionActive) || isAdmin;
  bool get hasPrioritySupport => isPremium && isSubscriptionActive;
  bool get hasDirectMessaging => (isPremium && isSubscriptionActive) || isAdmin;
}