import 'package:instaflutter/listings/model/tap_model.dart';

/// Repository interface for Tap operations
abstract class TapRepository {
  /// Create a tap (vouch) for a listing
  /// Returns true if successful, false otherwise
  Future<bool> createTap({
    required String listingId,
    required String userId,
    TapReason? reason,
  });

  /// Remove a tap (unvouch) from a listing
  /// Returns true if successful, false otherwise
  Future<bool> removeTap({
    required String listingId,
    required String userId,
  });

  /// Check if user has tapped a listing
  Future<bool> hasUserTapped({
    required String listingId,
    required String userId,
  });

  /// Get tap count for a listing
  Future<int> getTapCount({required String listingId});

  /// Get user's tap for a listing (if exists)
  Future<TapModel?> getUserTap({
    required String listingId,
    required String userId,
  });

  /// Get all taps for a listing (admin/analytics use)
  Future<List<TapModel>> getListingTaps({required String listingId});
}
