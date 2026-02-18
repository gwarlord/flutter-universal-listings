import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:caribtap/core/model/channel_data_model.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/chat/chat/chat_screen.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listings_user.dart';

class FirestoreChatScreen extends StatefulWidget {
  final ListingsUser user;
  final String chatId; // This is the recipient's userID
  final String listingId;
  final String listingTitle;
  final String listingImage;

  const FirestoreChatScreen({
    Key? key,
    required this.user,
    required this.chatId,
    required this.listingId,
    required this.listingTitle,
    required this.listingImage,
  }) : super(key: key);

  @override
  State<FirestoreChatScreen> createState() => _FirestoreChatScreenState();
}

class _FirestoreChatScreenState extends State<FirestoreChatScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      // 1. Generate channel ID unique per listing
      String channelID;
      List<String> ids = [widget.user.userID, widget.chatId];
      ids.sort();
      channelID = ids.join() + '_${widget.listingId}';

      // 2. Fetch recipient data
      final recipientDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.chatId)
          .get();

      if (!recipientDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Recipient user not found.";
        });
        return;
      }

      final recipient = User.fromJson(recipientDoc.data()!);

      // 3. Create ChannelDataModel for the native UI
      // Ensure channelID matches what ChatBloc uses to listen
      final channelData = ChannelDataModel(
        id: channelID,
        channelID: channelID,
        name: recipient.fullName(),
        participants: [recipient, widget.user],
        creatorID: widget.user.userID,
        listingId: widget.listingId,
        listingTitle: widget.listingTitle,
        listingImage: widget.listingImage,
      );

      if (!mounted) return;

      // 4. Navigate to the app's native Chat UI
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatWrapperWidget(
            channelDataModel: channelData,
            currentUser: widget.user,
            colorPrimary: Color(colorPrimary),
            colorAccent: Color(colorAccent),
          ),
        ),
      );
    } catch (e) {
      debugPrint('[ERROR] FirestoreChatScreen: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "Failed to initialize chat.";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Center(
        child: _errorMessage != null
            ? Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            : const CircularProgressIndicator.adaptive(),
      ),
    );
  }
}
