import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/model/listing_model.dart';
import 'package:caribtap/listings/services/deep_link_service.dart';

class PromoteListingScreen extends StatefulWidget {
  final ListingModel listing;

  const PromoteListingScreen({super.key, required this.listing});

  @override
  State<PromoteListingScreen> createState() => _PromoteListingScreenState();
}

class _PromoteListingScreenState extends State<PromoteListingScreen> {
  final GlobalKey _posterKey = GlobalKey();
  final DeepLinkService _deepLinkService = DeepLinkService();

  String? _shareLink;
  bool _isPreparingLink = true;
  bool _isGeneratingImage = false;
  bool _fillImage = false;
  bool _isFillAdjustMode = false;
  late String _selectedImageUrl;
  Alignment _fillAlignment = Alignment.center;

  List<String> get _imageOptions {
    final Set<String> unique = <String>{};
    if (widget.listing.photo.isNotEmpty) {
      unique.add(widget.listing.photo);
    }
    for (final image in widget.listing.photos) {
      if (image.isNotEmpty) unique.add(image);
    }
    return unique.toList();
  }

  @override
  void initState() {
    super.initState();
    final options = _imageOptions;
    _selectedImageUrl = options.isNotEmpty ? options.first : widget.listing.photo;
    _prepareShareLink();
  }

  void _selectImage(String url) {
    setState(() {
      _selectedImageUrl = url;
      _fillAlignment = Alignment.center;
      _isFillAdjustMode = false;
    });
  }

  void _onFillImagePan(Offset normalizedDelta) {
    setState(() {
      final nextX = (_fillAlignment.x + normalizedDelta.dx).clamp(-1.0, 1.0);
      final nextY = (_fillAlignment.y + normalizedDelta.dy).clamp(-1.0, 1.0);
      _fillAlignment = Alignment(nextX.toDouble(), nextY.toDouble());
    });
  }

  void _toggleFillAdjustMode() {
    if (!_fillImage) return;
    setState(() {
      _isFillAdjustMode = !_isFillAdjustMode;
    });
  }

