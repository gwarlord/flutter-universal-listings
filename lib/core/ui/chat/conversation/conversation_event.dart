part of 'conversation_bloc.dart';

abstract class ConversationsEvent {}

class InitConversationsEvent extends ConversationsEvent {}

class FetchConversationsPageEvent extends ConversationsEvent {
  int page;
  int size;

  FetchConversationsPageEvent({
    required this.page,
    required this.size,
    required Completer<List<ChatFeedModel>> completer,
  });
}

class FriendTapEvent extends ConversationsEvent {
  User friend;
  ListingModel? listing;

  FriendTapEvent({required this.friend, this.listing});
}

class FetchFriendByIDEvent extends ConversationsEvent {
  String friendID;
  ListingModel? listing;

  FetchFriendByIDEvent({required this.friendID, this.listing});
}

class SearchConversationsEvent extends ConversationsEvent {
  String query;
  List<ChatFeedModel> conversations;
  List<User> friends;

  SearchConversationsEvent({
    required this.query,
    required this.conversations,
    required this.friends,
  });
}
