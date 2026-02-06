import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/listings/listings_app_config.dart' as cfg;
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listing_review_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:instaflutter/listings/model/review_removal_request_model.dart';

class ReviewRemovalRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _requestsCollection = 'review_removal_requests';

  /// Submit a new removal request
  Future<String?> submitRemovalRequest({
    required ListingReviewModel review,
    required ListingModel listing,
    required ListingsUser currentUser,
    required String reasonCategory,
    required String reasonText,
  }) async {
    try {
      // Validate listing ownership or admin
      if (listing.authorID != currentUser.userID && !currentUser.isAdmin) {
        throw Exception('Unauthorized: Only listing owner or admin can request review removal');
      }

      // Check for existing pending request
      final existingRequest = await _firestore
          .collection(_requestsCollection)
          .where('reviewId', isEqualTo: review.id)
          .where('status', isEqualTo: 'PENDING')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        throw Exception('A pending removal request already exists for this review');
      }

      // Create new request
      final request = ReviewRemovalRequestModel(
        reviewId: review.id,
        listingId: listing.id,
        listerId: listing.authorID,
        reviewerId: review.authorID,
        reasonCategory: reasonCategory,
        reasonText: reasonText,
        status: 'PENDING',
      );

      final docRef = await _firestore
          .collection(_requestsCollection)
          .add(request.toJson());

      // Send notification to admins
      await _sendNotificationToAdmins(
        requestId: docRef.id,
        listingTitle: listing.title,
        listingId: listing.id,
      );

      return docRef.id;
    } catch (e) {
      debugPrint('Error submitting removal request: $e');
      rethrow;
    }
  }

  /// Stream pending requests for admin queue
  Stream<List<ReviewRemovalRequestModel>> streamPendingRequests() {
    return _firestore
        .collection(_requestsCollection)
        .where('status', isEqualTo: 'PENDING')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ReviewRemovalRequestModel.fromDoc(doc))
          .toList();
    });
  }

  /// Get count of pending requests
  Future<int> getPendingRequestsCount() async {
    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .where('status', isEqualTo: 'PENDING')
          .count()
          .get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting pending requests count: $e');
      return 0;
    }
  }

  /// Get requests for a specific listing
  Future<List<ReviewRemovalRequestModel>> getRequestsForListing(
      String listingId) async {
    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .where('listingId', isEqualTo: listingId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ReviewRemovalRequestModel.fromDoc(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting requests for listing: $e');
      return [];
    }
  }

  /// Get request status for a specific review
  Future<ReviewRemovalRequestModel?> getRequestForReview(String reviewId) async {
    try {
      final snapshot = await _firestore
          .collection(_requestsCollection)
          .where('reviewId', isEqualTo: reviewId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;
      
      // If multiple requests exist for same review, return the most recent one
      final docs = snapshot.docs;
      if (docs.length == 1) {
        return ReviewRemovalRequestModel.fromDoc(docs.first);
      }
      
      // Sort by createdAt in memory if multiple found
      docs.sort((a, b) {
        final aTime = (a.data()['createdAt'] ?? 0) as int;
        final bTime = (b.data()['createdAt'] ?? 0) as int;
        return bTime.compareTo(aTime); // Descending
      });
      
      return ReviewRemovalRequestModel.fromDoc(docs.first);
    } catch (e) {
      debugPrint('Error getting request for review: $e');
      return null;
    }
  }

  /// Get a single request by ID
  Future<ReviewRemovalRequestModel?> getRequest(String requestId) async {
    try {
      final doc =
          await _firestore.collection(_requestsCollection).doc(requestId).get();
      if (!doc.exists) return null;
      return ReviewRemovalRequestModel.fromDoc(doc);
    } catch (e) {
      debugPrint('Error getting request: $e');
      return null;
    }
  }

  /// Approve a removal request
  Future<void> approveRequest({
    required String requestId,
    required String adminId,
    String? adminNotes,
  }) async {
    try {
      final request = await getRequest(requestId);
      if (request == null) {
        throw Exception('Request not found');
      }

      // Update request status
      await _firestore.collection(_requestsCollection).doc(requestId).update({
        'status': 'APPROVED',
        'adminId': adminId,
        'adminNotes': adminNotes ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Hide the review
      await _firestore.collection(cfg.reviewCollection).doc(request.reviewId).update({
        'isHidden': true,
        'hiddenAt': FieldValue.serverTimestamp(),
        'hiddenBy': adminId,
        'hiddenReason': adminNotes ?? 'Request ID: $requestId',
      });

      debugPrint('Review removal request approved: $requestId');
    } catch (e) {
      debugPrint('Error approving request: $e');
      rethrow;
    }
  }

  /// Reject a removal request
  Future<void> rejectRequest({
    required String requestId,
    required String adminId,
    required String rejectionReason,
    String? adminNotes,
  }) async {
    try {
      await _firestore.collection(_requestsCollection).doc(requestId).update({
        'status': 'REJECTED',
        'adminId': adminId,
        'adminNotes': adminNotes ?? '',
        'rejectionReasonVisibleToLister': rejectionReason,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Review removal request rejected: $requestId');
    } catch (e) {
      debugPrint('Error rejecting request: $e');
      rethrow;
    }
  }

  /// Get the review document
  Future<ListingReviewModel?> getReview(String reviewId) async {
    try {
      final doc =
          await _firestore.collection(cfg.reviewCollection).doc(reviewId).get();
      if (!doc.exists) return null;
      return ListingReviewModel.fromDoc(doc);
    } catch (e) {
      debugPrint('Error getting review: $e');
      return null;
    }
  }

  /// Get the listing document
  Future<ListingModel?> getListing(String listingId) async {
    try {
      final doc = await _firestore
          .collection(cfg.listingsCollection)
          .doc(listingId)
          .get();
      if (!doc.exists) return null;
      final model = ListingModel.fromJson(doc.data()!);
      model.id = doc.id;
      return model;
    } catch (e) {
      debugPrint('Error getting listing: $e');
      return null;
    }
  }

  /// Send FCM notification to all admins
  Future<void> _sendNotificationToAdmins({
    required String requestId,
    required String listingTitle,
    required String listingId,
  }) async {
    try {
      final serverKey = dotenv.env['FCM_SERVER_KEY'];
      if (serverKey == null || serverKey.isEmpty) {
        debugPrint('FCM_SERVER_KEY not found. Skipping admin notification.');
        return;
      }

      final adminUsersSnapshot = await _firestore
          .collection(usersCollection)
          .where('isAdmin', isEqualTo: true)
          .where('pushToken', isNotEqualTo: null)
          .where('pushToken', isNotEqualTo: '')
          .get();

      if (adminUsersSnapshot.docs.isEmpty) {
        debugPrint('No admin users with push tokens found.');
        return;
      }

      for (var doc in adminUsersSnapshot.docs) {
        final pushToken = doc.data()['pushToken'];
        if (pushToken != null && pushToken.isNotEmpty) {
          final uri = Uri.parse('https://fcm.googleapis.com/fcm/send');
          final headers = {
            'Content-Type': 'application/json',
            'Authorization': 'key=$serverKey',
          };
          final body = jsonEncode({
            'to': pushToken,
            'priority': 'high',
            'notification': {
              'title': 'Review Removal Request',
              'body':
                  'A lister requested removal of a review for "$listingTitle"',
            },
            'data': {
              'type': 'review_removal_request',
              'requestId': requestId,
              'listingId': listingId,
            },
          });

          final response = await http.post(uri, headers: headers, body: body);

          if (response.statusCode == 200) {
            debugPrint('Notification sent to admin: ${doc.id}');
          } else {
            debugPrint(
                'Failed to send notification to admin ${doc.id}: ${response.statusCode}');
          }
        }
      }
    } catch (e) {
      debugPrint('Error sending admin notifications: $e');
    }
  }
}
