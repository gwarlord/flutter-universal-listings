import 'package:caribtap/listings/model/collaboration_model.dart';

abstract class CollaborationRepository {
  /// Add a collaborator to a listing
  /// Returns collaborator UID on success
  Future<String> addListingCollaborator({
    required String listingId,
    required String collaboratorEmailOrUid,
    required CollaboratorPermissions permissions,
  });

  /// Remove a collaborator from a listing (soft delete)
  Future<void> removeListingCollaborator({
    required String listingId,
    required String collaboratorUid,
  });

  /// Update collaborator permissions
  Future<void> updateListingCollaboratorPermissions({
    required String listingId,
    required String collaboratorUid,
    required CollaboratorPermissions permissions,
  });

  /// Get list of collaborators for a listing
  Future<List<CollaboratorModel>> getListingCollaborators({
    required String listingId,
  });

  /// Stream of collaborators for a listing
  Stream<List<CollaboratorModel>> streamListingCollaborators({
    required String listingId,
  });

  /// Get activity log for a listing
  Future<List<ActivityLogEntry>> getActivityLog({
    required String listingId,
    int limit = 50,
  });

  /// Stream of activity log for real-time updates
  Stream<List<ActivityLogEntry>> streamActivityLog({
    required String listingId,
    int limit = 50,
  });

  /// Write an activity log entry
  Future<void> logActivity({
    required String listingId,
    required String actorUid,
    String? actorName,
    required String actorRole,
    required String actionType,
    required String targetType,
    required String targetId,
    String? targetName,
    String? note,
  });

  /// Get listings where user is a collaborator
  Future<List<AssignedListingModel>> getAssignedListings({
    required String userId,
  });

  /// Stream of assigned listings
  Stream<List<AssignedListingModel>> streamAssignedListings({
    required String userId,
  });

  /// Create or update listing team chat
  Future<void> createListingChat({
    required String listingId,
    required String ownerUid,
    required List<String> participantUids,
  });

  /// Get listing team chat
  Future<ListingChat?> getListingChat({
    required String listingId,
  });

  /// Stream listing team chat
  Stream<ListingChat?> streamListingChat({
    required String listingId,
  });

  /// Create or update order thread chat
  Future<void> createOrderChat({
    required String orderId,
    required String listingId,
    required String ownerUid,
    required String customerUid,
    required List<String> participantUids,
  });

  /// Get order thread chat
  Future<OrderChat?> getOrderChat({
    required String orderId,
  });

  /// Stream order thread chat
  Stream<OrderChat?> streamOrderChat({
    required String orderId,
  });

  /// Check if user can access listing collaboration features
  Future<bool> canAccessListingCollaboration({
    required String listingId,
    required String userId,
  });

  /// Get collaborator's permissions for a listing
  Future<CollaboratorPermissions?> getCollaboratorPermissions({
    required String listingId,
    required String collaboratorUid,
  });

  /// Check if listing owner has premium
  Future<bool> isListingOwnerPremium({
    required String listingId,
  });

  /// Clean up resources
  void dispose();
}
