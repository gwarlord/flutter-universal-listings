import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/model/chat_feed_model.dart';
import 'package:instaflutter/core/model/channel_data_model.dart';
import 'package:instaflutter/core/model/user.dart';
import 'package:instaflutter/core/ui/chat/chat/chat_screen.dart';
import 'package:instaflutter/core/ui/chat/api/chat_api_manager.dart';
import 'package:instaflutter/core/ui/chat/api/conversations_data_factory.dart';
import 'package:instaflutter/core/ui/chat/conversation/conversation_bloc.dart';
import 'package:instaflutter/core/utils/helper.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';
import 'package:collection/collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConversationsWrapperWidget extends StatelessWidget {
  const ConversationsWrapperWidget({super.key, required this.user});
  final ListingsUser user;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) => ConversationsBloc(
            chatRepository: chatApiManager, currentUser: user),
        child: ConversationsScreen(user: user));
  }
}

class ConversationsScreen extends StatefulWidget {
  final ListingsUser user;

  const ConversationsScreen({super.key, required this.user});

  @override
  State createState() {
    return _ConversationsState();
  }
}

class _ConversationsState extends State<ConversationsScreen> {
  late ListingsUser user;
  late final PagingController<int, ChatFeedModel> _conversationsController;
  ConversationsDataFactory conversationsDataFactory = ConversationsDataFactory();
  int pageSize = pageSizeLimit;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ConversationsBloc>().add(InitConversationsEvent());
    });
    
    _conversationsController = PagingController<int, ChatFeedModel>(
      fetchPage: (pageKey) {
        final completer = Completer<List<ChatFeedModel>>();
        context.read<ConversationsBloc>().add(FetchConversationsPageEvent(
          page: pageKey,
          size: pageSize,
          completer: completer,
        ));
        return completer.future;
      },
      getNextPageKey: (state) => state.lastPageIsEmpty ? null : state.nextIntPageKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return BlocConsumer<ConversationsBloc, ConversationsState>(
      listener: (context, state) {
        if (state is UpdateLiveConversationsState) {
          conversationsDataFactory.newLiveConversations = state.liveConversations;
          final allConversations = conversationsDataFactory.getAllConversations()
                .where((c) => c.id.isNotEmpty && (c.chatFeedContent.content.trim().isNotEmpty || c.listingTitle.isNotEmpty))
                .toList();
          _conversationsController.value = _conversationsController.value.copyWith(
            pages: [allConversations],
            hasNextPage: true,
            keys: [0],
            error: null,
            isLoading: false,
          );
        } else if (state is NewConversationsPageState) {
          final isLastPage = state.newPage.length < pageSize;
          final existingPages = _conversationsController.value.pages ?? [];
          final newPageIds = Set.from(state.newPage.map((c) => c.id));
          
          final List<List<ChatFeedModel>> updatedPages = existingPages
              .map((page) => page.where((c) => !newPageIds.contains(c.id)).toList())
              .toList();
              
          updatedPages.add(state.newPage);
          final newKeys = [...?_conversationsController.value.keys, state.oldPageKey];

          _conversationsController.value = _conversationsController.value.copyWith(
            pages: updatedPages,
            keys: newKeys,
            hasNextPage: !isLastPage,
            error: null,
            isLoading: false,
          );
          conversationsDataFactory.appendHistoricalConversations(state.newPage);
        } else if (state is ConversationsPageErrorState) {
          _conversationsController.value = _conversationsController.value.copyWith(
            error: state.error,
            isLoading: false,
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? Colors.black : Colors.white,
          body: RefreshIndicator(
            color: Color(colorPrimary),
            onRefresh: () async {
              _conversationsController.refresh();
              context.read<ConversationsBloc>().add(InitConversationsEvent());
            },
            child: PagingListener(
              controller: _conversationsController,
              builder: (context, state, fetchNextPage) => PagedListView<int, ChatFeedModel>.separated(
                padding: const EdgeInsets.only(top: 8),
                state: state,
                fetchNextPage: fetchNextPage,
                builderDelegate: PagedChildBuilderDelegate(
                  animateTransitions: true,
                  noItemsFoundIndicatorBuilder: (context) => _buildEmptyState(isDark),
                  firstPageProgressIndicatorBuilder: (context) => const Center(child: CircularProgressIndicator.adaptive()),
                  itemBuilder: (context, conversation, index) => _ConversationItem(
                    key: ValueKey(conversation.id + (conversation.markedAsRead ? 'read' : 'unread') + conversation.chatFeedContent.content),
                    conversation: conversation,
                    currentUserId: user.userID,
                  ),
                ),
                separatorBuilder: (context, index) => Divider(
                  height: 1, 
                  indent: 84, 
                  endIndent: 16, 
                  color: isDark ? Colors.white12 : Colors.black.withOpacity(0.05)
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text(
            'No Conversations Yet',
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

  const _ConversationItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
  });

  @override
  State<_ConversationItem> createState() => _ConversationItemState();
}

class _ConversationItemState extends State<_ConversationItem> {
  User? _otherUser;
  StreamSubscription? _userSub;

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

    return InkWell(
      onTap: () {
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
      child: Container(
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
            // Branded Avatar
            SizedBox(
              width: 60,
              height: 60,
              child: Stack(
                children: [
                  // Main: Listing Logo
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
                  // Overlay: Profile Picture (bottom right)
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
                  // Active Status Indicator (RED DOT)
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
            // Text Area
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
    );
  }
}
