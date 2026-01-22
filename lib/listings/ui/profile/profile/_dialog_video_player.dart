import 'package:flutter/material.dart';
import 'package:instaflutter/core/ui/video/adaptive_video_player.dart';
import 'package:video_player/video_player.dart';

class DialogVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  const DialogVideoPlayer({Key? key, required this.controller}) : super(key: key);

  @override
  State<DialogVideoPlayer> createState() => DialogVideoPlayerState();
}

class DialogVideoPlayerState extends State<DialogVideoPlayer> {
    @override
    Widget build(BuildContext context) {
      return AdaptiveVideoPlayer(
        controller: widget.controller,
        showFullScreenButton: true,
        showMuteToggle: true,
        isMuted: _isMuted,
        onToggleMute: _toggleMute,
        onToggleFullScreen: _toggleFullScreen,
      );
    }
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.controller.value.volume == 0;
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  void _toggleFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _FullScreenVideoPlayer(
          controller: widget.controller,
          isMuted: _isMuted,
        ),
      ),
    ).then((value) {
      if (value is bool) {
        setState(() {
          _isMuted = value;
          widget.controller.setVolume(_isMuted ? 0 : 1);
        });
      }
    });
  }

// (removed duplicate build method)
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final bool isMuted;
  const _FullScreenVideoPlayer({Key? key, required this.controller, required this.isMuted}) : super(key: key);

  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  late bool _isMuted;

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    widget.controller.setVolume(_isMuted ? 0 : 1);
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      widget.controller.setVolume(_isMuted ? 0 : 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: widget.controller.value.aspectRatio,
            child: AdaptiveVideoPlayer(
              controller: widget.controller,
              showFullScreenButton: false,
              showMuteToggle: true,
              isMuted: _isMuted,
              onToggleMute: _toggleMute,
            ),
          ),
        ),
      ),
    );
  }
}