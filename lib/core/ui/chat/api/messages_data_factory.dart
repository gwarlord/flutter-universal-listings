import 'package:instaflutter/core/model/chat_feed_model.dart';

class MessagesDataFactory {
  List<ChatFeedContent> liveMessages = [];
  List<ChatFeedContent> historicalMessages = [];

  MessagesDataFactory({this.liveMessages = const [], historicalMessages})
      : historicalMessages = historicalMessages ?? [];

  set newLiveMessages(List<ChatFeedContent> value) {
    liveMessages = value;
    // Remove any historical messages that now appear in the live list to avoid duplicates
    final liveIds = Set.from(value.map((m) => m.id));
    historicalMessages.removeWhere((m) => liveIds.contains(m.id));
  }

  appendHistoricalMessages(List<ChatFeedContent> value) {
    // Remove any historical messages that are already in the live list
    final liveIds = Set.from(liveMessages.map((m) => m.id));
    value.removeWhere((m) => liveIds.contains(m.id));
    
    // Also remove from existing historical if we're re-fetching or overlapping
    final newNodeIds = Set.from(value.map((m) => m.id));
    historicalMessages.removeWhere((m) => newNodeIds.contains(m.id));
    
    historicalMessages.addAll(value);
  }

  List<ChatFeedContent> getAllMessages() {
    // Use a Map to guarantee uniqueness by message ID
    final Map<String, ChatFeedContent> messagesMap = {};
    
    // Add historical first, then live (live overwrites if ID exists, which is preferred)
    for (var m in historicalMessages) {
      messagesMap[m.id] = m;
    }
    for (var m in liveMessages) {
      messagesMap[m.id] = m;
    }
    
    final allMessages = messagesMap.values.toList();
    // Sort descending by creation date
    allMessages.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return allMessages;
  }
}
