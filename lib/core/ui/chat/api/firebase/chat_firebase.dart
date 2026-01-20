// ignore_for_file: body_might_complete_normally_catch_error

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_image_v2/flutter_native_image_v2.dart';

import 'package:http/http.dart' as http;
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/model/channel_data_model.dart';
import 'package:instaflutter/core/model/chat_feed_model.dart';
import 'package:instaflutter/core/model/media_container.dart';
import 'package:instaflutter/core/model/user.dart';
import 'package:instaflutter/core/ui/chat/api/chat_repository.dart';
import 'package:instaflutter/core/utils/helper.dart';

import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ChatFireStoreUtils extends ChatRepository {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  FirebaseFunctions functions = FirebaseFunctions.instance;
  Reference storage = FirebaseStorage.instance.ref();
  List<StreamSubscription> conversationsStreamSubs = [];
  List<StreamSubscription> chatStreamSubs = [];

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
  Stream<List<ChatFeedModel>> listenToConversations(
      {required String userID}) async* {
    StreamController<List<ChatFeedModel>> conversationsStream =
        StreamController<List<ChatFeedModel>>();
    var liveConversationsStreamSub = firestore
        .collection(socialFeedsCollection)
        .doc(userID)
        .collection(chatFeedLiveCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshots) {
      List<ChatFeedModel> chatConversations = [];
      for (var channel in snapshots.docs) {
        try {
          ChatFeedModel conversation =
              ChatFeedModel.fromJson(channel.data(), userID);
          chatConversations.add(conversation);
        } catch (e, s) {
          debugPrint('ChatFireStoreUtils.listenToConversations $e, $s');
        }
      }
      conversationsStream.add(chatConversations);
    });
    conversationsStreamSubs.add(liveConversationsStreamSub);
    yield* conversationsStream.stream;
  }

  @override
  Future<List<ChatFeedModel>> fetchConversations(
      {required String userID, required int page, required int size}) async {
    try {
      // Direct Firestore query instead of cloud function
      // This returns empty as we rely on listenToConversations for live updates
      // Pagination would require more complex Firestore queries
      return [];
    } catch (e, s) {
      debugPrint('ChatFireStoreUtils.fetchConversations error: $e $s');
      return [];
    }
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
    } else {
      channelModel = ChannelDataModel(
        participants: channelParticipants,
        name: channelParticipants.first.fullName(),
        participantProfilePictureURLs: [
          ChatFeedParticipantProfilePictureURL(
            participantId: channelParticipants.first.userID,
            profilePictureURL: channelParticipants.first.profilePictureURL,
          ),
        ],
      );
    }
    channelModel.name = channelParticipants.first.fullName();
    return channelModel;
  }

  @override
  Stream<List<ChatFeedContent>> listenToMessages(
      {required String channelID}) async* {
    StreamController<List<ChatFeedContent>> messagesStream = StreamController();
    var messagesStreamSub = firestore
        .collection(chatChannelsCollection)
        .doc(channelID)
        .collection('thread')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((messagesSnapshot) {
      List<ChatFeedContent> messages = [];
      for (var messageDoc in messagesSnapshot.docs) {
        try {
          ChatFeedContent message = ChatFeedContent.fromJson(messageDoc.data());
          messages.add(message);
        } catch (e, s) {
          debugPrint('ChatFireStoreUtils.listenToMessages $e, $s');
        }
      }
      messagesStream.add(messages);
    });
    chatStreamSubs.add(messagesStreamSub);
    yield* messagesStream.stream;
  }

  @override
  Future<List<ChatFeedContent>> fetchOldMessages(
      {required String channelID, required int page, required int size}) async {
    try {
      // Direct Firestore query instead of cloud function
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
          ChatFeedContent message = ChatFeedContent.fromJson(messageDoc.data());
          messages.add(message);
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
      required String currentUserID}) async* {
    StreamController<ChannelDataModel> channelChangeStreamController =
        StreamController();
    var channelStreamSub = firestore
        .collection(chatChannelsCollection)
        .doc(channelDataModel.channelID)
        .snapshots()
        .listen((newChannel) {
      try {
        ChannelDataModel newChannelDataModel =
            ChannelDataModel.fromJson(newChannel.data() ?? {}, currentUserID);
        channelChangeStreamController.add(newChannelDataModel);
      } catch (e, s) {
        debugPrint('ChatFireStoreUtils.listenToChannelChanges $e $s');
      }
    });
    chatStreamSubs.add(channelStreamSub);
    yield* channelChangeStreamController.stream;
  }

  @override
  Stream<User> listenToChatParticipants(
      {required ChannelDataModel channelDataModel,
      required String currentUserID}) async* {
    StreamController<User> participantsStreamController = StreamController();
    for (var user in channelDataModel.participants) {
      if (user.userID != currentUserID) {
        var participantStreamSub = firestore
            .collection(usersCollection)
            .doc(user.userID)
            .snapshots()
            .listen((newUser) {
          try {
            participantsStreamController
                .add(User.fromJson(newUser.data() ?? {}));
          } catch (e, s) {
            debugPrint('ChatFireStoreUtils.listenToChatParticipants $e $s');
          }
        });
        chatStreamSubs.add(participantStreamSub);
      }
    }
    yield* participantsStreamController.stream;
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
      // Guard against empty channelID
      if (channelID.isEmpty) {
        debugPrint('ChatFireStoreUtils.markAsRead: channelID is empty, skipping');
        return;
      }
      
      // Direct Firestore update instead of cloud function
      await firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .collection('thread')
          .doc(messageID)
          .update({
        'readUserIDs': readUserIDs,
      });
      
      // Update channel last read
      await firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .update({
        'readUserIDs': FieldValue.arrayUnion([currentUserID]),
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
      // Direct Firestore write instead of cloud function
      final channelID = channelDataModel.channelID;
      
      // Add message to thread collection (single source of truth)
      await firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .collection('thread')
          .doc(message.id)
          .set(message.toJson());
      
      // Update channel with last message
      await firestore
          .collection(chatChannelsCollection)
          .doc(channelID)
          .set({
        'lastMessage': message.content,
        'lastMessageDate': message.createdAt,
        'participants': channelDataModel.participants.map((p) => p.userID).toList(),
      }, SetOptions(merge: true));

      // Update conversation feed for each participant
      for (var participant in channelDataModel.participants) {
        await firestore
            .collection(socialFeedsCollection)
            .doc(participant.userID)
            .collection(chatFeedLiveCollection)
            .doc(channelID)
            .set({
          'id': channelID,
          'participants': channelDataModel.participants
              .where((p) => p.userID != participant.userID)
              .map((p) => p.toJson())
              .toList(),
          'createdAt': message.createdAt,
          'markedAsRead': participant.userID == message.senderID,
          'content': message.toJson(),
        }, SetOptions(merge: true));
      }

      // Send push notifications
      if (channelDataModel.channelID.contains(message.senderID)) {
        if (channelDataModel
            .participants.first.settings.allowPushNotifications) {
          await sendNotification(
            channelDataModel.participants.first.pushToken,
            channelDataModel.name,
            message.content,
            <String, dynamic>{
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'id': '1',
              'status': 'done',
              'channelDataModel': channelDataModel.toJson(currentUser),
            },
          );
        }
      } else {
        for (var friend in channelDataModel.participants) {
          if (friend.settings.allowPushNotifications) {
            await sendNotification(
              friend.pushToken,
              channelDataModel.name,
              message.content,
              <String, dynamic>{
                'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                'id': '1',
                'status': 'done',
                'channelDataModel': channelDataModel.toJson(currentUser),
              },
            );
          }
        }
      }
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
      
      // Ensure both participants are in the list (sender and recipient)
      bool hasCurrentUser = channelDataModel.participants.any((p) => p.userID == currentUser.userID);
      if (!hasCurrentUser) {
        channelDataModel.participants.add(currentUser);
      }
      
      // Direct Firestore write instead of cloud function
      await firestore
          .collection(chatChannelsCollection)
          .doc(channelDataModel.channelID)
          .set({
        'id': channelDataModel.channelID,
        'channelID': channelDataModel.channelID,
        'name': channelDataModel.name,
        'creatorID': channelDataModel.creatorID,
        'participants': channelDataModel.participants.map((p) => p.userID).toList(),
        'participantProfilePictureURLs': channelDataModel.participantProfilePictureURLs
            .map((p) => {'profilePictureURL': p.profilePictureURL, 'participantId': p.participantId})
            .toList(),
        'lastMessage': channelDataModel.lastMessage,
        'lastMessageDate': channelDataModel.lastMessageDate,
        'readUserIDs': channelDataModel.readUserIDs,
        'createdAt': Timestamp.now().seconds,
        'admins': channelDataModel.admins,
      });
      
      // Create chat feed entries for each participant
      for (var participant in channelDataModel.participants) {
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
          'createdAt': Timestamp.now().seconds,
          'markedAsRead': false,
          'content': {
            'content': '',
            'createdAt': Timestamp.now().seconds,
          },
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

  /// compress image file to make it load faster but with lower quality,
  /// change the quality parameter to control the quality of the image after
  /// being compressed(100 = max quality - 0 = low quality)
  /// @param file the image file that will be compressed
  /// @return File a new compressed file with smaller size
  Future<File> _compressImage(File file) async {
    File compressedImage = await FlutterNativeImage.compressImage(
      file.path,
      quality: 25,
    );
    return compressedImage;
  }

  /// compress video file to make it load faster but with lower quality,
  /// change the quality parameter to control the quality of the video after
  /// being compressed
  /// @param file the video file that will be compressed
  /// @return File a new compressed file with smaller size
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

sendNotification(String token, String title, String body,
    Map<String, dynamic>? payload) async {
  await http.post(
    Uri.parse('https://fcm.googleapis.com/fcm/send'),
    headers: <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'key=$serverKey',
    },
    body: jsonEncode(
      <String, dynamic>{
        'notification': <String, dynamic>{'body': body, 'title': title},
        'priority': 'high',
        'data': payload ?? <String, dynamic>{},
        'to': token
      },
    ),
  );
}
