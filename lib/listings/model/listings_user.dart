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
      'likedListingsIDs': likedListingsIDs,
    };
  }

  // Subscription helper methods
  bool get isFree => subscriptionTier.toLowerCase() == 'free';
  bool get isProfessional => subscriptionTier.toLowerCase() == 'professional';
  bool get isPremium => subscriptionTier.toLowerCase() == 'premium';
  
  bool get isSubscriptionActive {
    // Admins always have active access
    if (isAdmin) return true;
    
    // Free tier is always active
    if (subscriptionTier.toLowerCase() == 'free') return true;
    
    // For paid tiers without expiration date (legacy or manually set), treat as active
    // This handles users set to professional/premium in Firestore before RevenueCat integration
    if (subscriptionExpiresAt == null && !isFree) return true;
    
    // Check if subscription hasn't expired
    return DateTime.now().isBefore(subscriptionExpiresAt!);
  }

  bool get hasBookingServices => (isProfessional || isPremium) && isSubscriptionActive;
  bool get hasAdvancedAnalytics => isPremium && isSubscriptionActive;
  bool get hasPrioritySupport => isPremium && isSubscriptionActive;}