  Future<void> _prepareShareLink() async {
    try {
      final link = await _deepLinkService.createListingShareLink(
        widget.listing.id,
        title: widget.listing.title,
        description: widget.listing.description,
        imageUrl: widget.listing.photo,
      );
      if (mounted) {
        setState(() {
          _shareLink = link;
        });
      }
    } catch (_) {
      if (mounted) {
        showSnackBar(context, 'Unable to prepare share link right now.'.tr());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingLink = false;
        });
      }
    }
  }

  String get _resolvedShareLink => _shareLink ?? 'caribtap://listing/${widget.listing.id}';
  String get _qrShareLink {
    final raw = _resolvedShareLink;
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    return 'https://caribtap.com/l/${widget.listing.id}';
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _resolvedShareLink));
    if (mounted) {
      showSnackBar(context, 'Listing link copied.'.tr());
    }
  }

  Future<void> _sharePosterImage() async {
    if (_isGeneratingImage) return;

    setState(() {
      _isGeneratingImage = true;
    });

    try {
      final bytes = await _capturePosterPngBytes();
      final shareText =
          'Check out ${widget.listing.title} on CaribTap. Scan the QR code or open: $_resolvedShareLink';
      final Rect? sharePositionOrigin = _sharePositionOrigin;

      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'listing_promo_${widget.listing.id}.png',
            ),
          ],
          text: shareText,
          subject: 'Promote ${widget.listing.title}',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/listing_promo_${widget.listing.id}_${DateTime.now().millisecondsSinceEpoch}.png',
        );

        await file.writeAsBytes(bytes, flush: true);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          subject: 'Promote ${widget.listing.title}',
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } catch (e) {
      debugPrint('Poster generation failed: $e');
      try {
        await Share.share(
          'Check out ${widget.listing.title} on CaribTap: $_resolvedShareLink',
          subject: 'Promote ${widget.listing.title}',
          sharePositionOrigin: _sharePositionOrigin,
        );
      } catch (_) {
        // If fallback share also fails, show the existing snack bar below.
      }
      if (mounted) {
        showSnackBar(context, 'Unable to create poster image right now.'.tr());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingImage = false;
        });
      }
    }
  }

  Future<Uint8List> _capturePosterPngBytes() async {
    // Wait for current frame so the repaint boundary has fully painted.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await WidgetsBinding.instance.endOfFrame;

    RenderRepaintBoundary? boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('Poster preview is not ready yet.');
    }

    // Retry once if still pending paint.
    if (boundary.debugNeedsPaint) {
      await Future<void>.delayed(const Duration(milliseconds: 16));
      await WidgetsBinding.instance.endOfFrame;
      boundary =
          _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('Poster preview is not ready yet.');
      }
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    final devicePixelRatio = mediaQuery?.devicePixelRatio ?? 2.0;
    final pixelRatio = defaultTargetPlatform == TargetPlatform.iOS
      ? devicePixelRatio.clamp(1.5, 2.0)
      : devicePixelRatio.clamp(2.0, 3.0);

    final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();

    if (byteData == null) {
      throw Exception('Failed to generate image bytes.');
    }

    return byteData.buffer.asUint8List();
  }

  Rect? get _sharePositionOrigin {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return null;
    final offset = renderObject.localToGlobal(Offset.zero);
    return offset & renderObject.size;
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Promote Listing'.tr()),
      ),
      body: SingleChildScrollView(
        physics: _isFillAdjustMode
            ? const NeverScrollableScrollPhysics()
            : const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          24 + MediaQuery.of(context).padding.bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create a clean postable image with QR code, listing highlights, and app download prompts.'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Show Full'.tr()),
                  selected: !_fillImage,
                  onSelected: (_) {
                    setState(() {
                      _fillImage = false;
                      _isFillAdjustMode = false;
                    });
                  },
                ),
                ChoiceChip(
                  label: Text('Fill'.tr()),
                  selected: _fillImage,
                  onSelected: (_) {
                    setState(() {
                      _fillImage = true;
                      _isFillAdjustMode = false;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_fillImage)
              (_isFillAdjustMode
                  ? Text(
                      'Adjust mode ON: drag image to position. Double-tap image to finish.'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  : Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: [
                          TextSpan(
                            text: 'Double-tap',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text: ' image to enter adjust mode, then drag to position.'.tr(),
                          ),
                        ],
                      ),
                    )),
            if (_imageOptions.length > 1) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 70,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final imageUrl = _imageOptions[index];
                    final bool selected = imageUrl == _selectedImageUrl;
                    return GestureDetector(
                      onTap: () => _selectImage(imageUrl),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 16),
            Center(
              child: RepaintBoundary(
                key: _posterKey,
                child: _ListingPoster(
                  listing: widget.listing,
                  shareLink: _qrShareLink,
                  fillImage: _fillImage,
                  selectedImageUrl: _selectedImageUrl,
                  fillAlignment: _fillAlignment,
                    fillAdjustMode: _isFillAdjustMode,
                    onFillImagePan: (_fillImage && _isFillAdjustMode)
                      ? _onFillImagePan
                      : null,
                    onFillImageDoubleTap:
                      _fillImage ? _toggleFillAdjustMode : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isPreparingLink)
              const LinearProgressIndicator(minHeight: 3),
            if (_isPreparingLink) const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isGeneratingImage ? null : _sharePosterImage,
                    icon: _isGeneratingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign),
                    label: Text(
                      _isGeneratingImage
                          ? 'Generating...'.tr()
                          : 'Generate and Share Image'.tr(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _copyLink,
                    icon: const Icon(Icons.copy),
                    label: Text('Copy Listing Link'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ListingPoster extends StatelessWidget {
  final ListingModel listing;
  final String shareLink;
  final bool fillImage;
  final bool fillAdjustMode;
  final String selectedImageUrl;
  final Alignment fillAlignment;
  final ValueChanged<Offset>? onFillImagePan;
  final VoidCallback? onFillImageDoubleTap;

  const _ListingPoster({
    required this.listing,
    required this.shareLink,
    required this.fillImage,
    required this.fillAdjustMode,
    required this.selectedImageUrl,
    required this.fillAlignment,
    this.onFillImagePan,
    this.onFillImageDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    final Color surface = dark ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = dark ? Colors.white : const Color(0xFF111827);

    return Container(
      width: 360,
      constraints: const BoxConstraints(minHeight: 560),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E7490), Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: surface,
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFF0F766E),
                  radius: 15,
                  backgroundImage:
                      listing.logo.isNotEmpty ? NetworkImage(listing.logo) : null,
                  child: listing.logo.isNotEmpty
                      ? null
                      : Text(
                          'CT',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Promoted on CaribTap'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: selectedImageUrl.isNotEmpty
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onDoubleTap: onFillImageDoubleTap,
                            onPanUpdate: onFillImagePan == null
                                ? null
                                : (details) {
                                    final width = constraints.maxWidth <= 0
                                        ? 1.0
                                        : constraints.maxWidth;
                                    final height = constraints.maxHeight <= 0
                                        ? 1.0
                                        : constraints.maxHeight;

                                    final normalizedDelta = Offset(
                                      -(details.delta.dx / (width / 2)),
                                      -(details.delta.dy / (height / 2)),
                                    );
                                    onFillImagePan!(normalizedDelta);
                                  },
                            child: Container(
                              color: dark
                                  ? const Color(0xFF111827)
                                  : const Color(0xFFF3F4F6),
                              padding:
                                  fillImage ? EdgeInsets.zero : const EdgeInsets.all(8),
                              child: Image.network(
                                selectedImageUrl,
                                fit: fillImage ? BoxFit.cover : BoxFit.contain,
                                alignment: fillImage ? fillAlignment : Alignment.center,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.image, size: 42),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              listing.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 6),
            if (listing.place.isNotEmpty)
              Text(
                listing.place,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor.withOpacity(0.75)),
              ),
            if (listing.price.isNotEmpty && listing.price != '0')
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '${listing.currencyCode} ${listing.price}',
                  style: const TextStyle(
                    color: Color(0xFF047857),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: dark ? Colors.white12 : Colors.black.withOpacity(0.04),
                  ),
                  child: QrImageView(
                    data: shareLink,
                    version: QrVersions.auto,
                    size: 106,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan to open listing'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get details, contact options, and live updates in the app.'.tr(),
                        style: TextStyle(
                          fontSize: 12,
                          color: textColor.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: const [
                Expanded(
                  child: _StoreBadge(
                    icon: FontAwesomeIcons.apple,
                    line1: 'Download on the',
                    line2: 'App Store',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _StoreBadge(
                    icon: FontAwesomeIcons.googlePlay,
                    line1: 'Get it on',
                    line2: 'Google Play',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  final IconData icon;
  final String line1;
  final String line2;

  const _StoreBadge({
    required this.icon,
    required this.line1,
    required this.line2,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          FaIcon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 9),
                ),
                Text(
                  line2,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
