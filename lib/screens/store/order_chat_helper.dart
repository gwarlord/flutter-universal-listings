import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:caribtap/listings/model/order_request.dart';

/// Helper functions for chat integration with order requests
class OrderChatHelper {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Ensure a chat channel exists between customer and lister
  /// Returns channelId
  Future<String> ensureOrderChannel({
    required ListingModel listing,
    required String customerId,
    required String listerId,
  }) async {
    // Try to find existing channel between these two users
    final existingChannels = await _firestore
        .collection(chatChannelsCollection)
        .where('participants', arrayContains: customerId)
        .get();

    for (final doc in existingChannels.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      if (participants.contains(listerId)) {
        return doc.id;
      }
    }

    // Create new channel
    final channelRef = _firestore.collection(chatChannelsCollection).doc();
    await channelRef.set({
      'participants': [customerId, listerId],
      'listingId': listing.id,
      'listingTitle': listing.title,
      'created': Timestamp.now(),
      'lastMessageDate': Timestamp.now(),
      'lastMessage': 'New order request',
    });

    return channelRef.id;
  }

  /// Post order request message to chat
  Future<void> postOrderRequestMessage({
    required String channelId,
    required OrderRequest order,
    required ListingsUser customer,
  }) async {
    final itemsText = order.items
        .map((item) {
          final variantText = item.variant != null
              ? ' (${item.variant!['size'] ?? ''}${item.variant!['size'] != null && item.variant!['color'] != null ? ', ' : ''}${item.variant!['color'] ?? ''})'
              : '';
          return '• ${item.name}$variantText x${item.qty} @ ${_formatCurrency(item.unitPrice, order.currencyCode)}';
        })
        .join('\n');

    final fulfillmentText = order.fulfillment.method == FulfillmentMethod.pickup
        ? 'Pickup'
        : 'Delivery${order.fulfillment.address != null ? ' to ${order.fulfillment.address}' : ''}';

    final preferredTimeText = order.fulfillment.preferredAt != null
        ? '\nPreferred: ${_formatDate(order.fulfillment.preferredAt!)}'
        : '';

    final notesText = order.notes != null && order.notes!.isNotEmpty
        ? '\nNotes: ${order.notes}'
        : '';

    final messageText = '''
📦 New Order Request

Items:
$itemsText

Total: ${_formatCurrency(order.estimatedTotal, order.currencyCode)}
Fulfillment: $fulfillmentText$preferredTimeText$notesText

Order ID: ${order.id}
''';

    await _firestore
        .collection(chatChannelsCollection)
        .doc(channelId)
        .collection('thread')
        .add({
      'content': messageText,
      'senderId': customer.userID,
      'senderFirstName': customer.firstName,
      'senderLastName': customer.lastName,
      'senderProfilePictureURL': customer.profilePictureURL,
      'created': Timestamp.now(),
      'type': 'order_request',
      'metadata': {
        'orderId': order.id,
      },
    });

    // Update channel last message
    await _firestore.collection(chatChannelsCollection).doc(channelId).update({
      'lastMessage': '📦 New Order Request',
      'lastMessageDate': Timestamp.now(),
    });
  }

  /// Post order status update message to chat
  Future<void> postOrderStatusMessage({
    required String channelId,
    required OrderRequest order,
    required OrderStatus newStatus,
    required ListingsUser actor,
  }) async {
    String statusEmoji;
    String statusText;

    switch (newStatus) {
      case OrderStatus.confirmed:
        statusEmoji = '✅';
        statusText = 'CONFIRMED';
        break;
      case OrderStatus.preparing:
        statusEmoji = '👨‍🍳';
        statusText = 'PREPARING';
        break;
      case OrderStatus.ready:
        statusEmoji = '🔔';
        statusText = 'READY';
        break;
      case OrderStatus.served:
        statusEmoji = '🍽️';
        statusText = 'SERVED';
        break;
      case OrderStatus.declined:
        statusEmoji = '❌';
        statusText = 'DECLINED';
        break;
      case OrderStatus.fulfilled:
        statusEmoji = '🎉';
        statusText = 'FULFILLED';
        break;
      case OrderStatus.cancelled:
        statusEmoji = '🚫';
        statusText = 'CANCELLED';
        break;
      default:
        statusEmoji = '📋';
        statusText = newStatus.value.toUpperCase();
    }

    final messageText = '''
$statusEmoji Order Update: $statusText

Order ID: ${order.id}
Total: ${_formatCurrency(order.estimatedTotal, order.currencyCode)}
''';

    await _firestore
        .collection(chatChannelsCollection)
        .doc(channelId)
        .collection('thread')
        .add({
      'content': messageText,
      'senderId': actor.userID,
      'senderFirstName': actor.firstName,
      'senderLastName': actor.lastName,
      'senderProfilePictureURL': actor.profilePictureURL,
      'created': Timestamp.now(),
      'type': 'order_status',
      'metadata': {
        'orderId': order.id,
        'status': newStatus.value,
      },
    });

    // Update channel last message
    await _firestore.collection(chatChannelsCollection).doc(channelId).update({
      'lastMessage': '$statusEmoji Order $statusText',
      'lastMessageDate': Timestamp.now(),
    });
  }

  String _formatCurrency(double amount, String currencyCode) {
    final symbol = _getCurrencySymbol(currencyCode);
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  String _getCurrencySymbol(String code) {
    switch (code.toUpperCase()) {
      case 'USD':
      case 'TTD':
      case 'JMD':
      case 'BSD':
      case 'BBD':
      case 'GYD':
      case 'DOP':
      case 'KYD':
      case 'SRD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '\$';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
