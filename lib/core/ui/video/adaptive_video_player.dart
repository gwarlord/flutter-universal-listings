import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class AdaptiveVideoPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final BoxFit fit;
  final bool showPlayOverlay;
  final bool showMuteToggle;
  final bool isMuted;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onToggleMute;

  const AdaptiveVideoPlayer({
    super.key,
    required this.controller,
    this.fit = BoxFit.contain,
    this.showPlayOverlay = true,
    this.showMuteToggle = true,
    this.isMuted = false,
    this.onTogglePlay,
    this.onToggleMute,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isPortrait = controller.value.aspectRatio < 1.0;
        // Container takes available space; FittedBox scales/crops the video to match desired fit.
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: fit,
                alignment: Alignment.center,
                child: SizedBox(
                  // Use the raw video dimensions to allow FittedBox to scale correctly
                  width: controller.value.size.width == 0
                      ? constraints.maxWidth
                      : controller.value.size.width,
                  height: controller.value.size.height == 0
                      ? constraints.maxHeight
                      : controller.value.size.height,
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
          ],
        );
      },
    );
  }
}
