import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:instaflutter/core/ui/video/adaptive_video_player.dart';

class FullScreenVideoViewer extends StatefulWidget {
  final String videoUrl;
  final String heroTag;
  final File? videoFile;

  const FullScreenVideoViewer(
      {super.key, required this.videoUrl, required this.heroTag, this.videoFile});

  @override
  State<FullScreenVideoViewer> createState() => _FullScreenVideoViewerState();
}

class _FullScreenVideoViewerState extends State<FullScreenVideoViewer> {
  late VideoPlayerController _controller;
  late String videoUrl;
  late String heroTag;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    videoUrl = widget.videoUrl;
    heroTag = widget.heroTag;
    _controller = widget.videoFile == null
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        : VideoPlayerController.file(widget.videoFile!)
      ..initialize().then((_) {
        _controller.play();
        _controller.setLooping(true);
        setState(() {});
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        elevation: 0.0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Hero(
        tag: videoUrl,
        child: Center(
          child: _controller.value.isInitialized
              ? AdaptiveVideoPlayer(
                  controller: _controller,
                  fit: _controller.value.aspectRatio < 1.0
                      ? BoxFit.cover
                      : BoxFit.contain,
                  showPlayOverlay: true,
                  showMuteToggle: true,
                  isMuted: _isMuted,
                  fullScreenIcon: Icons.fullscreen_exit,
                  onTogglePlay: () {
                    setState(() {
                      _controller.value.isPlaying
                          ? _controller.pause()
                          : _controller.play();
                    });
                  },
                  onToggleMute: () {
                    setState(() {
                      _isMuted = !_isMuted;
                      _controller.setVolume(_isMuted ? 0 : 1);
                    });
                  },
                  onToggleFullScreen: () => Navigator.pop(context),
                )
              : const CircularProgressIndicator.adaptive(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
