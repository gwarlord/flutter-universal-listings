import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class User with ChangeNotifier {
  String email;

  String firstName;

  String lastName;

  UserSettings settings;

  String phoneNumber;

  bool active;

  int lastOnlineTimestamp;

  String userID;

  String profilePictureURL;

  bool selected = false;

  String pushToken;

  String appIdentifier;

  User(
      {this.email = '',
      this.firstName = '',
      this.phoneNumber = '',
      this.lastName = '',
      this.active = false,
      lastOnlineTimestamp,
      appIdentifier,
      settings,
      this.pushToken = '',
      this.userID = '',
      this.profilePictureURL = ''})
      : lastOnlineTimestamp = lastOnlineTimestamp is int
            ? lastOnlineTimestamp
            : Timestamp.now().seconds,
        settings = settings ?? UserSettings(),
        appIdentifier =
            appIdentifier ?? 'Instaflutter ${Platform.operatingSystem}';

  String fullName() {
    return '$firstName $lastName';
  }

  factory User.fromJson(Map<String, dynamic> parsedJson) {
    return User(
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
        pushToken: parsedJson['pushToken'] ?? '',
        userID: parsedJson['id'] ?? parsedJson['userID'] ?? '',
        profilePictureURL: parsedJson['profilePictureURL'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'settings': settings.toJson(),
      'phoneNumber': phoneNumber,
      'id': userID,
      'userID': userID,
      'active': active,
      'lastOnlineTimestamp': lastOnlineTimestamp,
      'pushToken': pushToken,
      'profilePictureURL': profilePictureURL,
      'appIdentifier': appIdentifier
    };
  }
}

class UserSettings {
  bool allowPushNotifications;
  int subscriptionReminderDays;
  bool bookingEmailReminders;
  bool bookingPushReminders;
  String? languageCode; // null = system default, 'en', 'es', 'fr', 'nl', 'ht'
  String chatAvailabilityHours;

  UserSettings({
    this.allowPushNotifications = true,
    this.subscriptionReminderDays = 3,
    this.bookingEmailReminders = true,
    this.bookingPushReminders = true,
    this.languageCode,
    this.chatAvailabilityHours = '',
  });

  factory UserSettings.fromJson(Map<dynamic, dynamic> parsedJson) {
    final dynamic reminderValue = parsedJson['subscriptionReminderDays'];
    int parsedReminderDays = 3;
    if (reminderValue is num) {
      parsedReminderDays = reminderValue.toInt();
    } else if (reminderValue is String) {
      parsedReminderDays = int.tryParse(reminderValue) ?? 3;
    }

    return UserSettings(
      allowPushNotifications: parsedJson['allowPushNotifications'] ?? true,
      subscriptionReminderDays: parsedReminderDays,
      bookingEmailReminders: parsedJson['bookingEmailReminders'] ?? true,
      bookingPushReminders: parsedJson['bookingPushReminders'] ?? true,
      languageCode: parsedJson['languageCode'] as String?,
      chatAvailabilityHours: parsedJson['chatAvailabilityHours']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'allowPushNotifications': allowPushNotifications,
      'subscriptionReminderDays': subscriptionReminderDays,
      'bookingEmailReminders': bookingEmailReminders,
      'bookingPushReminders': bookingPushReminders,
      'languageCode': languageCode,
      'chatAvailabilityHours': chatAvailabilityHours,
    };
  }
}
