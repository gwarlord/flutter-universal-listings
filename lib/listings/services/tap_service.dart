import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:instaflutter/listings/constants/tap_constants.dart';
import 'package:instaflutter/listings/listings_module/api/tap_repository.dart';
import 'package:instaflutter/listings/model/listing_model.dart';
import 'package:instaflutter/listings/model/tap_model.dart';

/// Service layer for Tap operations with business logic and validation
class TapService {
  final TapRepository _repository;
  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  
  // Track last tap action timestamp to prevent spam
  DateTime? _lastTapAction;

  TapService(this._repository);

  /// Validate if user can tap a listing
  /// Returns (canTap, errorMessage)
  Future<(bool, String?)> validateTapEligibility({
    required ListingModel listing,
    required String userId,
  }) async {
    // Check if user is authenticated
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) {
      return (false, tapErrorNotAuthenticated);
    }

    // Check if user owns the listing
    if (listing.authorID == userId) {
      return (false, tapErrorOwnListing);
    }

    // Check if email is verified OR account is old enough
    final accountCreationTime = currentUser.metadata.creationTime;
    final accountAge = accountCreationTime != null 
        ? DateTime.now().difference(accountCreationTime)
        : Duration.zero;
    
    final isEmailVerified = currentUser.emailVerified;
    final isAccountOldEnough = accountAge.inMinutes >= minAccountAgeMinutesForTap;

    if (!isEmailVerified && !isAccountOldEnough) {
      return (false, tapErrorAccountTooNew);
    }

    // Check for spam (rapid tap/untap)
    if (_lastTapAction != null) {
      final timeSinceLastAction = DateTime.now().difference(_lastTapAction!);
      if (timeSinceLastAction.inSeconds < tapSpamPreventionDelaySeconds) {
        return (false, tapErrorTooQuick);
      }
    }

    return (true, null);
  }

  /// Toggle tap for a listing (tap if not tapped, untap if already tapped)
  Future<TapResult> toggleTap({
    required ListingModel listing,
    required String userId,
    TapReason? reason,
  }) async {
    try {
      final effectiveUserId = _firebaseAuth.currentUser?.uid ?? userId;
      debugPrint('🎯 toggleTap() START - userId=$effectiveUserId, listingId=${listing.id}, reason=$reason');

      // Validate eligibility
      final (canTap, errorMessage) = await validateTapEligibility(
        listing: listing,
        userId: effectiveUserId,
      );

      if (!canTap) {
        debugPrint('❌ toggleTap() BLOCKED - $errorMessage');
        return TapResult(
          success: false,
          isTapped: false,
          errorMessage: errorMessage,
        );
      }

      // Check current tap status
      final isTapped = await _repository.hasUserTapped(
        listingId: listing.id,
        userId: effectiveUserId,
      );
      debugPrint('🎯 Current isTapped: $isTapped');

      bool success;
      if (isTapped) {
        // Remove tap
        debugPrint('🎯 Removing tap...');
        success = await _repository.removeTap(
          listingId: listing.id,
          userId: effectiveUserId,
        );
      } else {
        // Create tap
        debugPrint('🎯 Creating tap...');
        success = await _repository.createTap(
          listingId: listing.id,
          userId: effectiveUserId,
          reason: reason,
        );
      }

      // Update last action timestamp
      _lastTapAction = DateTime.now();
      
      final result = TapResult(
        success: success,
        isTapped: !isTapped && success,
        errorMessage: success ? null : tapErrorGeneral,
      );
      
      debugPrint('🎯 toggleTap() COMPLETE - success=$success, newIsTapped=${result.isTapped}');
      return result;
    } catch (e) {
      debugPrint('❌ toggleTap() ERROR: $e');
      return TapResult(
        success: false,
        isTapped: false,
        errorMessage: tapErrorGeneral,
      );
    }
  }

  /// Check if user has tapped a listing
  Future<bool> hasUserTapped({
    required String listingId,
    required String userId,
  }) async {
    final effectiveUserId = _firebaseAuth.currentUser?.uid ?? userId;
    return await _repository.hasUserTapped(
      listingId: listingId,
      userId: effectiveUserId,
    );
  }

  /// Get tap count for a listing
  Future<int> getTapCount({required String listingId}) async {
    return await _repository.getTapCount(listingId: listingId);
  }

  /// Get user's tap for a listing
  Future<TapModel?> getUserTap({
    required String listingId,
    required String userId,
  }) async {
    final effectiveUserId = _firebaseAuth.currentUser?.uid ?? userId;
    return await _repository.getUserTap(
      listingId: listingId,
      userId: effectiveUserId,
    );
  }

  /// Get tap badge for a listing based on tap count
  TapBadge getTapBadge(int tapCount) {
    return TapBadge.fromTapCount(tapCount);
  }
}

/// Result of a tap operation
class TapResult {
  final bool success;
  final bool isTapped;
  final String? errorMessage;

  TapResult({
    required this.success,
    required this.isTapped,
    this.errorMessage,
  });
}
