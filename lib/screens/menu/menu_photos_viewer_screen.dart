import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:instaflutter/core/utils/helper.dart';

class MenuPhotosViewerScreen extends StatefulWidget {
  final List<String> photoUrls;
  final int initialIndex;

  const MenuPhotosViewerScreen({
    Key? key,
    required this.photoUrls,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MenuPhotosViewerScreen> createState() => _MenuPhotosViewerScreenState();
}

class _MenuPhotosViewerScreenState extends State<MenuPhotosViewerScreen> {
  late int _currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentIndex + 1}/${widget.photoUrls.length}'),
        elevation: 0,
        backgroundColor: dark ? Colors.grey.shade900 : Colors.grey.shade50,
      ),
      body: PhotoViewGallery.builder(
        scrollPhysics: const BouncingScrollPhysics(),
        builder: (BuildContext context, int index) {
          return PhotoViewGalleryPageOptions(
            imageProvider: NetworkImage(widget.photoUrls[index]),
            initialScale: PhotoViewComputedScale.contained * 0.8,
            minScale: PhotoViewComputedScale.contained * 0.5,
            maxScale: PhotoViewComputedScale.covered * 2,
            heroAttributes: PhotoViewHeroAttributes(
              tag: 'photo_$index',
            ),
          );
        },
        itemCount: widget.photoUrls.length,
        loadingBuilder: (context, event) => Center(
          child: CircularProgressIndicator(
            value: event == null ? null : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
          ),
        ),
        pageController: _pageController,
        onPageChanged: (index) {
          setState(() => _currentIndex = index);
        },
        backgroundDecoration: BoxDecoration(
          color: dark ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }
}
