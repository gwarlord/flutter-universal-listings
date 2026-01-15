import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../model/listing_model.dart';

class ListingDetailsScreen extends StatefulWidget {
  final ListingModel listing;

  const ListingDetailsScreen({
    super.key,
    required this.listing,
  });

  @override
  State<ListingDetailsScreen> createState() => _ListingDetailsScreenState();
}

class _ListingDetailsScreenState extends State<ListingDetailsScreen> {
  ListingModel get listing => widget.listing;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listing Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== IMAGES / VIDEOS =====
            if (listing.videos.isNotEmpty) _buildVideoStrip(),

            const SizedBox(height: 16),

            // ===== TITLE =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                listing.title ?? '',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),

            const SizedBox(height: 8),

            // ===== DESCRIPTION =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(listing.description ?? ''),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoStrip() {
    return SizedBox(
      height: 110,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: listing.videos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final url = listing.videos[index];
          if (url.trim().isEmpty) return const SizedBox.shrink();

          return ListingVideoThumbnailTile(
            url: url,
            index: index,
          );
        },
      ),
    );
  }
}

//
// ──────────────────────────────────────────────────────────────────────────────
// VIDEO THUMBNAIL TILE
// ──────────────────────────────────────────────────────────────────────────────
//

class ListingVideoThumbnailTile extends StatefulWidget {
  final String url;
  final int index;

  const ListingVideoThumbnailTile({
    super.key,
    required this.url,
    required this.index,
  });

  @override
  State<ListingVideoThumbnailTile> createState() =>
      _ListingVideoThumbnailTileState();
}

class _ListingVideoThumbnailTileState
    extends State<ListingVideoThumbnailTile> {
  Uint8List? _thumbnail;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    final bytes = await VideoThumbnail.thumbnailData(
      video: widget.url,
      imageFormat: ImageFormat.JPEG,
      maxHeight: 120,
      quality: 75,
    );

    if (mounted) {
      setState(() => _thumbnail = bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullscreenVideoViewer(
              url: widget.url,
            ),
          ),
        );
      },
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black12,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_thumbnail != null)
              Image.memory(
                _thumbnail!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              )
            else
              const Center(child: CircularProgressIndicator()),

            const Icon(
              Icons.play_circle_fill,
              size: 48,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

//
// ──────────────────────────────────────────────────────────────────────────────
// FULLSCREEN VIDEO VIEWER
// ──────────────────────────────────────────────────────────────────────────────
//

class FullscreenVideoViewer extends StatefulWidget {
  final String url;

  const FullscreenVideoViewer({
    super.key,
    required this.url,
  });

  @override
  State<FullscreenVideoViewer> createState() => _FullscreenVideoViewerState();
}

class _FullscreenVideoViewerState extends State<FullscreenVideoViewer> {
  late final VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: VisibilityDetector(
          key: const ValueKey('fullscreen-video'),
          onVisibilityChanged: (info) {
            if (info.visibleFraction == 0) {
              _controller.pause();
            }
          },
          child: _controller.value.isInitialized
              ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          )
              : const CircularProgressIndicator(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white,
        onPressed: () {
          setState(() {
            _controller.value.isPlaying
                ? _controller.pause()
                : _controller.play();
          });
        },
        child: Icon(
          _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
          color: Colors.black,
        ),
      ),
    );
  }
}
//
// ──────────────────────────────────────────────────────────────────────────────
// BACKWARD-COMPAT NAVIGATION WRAPPER (REQUIRED BY APP)
// ──────────────────────────────────────────────────────────────────────────────
//

class ListingDetailsWrappingWidget extends StatelessWidget {
  final ListingModel listing;
  final dynamic currentUser; // kept dynamic to avoid tight coupling

  const ListingDetailsWrappingWidget({
    super.key,
    required this.listing,
    this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    return ListingDetailsScreen(
      listing: listing,
    );
  }
}

