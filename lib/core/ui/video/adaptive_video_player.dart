import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AdaptiveVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final BoxFit fit;
  final bool showPlayOverlay;
  final bool showMuteToggle;
  final bool showFullScreenButton;
  final bool isMuted;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onToggleMute;
  final VoidCallback? onToggleFullScreen;

  const AdaptiveVideoPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.showPlayOverlay = true,
    this.showMuteToggle = true,
    this.showFullScreenButton = true,
    this.isMuted = false,
    this.onTogglePlay,
    this.onToggleMute,
    this.onToggleFullScreen,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = controller.value.aspectRatio;
        final isPortrait = aspectRatio < 1.0;
        
        // Calculate video dimensions based on aspect ratio for proper scaling
        final videoWidth = controller.value.size.width > 0
            ? controller.value.size.width
            : constraints.maxWidth;
        final videoHeight = controller.value.size.height > 0
            ? controller.value.size.height
            : (videoWidth / aspectRatio);
        
        // Container takes available space; FittedBox scales/crops the video to match desired fit.
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: fit,
                alignment: Alignment.center,
                child: SizedBox(
                  width: videoWidth,
                  height: videoHeight,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            if (showPlayOverlay && !controller.value.isPlaying)
              Container(
                color: Colors.black.withOpacity(0.2),
                child: Center(
                  child: GestureDetector(
                    onTap: onTogglePlay,
                    child: const Icon(
                      Icons.play_circle_fill,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            if (showMuteToggle)
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onToggleMute,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isMuted ? Icons.volume_off : Icons.volume_up,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            if (showFullScreenButton)
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onToggleFullScreen,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
