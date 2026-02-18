import 'package:caribtap/core/model/channel_data_model.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/listings/listings_module/api/collaboration_api_manager.dart';
import 'package:caribtap/listings/model/collaboration_model.dart';

/// Helper class to integrate collaboration chats with the existing chat system
class ChatScopeIntegration {
  /// Create a channel for listing team chat
  /// Participants: owner + collaborators with manageChats permission
  static Future<ChannelDataModel> createListingTeamChat({
    required String listingId,
    required String ownerUid,
    required User ownerUser,
    required List<User> collaboratorUsers,
  }) async {
    // Create listing chat metadata in Firebase
    final participantUids = <String>[ownerUid];
    final participants = <User>[ownerUser];

    for (var collab in collaboratorUsers) {
      if (!participantUids.contains(collab.userID)) {
        participantUids.add(collab.userID);
        participants.add(collab);
      }
    }

    await collaborationApiManager.createListingChat(
      listingId: listingId,
      ownerUid: ownerUid,
      participantUids: participantUids,
    );

    // Return channel for chat UI
    return ChannelDataModel(
      channelID: 'listing_$listingId',
      id: 'listing_$listingId',
      name: 'Listing Team Chat',
      creatorID: ownerUid,
      participants: participants,
    );
  }

  /// Create a channel for order thread chat
  /// Participants: owner + collaborators with manageChats permission + customer
  static Future<ChannelDataModel> createOrderThreadChat({
    required String orderId,
    required String listingId,
    required String ownerUid,
    required User ownerUser,
    required String customerUid,
    required User customerUser,
    required List<User> collaboratorUsers,
  }) async {
    // Create order chat metadata in Firebase
    final participantUids = <String>[ownerUid, customerUid];
    final participants = <User>[ownerUser, customerUser];

    for (var collab in collaboratorUsers) {
      if (!participantUids.contains(collab.userID)) {
        participantUids.add(collab.userID);
        participants.add(collab);
      }
    }

    await collaborationApiManager.createOrderChat(
      orderId: orderId,
      listingId: listingId,
      ownerUid: ownerUid,
      customerUid: customerUid,
      participantUids: participantUids,
    );

    // Return channel for chat UI
    return ChannelDataModel(
      channelID: 'order_$orderId',
      id: 'order_$orderId',
      name: 'Order #${orderId.substring(0, 8)}...',
      creatorID: ownerUid,
      participants: participants,
    );
  }

  /// Get listing team chat channel
  static Future<ChannelDataModel?> getListingTeamChat({
    required String listingId,
    required String ownerUid,
    required User ownerUser,
    required List<User> collaboratorUsers,
  }) async {
    final chat = await collaborationApiManager.getListingChat(
      listingId: listingId,
    );

    if (chat == null) return null;

    final participants = <User>[ownerUser];
    for (var collab in collaboratorUsers) {
      if (!participants.any((p) => p.userID == collab.userID)) {
        participants.add(collab);
      }
    }

    return ChannelDataModel(
      channelID: 'listing_$listingId',
      id: 'listing_$listingId',
      name: 'Listing Team Chat',
      creatorID: ownerUid,
      participants: participants,
    );
  }

  /// Get order thread chat channel
  static Future<ChannelDataModel?> getOrderThreadChat({
    required String orderId,
    required String ownerUid,
    required User ownerUser,
    required String customerUid,
    required User customerUser,
    required List<User> collaboratorUsers,
  }) async {
    final chat = await collaborationApiManager.getOrderChat(
      orderId: orderId,
    );

    if (chat == null) return null;

    final participants = <User>[ownerUser, customerUser];
    for (var collab in collaboratorUsers) {
      if (!participants.any((p) => p.userID == collab.userID)) {
        participants.add(collab);
      }
    }

    return ChannelDataModel(
      channelID: 'order_$orderId',
      id: 'order_$orderId',
      name: 'Order #${orderId.substring(0, 8)}...',
      creatorID: ownerUid,
      participants: participants,
    );
  }

  /// Check if user can access listing team chat
  static Future<bool> canAccessListingTeamChat({
    required String listingId,
    required String userId,
    required String listingOwnerId,
  }) async {
    if (userId == listingOwnerId) return true;

    final perms = await collaborationApiManager.getCollaboratorPermissions(
      listingId: listingId,
      collaboratorUid: userId,
    );

    return perms != null && perms.manageChats;
  }

  /// Check if user can access order thread chat
  static Future<bool> canAccessOrderThreadChat({
    required String orderId,
    required String listingId,
    required String userId,
    required String listingOwnerId,
    required String customerUid,
  }) async {
    // Customer can always access their own order chat
    if (userId == customerUid) return true;

    // Owner can always access
    if (userId == listingOwnerId) return true;

    // Collaborators need manageChats permission
    final perms = await collaborationApiManager.getCollaboratorPermissions(
      listingId: listingId,
      collaboratorUid: userId,
    );

    return perms != null && perms.manageChats;
  }
}
