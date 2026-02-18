import 'dart:async';
import 'package:flutter/material.dart';
// LEGACY: To be deleted after migration
import 'package:flutter_chat_ui/flutter_chat_ui.dart' as chat_ui;
import 'package:flutter_chat_ui/flutter_chat_ui.dart' show InMemoryChatController;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:uuid/uuid.dart';

class FirestoreChatScreenLegacy extends StatefulWidget {
  final String channelId;
  final types.User currentUser;
  final List<String> participantIds;

  const FirestoreChatScreenLegacy({
    Key? key,
    required this.channelId,
    required this.currentUser,
    required this.participantIds,
  }) : super(key: key);

  @override
  State<FirestoreChatScreenLegacy> createState() => _FirestoreChatScreenLegacyState();
}

class _FirestoreChatScreenLegacyState extends State<FirestoreChatScreenLegacy> {
  final List<types.Message> _messages = [];
  late final CollectionReference _messagesRef;
  StreamSubscription? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _messagesRef = FirebaseFirestore.instance
      .collection(chatChannelsCollection)
      .doc(widget.channelId)
      .collection('thread');
    _messagesSubscription = _messagesRef
      .orderBy('createdAt', descending: true)
      .snapshots()
      .listen(_onMessageSnapshot);
  }

  void _onMessageSnapshot(QuerySnapshot snapshot) {
    final List<types.Message> messages = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      int createdAtMs;
      if (data['createdAt'] is Timestamp) {
        createdAtMs = (data['createdAt'] as Timestamp).millisecondsSinceEpoch;
      } else if (data['createdAt'] is int) {
        createdAtMs = data['createdAt'];
        if (createdAtMs < 100000000000) createdAtMs *= 1000;
      } else {
        createdAtMs = DateTime.now().millisecondsSinceEpoch;
      }

      return types.TextMessage(
        id: doc.id,
        author: types.User(id: data['senderID'] ?? ''),
        createdAt: createdAtMs,
        text: data['content'] ?? '',
      );
    }).toList();

    if (mounted) {
      setState(() {
        _messages.clear();
        _messages.addAll(messages);
      });
    }
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    super.dispose();
  }

  void _handleSendPressed(types.PartialText message) async {
    final text = message.text;
    final serverTimestamp = FieldValue.serverTimestamp();
    final messageId = const Uuid().v4();
    
    await _messagesRef.doc(messageId).set({
      'id': messageId,
      'content': text,
      'createdAt': serverTimestamp,
      'senderID': widget.currentUser.id,
    });

    final channelDoc = FirebaseFirestore.instance
        .collection(chatChannelsCollection)
        .doc(widget.channelId);
    
    await channelDoc.set({
      'participantIds': widget.participantIds,
      'lastMessage': text,
      'lastMessageDate': serverTimestamp,
    }, SetOptions(merge: true));

    WriteBatch batch = FirebaseFirestore.instance.batch();
    for (var participantId in widget.participantIds) {
      DocumentReference feedRef = FirebaseFirestore.instance
          .collection(socialFeedsCollection)
          .doc(participantId)
          .collection(chatFeedLiveCollection)
          .doc(widget.channelId);
      
      batch.set(feedRef, {
        'id': widget.channelId,
        'content': text,
        'createdAt': serverTimestamp,
        'markedAsRead': participantId == widget.currentUser.id,
        'lastMessage': {
          'content': text,
          'senderID': widget.currentUser.id,
          'createdAt': serverTimestamp,
        },
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    // LEGACY: This screen is deprecated and will be deleted. UI removed to fix build error.
    return Scaffold(
      appBar: AppBar(title: const Text('Legacy Chat (To Delete)')),
      body: const Center(
        child: Text('This legacy chat screen is deprecated and will be removed.'),
      ),
    );
  }
}
