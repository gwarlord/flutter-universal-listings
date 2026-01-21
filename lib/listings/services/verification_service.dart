import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

class VerificationService {
  static const int MIN_ACCOUNT_AGE_DAYS = 7;
  static const int MIN_POSITIVE_REVIEWS = 1;
  static const double MIN_AVERAGE_RATING = 4.0;

  /// Auto-verify listing based on criteria
  /// Returns (shouldVerify, reason)
  static Future<(bool, String)> autoVerifyListing(
    ListingModel listing,
    ListingsUser lister,
  ) async {
    final List<String> criteria = [];

    // 1. Account age check
    final accountAgeSeconds = Timestamp.now().seconds - lister.lastOnlineTimestamp;
    final accountAgeDays = accountAgeSeconds ~/ 86400;
    if (accountAgeDays >= MIN_ACCOUNT_AGE_DAYS) {
      criteria.add('Account age: $accountAgeDays days');
    } else {
      return (false, 'Account too new (${MIN_ACCOUNT_AGE_DAYS} days required)');
    }

    // 2. Email verified check
    if (lister.email.contains('@') && lister.email.isNotEmpty) {
      criteria.add('Email verified');
    } else {
      return (false, 'Email not verified');
    }

    // 3. Phone verified check
    if (lister.phoneNumber.isNotEmpty) {
      criteria.add('Phone verified');
    } else {
      return (false, 'Phone not verified');
    }

    // 4. Review rating check (optional but preferred)
    if (listing.reviewsCount > 0) {
      final avgRating = listing.reviewsSum / listing.reviewsCount;
      if (avgRating >= MIN_AVERAGE_RATING) {
        criteria.add('Good rating: ${avgRating.toStringAsFixed(1)}/5');
      }
    }

    // All core criteria met
    if (criteria.isNotEmpty) {
      final reason = criteria.join(', ');
      return (true, reason);
    }

    return (false, 'Criteria not met');
  }

  /// Manually verify a listing by admin
  static Future<void> manuallyVerifyListing(
    String listingId,
    String adminId,
    String reason,
  ) async {
    await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .update({
      'verified': true,
      'verificationMethod': 'manual',
      'verifiedAt': Timestamp.now().seconds,
      'verifiedBy': adminId,
      'verificationReason': reason,
    });
  }

  /// Revoke verification
  static Future<void> revokeVerification(
    String listingId,
    String reason,
  ) async {
    await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .update({
      'verified': false,
      'verificationMethod': null,
      'verifiedAt': null,
      'verifiedBy': null,
      'verificationReason': reason,
    });
  }

  /// Batch auto-verify listings (scheduled job)
  static Future<int> batchAutoVerify() async {
    int verifiedCount = 0;
    final snapshot = await FirebaseFirestore.instance
        .collection('listings')
        .where('verified', isEqualTo: false)
        .where('suspended', isEqualTo: false)
        .limit(100)
        .get();

    for (final doc in snapshot.docs) {
      final listing = ListingModel.fromJson(doc.data());
      try {
        final authorDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(listing.authorID)
            .get();

        if (authorDoc.exists) {
          final lister = ListingsUser.fromJson(authorDoc.data()!);
          final (shouldVerify, reason) = await autoVerifyListing(listing, lister);

          if (shouldVerify) {
            await FirebaseFirestore.instance
                .collection('listings')
                .doc(listing.id)
                .update({
              'verified': true,
              'verificationMethod': 'auto',
              'verifiedAt': Timestamp.now().seconds,
              'verificationReason': reason,
            });
            verifiedCount++;
          }
        }
      } catch (e) {
        print('Error auto-verifying listing ${listing.id}: $e');
      }
    }

    return verifiedCount;
  }

  /// Get verification badge display info
  static String getVerificationBadgeText(ListingModel listing) {
    if (!listing.verified) return '';
    switch (listing.verificationMethod) {
      case 'auto':
        return '✓ Verified (Auto)';
      case 'manual':
        return '✓ Verified (Admin)';
      default:
        return '✓ Verified';
    }
  }

  /// Format verification details for display
  static String getVerificationDetails(ListingModel listing) {
    if (!listing.verified) return 'Not verified';

    final method = listing.verificationMethod ?? 'unknown';
    final reason = listing.verificationReason ?? 'No reason provided';
    return 'Method: $method\nReason: $reason';
  }
}
