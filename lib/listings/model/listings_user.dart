import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/suspension_info.dart';
import 'package:flutter/foundation.dart';

String _listingsPlatformLabel() {
  if (kIsWeb) return 'web';

  switch (defaultTargetPlatform) {
    case TargetPlatform.iOS:
      return 'ios';
    case TargetPlatform.android:
      return 'android';
    case TargetPlatform.macOS:
      return 'macos';
    case TargetPlatform.windows:
      return 'windows';
    case TargetPlatform.linux:
      return 'linux';
    case TargetPlatform.fuchsia:
      return 'fuchsia';
  }
}

class ListingsUser extends User {
  bool isAdmin;
  String subscriptionTier;
  bool suspended;
  SuspensionInfo? suspensionInfo;
  DateTime? subscriptionExpiresAt;
  String? revenueCatCustomerId;
  String countryCode;
  String gender;
  String ageRange;
  bool listingFreshnessExempt;
  bool isSubscriptionActiveOverride;

  // Location Scope fields (additive - backwards compatible)
  String? homeCountry;
  String? selectedCountry;
  String? locationScopeMode;
  bool strictLocalOnly;

  // Phone verification (Booking Trust System - Phase 1)
  bool phoneVerified;
  DateTime? phoneVerifiedAt;

  List<String> likedListingsIDs;
  List<String> likedEventsIDs;

  ListingsUser({
    String email = '',
    String userID = '',
    String profilePictureURL = '',
    String firstName = '',
    String phoneNumber = '',
    String lastName = '',
    bool active = false,
    dynamic lastOnlineTimestamp,
    UserSettings? settings,
    String pushToken = '',
    this.isAdmin = false,
    this.subscriptionTier = 'free',
    this.suspended = false,
    this.suspensionInfo,
    this.subscriptionExpiresAt,
    this.revenueCatCustomerId,
    this.countryCode = '',
    this.gender = 'Prefer not to say',
    this.ageRange = 'Prefer not to say',
    this.listingFreshnessExempt = false,
    this.likedListingsIDs = const [],
    this.likedEventsIDs = const [],
    bool? isSubscriptionActive,
    // Location Scope parameters
    this.homeCountry,
    this.selectedCountry,
    this.locationScopeMode,
    this.strictLocalOnly = false,
    // Phone verification
    this.phoneVerified = false,
    this.phoneVerifiedAt,
  })  : isSubscriptionActiveOverride = isSubscriptionActive ?? false,
        super(
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
          appIdentifier: '$appName ${_listingsPlatformLabel()}',
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
      suspensionInfo: parsedJson['suspensionInfo'] != null
          ? SuspensionInfo.fromJson(parsedJson['suspensionInfo'] as Map<String, dynamic>)
          : null,
      subscriptionExpiresAt: parsedJson['subscriptionExpiresAt'] != null
          ? (parsedJson['subscriptionExpiresAt'] is Timestamp
              ? (parsedJson['subscriptionExpiresAt'] as Timestamp).toDate()
              : DateTime.tryParse(parsedJson['subscriptionExpiresAt'].toString()))
          : null,
      revenueCatCustomerId: parsedJson['revenueCatCustomerId']?.toString(),
      countryCode: parsedJson['countryCode'] ?? '',
      gender: parsedJson['gender'] ?? 'Prefer not to say',
      ageRange: parsedJson['ageRange'] ?? 'Prefer not to say',
      listingFreshnessExempt: parsedJson['listingFreshnessExempt'] ?? false,
      likedListingsIDs:
          List<String>.from(parsedJson['likedListingsIDs'] ?? const []),
        likedEventsIDs:
          List<String>.from(parsedJson['likedEventsIDs'] ?? const []),
      isSubscriptionActive: parsedJson['isSubscriptionActive'],
      // Location Scope fields
      homeCountry: parsedJson['homeCountry'] as String?,
      selectedCountry: parsedJson['selectedCountry'] as String?,
      locationScopeMode: parsedJson['locationScopeMode'] as String?,
      strictLocalOnly: parsedJson['strictLocalOnly'] as bool? ?? false,
      // Phone verification
      phoneVerified: parsedJson['phoneVerified'] as bool? ?? false,
      phoneVerifiedAt: parsedJson['phoneVerifiedAt'] is Timestamp
          ? (parsedJson['phoneVerifiedAt'] as Timestamp).toDate()
          : null,
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
      'suspensionInfo': suspensionInfo?.toJson(),
      'countryCode': countryCode,
      // Location Scope fields
      'homeCountry': homeCountry,
      'selectedCountry': selectedCountry,
      'locationScopeMode': locationScopeMode,
      'strictLocalOnly': strictLocalOnly,
      // Phone verification
      'phoneVerified': phoneVerified,
      'phoneVerifiedAt': phoneVerifiedAt != null
          ? Timestamp.fromDate(phoneVerifiedAt!)
          : null,
      'gender': gender,
      'ageRange': ageRange,
      'listingFreshnessExempt': listingFreshnessExempt,
      'likedListingsIDs': likedListingsIDs,
      'likedEventsIDs': likedEventsIDs,
      'isSubscriptionActive': isSubscriptionActive,
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

    // Use the override field from Firestore if it exists
    if (isSubscriptionActiveOverride) return true;

    // If there's an expiration date, check if it's in the future.
    if (subscriptionExpiresAt != null) {
      return subscriptionExpiresAt!.isAfter(DateTime.now());
    }

    // Fallback for non-free tiers without an expiration date (legacy users)
    if (!isFree) {
      return true;
    }

    return false; // Default to inactive
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
