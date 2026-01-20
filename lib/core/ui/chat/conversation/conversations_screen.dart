import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:instaflutter/constants.dart';
import 'package:instaflutter/core/model/chat_feed_model.dart';
import 'package:instaflutter/core/ui/chat/api/chat_api_manager.dart';
import 'package:instaflutter/core/ui/chat/api/conversations_data_factory.dart';
import 'package:instaflutter/core/ui/chat/conversation/conversation_bloc.dart';
import 'package:instaflutter/core/ui/chat/group_conversation_tile.dart';
import 'package:instaflutter/core/ui/chat/private_conversation_tile.dart';
import 'package:instaflutter/listings/listings_app_config.dart';
import 'package:instaflutter/listings/model/listings_user.dart';

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
  // FIX 1: Use late final for modern PagingController initialization
  late final PagingController<int, ChatFeedModel> _conversationsController;
  ConversationsDataFactory conversationsDataFactory =
      ConversationsDataFactory();
  int pageSize = pageSizeLimit;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    
    // FIX 1: UPGRADED PagingController INITIALIZATION with fetchPage
    _conversationsController = PagingController<int, ChatFeedModel>(
     
      fetchPage: (pageKey) {
        final completer = Completer<List<ChatFeedModel>>();

        // Call the Bloc event, using the Completer to signal when data is ready
        context.read<ConversationsBloc>().add(FetchConversationsPageEvent(
              page: pageKey,
              size: pageSize,
              completer: completer, // Assuming the event/bloc handles this
            ));
        return completer.future;
      },
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
    );
    // FIX 2: Removed addPageRequestListener
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConversationsBloc, ConversationsState>(
      listener: (context, state) {
        if (state is UpdateLiveConversationsState) {
          conversationsDataFactory.newLiveConversations =
              state.liveConversations;
              
          // FIX 3: Replaced _conversationsController.itemList = ... with copyWith
          final allConversations =
              conversationsDataFactory.getAllConversations();
          _conversationsController.value = _conversationsController.value.copyWith(
            pages: [allConversations],
            hasNextPage: true,
            keys: [0],
            error: null,
            isLoading: false,
          );
        } else if (state is NewConversationsPageState) {
          final isLastPage = state.newPage.length < pageSize;
          
          // FIX 3: Replaced direct manipulation with state copy
          final existingPages = _conversationsController.value.pages ?? [];
          final newPageIds = Set.from(state.newPage.map((c) => c.id));
          
          // 1. Remove duplicates from existing pages
          final List<List<ChatFeedModel>> updatedPages = existingPages
              .map((page) =>
                  page.where((c) => !newPageIds.contains(c.id)).toList())
              .toList();
              
          // 2. Add the new page
          updatedPages.add(state.newPage);

          // 3. Update keys 
          final newKeys = [
            ...?_conversationsController.value.keys,
            state.oldPageKey
          ];

          _conversationsController.value = _conversationsController.value.copyWith(
            pages: updatedPages,
            keys: newKeys,
            hasNextPage: !isLastPage,
            error: null,
            isLoading: false,
          );
          
          conversationsDataFactory.appendHistoricalConversations(state.newPage);
        } else if (state is ConversationsPageErrorState) {
          // FIX 3: Replaced _conversationsController.error = ... with copyWith
          _conversationsController.value = _conversationsController.value.copyWith(
            error: state.error,
            isLoading: false,
          );
        }
      },
      builder: (context, state) {
        return GestureDetector(
          onTap: () {
            final FocusScopeNode currentScope = FocusScope.of(context);
            if (!currentScope.hasPrimaryFocus && currentScope.hasFocus) {
              FocusManager.instance.primaryFocus!.unfocus();
            }
          },
          child: RefreshIndicator(
            onRefresh: () async {
              _conversationsController.refresh();
            },
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // FIX 4: Wrap PagedSliverList in PagingListener
                PagingListener(
                  controller: _conversationsController,
                  builder: (context, state, fetchNextPage) =>
                      PagedSliverList<int, ChatFeedModel>.separated(
                    state: state,
                    fetchNextPage: fetchNextPage,
                    builderDelegate: PagedChildBuilderDelegate(
                      invisibleItemsThreshold: 5,
                      animateTransitions: true,
                      noItemsFoundIndicatorBuilder: (context) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 80,
                                color: Colors.grey.withOpacity(0.3),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'No Conversations Yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ).tr(),
                              const SizedBox(height: 12),
                              Text(
                                'Start chatting with sellers and buyers by visiting listings',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ).tr(),
                            ],
                          ),
                        ),
                      ),
                      firstPageProgressIndicatorBuilder: (context) =>
                          const Center(
                        child: CircularProgressIndicator.adaptive(),
                      ),
                      itemBuilder: (context, conversation, index) =>
                          _buildConversationRow(conversation),
                    ),
                    separatorBuilder: (context, index) => const Divider()),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  _buildConversationRow(ChatFeedModel chatFeedModel) {
    String user1Image = '';
    String user2Image = '';
    if (chatFeedModel.participants.length >= 2) {
      user1Image = chatFeedModel.participants.first.profilePictureURL;
      user2Image = chatFeedModel.participants.elementAt(1).profilePictureURL;
    }
    if (chatFeedModel.isGroupChat) {
      // FIX 5: Removed 'const' keyword to resolve the color error
      return GroupConversationTile(
        colorAccent: Color(colorAccent),
        colorPrimary: Color(colorPrimary),
        currentUser: user,
        chatFeedModel: chatFeedModel,
        membersImages: [user1Image, user2Image],
      );
    } else {
      // FIX 5: Removed 'const' keyword to resolve the color error
      return PrivateConversationTile(
        colorAccent: Color(colorAccent),
        colorPrimary: Color(colorPrimary),
        currentUser: user,
        chatFeedModel: chatFeedModel,
      );
    }
  }

  @override
  void dispose() {
    _conversationsController.dispose();
    super.dispose();
  }
}