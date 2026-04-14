import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:caribtap/constants.dart';
import 'package:caribtap/core/model/channel_data_model.dart';
import 'package:caribtap/core/model/chat_feed_model.dart';
import 'package:caribtap/core/model/user.dart';
import 'package:caribtap/core/ui/chat/api/chat_api_manager.dart';
import 'package:caribtap/core/ui/chat/api/messages_data_factory.dart';
import 'package:caribtap/core/ui/chat/chat/chat_bloc.dart';
import 'package:caribtap/core/ui/chat/player_widget.dart';
import 'package:caribtap/core/ui/full_screen_image_viewer/full_screen_image_viewer.dart';
import 'package:caribtap/core/ui/full_screen_video_viewer/full_screen_video_viewer.dart';
import 'package:caribtap/core/ui/loading/loading_cubit.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/core/utils/user_report/api/api_manager.dart';
import 'package:caribtap/core/utils/user_report/api/user_report_repository.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firestore_chat_screen_v2.dart';

String activeNow = 'Active now'.tr();
String lastSeenOn = 'Last seen'.tr();

class ChatWrapperWidget extends StatelessWidget {
  final ChannelDataModel channelDataModel;
  final User currentUser;
  final Color colorPrimary;
  final Color colorAccent;

  const ChatWrapperWidget({
    super.key,
    required this.channelDataModel,
    required this.currentUser,
    required this.colorPrimary,
    required this.colorAccent,
  });

  @override
  Widget build(BuildContext context) {
    return FirestoreChatScreenV2(
      channelId: channelDataModel.channelID,
      currentUserId: currentUser.userID,
      currentUser: currentUser,
      listingTitle: channelDataModel.listingTitle ?? '',
      listingImage: channelDataModel.listingImage ?? '',
      otherParticipants: channelDataModel.participants,
    );
  }
}

class ChatScreen extends StatefulWidget {
  final ChannelDataModel channelDataModel;
  final User currentUser;
  final Color colorPrimary;
  final Color colorAccent;

  const ChatScreen({
    super.key,
    required this.channelDataModel,
    required this.currentUser,
    required this.colorPrimary,
    required this.colorAccent,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // Local list to keep track of loaded messages for day separator logic
  List<ChatFeedContent> _loadedMessages = [];
  final ScrollController _scrollController = ScrollController();
  late User currentUser;
  final TextEditingController _messageController = TextEditingController();
  RecordingState currentRecordingState = RecordingState.hidden;
  String audioMessageTime = 'Start Recording'.tr(), subtitleText = '';
  late final PagingController<int, ChatFeedContent> _pagingController;

  bool isFirstPage = true;
  int pageSize = pageSizeLimit;
  late ChannelDataModel channelDataModel;
  MessagesDataFactory messagesDataFactory = MessagesDataFactory();

  @override
  void initState() {
    super.initState();
    channelDataModel = widget.channelDataModel;
    currentUser = widget.currentUser;

    // DEBUG: Log group chat setup
    debugPrint(
        'GROUP_CHAT_DEBUG: isGroupChat=${channelDataModel.isGroupChat}, participants=${channelDataModel.participants.length}, currentUserID=$currentUser');
    for (var p in channelDataModel.participants) {
      debugPrint('  - Participant: ${p.userID} (${p.firstName} ${p.lastName})');
    }

    subtitleText =
        channelDataModel.participants.isNotEmpty && channelDataModel.participants.first.active
            ? activeNow
            : channelDataModel.participants.isNotEmpty
                ? '$lastSeenOn ${formatTimestamp(channelDataModel.participants.first.lastOnlineTimestamp, lastSeen: true)}'
                : '';

    _pagingController = PagingController<int, ChatFeedContent>(
      fetchPage: (pageKey) {
        final completer = Completer<List<ChatFeedContent>>();

        context.read<ChatBloc>().add(
              FetchMessagesPageEvent(
                page: pageKey,
                size: pageSize,
                completer: completer,
              ),
            );

        return completer.future;
      },
      getNextPageKey: (state) =>
          state.lastPageIsEmpty ? null : state.nextIntPageKey,
    );

    // Listen to page changes and update _loadedMessages
    _pagingController.addListener(() {
      final pages = _pagingController.value.pages;
      if (pages != null) {
        // Flatten all pages into a single list and sort by createdAt ascending (oldest first)
        final allMessages = pages.expand((page) => page).toList();
        allMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        setState(() {
          _loadedMessages = allMessages;
        });
        // Optionally scroll to bottom when new messages arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController
                .jumpTo(_scrollController.position.maxScrollExtent);
          }
        });
      }
    });

