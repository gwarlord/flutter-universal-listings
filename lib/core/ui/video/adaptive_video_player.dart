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
  final IconData? fullScreenIcon;

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
    this.fullScreenIcon,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = controller.value.aspectRatio;
        
        final videoWidth = controller.value.size.width > 0
            ? controller.value.size.width
            : constraints.maxWidth;
        final videoHeight = controller.value.size.height > 0
            ? controller.value.size.height
            : (videoWidth / aspectRatio);
        
        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Video Surface & Main Tap Layer
            GestureDetector(
              onTap: onTogglePlay,
              behavior: HitTestBehavior.opaque,
              child: ClipRect(
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
            ),
            
            // 2. Play/Pause Overlay (Center)
            if (showPlayOverlay && !controller.value.isPlaying)
              IgnorePointer(
                child: Container(
                  color: Colors.black.withOpacity(0.2),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 64,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              
            // 3. Controls Layer
            // Positioned higher (bottom: 100) to clear system bars and floating buttons
            Positioned(
              bottom: 100,
              left: 20,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (showMuteToggle)
                      _VideoControlButton(
                        icon: isMuted ? Icons.volume_off : Icons.volume_up,
                        onTap: onToggleMute,
                      ),
                    if (showMuteToggle && showFullScreenButton) const SizedBox(height: 16),
                    if (showFullScreenButton)
                      _VideoControlButton(
                        icon: fullScreenIcon ?? Icons.fullscreen,
                        onTap: onToggleFullScreen,
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _VideoControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _VideoControlButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.6),
      shape: const CircleBorder(),
      elevation: 4,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
