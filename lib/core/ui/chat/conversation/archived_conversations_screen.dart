import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/model/chat_feed_model.dart';
import 'package:caribtap/core/model/channel_data_model.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/chat/chat/chat_screen.dart';
import 'package:caribtap/core/ui/chat/api/conversations_data_factory.dart';
import 'package:caribtap/core/ui/chat/conversation/conversation_bloc.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/listings_user.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ArchivedConversationsScreen extends StatefulWidget {
  final ListingsUser user;

  const ArchivedConversationsScreen({super.key, required this.user});

  @override
  State createState() => _ArchivedConversationsScreenState();
}

class _ArchivedConversationsScreenState extends State<ArchivedConversationsScreen> {
  late ListingsUser user;
  List<ChatFeedModel> _archivedConversations = [];
  ConversationsDataFactory conversationsDataFactory = ConversationsDataFactory();

  @override
  void initState() {
    super.initState();
    user = widget.user;
    context.read<ConversationsBloc>().add(InitConversationsEvent());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocListener<ConversationsBloc, ConversationsState>(
      listener: (context, state) {
        if (state is UpdateLiveConversationsState) {
          conversationsDataFactory.newLiveConversations = state.liveConversations;
          _updateConversationList();
        } else if (state is NewConversationsPageState) {
          conversationsDataFactory.appendHistoricalConversations(state.newPage);
          _updateConversationList();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? Colors.black : Colors.white,
          title: Text('Archived Conversations'.tr()),
        ),
        body: RefreshIndicator(
          color: Color(colorPrimary),
          onRefresh: () async {
            context.read<ConversationsBloc>().add(InitConversationsEvent());
          },
          child: _archivedConversations.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.separated(
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: _archivedConversations.length,
                  itemBuilder: (context, index) {
                    final conversation = _archivedConversations[index];
                    return _buildDismissibleConversationItem(conversation);
                  },
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 84,
                    endIndent: 16,
                    color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05),
                  ),
                ),
        ),
      ),
    );
  }

  void _updateConversationList() {
    final allConversations = conversationsDataFactory
        .getAllConversations()
        .where((c) => c.id.isNotEmpty && (c.chatFeedContent.content.trim().isNotEmpty || c.listingTitle.isNotEmpty))
        .where((c) => !c.deletedFor.contains(user.userID))
        .where((c) => c.isArchived[user.userID] == true)
        .toList();
    setState(() {
      _archivedConversations = allConversations;
    });
  }

  Widget _buildDismissibleConversationItem(ChatFeedModel conversation) {
    return Dismissible(
      key: ValueKey(conversation.id),
      background: Container(
        color: Colors.orange,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: 20),
            child: Icon(Icons.unarchive, color: Colors.white),
          ),
        ),
      ),
      secondaryBackground: Container(
        color: Colors.red,
        child: const Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: EdgeInsets.only(right: 20),
            child: Icon(Icons.delete, color: Colors.white),
          ),
        ),
      ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          context.read<ConversationsBloc>().add(ArchiveConversationEvent(channelID: conversation.id, userID: user.userID));
        } else {
          context.read<ConversationsBloc>().add(DeleteConversationEvent(channelID: conversation.id, userID: user.userID));
        }
      },
      child: _ConversationItem(
        key: ValueKey(conversation.id + (conversation.markedAsRead ? 'read' : 'unread') + conversation.chatFeedContent.content),
        conversation: conversation,
        currentUserId: user.userID,
        chatAvailabilityHours: user.settings.chatAvailabilityHours,
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.archive, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text(
            'No Archived Conversations',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ).tr(),
        ],
      ),
    );
  }
}

class _ConversationItem extends StatefulWidget {
  final ChatFeedModel conversation;
  final String currentUserId;
  final String chatAvailabilityHours;