    context
        .read<ChatBloc>()
        .add(SetupChatListeners(channelDataModel: channelDataModel));

    // START LIVE MESSAGE LISTENER (NON-BLOCKING)
    context.read<ChatBloc>().add(StartLiveMessagesListenerEvent());

    if (!channelDataModel.readUserIDs.contains(currentUser.userID) &&
        channelDataModel.id.isNotEmpty) {
      channelDataModel.readUserIDs.add(currentUser.userID);
      context.read<ChatBloc>().add(
            MarkChatAsReadEvent(
              channelID: channelDataModel.id,
              currentUserID: currentUser.userID,
              messageID: channelDataModel.lastThreadMessageId,
              readUserIDs: channelDataModel.readUserIDs,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: BlocConsumer<ChatBloc, ChatState>(
          listener: (context, state) {
            if (state is ChannelUpdatedStream) {
              channelDataModel = state.channelDataModel;
            } else if (state is ParticipantsUpdatedStream) {
              channelDataModel.participants.removeWhere(
                (element) => element.userID == state.updatedUser.userID,
              );
            }
          },
          buildWhen: (old, current) =>
              (current is ChannelUpdatedStream ||
                  current is ParticipantsUpdatedStream) &&
              old != current,
          builder: (context, state) {
            String? statusText;
            if (channelDataModel.participants.isNotEmpty) {
              final first = channelDataModel.participants.first;
              if (first.active) {
                statusText = activeNow;
              } else if (first.lastOnlineTimestamp != null) {
                statusText =
                    '$lastSeenOn ${formatTimestamp(first.lastOnlineTimestamp, lastSeen: true)}';
              }
            }
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (channelDataModel.listingTitle != null &&
                    channelDataModel.listingTitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2.0),
                    child: Text(
                      channelDataModel.listingTitle!,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                Text(
                  channelDataModel.name,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (statusText != null && statusText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            );
          },
        ),
        backgroundColor: isDarkMode(context) ? null : widget.colorPrimary,
        actionsIconTheme: IconThemeData(
          color: isDarkMode(context) ? Colors.grey.shade200 : Colors.white,
        ),
        iconTheme: IconThemeData(
          color: isDarkMode(context) ? Colors.grey.shade200 : Colors.white,
        ),
        actions: [
          PopupMenuButton<int>(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode(context) ? Colors.grey.shade200 : Colors.white,
            ),
            onSelected: (value) {
              switch (value) {
                case 0:
                  _onPrivateChatSettingsClick();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<int>(
                value: 0,
                child: Row(
                  children: [
                    Icon(
                      Icons.settings,
                      size: 20,
                      color: isDarkMode(context)
                          ? Colors.grey.shade200
                          : Colors.black87,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Settings'.tr(),
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) async {
          if (state is UpdateLiveMessagesState) {
            messagesDataFactory.newLiveMessages = state.liveMessages;
            final allMessages = messagesDataFactory.getAllMessages();

            final initialKey = _pagingController.value.keys?.isNotEmpty ?? false
                ? _pagingController.value.keys!.first
                : 0;

            _pagingController.value = _pagingController.value.copyWith(
              pages: [allMessages],
              keys: [initialKey],
              hasNextPage: true,
              error: null,
              isLoading: false,
            );
          } else if (state is NewMessagesPageState) {
            final isLastPage = state.newPage.length < pageSize;

            final existingPages = _pagingController.value.pages ?? [];
            final Set<String> newPageIds =
                Set.from(state.newPage.map((m) => m.id));

            final List<List<ChatFeedContent>> updatedPages = existingPages
                .map(
                  (page) =>
                      page.where((m) => !newPageIds.contains(m.id)).toList(),
                )
                .toList();

            updatedPages.add(state.newPage);

            final newKeys = [
              ...?_pagingController.value.keys,
              state.oldPageKey
            ];

            _pagingController.value = _pagingController.value.copyWith(
              pages: updatedPages,
              keys: newKeys,
              hasNextPage: !isLastPage,
              error: null,
              isLoading: false,
            );
            messagesDataFactory.appendHistoricalMessages(state.newPage);
          } else if (state is MessagesPageErrorState) {
            _pagingController.value = _pagingController.value.copyWith(
              error: state.error,
              isLoading: false,
            );
          } else if (state is ChatErrorState) {
            context.read<LoadingCubit>().hideLoading();
            showSnackBar(context, state.errorMessage);
          } else if (state is MediaSelectedState) {
            if (state.mediaType == imageMediaType) {
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Uploading image...'.tr(),
                    false,
                    widget.colorPrimary,
                  );
              context
                  .read<ChatBloc>()
                  .add(SendImageMessageEvent(image: state.mediaFile));
            } else if (state.mediaType == videoMediaType) {
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Uploading video...'.tr(),
                    false,
                    widget.colorPrimary,
                  );
              context
                  .read<ChatBloc>()
                  .add(SendVideoMessageEvent(video: state.mediaFile));
            }
          } else if (state is MediaUploadDoneState) {
            context.read<LoadingCubit>().hideLoading();
          } else if (state is RecordingViewVisibleState) {
            FocusScope.of(context).unfocus();
          } else if (state is UserReportDoneState) {
            context.read<LoadingCubit>().hideLoading();
            await showAlertDialog(context, 'Success'.tr(), state.message);
            if (!context.mounted) return;
            Navigator.pop(context);
          }
        },
        buildWhen: (old, current) =>
            current.runtimeType != UpdateAppBarState && old != current,
        builder: (context, state) {
          if (state is RestartStream) {
            channelDataModel = state.channelDataModel;
            isFirstPage = true;
            _pagingController.refresh();
          } else if (state is RecordingViewVisibleState) {
            currentRecordingState = RecordingState.visible;
          } else if (state is RecordCancelState) {
            audioMessageTime = 'Start Recording'.tr();
            currentRecordingState = RecordingState.visible;
          } else if (state is RecordSentState) {
            context.read<LoadingCubit>().hideLoading();
            audioMessageTime = 'Start Recording'.tr();
            currentRecordingState = RecordingState.hidden;
          } else if (state is RecordingViewHiddenState) {
            currentRecordingState = RecordingState.hidden;
          } else if (state is RecordingAudioState) {
            currentRecordingState = RecordingState.recording;
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0, right: 8, bottom: 8),
              child: Column(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        context.read<ChatBloc>().add(
                              MicClickedEvent(
                                recordingState: RecordingState.visible,
                              ),
                            );
                      },
                      child: PagingListener(
                        controller: _pagingController,
                        builder: (context, state, fetchNextPage) =>
                            PagedListView<int, ChatFeedContent>(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          state: state,
                          fetchNextPage: fetchNextPage,
                          reverse:
                              false, // Show oldest at top, newest at bottom
                          scrollController: _scrollController,
                          builderDelegate:
                              PagedChildBuilderDelegate<ChatFeedContent>(
                            invisibleItemsThreshold: 5,
                            noItemsFoundIndicatorBuilder: (_) => Center(
                              child: const Text('No Messages Yet.').tr(),
                            ),
                            firstPageProgressIndicatorBuilder: (_) =>
                                const Center(
                              child: CircularProgressIndicator.adaptive(),
                            ),
                            itemBuilder: (context, message, index) {
                              // Use the local _loadedMessages for day separator logic
                              final messages = _loadedMessages;
                              bool showDaySeparator = false;
                              String? dayString;

                              final currDate =
                                  DateTime.fromMillisecondsSinceEpoch(
                                      message.createdAt);

                              if (index == 0) {
                                showDaySeparator = true;
                              } else {
                                final prevMsg = messages[index - 1];
                                final prevDate =
                                    DateTime.fromMillisecondsSinceEpoch(
                                        prevMsg.createdAt);
                                if (currDate.year != prevDate.year ||
                                    currDate.month != prevDate.month ||
                                    currDate.day != prevDate.day) {
                                  showDaySeparator = true;
                                }
                              }

                              if (showDaySeparator) {
                                final now = DateTime.now();
                                if (currDate.year == now.year &&
                                    currDate.month == now.month &&
                                    currDate.day == now.day) {
                                  dayString = 'Today'.tr();
                                } else if (currDate.year == now.year &&
                                    currDate.month == now.month &&
                                    currDate.day == now.day - 1) {
                                  dayString = 'Yesterday'.tr();
                                } else {
                                  dayString =
                                      DateFormat('MMMM d, yyyy').format(currDate);
                                }
                              }

                              return Column(
                                children: [
                                  if (showDaySeparator && dayString != null)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6, horizontal: 16),
                                            decoration: BoxDecoration(
                                              color: isDarkMode(context)
                                                  ? Colors.white10
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              dayString,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDarkMode(context)
                                                    ? Colors.white70
                                                    : Colors.black54,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  buildMessage(
                                    message,
                                    channelDataModel.participants,
                                    showTime: true,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _onCameraClick,
                          icon: Icon(
                            Icons.camera_alt,
                            color: widget.colorPrimary,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2.0, right: 2),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: ShapeDecoration(
                                shape: const OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(360)),
                                  borderSide: BorderSide.none,
                                ),
                                color: isDarkMode(context)
                                    ? Colors.grey[700]
                                    : Colors.grey.shade200,
                              ),
                              child: Row(
                                children: [
                                  InkWell(
                                    onTap: () => context.read<ChatBloc>().add(
                                          MicClickedEvent(
                                            recordingState:
                                                currentRecordingState,
                                          ),
                                        ),
                                    child: Icon(
                                      Icons.mic,
                                      color: currentRecordingState ==
                                              RecordingState.hidden
                                          ? widget.colorPrimary
                                          : Colors.red,
                                    ),
                                  ),
                                  Expanded(
                                    child: TextField(
                                      onChanged: (s) =>
                                          context.read<ChatBloc>().add(
                                                TextUpdateEvent(
                                                  isTextEmpty: s.isEmpty,
                                                ),
                                              ),
                                      onTap: () {
                                        context.read<ChatBloc>().add(
                                              MicClickedEvent(
                                                recordingState:
                                                    RecordingState.visible,
                                              ),
                                            );
                                      },
                                      textAlignVertical:
                                          TextAlignVertical.center,
                                      controller: _messageController,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                        hintText: 'Start typing'.tr(),
                                        hintStyle: TextStyle(
                                          color: Colors.grey[400],
                                        ),
                                        focusedBorder:
                                            const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(360),
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder:
                                            const OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(360),
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      maxLines: 5,
                                      minLines: 1,
                                      keyboardType: TextInputType.multiline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        BlocBuilder<ChatBloc, ChatState>(
                          buildWhen: (old, current) =>
                              current is TextUpdateState && old != current,
                          builder: (context, state) {
                            return IconButton(
                              icon: Icon(
                                Icons.send,
                                color: state is TextUpdateState &&
                                        state.isTextEmpty
                                    ? widget.colorPrimary
                                        .withAlpha((0.5 * 255).toInt())
                                    : widget.colorPrimary,
                              ),
                              onPressed: () async {
                                if (_messageController.text.isNotEmpty) {
                                  context.read<ChatBloc>().add(
                                        SendTextMessageEvent(
                                          messageContent: _messageController
                                              .text
                                              .trim(),
                                        ),
                                      );
                                  _messageController.clear();
                                }
                              },
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  _buildAudioMessageRecorder(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAudioMessageRecorder() {
    return Visibility(
      visible: currentRecordingState != RecordingState.hidden,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * .3,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                return Expanded(
                  child: Center(
                    child: Text(
                      state is RecordTimerUpdateState
                          ? state.updatedAudioTime
                          : 'Start Recording'.tr(),
                    ),
                  ),
                );
              },
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Stack(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Visibility(
                            visible:
                                currentRecordingState == RecordingState.recording,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.colorPrimary,
                                padding:
                                    const EdgeInsets.only(top: 12, bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                  side: BorderSide.none,
                                ),
                              ),
                              child: const Text(
                                'Send',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ).tr(),
                              onPressed: () {
                                context
                                    .read<ChatBloc>()
                                    .add(SendAudioMessageEvent());
                                context.read<LoadingCubit>().showLoading(
                                      context,
                                      'Uploading Audio...'.tr(),
                                      false,
                                      widget.colorPrimary,
                                    );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Visibility(
                            visible:
                                currentRecordingState == RecordingState.recording,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                                padding:
                                    const EdgeInsets.only(top: 12, bottom: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25.0),
                                  side: BorderSide.none,
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ).tr(),
                              onPressed: () => context
                                  .read<ChatBloc>()
                                  .add(RecordCancelEvent()),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Visibility(
                        visible: currentRecordingState == RecordingState.visible,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding:
                                const EdgeInsets.only(top: 12, bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25.0),
                              side: BorderSide.none,
                            ),
                          ),
                          child: const Text(
                            'Record',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ).tr(),
                          onPressed: () => context
                              .read<ChatBloc>()
                              .add(StartRecordingEvent()),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget buildSubTitle(User friend) {
    subtitleText = friend.active
        ? activeNow
        : '$lastSeenOn ${formatTimestamp(friend.lastOnlineTimestamp, lastSeen: true)}';
    return Text(
      subtitleText,
      style: TextStyle(fontSize: 15, color: Colors.grey.shade200),
    );
  }

  _onCameraClick() {
    context
        .read<ChatBloc>()
        .add(MicClickedEvent(recordingState: RecordingState.visible));

    showCupertinoModalPopup(
      context: context,
      builder: (actionSheetContext) => CupertinoActionSheet(
        message: const Text(
          'Send Media',
          style: TextStyle(fontSize: 15.0),
        ).tr(),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Choose image from gallery').tr(),
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              context.read<ChatBloc>().add(
                    AddMediaToChatEvent(
                      mediaSource: galleryMediaSource,
                      mediaType: imageMediaType,
                    ),
                  );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Choose video from gallery').tr(),
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              context.read<ChatBloc>().add(
                    AddMediaToChatEvent(
                      mediaSource: galleryMediaSource,
                      mediaType: videoMediaType,
                    ),
                  );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Take a picture').tr(),
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              context.read<ChatBloc>().add(
                    AddMediaToChatEvent(
                      mediaSource: cameraMediaSource,
                      mediaType: imageMediaType,
                    ),
                  );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Record video').tr(),
            onPressed: () async {
              Navigator.pop(actionSheetContext);
              context.read<ChatBloc>().add(
                    AddMediaToChatEvent(
                      mediaSource: cameraMediaSource,
                      mediaType: videoMediaType,
                    ),
                  );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel').tr(),
          onPressed: () {
            Navigator.pop(actionSheetContext);
          },
        ),
      ),
    );
  }

  Widget buildMessage(ChatFeedContent messageData, List<User> members,
      {bool showTime = true}) {
    Widget messageWidget;
    if (messageData.senderID == currentUser.userID) {
      messageWidget = myMessageView(messageData);
    } else {
      messageWidget = remoteMessageView(
        messageData: messageData,
        sender:
            members.firstWhereOrNull((user) => user.userID == messageData.senderID),
      );
    }
    if (!showTime) return messageWidget;
    final msgDate = DateTime.fromMillisecondsSinceEpoch(messageData.createdAt);
    final msgTimeString = DateFormat('h:mma').format(msgDate).toLowerCase();
    return Column(
      crossAxisAlignment: messageData.senderID == currentUser.userID
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        messageWidget,
        Padding(
          padding:
              const EdgeInsets.only(left: 12.0, right: 12.0, top: 2, bottom: 2),
          child: Text(
            msgTimeString,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
        ),
      ],
    );
  }

  Widget myMessageView(ChatFeedContent messageData) {
    // Show the profile/avatar in the small circle, and the logo in the bubble
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12.0),
            child: _myMessageContentWidgetWithLogo(messageData),
          ),
          displayCircleImage(messageData.senderProfilePictureURL, 35, false),
        ],
      ),
    );
  }

  Widget _myMessageContentWidgetWithLogo(ChatFeedContent messageData) {
    var mediaUrl = '';
    if (messageData.chatMedia != null) {
      if (messageData.chatMedia!.mime.contains('video')) {
        mediaUrl = messageData.chatMedia!.thumbnailURL ?? '';
      } else {
        mediaUrl = messageData.chatMedia!.url;
      }
    }

    // Get the listing logo from the channelDataModel
    final listingLogo = channelDataModel.listingImage ?? '';

    // NOTE: We intentionally avoid using TextDirection.ltr/rtl in this file.
    // Directional widgets handle LTR/RTL automatically.

    if (mediaUrl.contains('audio')) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          PositionedDirectional(
            end: -8,
            bottom: 0,
            child: Image.asset(
              'assets/images/chat_arrow_right.png',
              color: widget.colorAccent,
              height: 12,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
            child: Container(
              decoration: BoxDecoration(
                color: widget.colorAccent,
                shape: BoxShape.rectangle,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listingLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          listingLogo,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: PlayerWidget(
                      url: messageData.chatMedia!.url,
                      color: isDarkMode(context)
                          ? Colors.grey.shade800
                          : Colors.grey.shade200,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (messageData.chatMedia?.thumbnailURL == null) {
                    push(context, FullScreenImageViewer(imageUrl: mediaUrl));
                  }
                },
                child: Hero(
                  tag: mediaUrl,
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    placeholder: (context, url) =>
                        Image.asset('assets/images/img_placeholder.png'),
                    errorWidget: (context, url, error) =>
                        Image.asset('assets/images/error_image.png'),
                  ),
                ),
              ),
              if (listingLogo.isNotEmpty)
                Positioned(
                  top: 8,
                  right: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      listingLogo,
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (messageData.chatMedia?.thumbnailURL != null)
                FloatingActionButton(
                  mini: true,
                  heroTag: messageData.id,
                  backgroundColor: widget.colorAccent,
                  onPressed: () {
                    push(
                      context,
                      FullScreenVideoViewer(
                        heroTag: messageData.id,
                        videoUrl: messageData.chatMedia?.url ?? '',
                      ),
                    );
                  },
                  child: Icon(
                    Icons.play_arrow,
                    color: isDarkMode(context) ? Colors.black : Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomEnd,
        children: [
          PositionedDirectional(
            end: -8,
            bottom: 0,
            child: Image.asset(
              'assets/images/chat_arrow_right.png',
              color: widget.colorAccent,
              height: 12,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
            child: Container(
              decoration: BoxDecoration(
                color: widget.colorAccent,
                shape: BoxShape.rectangle,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listingLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          listingLogo,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: _ChatMessageText(
                      text: messageData.content,
                      textColor: isDarkMode(context) ? Colors.black : Colors.white,
                      linkColor: isDarkMode(context) ? Colors.blue.shade900 : Colors.blue.shade100,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget remoteMessageView({
    required ChatFeedContent messageData,
    required User? sender,
  }) {
    if (messageData.content.contains('XARQEGWE13SD') &&
        sender?.email == 'florian@instamobile.io') {
      return const SizedBox();
    }

    // Get sender name for display in group chats
    // Prioritize messageData.senderFirstName since it's what was stored when message was sent
    final senderName = messageData.senderFirstName.isNotEmpty
        ? messageData.senderFirstName
        : (sender?.firstName ?? 'Unknown');

    // DEBUG: Log sender info
    debugPrint(
        'REMOTE_MESSAGE: senderID=${messageData.senderID}, senderName=$senderName, isGroupChat=${channelDataModel.isGroupChat}, sender=${sender?.firstName}, fromMessage=${messageData.senderFirstName}');

    // Show the profile/avatar in the small circle, and the logo in the bubble
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              displayCircleImage(messageData.senderProfilePictureURL, 35, false),
              PositionedDirectional(
                end: 1,
                bottom: 1,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: sender?.active ?? false ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show sender name in group chats
                  if (channelDataModel.isGroupChat)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0, left: 8.0),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDarkMode(context)
                              ? Colors.grey.shade300
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  _remoteMessageContentWidgetWithLogo(messageData),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _remoteMessageContentWidgetWithLogo(ChatFeedContent messageData) {
    var mediaUrl = '';
    if (messageData.chatMedia != null) {
      if (messageData.chatMedia!.mime.contains('video')) {
        mediaUrl = messageData.chatMedia!.thumbnailURL ?? '';
      } else {
        mediaUrl = messageData.chatMedia?.url ?? '';
      }
    }

    // Get the listing logo from the channelDataModel
    final listingLogo = channelDataModel.listingImage ?? '';

    if (mediaUrl.contains('audio')) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomStart,
        children: [
          PositionedDirectional(
            start: -8,
            bottom: 0,
            child: Image.asset(
              'assets/images/chat_arrow_left.png',
              color: isDarkMode(context) ? Colors.grey[600] : Colors.grey[300],
              height: 12,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode(context)
                    ? Colors.grey.shade600
                    : Colors.grey.shade300,
                shape: BoxShape.rectangle,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listingLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          listingLogo,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: PlayerWidget(
                      url: messageData.chatMedia!.url,
                      color: isDarkMode(context)
                          ? widget.colorAccent
                          : widget.colorPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (mediaUrl.isNotEmpty) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () {
                  if (messageData.chatMedia?.thumbnailURL == null) {
                    push(context, FullScreenImageViewer(imageUrl: mediaUrl));
                  }
                },
                child: Hero(
                  tag: mediaUrl,
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    placeholder: (context, url) =>
                        Image.asset('assets/images/img_placeholder.png'),
                    errorWidget: (context, url, error) =>
                        Image.asset('assets/images/error_image.png'),
                  ),
                ),
              ),
              if (listingLogo.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      listingLogo,
                      height: 40,
                      width: 40,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (messageData.chatMedia?.thumbnailURL != null)
                FloatingActionButton(
                  mini: true,
                  heroTag: messageData.id,
                  backgroundColor: widget.colorAccent,
                  onPressed: () {
                    push(
                      context,
                      FullScreenVideoViewer(
                        heroTag: messageData.id,
                        videoUrl: messageData.chatMedia!.url,
                      ),
                    );
                  },
                  child: Icon(
                    Icons.play_arrow,
                    color: isDarkMode(context) ? Colors.black : Colors.white,
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      return Stack(
        clipBehavior: Clip.none,
        alignment: AlignmentDirectional.bottomStart,
        children: [
          PositionedDirectional(
            start: -8,
            bottom: 0,
            child: Image.asset(
              'assets/images/chat_arrow_left.png',
              color: isDarkMode(context) ? Colors.grey[600] : Colors.grey[300],
              height: 12,
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 50, maxWidth: 200),
            child: Container(
              decoration: BoxDecoration(
                color: isDarkMode(context) ? Colors.grey[600] : Colors.grey[300],
                shape: BoxShape.rectangle,
                borderRadius: const BorderRadius.all(Radius.circular(8)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (listingLogo.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          listingLogo,
                          height: 60,
                          width: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                    child: _ChatMessageText(
                      text: messageData.content,
                      textColor: isDarkMode(context) ? Colors.white : Colors.black,
                      linkColor: isDarkMode(context) ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pagingController.dispose();
    super.dispose();
  }

  _onPrivateChatSettingsClick() {
    showCupertinoModalPopup(
      context: context,
      builder: (actionSheetContext) => CupertinoActionSheet(
        message: const Text(
          'Chat Settings',
          style: TextStyle(fontSize: 15.0),
        ).tr(),
        actions: [
          CupertinoActionSheetAction(
            child: const Text('Block user').tr(),
            onPressed: () {
              Navigator.pop(actionSheetContext);
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Blocking user...'.tr(),
                    false,
                    widget.colorPrimary,
                  );
              context.read<ChatBloc>().add(
                    BlockUserEvent(
                      targetUser: channelDataModel.participants.first,
                      action: blockUserAction,
                    ),
                  );
            },
          ),
          CupertinoActionSheetAction(
            child: const Text('Report user').tr(),
            onPressed: () {
              Navigator.pop(actionSheetContext);
              context.read<LoadingCubit>().showLoading(
                    context,
                    'Reporting user...'.tr(),
                    false,
                    widget.colorPrimary,
                  );
              context.read<ChatBloc>().add(
                    BlockUserEvent(
                      targetUser: channelDataModel.participants.first,
                      action: blockUserAction,
                    ),
                  );
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: const Text('Cancel').tr(),
          onPressed: () {
            Navigator.pop(actionSheetContext);
          },
        ),
      ),
    );
  }
}

/// Renders a chat message with clickable URLs and long-press to copy.
class _ChatMessageText extends StatelessWidget {
  final String text;
  final Color textColor;
  final Color linkColor;

  const _ChatMessageText({
    required this.text,
    required this.textColor,
    required this.linkColor,
  });

  static final _urlRegex = RegExp(
    r'(https?://[^\s]+|caribtap://[^\s]+)',
    caseSensitive: false,
  );

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied to clipboard'.tr()),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _urlRegex.allMatches(text).toList();

    if (matches.isEmpty) {
      // Plain text — just long-press to copy
      return GestureDetector(
        onLongPress: () => _copyToClipboard(context, text),
        child: Text(
          text,
          textAlign: TextAlign.start,
          style: TextStyle(color: textColor, fontSize: 16),
        ),
      );
    }

    // Build a RichText with tappable link spans
    final spans = <InlineSpan>[];
    int cursor = 0;
    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: TextStyle(color: textColor, fontSize: 16),
        ));
      }
      final url = match.group(0)!;
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => _launch(url),
          onLongPress: () => _copyToClipboard(context, url),
          child: Text(
            url,
            style: TextStyle(
              color: linkColor,
              fontSize: 16,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
          ),
        ),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: TextStyle(color: textColor, fontSize: 16),
      ));
    }

    return GestureDetector(
      onLongPress: () => _copyToClipboard(context, text),
      child: Text.rich(
        TextSpan(children: spans),
        textAlign: TextAlign.start,
      ),
    );
  }
}
