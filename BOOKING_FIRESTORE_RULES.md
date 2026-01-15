# Booking Feature - Firestore Rules & Implementation Guide

## 1. Firestore Security Rules

Add these rules to your `firestore.rules` to enforce booking access control:

```javascript
// Users collection - ensure subscriptionTier is only updated by admins or self
match /users/{userId} {
  allow read: if request.auth.uid == userId || request.auth.uid in getAdmin();
  allow update: if request.auth.uid == userId && 
                   !('subscriptionTier' in request.resource.data.keys) ||
                   request.auth.uid in getAdmin();
  allow update: if request.auth.uid in getAdmin() && 
                   'subscriptionTier' in request.resource.data.keys; // Admins set tier
}

// Listings collection - booking fields gated by subscription
match /listings/{listingId} {
  allow read: if true; // Public read
  
  allow create: if request.auth.uid != null &&
                   request.auth.uid == request.resource.data.authorID;
  
  allow update: if request.auth.uid != null &&
                   request.auth.uid == request.resource.data.authorID &&
                   validateBookingEligibility();
                   
  allow delete: if request.auth.uid == resource.data.authorID ||
                   request.auth.uid in getAdmin();
}

// Helper function to check booking eligibility
function validateBookingEligibility() {
  let bookingEnabled = request.resource.data.get('bookingEnabled', false);
  let bookingUrl = request.resource.data.get('bookingUrl', '');
  
  // If booking is being enabled, validate subscription tier
  if (bookingEnabled == true) {
    let userTier = getUserSubscriptionTier(request.auth.uid);
    let eligibleTiers = ['pro', 'premium', 'business'];
    
    return userTier in eligibleTiers && 
           bookingUrl != null && 
           bookingUrl.size() > 0;
  }
  
  return true; // Disabling booking is always allowed
}

// Helper function to get user's subscription tier
function getUserSubscriptionTier(userId) {
  return get(/databases/$(database)/documents/users/$(userId)).data.subscriptionTier;
}

// Helper function to identify admins
function getAdmin() {
  return get(/databases/$(database)/documents/admins/admins).data.adminUserIds;
}

// Optional: Bookings subcollection for slot-based booking
match /listings/{listingId}/bookings/{bookingId} {
  allow read: if request.auth.uid != null &&
                 (request.auth.uid == resource.data.userId ||
                  request.auth.uid == get(/databases/$(database)/documents/listings/$(listingId)).data.authorID);
  
  allow create: if request.auth.uid != null &&
                   request.auth.uid == request.resource.data.userId &&
                   request.resource.data.listingId == listingId;
  
  allow update: if request.auth.uid in getAdmin();
  
  allow delete: if request.auth.uid == resource.data.userId ||
                   request.auth.uid in getAdmin();
}
```

## 2. Optional: Bookings Subcollection Model

If you want to implement in-app booking slots (instead of just external links), add this model:

```dart
// lib/listings/model/booking_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BookingModel {
  String id;
  String listingId;
  String userId; // Person making the booking
  String userName;
  String userEmail;
  String userPhone;
  
  DateTime bookedDate;
  int startTime; // Hour (0-23)
  int endTime;   // Hour (0-23)
  
  String status; // 'pending', 'confirmed', 'cancelled'
  int createdAt;
  
  BookingModel({
    this.id = '',
    required this.listingId,
    required this.userId,
    this.userName = '',
    this.userEmail = '',
    this.userPhone = '',
    required this.bookedDate,
    required this.startTime,
    required this.endTime,
    this.status = 'pending',
    int? createdAt,
  }) : createdAt = createdAt ?? Timestamp.now().seconds;
  
  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? '',
      userEmail: json['userEmail'] ?? '',
      userPhone: json['userPhone'] ?? '',
      bookedDate: json['bookedDate'] is Timestamp
          ? (json['bookedDate'] as Timestamp).toDate()
          : DateTime.parse(json['bookedDate'] ?? DateTime.now().toString()),
      startTime: json['startTime'] ?? 0,
      endTime: json['endTime'] ?? 1,
      status: json['status'] ?? 'pending',
      createdAt: json['createdAt'] ?? Timestamp.now().seconds,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'userPhone': userPhone,
      'bookedDate': Timestamp.fromDate(bookedDate),
      'startTime': startTime,
      'endTime': endTime,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
```

## 3. Optional: Repository Methods for Bookings

Add to `ListingsRepository`:

```dart
// Create booking (in-app slot reservation)
Future<String> createBooking({
  required String listingId,
  required BookingModel booking,
});

// Get all bookings for a listing (lister only)
Future<List<BookingModel>> getListingBookings({required String listingId});

// Approve/reject booking (lister only)
Future<void> updateBookingStatus({
  required String listingId,
  required String bookingId,
  required String status,
});
```

## 4. Implementation Checklist

- [x] Add subscription tier to users
- [x] Gate booking UI to eligible tiers
- [x] Validate on client and server
- [ ] Deploy Firestore rules
- [ ] Update users collection with default subscriptionTier: "free"
- [ ] (Optional) Implement BookingModel and slot-based booking UI
- [ ] (Optional) Add booking calendar/slot picker on details screen

## 5. Testing

Before deploying, test:
1. Free tier users see upgrade notice (cannot enable bookings)
2. Pro/premium/business tier users can toggle bookings
3. Pro users must provide a booking URL before saving
4. Firestore rejects updates from non-eligible users
5. "Book Now" button appears/disappears based on bookingEnabled flag

## Notes

- Booking URLs can point to external services (Calendly, Acuity, etc.)
- For full control, implement the BookingModel and manage slots in Firestore
- Consider adding a bookings dashboard on the lister profile
- Email notifications when a booking is made (optional enhancement)
