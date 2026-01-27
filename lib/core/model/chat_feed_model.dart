import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/core/model/media_container.dart';
import 'package:instaflutter/core/model/user.dart';

class ChatFeedModel {
  ChatFeedContent chatFeedContent;
  int createdAt;
  String id;
  bool markedAsRead;
  List<User> participants;
  String title;
  bool isGroupChat;
  String listingId;
  String listingTitle;
  String listingImage;

  ChatFeedModel({
    chatFeedContent,
    this.createdAt = 0,
    this.id = '',
    this.markedAsRead = false,
    this.participants = const [],
    this.title = '',
    this.listingId = '',
    this.listingTitle = '',
    this.listingImage = '',
  })  : chatFeedContent = chatFeedContent ?? ChatFeedContent(),
        isGroupChat = participants.length > 1;

  factory ChatFeedModel.fromJson(
      Map<String, dynamic> parsedJson, String currentUserID) {
    // Handle createdAt as int or Timestamp
    int createdAtValue = 0;
    if (parsedJson['createdAt'] is int) {
      createdAtValue = parsedJson['createdAt'];
      // Heuristic: if less than 10^11, it's likely in seconds
      if (createdAtValue < 100000000000) {
        createdAtValue *= 1000;
      }
    } else if (parsedJson['createdAt'] is Timestamp) {
      createdAtValue = (parsedJson['createdAt'] as Timestamp).millisecondsSinceEpoch;
    } else if (parsedJson['lastMessageDate'] is Timestamp) {
      createdAtValue = (parsedJson['lastMessageDate'] as Timestamp).millisecondsSinceEpoch;
    }

    // Handle participants as List<String> or List<Map>
    List<User> participantsList = [];
    if (parsedJson['participants'] is List) {
      var rawList = parsedJson['participants'] as List;
      if (rawList.isNotEmpty && rawList.first is String) {
        participantsList = rawList.map((e) => User(userID: e)).toList();
      } else if (rawList.isNotEmpty && rawList.first is Map) {
        participantsList = rawList.map((e) => User.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } else if (parsedJson['participantIds'] is List) {
      var rawList = parsedJson['participantIds'] as List;
      participantsList = rawList.map((e) => User(userID: e.toString())).toList();
    }
    
    participantsList.removeWhere((element) => element.userID == currentUserID);

    // Handle content parsing from both legacy 'content' and new 'lastMessage' structures
    ChatFeedContent chatContent;
    if (parsedJson.containsKey('lastMessage') && parsedJson['lastMessage'] is Map) {
      chatContent = ChatFeedContent.fromJson(Map<String, dynamic>.from(parsedJson['lastMessage']));
    } else if (parsedJson.containsKey('content')) {
      chatContent = parsedJson['content'] is String
          ? ChatFeedContent(content: parsedJson['content'])
          : ChatFeedContent.fromJson(Map<String, dynamic>.from(parsedJson['content'] ?? {}));
    } else {
      chatContent = ChatFeedContent();
    }

    // Title fallback
    String title = parsedJson['title'] ?? parsedJson['listingTitle'] ?? '';
    if (title.isEmpty && participantsList.isNotEmpty) {
      title = participantsList.first.fullName();
    }

    return ChatFeedModel(
      chatFeedContent: chatContent,
      createdAt: createdAtValue,
      id: parsedJson['id'] ?? parsedJson['channelID'] ?? '',
      markedAsRead: parsedJson['markedAsRead'] ?? false,
      participants: participantsList,
      title: title,
      listingId: parsedJson['listingId'] ?? '',
      listingTitle: parsedJson['listingTitle'] ?? '',
      listingImage: parsedJson['listingImage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': chatFeedContent.toJson(),
      'createdAt': createdAt,
      'id': id,
      'markedAsRead': markedAsRead,
      'participants': participants.map((e) => e.toJson()).toList(),
      'title': title,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImage': listingImage,
    };
  }
}

class ChatFeedContent {
  String content;
  int createdAt;
  String id;
  List<ChatFeedParticipantProfilePictureURL> participantProfilePictureURLs;
  List<dynamic> readUserIDs;
  String recipientID;
  String recipientFirstName;
  String recipientLastName;
  String recipientProfilePictureURL;
  String senderID;
  String senderFirstName;
  String senderLastName;
  String senderProfilePictureURL;
  MediaContainer? chatMedia;
  String listingId;
  String listingTitle;
  String listingImage;

  ChatFeedContent({
    this.content = '',
    this.createdAt = 0,
    this.id = '',
    this.participantProfilePictureURLs = const [],
    this.readUserIDs = const [],
    this.recipientID = '',
    this.recipientFirstName = '',
    this.recipientLastName = '',
    this.recipientProfilePictureURL = '',
    this.senderID = '',
    this.senderFirstName = '',
    this.senderLastName = '',
    this.senderProfilePictureURL = '',
    this.chatMedia,
    this.listingId = '',
    this.listingTitle = '',
    this.listingImage = '',
  });

  factory ChatFeedContent.fromJson(Map<String, dynamic> parsedJson) {
    List<ChatFeedParticipantProfilePictureURL> participantProfilePictureURLs = [];
    var jsonList = parsedJson['participantProfilePictureURLs'] ?? [];
    if (jsonList is List) {
      for (var item in jsonList) {
        if (item is Map) {
          participantProfilePictureURLs.add(ChatFeedParticipantProfilePictureURL.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    // Handle createdAt as int or Timestamp
    int createdAtValue = 0;
    if (parsedJson['createdAt'] is int) {
      createdAtValue = parsedJson['createdAt'];
      // Heuristic: if less than 10^11, it's likely in seconds
      if (createdAtValue < 100000000000) {
        createdAtValue *= 1000;
      }
    } else if (parsedJson['createdAt'] is Timestamp) {
      createdAtValue = (parsedJson['createdAt'] as Timestamp).millisecondsSinceEpoch;
    }

    return ChatFeedContent(
      content: parsedJson['content'] ?? '',
      createdAt: createdAtValue,
      id: parsedJson['id'] ?? '',
      participantProfilePictureURLs: participantProfilePictureURLs,
      readUserIDs: (parsedJson['readUserIDs'] ?? []).cast<String>(),
      recipientID: parsedJson['recipientID'] ?? '',
      recipientFirstName: parsedJson['recipientFirstName'] ?? '',
      recipientLastName: parsedJson['recipientLastName'] ?? '',
      recipientProfilePictureURL:
        parsedJson['recipientProfilePictureURL'] ?? '',
      senderID: parsedJson['senderID'] ?? '',
      senderFirstName: parsedJson['senderFirstName'] ?? '',
      senderLastName: parsedJson['senderLastName'] ?? '',
      senderProfilePictureURL: parsedJson['senderProfilePictureURL'] ?? '',
      chatMedia: parsedJson.containsKey('url') && parsedJson['url'] != null
        ? MediaContainer.fromJson(
          Map<String, dynamic>.from(parsedJson['url']))
        : null,
      listingId: parsedJson['listingId'] ?? '',
      listingTitle: parsedJson['listingTitle'] ?? '',
      listingImage: parsedJson['listingImage'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'createdAt': createdAt,
      'id': id,
      'participantProfilePictureURLs':
          participantProfilePictureURLs.map((e) => e.toJson()).toList(),
      'readUserIDs': readUserIDs,
      'recipientID': recipientID,
      'recipientFirstName': recipientFirstName,
      'recipientLastName': recipientLastName,
      'recipientProfilePictureURL': recipientProfilePictureURL,
      'senderID': senderID,
      'senderFirstName': senderFirstName,
      'senderLastName': senderLastName,
      'senderProfilePictureURL': senderProfilePictureURL,
      'url': chatMedia?.toJson(),
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImage': listingImage,
    };
  }
}

class ChatFeedParticipantProfilePictureURL {
  String participantId;
  String profilePictureURL;

  ChatFeedParticipantProfilePictureURL(
      {this.participantId = '', this.profilePictureURL = ''});

  factory ChatFeedParticipantProfilePictureURL.fromJson(
      Map<String, dynamic> parsedJson) {
    return ChatFeedParticipantProfilePictureURL(
        participantId: parsedJson['participantId'] ?? '',
        profilePictureURL: parsedJson['profilePictureURL'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {
      'participantId': participantId,
      'profilePictureURL': profilePictureURL
    };
  }
}