  const _ConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    required this.chatAvailabilityHours,
  });

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem> {
  User? _otherUser;
  StreamSubscription? _userSub;

  String _formatHoursSummary(String hours) {
    final trimmed = hours.trim();
    if (trimmed.isEmpty) return 'Hours not set'.tr();
    final lines = trimmed.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty).toList();
    if (lines.isEmpty) return 'Hours not set'.tr();
    if (lines.length <= 2) return lines.join('\n');
    return '${lines[0]}\n${lines[1]}\n...';
  }

  Future<String> _fetchListingHours() async {
    final listingId = widget.conversation.listingId.trim();
    if (listingId.isEmpty) return '';
    try {
      final doc = await FirebaseFirestore.instance.collection(listingsCollection).doc(listingId).get();
      return doc.data()?['openingHours']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _showHoursDialog() async {
    try {
      final hours = await _fetchListingHours();
      final summary = _formatHoursSummary(hours);
      if (!mounted) return;
      final isDark = Theme.of(context).brightness == Brightness.dark;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          title: Text('Chat Hours'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
          content: Text(summary, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('OK'.tr(), style: TextStyle(color: Theme.of(context).primaryColor)),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing hours dialog: $e');
    }
  }

  bool _isChatAvailableNow(String hoursString) {
    final trimmed = hoursString.trim();
    if (trimmed.isEmpty) return true;
    
    final lower = trimmed.toLowerCase();
    if (lower.contains('24/7') || lower.contains('always open')) return true;
    
    final now = DateTime.now();
    final weekday = now.weekday;
    final currentMinutes = now.hour * 60 + now.minute;
    final dayNames = const ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    String? lineForDay;
    for (final line in trimmed.split('\n')) {
      final matched = dayNames.firstWhereOrNull((d) => line.startsWith('$d:'));
      if (matched != null && dayNames.indexOf(matched) + 1 == weekday) {
        lineForDay = line;
        break;
      }
    }
    
    if (lineForDay == null) return true;
    
    final content = lineForDay.split(':').sublist(1).join(':').trim();
    if (content.toLowerCase() == 'closed') return false;
    
    final parts = content.split(content.contains('→') ? '→' : '-');
    if (parts.length != 2) return true;
    
    try {
      final open = DateFormat.jm().parse(parts[0].trim());
      final close = DateFormat.jm().parse(parts[1].trim());
      final openMinutes = open.hour * 60 + open.minute;
      final closeMinutes = close.hour * 60 + close.minute;
      
      if (closeMinutes < openMinutes) {
        return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
      }
      return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } catch (_) {
      return true;
    }
  }

  Future<void> _showClosedDialog() async {
    final hours = await _fetchListingHours();
    final summary = _formatHoursSummary(hours);
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        title: Text('Business Closed'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This business is currently closed.'.tr(), style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
            const SizedBox(height: 16),
            Text('Hours:'.tr(), style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(summary, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text('OK'.tr(), style: TextStyle(color: Theme.of(context).primaryColor)),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _initUserListener();
  }

  void _initUserListener() {
    final otherUserFromModel = widget.conversation.participants.firstWhereOrNull((p) => p.userID != widget.currentUserId);
    if (otherUserFromModel != null && otherUserFromModel.profilePictureURL.isNotEmpty) {
       _otherUser = otherUserFromModel;
    }

    final otherUserId = otherUserFromModel?.userID;
    if (otherUserId != null) {
      _userSub = FirebaseFirestore.instance
          .collection(usersCollection)
          .doc(otherUserId)
          .snapshots()
          .listen((snap) {
        if (snap.exists && mounted) {
          setState(() {
            _otherUser = User.fromJson(snap.data()!);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUnread = !widget.conversation.markedAsRead;
    
    final displayName = widget.conversation.title;
    final lastMsg = widget.conversation.chatFeedContent.content;
    final lastMsgDate = (widget.conversation.chatFeedContent.createdAt > widget.conversation.createdAt)
        ? widget.conversation.chatFeedContent.createdAt
        : widget.conversation.createdAt;
    final timeStr = lastMsgDate > 0 
        ? DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(lastMsgDate))
        : '';

    final isActive = _otherUser?.active ?? false;
    final profilePic = _otherUser?.profilePictureURL ?? '';
    final listingLogo = widget.conversation.listingImage;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isUnread 
            ? (isDark ? Color(colorPrimary).withOpacity(0.12) : Color(colorPrimary).withOpacity(0.07)) 
            : Colors.transparent,
        border: isUnread 
            ? Border(left: BorderSide(color: Color(colorPrimary), width: 4))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () async {
                final hoursString = await _fetchListingHours();
                if (!mounted) return;
                
                if (!_isChatAvailableNow(hoursString)) {
                  await _showClosedDialog();
                  return;
                }
                
                push(
                  context,
                  ChatWrapperWidget(
                    channelDataModel: ChannelDataModel(
                      id: widget.conversation.id,
                      participants: widget.conversation.participants,
                      participantProfilePictureURLs: widget.conversation.chatFeedContent.participantProfilePictureURLs,
                      name: widget.conversation.title,
                      channelID: widget.conversation.id,
                      lastMessage: widget.conversation.chatFeedContent,
                      lastMessageDate: widget.conversation.chatFeedContent.createdAt,
                      lastThreadMessageId: widget.conversation.chatFeedContent.id,
                      listingId: widget.conversation.listingId,
                      listingTitle: widget.conversation.listingTitle,
                      listingImage: widget.conversation.listingImage,
                    ),
                    currentUser: ListingsUser(userID: widget.currentUserId),
                    colorPrimary: Color(colorPrimary),
                    colorAccent: Color(colorAccent),
                  ),
                );
              },
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Stack(
                      children: [
                        Center(
                          child: Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isUnread ? Color(colorPrimary).withOpacity(0.5) : Colors.transparent,
                                width: 2
                              ),
                              color: Colors.white,
                            ),
                            child: listingLogo.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      listingLogo,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                    ),
                                  )
                                : Icon(Icons.store, size: 32, color: Colors.grey[400]),
                          ),
                        ),
                        if (profilePic.isNotEmpty)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                              ),
                              child: ClipOval(
                                child: displayCircleImage(profilePic, 22, false),
                              ),
                            ),
                          ),
                        if (isActive)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2.5),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: isUnread ? FontWeight.w900 : FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: isUnread ? Color(colorPrimary) : Colors.grey,
                                fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        if (widget.conversation.listingTitle.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              widget.conversation.listingTitle,
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(colorPrimary).withOpacity(0.9),
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                lastMsg,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: isUnread 
                                      ? (isDark ? Colors.white : Colors.black87) 
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Chat Hours'.tr(),
            icon: Icon(Icons.info_outline, size: 18, color: isDark ? Colors.white70 : Colors.black45),
            onPressed: () => _showHoursDialog(),
          ),
        ],
      ),
    );
  }
}
