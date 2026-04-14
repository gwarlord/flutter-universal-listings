// ignore_for_file: body_might_complete_normally_catch_error

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image_v2/flutter_native_image_v2.dart';

import 'package:caribtap/constants.dart';
import 'package:caribtap/core/model/channel_data_model.dart';
import 'package:caribtap/core/model/chat_feed_model.dart';
import 'package:caribtap/core/model/media_container.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/chat/api/chat_repository.dart';
import 'package:caribtap/listings/services/listing_activity_service.dart';
import 'package:caribtap/core/utils/helper.dart';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:rxdart/rxdart.dart';

class ChatFireStoreUtils extends ChatRepository {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  FirebaseFunctions functions = FirebaseFunctions.instance;
  Reference storage = FirebaseStorage.instance.ref();
  List<StreamSubscription> conversationsStreamSubs = [];
  List<StreamSubscription> chatStreamSubs = [];

  @override
  Future<void> archiveConversation(String channelID, String userID) async {
    DocumentReference docRef = firestore.collection(chatChannelsCollection).doc(channelID);
    DocumentSnapshot doc = await docRef.get();
    if (doc.exists) {
      bool isCurrentlyArchived = false;
      var data = doc.data() as Map<String, dynamic>;
      if (data.containsKey('isArchived') && data['isArchived'] is Map) {
        isCurrentlyArchived = data['isArchived'][userID] == true;
      }
      await docRef.update({'isArchived.$userID': !isCurrentlyArchived});
    }
  }

  @override
  Future<void> deleteConversation(String channelID, String userID) async {
    await firestore.collection(chatChannelsCollection).doc(channelID).update({
      'deletedFor': FieldValue.arrayUnion([userID]),
    });
  }

  @override
  Future<User?> getUserByID(String userID) async {
    DocumentSnapshot<Map<String, dynamic>> userDocument =
        await firestore.collection(usersCollection).doc(userID).get();
    if (userDocument.exists) {
      return User.fromJson(userDocument.data() ?? {});
    } else {
      return null;
    }
  }

