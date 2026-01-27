import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/core/model/chat_feed_model.dart';
import 'package:instaflutter/core/model/user.dart';

class ChannelDataModel {
  String channelID;
  String creatorID;
  String id;
  int lastMessageDate;
  String lastMessageSenderId;
  String lastThreadMessageId;
  String name;
  dynamic lastMessage;
  List<ChatFeedParticipantProfilePictureURL> participantProfilePictureURLs;
  List<User> participants;
  List<String> readUserIDs;
  List<String>? admins;
  bool isGroupChat;
  String? listingId;
  String? listingTitle;
  String? listingImage;

  ChannelDataModel({
    this.channelID = '',
    this.creatorID = '',
    this.id = '',
    this.lastMessage,
    this.lastMessageDate = 0,
    this.lastMessageSenderId = '',
    this.lastThreadMessageId = '',
    String? name,
    this.participantProfilePictureURLs = const [],
    this.participants = const [],
    List<String>? readUserIDs,
    this.admins,
    this.listingId,
    this.listingTitle,
    this.listingImage,
  })  : readUserIDs = readUserIDs ?? [],
        name = name ?? (participants.isNotEmpty ? participants.first.fullName() : ''),
        isGroupChat = (participants).length > 1;

  factory ChannelDataModel.fromJson(
      Map<String, dynamic> parsedJson, String currentUserID) {
    
    // Parse ALL participants first
    final List<User> allParticipants = ((parsedJson['participants'] ?? []) as Iterable)
          .where((e) => e is Map<String, dynamic>)
          .map((e) => User.fromJson(e))
          .toList();

    // Create a filtered list for the UI (excluding current user)
    final List<User> uiParticipants = List<User>.from(allParticipants)
        ..removeWhere((element) => element.userID == currentUserID);

    return ChannelDataModel(
      channelID: parsedJson['id'] ?? parsedJson['channelID'] ?? '',
      creatorID: parsedJson['creatorID'] ?? '',
      id: parsedJson['id'] ?? parsedJson['channelID'] ?? '',
      lastMessage: (parsedJson['lastMessage'] ?? '') is String
        ? parsedJson['lastMessage'] ?? ''
        : ChatFeedContent.fromJson(parsedJson['lastMessage'] ?? {}),
      lastMessageDate: (parsedJson['lastMessageDate'] ?? 0) is Timestamp
        ? (parsedJson['lastMessageDate'] as Timestamp).seconds
        : parsedJson['lastMessageDate'] ?? 0,
      lastMessageSenderId: parsedJson['lastMessageSenderId'] ?? '',
      lastThreadMessageId: parsedJson['lastThreadMessageId'] ?? '',
      name: parsedJson['name'] ?? (uiParticipants.isNotEmpty ? uiParticipants.first.fullName() : ''),
      participantProfilePictureURLs:
        ((parsedJson['participantProfilePictureURLs'] ?? []) as Iterable)
          .map((e) => ChatFeedParticipantProfilePictureURL.fromJson(e))
          .toList(),
      participants: uiParticipants,
      readUserIDs: List<String>.from(parsedJson['readUserIDs'] ?? []),
      admins: parsedJson.containsKey('admins') && parsedJson['admins'] != null
        ? List<String>.from(parsedJson['admins'])
        : null,
      listingId: parsedJson['listingId'],
      listingTitle: parsedJson['listingTitle'],
      listingImage: parsedJson['listingImage'],
    );
  }

  Map<String, dynamic> toJson(User currentUser) {
    List<User> fullParticipants = List.from(participants);
    if (fullParticipants.where((element) => element.userID == currentUser.userID).isEmpty) {
      fullParticipants.add(currentUser);
    }
    return {
      'channelID': channelID,
      'creatorID': creatorID,
      'id': id,
      'lastMessage': lastMessage is ChatFeedContent
        ? (lastMessage as ChatFeedContent).toJson()
        : lastMessage,
      'lastMessageDate': lastMessageDate,
      'lastMessageSenderId': lastMessageSenderId,
      'lastThreadMessageId': lastThreadMessageId,
      'name': name,
      'participantProfilePictureURLs':
        participantProfilePictureURLs.map((e) => e.toJson()).toList(),
      'participants': fullParticipants.map((e) => e.toJson()).toList(),
      'readUserIDs': readUserIDs,
      'admins': admins,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingImage': listingImage,
    };
  }
}
