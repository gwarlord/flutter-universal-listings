import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:easy_localization/easy_localization.dart';

class FirestoreChatScreenV2 extends StatefulWidget {
  final String channelId;
  final String currentUserId;
  final User? currentUser;
  final String listingTitle;
  final String listingImage;
  final List<User> otherParticipants;

  const FirestoreChatScreenV2({
    Key? key,
    required this.channelId,
    required this.currentUserId,
    this.currentUser,
    required this.listingTitle,
    required this.listingImage,
    this.otherParticipants = const [],
  }) : super(key: key);

  @override
  State<FirestoreChatScreenV2> createState() => _FirestoreChatScreenV2State();
}

class _FirestoreChatScreenV2State extends State<FirestoreChatScreenV2> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  late final CollectionReference _messagesRef;
  StreamSubscription? _messagesSubscription;
  bool _isSending = false;
  List<User> _fullParticipants = [];

  @override
  void initState() {
    super.initState();
    _messagesRef = FirebaseFirestore.instance
        .collection(chatChannelsCollection)
        .doc(widget.channelId)
        .collection('thread');
    
    _fetchParticipantDetails();
    _markAsRead();

    _messagesSubscription = _messagesRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(_onMessageSnapshot);
  }

  Future<void> _fetchParticipantDetails() async {
    final Map<String, User> participantsById = {};

    void upsertParticipant(User candidate) {
      final id = candidate.userID.trim();
      if (id.isEmpty) return;
      final existing = participantsById[id];
      if (existing == null) {
        participantsById[id] = candidate;
        return;
      }

      // Prefer the record that has a profile image and a more complete name.
      final existingNameLen = existing.fullName().trim().length;
      final candidateNameLen = candidate.fullName().trim().length;
      final candidateHasBetterProfile =
          existing.profilePictureURL.isEmpty && candidate.profilePictureURL.isNotEmpty;
      final candidateHasBetterName = candidateNameLen > existingNameLen;

      if (candidateHasBetterProfile || candidateHasBetterName) {
        participantsById[id] = candidate;
      }
    }

    if (widget.currentUser != null) {
      upsertParticipant(widget.currentUser!);
    }

    for (var user in widget.otherParticipants) {
      final participantId = user.userID.trim();
      if (participantId.isEmpty) continue;

      if (user.profilePictureURL.isEmpty) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(participantId)
            .get();
        if (userDoc.exists) {
          upsertParticipant(User.fromJson(userDoc.data()!));
        } else {
          upsertParticipant(user);
        }
      } else {
        upsertParticipant(user);
      }
    }

    if (mounted) {
      setState(() {
        _fullParticipants = participantsById.values.toList();
      });
    }
  }

  void _markAsRead() async {
    try {
      final feedRef = FirebaseFirestore.instance
          .collection(socialFeedsCollection)
          .doc(widget.currentUserId)
          .collection(chatFeedLiveCollection)
          .doc(widget.channelId);
      
      await feedRef.set({
        'markedAsRead': true,
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection(chatChannelsCollection)
          .doc(widget.channelId)
          .update({
        'readUserIDs': FieldValue.arrayUnion([widget.currentUserId]),
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  void _onMessageSnapshot(QuerySnapshot snapshot) {
    final messages = snapshot.docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return {
        'id': doc.id,
        'content': data['content'] ?? '',
        'senderID': data['senderID'] ?? '',
        'createdAt': data['createdAt'],
      };
    }).toList();
    if (mounted) {
      setState(() {
        _messages = messages;
      });
    }
  }

  void _handleSendPressed() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;
    
    setState(() => _isSending = true);
    _controller.clear();
    HapticFeedback.lightImpact();
    
    final serverTimestamp = FieldValue.serverTimestamp();
    
    try {
        await _messagesRef.add({
        'content': text,
        'createdAt': serverTimestamp,
        'senderID': widget.currentUserId,
        'readUserIDs': [widget.currentUserId],
        });

        Set<String> participantIdsSet = {widget.currentUserId};
        for (var p in _fullParticipants) {
          participantIdsSet.add(p.userID);
        }
        List<String> finalParticipantIds = participantIdsSet.toList();

        final lastMessageObj = {
        'content': text,
        'senderID': widget.currentUserId,
        'createdAt': serverTimestamp,
        'readUserIDs': [widget.currentUserId],
        };

        final channelDocRef = FirebaseFirestore.instance
            .collection(chatChannelsCollection)
            .doc(widget.channelId);

        final channelSnap = await channelDocRef.get();
        
        await channelDocRef.set({
        'id': widget.channelId,
        'channelID': widget.channelId,
        'lastMessage': lastMessageObj,
        'lastMessageDate': serverTimestamp,
        'participantIds': finalParticipantIds,
        'participants': _fullParticipants.map((u) => u.toJson()).toList(),
        'listingTitle': widget.listingTitle,
        'listingImage': widget.listingImage,
        'readUserIDs': [widget.currentUserId],
        'createdAt': channelSnap.exists ? (channelSnap.data()?['createdAt'] ?? serverTimestamp) : serverTimestamp,
        }, SetOptions(merge: true));

        for (final userId in finalParticipantIds) {
        final feedRef = FirebaseFirestore.instance
            .collection(socialFeedsCollection)
            .doc(userId)
            .collection(chatFeedLiveCollection)
            .doc(widget.channelId);
        
        await feedRef.set({
            'id': widget.channelId,
            'createdAt': serverTimestamp,
            'markedAsRead': userId == widget.currentUserId,
            'content': text,
            'lastMessage': lastMessageObj,
            'listingTitle': widget.listingTitle,
            'listingImage': widget.listingImage,
            'participantIds': finalParticipantIds,
        }, SetOptions(merge: true));
        }
    } finally {
        if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;
    final accentColor = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF09131D) : const Color(0xFFF6FAFC),
      appBar: AppBar(
        elevation: 1,
        centerTitle: true,
        backgroundColor: isDark ? const Color(0xFF1F2C34) : Color(colorPrimary),
        iconTheme: IconThemeData(color: Colors.white),
        leadingWidth: 150,
        leading: Row(
          children: [
            const BackButton(),
            if (widget.listingImage.isNotEmpty)
              CircleAvatar(
                radius: 15,
                backgroundImage: CachedNetworkImageProvider(widget.listingImage),
              ),
            const SizedBox(width: 4),
            if (widget.listingTitle.isNotEmpty)
              Expanded(
                child: Text(
                  widget.listingTitle,
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
              ),
          ],
        ),
        title: Text(
          'CaribTap Chat'.tr(),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Center(
              child: SizedBox(
                height: 30,
                child: _fullParticipants.isEmpty
                    ? const SizedBox.shrink()
                    : ListView.separated(
                        shrinkWrap: true,
                        scrollDirection: Axis.horizontal,
                        itemCount: _fullParticipants.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 4),
                        itemBuilder: (context, index) {
                          final participant = _fullParticipants[index];
                          final isCurrentUser = participant.userID == widget.currentUserId;
                          final hasProfilePic = participant.profilePictureURL.isNotEmpty;
                          final hasListingImage = widget.listingImage.isNotEmpty;

                          ImageProvider? backgroundImage;
                          Widget? child;

                          if (hasProfilePic) {
                            backgroundImage = CachedNetworkImageProvider(participant.profilePictureURL);
                          } else if (isCurrentUser && hasListingImage) {
                            backgroundImage = CachedNetworkImageProvider(widget.listingImage);
                          } else {
                            child = Text(
                              participant.firstName.isNotEmpty ? participant.firstName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                            );
                          }

                          return CircleAvatar(
                            radius: 15,
                            backgroundImage: backgroundImage,
                            child: child,
                          );
                        },
                      ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF08111A),
                          const Color(0xFF0E1C2A),
                          const Color(0xFF102331),
                        ]
                      : [
                          const Color(0xFFF9FCFE),
                          const Color(0xFFF2F8FB),
                          const Color(0xFFEAF3F8),
                        ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(
              painter: ChatBackgroundPainter(
                primary: primaryColor,
                accent: accentColor,
                isDark: isDark,
                textDirection: Directionality.of(context),
              ),
            ),
          ),
          Column(
            children: [
              Expanded(
                child: _messages.isEmpty
                    ? _buildEmptyState(isDark)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 8),
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg['senderID'] == widget.currentUserId;
                          return _buildMessageBubble(
                              msg, isMe, primaryColor, isDark);
                        },
                      ),
              ),
              _buildInputBar(primaryColor, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 64, color: isDark ? Colors.white24 : Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No messages yet'.tr(),
            style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[700],
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      Map<String, dynamic> msg, bool isMe, Color primaryColor, bool isDark) {
    final timestamp = msg['createdAt'] as Timestamp?;
    final timeStr =
        timestamp != null ? DateFormat('hh:mm a').format(timestamp.toDate()) : '';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFDCF8C6))
              : (isDark ? const Color(0xFF1F2C34) : Colors.white),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 1,
                offset: const Offset(0, 1))
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  _fullParticipants
                      .firstWhere(
                        (user) => user.userID == msg['senderID'],
                        orElse: () => User(firstName: 'Unknown'),
                      )
                      .fullName(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.lightBlue[200] : primaryColor,
                    fontSize: 12,
                  ),
                ),
              ),
            Text(
              msg['content'] ?? '',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                fontSize: 10,
                color:
                    isDark ? Colors.white.withOpacity(0.5) : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: isDark ? const Color(0xFF1F2C34) : const Color(0xFFF0F0F0),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A3942) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  maxLines: 4,
                  minLines: 1,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Type a message...'.tr(),
                    hintStyle: TextStyle(
                        color:
                            isDark ? const Color(0xFF8696A0) : Colors.grey[500]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: _handleSendPressed,
              child: CircleAvatar(
                radius: 22,
                backgroundColor:
                    isDark ? const Color(0xFF00A884) : primaryColor,
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messagesSubscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class ChatBackgroundPainter extends CustomPainter {
  final Color primary;
  final Color accent;
  final bool isDark;
  final ui.TextDirection textDirection;
  ChatBackgroundPainter({
    required this.primary,
    required this.accent,
    required this.isDark,
    required this.textDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final blobAlpha = isDark ? 0.18 : 0.12;
    final lineAlpha = isDark ? 0.16 : 0.11;
    final dotAlpha = isDark ? 0.14 : 0.1;

    final Paint topBlob = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.15, height * 0.1),
        width * 0.45,
        [
          primary.withOpacity(blobAlpha),
          primary.withOpacity(0),
        ],
      );

    final Paint bottomBlob = Paint()
      ..shader = ui.Gradient.radial(
        Offset(width * 0.85, height * 0.85),
        width * 0.5,
        [
          accent.withOpacity(blobAlpha * 0.95),
          accent.withOpacity(0),
        ],
      );

    canvas.drawRect(Offset.zero & size, topBlob);
    canvas.drawRect(Offset.zero & size, bottomBlob);

    final Paint wavePaint = Paint()
      ..color = primary.withOpacity(lineAlpha)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const double spacing = 90;
    for (double y = -40; y < height + spacing; y += spacing) {
      final path = Path()..moveTo(-40, y);
      path.quadraticBezierTo(width * 0.25, y + 26, width * 0.5, y + 10);
      path.quadraticBezierTo(width * 0.75, y - 12, width + 40, y + 14);
      canvas.drawPath(path, wavePaint);
    }

    final Paint dotPaint = Paint()
      ..color = accent.withOpacity(dotAlpha)
      ..style = PaintingStyle.fill;

    const double step = 34;
    for (double x = 12; x < width; x += step) {
      for (double y = 20; y < height; y += step) {
        final bool skip = ((x ~/ step) + (y ~/ step)) % 3 == 0;
        if (!skip) {
          canvas.drawCircle(Offset(x, y), 1.15, dotPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant ChatBackgroundPainter oldDelegate) =>
      oldDelegate.primary != primary ||
      oldDelegate.accent != accent ||
      oldDelegate.isDark != isDark ||
      oldDelegate.textDirection != textDirection;
}