  @override
  Future<MediaContainer> uploadChatImageToBackend(File image) async {
    File compressedImage = await _compressImage(image);
    var uniqueID = const Uuid().v4();
    Reference upload = storage.child('images/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(compressedImage);
    var streamSub = uploadTask.snapshotEvents.listen((event) {
      updateProgress(
          'Uploading image ${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)} /'
          '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
          'KB');
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    streamSub.cancel();
    return MediaContainer(
        mime: metaData.contentType ?? 'image', url: downloadUrl.toString());
  }

  @override
  Future<MediaContainer> uploadChatVideoToBackend(File video) async {
    var uniqueID = const Uuid().v4();
    File compressedVideo = await _compressVideo(video);
    Reference upload = storage.child('videos/$uniqueID.mp4');
    SettableMetadata metadata = SettableMetadata(contentType: 'video');
    UploadTask uploadTask = upload.putFile(compressedVideo, metadata);
    var streamSub = uploadTask.snapshotEvents.listen((event) {
      updateProgress(
          'Uploading video ${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)} /'
          '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
          'KB');
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    final uint8list = await VideoThumbnail.thumbnailFile(
        video: downloadUrl,
        thumbnailPath: (await getTemporaryDirectory()).path,
        imageFormat: ImageFormat.PNG);
    final file = File(uint8list!);
    String thumbnailDownloadUrl =
        await _uploadVideoThumbnailToFireStorage(file);
    streamSub.cancel();
    return MediaContainer(
        url: downloadUrl.toString(),
        mime: metaData.contentType ?? 'video',
        thumbnailURL: thumbnailDownloadUrl);
  }

  @override
  Future<MediaContainer> uploadAudioFileToBackend(File file) async {
    var uniqueID = const Uuid().v4();
    Reference upload = storage.child('audio/$uniqueID.mp3');
    SettableMetadata metadata = SettableMetadata(contentType: 'audio');
    UploadTask uploadTask = upload.putFile(file, metadata);
    var streamSub = uploadTask.snapshotEvents.listen((event) {
      updateProgress(
          'Uploading Audio ${(event.bytesTransferred.toDouble() / 1000).toStringAsFixed(2)} /'
          '${(event.totalBytes.toDouble() / 1000).toStringAsFixed(2)} '
          'KB');
    });
    uploadTask.whenComplete(() {}).catchError((onError) {
      debugPrint((onError as PlatformException).message);
    });
    var storageRef = (await uploadTask.whenComplete(() {})).ref;
    var downloadUrl = await storageRef.getDownloadURL();
    var metaData = await storageRef.getMetadata();
    streamSub.cancel();
    return MediaContainer(
        mime: metaData.contentType ?? 'audio', url: downloadUrl.toString());
  }

  @override
  Stream<List<ChatFeedModel>> listenToConversations({required String userID}) {
    debugPrint('[ChatDebug] listenToConversations started for: $userID');
    
    // Create individual streams
    final liveStream = firestore
        .collection(socialFeedsCollection)
        .doc(userID)
        .collection(chatFeedLiveCollection)
        .snapshots();

    final historicalStream = firestore
        .collection(socialFeedsCollection)
        .doc(userID)
        .collection('chat_feed')
        .snapshots();

    final chatChannelsStream = firestore
      .collection(chatChannelsCollection)
      .where('participantIds', arrayContains: userID)
      .snapshots();

    // Use combineLatest with explicit error handling and default values to prevent blocking
    return Rx.combineLatest3<QuerySnapshot<Map<String, dynamic>>, QuerySnapshot<Map<String, dynamic>>, QuerySnapshot<Map<String, dynamic>>, List<ChatFeedModel>>(
      liveStream.onErrorReturnWith((e, s) {
        debugPrint('[ChatDebug] LiveStream Error: $e');
        return emptySnapshot();
      }),
      historicalStream.onErrorReturnWith((e, s) {
         debugPrint('[ChatDebug] HistoricalStream Error: $e');
         return emptySnapshot();
      }),
      chatChannelsStream.onErrorReturnWith((e, s) {
         debugPrint('[ChatDebug] ChannelsStream Error: $e');
         return emptySnapshot();
      }),
      (live, historical, channels) {
        final Map<String, ChatFeedModel> conversationsMap = {};

        debugPrint('[ChatDebug] Streams Update - Live: ${live.docs.length}, Hist: ${historical.docs.length}, Chan: ${channels.docs.length}');

        void processDocs(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, String source) {
          for (var doc in docs) {
            try {
              final data = doc.data();
              final model = ChatFeedModel.fromJson(data, userID);
              if (model.id.isEmpty) model.id = doc.id;
              
              // Only add if it has some content or listing info
              if (model.id.isNotEmpty && (model.chatFeedContent.content.trim().isNotEmpty || model.listingTitle.isNotEmpty)) {
                  conversationsMap[model.id] = model;
              }
            } catch (e) {
              debugPrint('[ChatDebug] Error parsing $source doc ${doc.id}: $e');
            }
          }
        }

        processDocs(live.docs, 'LIVE');
        processDocs(historical.docs, 'HIST');
        processDocs(channels.docs, 'CHAN');

        final sortedList = conversationsMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        debugPrint('[ChatDebug] Emitting ${sortedList.length} conversations');
        return sortedList;
      },
    ).startWith([]); // Ensure it starts with something immediately
  }

  // Helper to provide an empty snapshot for error cases
  QuerySnapshot<Map<String, dynamic>> emptySnapshot() {
    return _EmptyQuerySnapshot();
  }

  @override
  Future<List<ChatFeedModel>> fetchConversations(
      {required String userID, required int page, required int size}) async {
    return [];
  }

  @override
  cleanConversationStreams() async {
    for (var streamSub in conversationsStreamSubs) {
      await streamSub.cancel();
    }
    conversationsStreamSubs.clear();
  }

  @override
  Future<ChannelDataModel> getChannelById(String channelID,
      List<User> channelParticipants, String currentUserID) async {
    ChannelDataModel channelModel;
    DocumentSnapshot<Map<String, dynamic>> channel =
        await firestore.collection(chatChannelsCollection).doc(channelID).get();
    if (channel.exists && channel.data() != null) {
      channelModel = ChannelDataModel.fromJson(channel.data()!, currentUserID);
      channelModel.participants = channelParticipants;
    } else {
      channelModel = ChannelDataModel(
        participants: channelParticipants,
        name: channelParticipants.isNotEmpty ? channelParticipants.first.fullName() : '',
        participantProfilePictureURLs: [
          if (channelParticipants.isNotEmpty)
            ChatFeedParticipantProfilePictureURL(
              participantId: channelParticipants.first.userID,
              profilePictureURL: channelParticipants.first.profilePictureURL,
            ),
        ],
      );
    }
    if (channelParticipants.isNotEmpty) {
      channelModel.name = channelParticipants.first.fullName();
    }
    return channelModel;
  }

  @override
  Stream<List<ChatFeedContent>> listenToMessages({required String channelID}) {
    return firestore
        .collection(chatChannelsCollection)
        .doc(channelID)
        .collection('thread')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((messagesSnapshot) {
      List<ChatFeedContent> messages = [];
      for (var messageDoc in messagesSnapshot.docs) {
        try {
          messages.add(ChatFeedContent.fromJson(messageDoc.data()));
        } catch (e, s) {
          debugPrint('ChatFireStoreUtils.listenToMessages $e, $s');
        }
      }
      return messages;
    });
  }

  @override
  Future<List<ChatFeedContent>> fetchOldMessages(
      {required String channelID, required int page, required int size}) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snapshot = await firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .collection('thread')
          .orderBy('createdAt', descending: true)
          .limit(size)
          .get();
      
      List<ChatFeedContent> messages = [];
      for (var messageDoc in snapshot.docs) {
        try {
          messages.add(ChatFeedContent.fromJson(messageDoc.data()));
        } catch (e, s) {
          debugPrint('ChatFireStoreUtils.fetchOldMessages $e $s');
        }
      }
      return messages;
    } catch (e, s) {
      debugPrint('ChatFireStoreUtils.fetchOldMessages error: $e $s');
      return [];
    }
  }

  @override
  Stream<ChannelDataModel> listenToChannelChanges(
      {required ChannelDataModel channelDataModel,
      required String currentUserID}) {
    return firestore
        .collection(chatChannelsCollection)
        .doc(channelDataModel.channelID)
        .snapshots()
        .map((newChannel) {
      try {
        if (newChannel.exists) {
          return ChannelDataModel.fromJson(newChannel.data() ?? {}, currentUserID);
        }
        return channelDataModel;
      } catch (e, s) {
        debugPrint('ChatFireStoreUtils.listenToChannelChanges $e $s');
        return channelDataModel;
      }
    });
  }

  @override
  Stream<User> listenToChatParticipants(
      {required ChannelDataModel channelDataModel,
      required String currentUserID}) async* {
    for (var user in channelDataModel.participants) {
      if (user.userID != currentUserID) {
        yield* firestore
            .collection(usersCollection)
            .doc(user.userID)
            .snapshots()
            .map((newUser) => User.fromJson(newUser.data() ?? {}));
      }
    }
  }

  @override
  cleanChatStreams() {
    for (var streamSub in chatStreamSubs) {
      streamSub.cancel();
    }
    chatStreamSubs.clear();
  }

  @override
  markAsRead(
          {required String channelID,
          required String currentUserID,
          required String messageID,
          required List<String> readUserIDs}) async {
    try {
      if (channelID.isEmpty) return;
      
      if (messageID.isNotEmpty) {
        await firestore
            .collection(chatChannelsCollection)
            .doc(channelID)
            .collection('thread')
            .doc(messageID)
            .update({
          'readUserIDs': readUserIDs,
        });
      }
      
      await firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .update({
        'readUserIDs': FieldValue.arrayUnion([currentUserID]),
      });

      // ALSO update the chat feed live entry so the unread indicator goes away
      await firestore
          .collection(socialFeedsCollection)
          .doc(currentUserID)
          .collection(chatFeedLiveCollection)
          .doc(channelID)
          .update({
        'markedAsRead': true,
      });
      
    } catch (e, s) {
      debugPrint('ChatFireStoreUtils.markAsRead error: $e $s');
    }
  }

  @override
  Future<bool> sendMessage({
    required ChannelDataModel channelDataModel,
    required ChatFeedContent message,
    required User currentUser,
  }) async {
    try {
      final channelID = channelDataModel.channelID;
      if (channelID.isEmpty) return false;

      // Batch write for atomicity
      WriteBatch batch = firestore.batch();
      
      DocumentReference msgRef = firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .collection('thread')
          .doc(message.id);
      batch.set(msgRef, message.toJson());
      
      DocumentReference channelRef = firestore.collection(chatChannelsCollection).doc(channelID);
      batch.set(channelRef, {
        'lastMessage': message.content,
        'lastMessageDate': FieldValue.serverTimestamp(), // Use server timestamp
        'participants': channelDataModel.participants.map((p) => p.toJson()).toList(),
         'participantIds': channelDataModel.participants.map((p) => p.userID).toList(),
      }, SetOptions(merge: true));

      // Update conversation feed for EACH participant
      List<User> allParticipants = List.from(channelDataModel.participants);
      if (!allParticipants.any((p) => p.userID == currentUser.userID)) {
        allParticipants.add(currentUser);
      }

      for (var participant in allParticipants) {
        DocumentReference feedRef = firestore
            .collection(socialFeedsCollection)
            .doc(participant.userID)
            .collection(chatFeedLiveCollection)
            .doc(channelID);
        debugPrint('[ChatDebug] Writing chatFeedLive for user: \\${participant.userID}, channel: \\${channelID}');
        batch.set(feedRef, {
          'id': channelID,
          'participants': allParticipants
              .where((p) => p.userID != participant.userID)
              .map((p) => p.toJson())
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'markedAsRead': participant.userID == message.senderID,
          'content': message.content, // Summary text
          'lastMessage': message.toJson(), // Full last message model
          'listingId': channelDataModel.listingId ?? '',
          'listingTitle': channelDataModel.listingTitle ?? '',
          'listingImage': channelDataModel.listingImage ?? '',
        }, SetOptions(merge: true));
      }

      await batch.commit();

      // Record activity if this message is about a listing
      if (channelDataModel.listingId != null && channelDataModel.listingId!.isNotEmpty) {
        try {
          final activityService = ListingActivityService();
          await activityService.recordMessage(
            channelDataModel.listingId!,
            message.senderID,
          );
        } catch (e) {
          // Log but don't fail the message if activity tracking fails
          debugPrint('Activity tracking error: $e');
        }
      }

      // Push notifications are handled server-side by Cloud Functions
      // to avoid exposing FCM server credentials in the client app.
      return true;
    } catch (e, s) {
      debugPrint('ChatFireStoreUtils.sendMessage $e $s');
      return false;
    }
  }

  @override
  createChannel(
      {required ChannelDataModel channelDataModel,
      required User currentUser}) async {
    try {
      if (channelDataModel.isGroupChat) {
        channelDataModel.admins = [];
      } else {
        channelDataModel.admins = null;
      }
      
      bool hasCurrentUser = channelDataModel.participants.any((p) => p.userID == currentUser.userID);
      if (!hasCurrentUser) {
        channelDataModel.participants.add(currentUser);
      }
      
        debugPrint('[ChatDebug] Creating chat channel: \\${channelDataModel.channelID}');
        await firestore
          .collection(chatChannelsCollection)
          .doc(channelDataModel.channelID)
          .set({
        'id': channelDataModel.channelID,
        'channelID': channelDataModel.channelID,
        'name': channelDataModel.name,
        'creatorID': channelDataModel.creatorID,
        'participants': channelDataModel.participants.map((p) => p.toJson()).toList(),
           'participantIds': channelDataModel.participants.map((p) => p.userID).toList(),
        'participantProfilePictureURLs': channelDataModel.participantProfilePictureURLs
            .map((p) => {'profilePictureURL': p.profilePictureURL, 'participantId': p.participantId})
            .toList(),
        'lastMessage': channelDataModel.lastMessage,
        'lastMessageDate': FieldValue.serverTimestamp(),
        'readUserIDs': channelDataModel.readUserIDs,
        'createdAt': FieldValue.serverTimestamp(),
        'admins': channelDataModel.admins,
        'listingId': channelDataModel.listingId ?? '',
        'listingTitle': channelDataModel.listingTitle ?? '',
        'listingImage': channelDataModel.listingImage ?? '',
      });
      
      for (var participant in channelDataModel.participants) {
        debugPrint('[ChatDebug] Creating chatFeedLive for user: \\${participant.userID}, channel: \\${channelDataModel.channelID}');
        await firestore
            .collection(socialFeedsCollection)
            .doc(participant.userID)
            .collection(chatFeedLiveCollection)
            .doc(channelDataModel.channelID)
            .set({
          'id': channelDataModel.channelID,
          'participants': channelDataModel.participants
              .where((p) => p.userID != participant.userID)
              .map((p) => p.toJson())
              .toList(),
          'createdAt': FieldValue.serverTimestamp(),
          'markedAsRead': participant.userID == currentUser.userID,
          'content': '',
          'listingId': channelDataModel.listingId ?? '',
          'listingTitle': channelDataModel.listingTitle ?? '',
          'listingImage': channelDataModel.listingImage ?? '',
        });
      }
    } catch (e, s) {
      debugPrint('ChatFireStoreUtils.createChannel error: $e $s');
    }
  }

  Future<String> _uploadVideoThumbnailToFireStorage(File file) async {
    var uniqueID = const Uuid().v4();
    File compressedImage = await _compressImage(file);
    Reference upload = storage.child('thumbnails/$uniqueID.png');
    UploadTask uploadTask = upload.putFile(compressedImage);
    var downloadUrl =
        await (await uploadTask.whenComplete(() {})).ref.getDownloadURL();
    return downloadUrl.toString();
  }

  Future<File> _compressImage(File file) async {
    if (kIsWeb) {
      return file;
    }

    File compressedImage = await FlutterNativeImage.compressImage(
      file.path,
      quality: 25,
    );
    return compressedImage;
  }

  Future<File> _compressVideo(File file) async {
    MediaInfo? info = await VideoCompress.compressVideo(file.path,
        quality: VideoQuality.DefaultQuality,
        deleteOrigin: false,
        includeAudio: true,
        frameRate: 24);
    if (info != null) {
      File compressedVideo = File(info.path!);
      return compressedVideo;
    } else {
      return file;
    }
  }
}

// Mock class to satisfy return types for empty streams
class _EmptyQuerySnapshot implements QuerySnapshot<Map<String, dynamic>> {
  @override
  List<QueryDocumentSnapshot<Map<String, dynamic>>> get docs => [];
  @override
  List<DocumentChange<Map<String, dynamic>>> get docChanges => [];
  @override
  SnapshotMetadata get metadata => _MockMetadata();
  @override
  int get size => 0;
}

class _MockMetadata implements SnapshotMetadata {
  @override
  bool get hasPendingWrites => false;
  @override
  bool get isFromCache => false;
}

