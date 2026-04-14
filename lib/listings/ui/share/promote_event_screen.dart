import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/currency/currency_formatter.dart';
import 'package:caribtap/listings/model/event_model.dart';

class PromoteEventScreen extends StatefulWidget {
  final EventModel event;

  const PromoteEventScreen({super.key, required this.event});

  @override
  State<PromoteEventScreen> createState() => _PromoteEventScreenState();
}

class _PromoteEventScreenState extends State<PromoteEventScreen> {
  final GlobalKey _posterKey = GlobalKey();
  final GlobalKey _shareButtonKey = GlobalKey();

  bool _isGeneratingImage = false;
  bool _fillImage = false;
  bool _isFillAdjustMode = false;
  Alignment _fillAlignment = Alignment.center;

  String get _eventShareUrl => 'https://caribtap.com/event/${widget.event.id}';

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

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _eventShareUrl));
    if (mounted) {
      showSnackBar(context, 'Event link copied.'.tr());
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
          'Check out ${widget.event.title} on CaribTap. Scan the QR code or open: $_eventShareUrl';
      final Rect? sharePositionOrigin = _sharePositionOrigin;

      if (kIsWeb) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'event_promo_${widget.event.id}.png',
            ),
          ],
          text: shareText,
          subject: 'Event: ${widget.event.title}',
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        final directory = await getTemporaryDirectory();
        final file = File(
          '${directory.path}/event_promo_${widget.event.id}_${DateTime.now().millisecondsSinceEpoch}.png',
        );

        await file.writeAsBytes(bytes, flush: true);

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          subject: 'Event: ${widget.event.title}',
          sharePositionOrigin: sharePositionOrigin,
        );
      }
    } catch (e) {
      debugPrint('Event poster generation failed: $e');
      try {
        await Share.share(
          'Check out ${widget.event.title} on CaribTap: $_eventShareUrl',
          subject: 'Event: ${widget.event.title}',
          sharePositionOrigin: _sharePositionOrigin,
        );
      } catch (_) {
        // Fallback also failed — snack bar shown below.
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
    await Future<void>.delayed(const Duration(milliseconds: 16));
    await WidgetsBinding.instance.endOfFrame;

    RenderRepaintBoundary? boundary =
        _posterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

    if (boundary == null) {
      throw Exception('Poster preview is not ready yet.');
    }

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
    // Try the share button key first (most precise anchor for iOS popover)
    final buttonContext = _shareButtonKey.currentContext;
    if (buttonContext != null) {
      final renderObject = buttonContext.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final offset = renderObject.localToGlobal(Offset.zero);
        final rect = offset & renderObject.size;
        if (rect.width > 0 && rect.height > 0) return rect;
      }
    }
    // Fallback: centre of the screen
    final size = MediaQuery.sizeOf(context);
    return Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: 1,
      height: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Event'.tr()),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
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
              'Create a shareable event poster with ticket details and a QR code.'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            if (widget.event.posterImageUrl.isNotEmpty) ...[
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
            ],
            const SizedBox(height: 16),
            Center(
              child: RepaintBoundary(
                key: _posterKey,
                child: _EventPoster(
                  event: widget.event,
                  shareUrl: _eventShareUrl,
                  fillImage: _fillImage,
                  fillAdjustMode: _isFillAdjustMode,
                  fillAlignment: _fillAlignment,
                  onFillImagePan: (_fillImage && _isFillAdjustMode)
                      ? _onFillImagePan
                      : null,
                  onFillImageDoubleTap:
                      _fillImage ? _toggleFillAdjustMode : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: _shareButtonKey,
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
                    label: Text('Copy Event Link'.tr()),
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

// ---------------------------------------------------------------------------
// Poster widget
// ---------------------------------------------------------------------------

class _EventPoster extends StatelessWidget {
  final EventModel event;
  final String shareUrl;
  final bool fillImage;
  final bool fillAdjustMode;
  final Alignment fillAlignment;
  final ValueChanged<Offset>? onFillImagePan;
  final VoidCallback? onFillImageDoubleTap;

  const _EventPoster({
    required this.event,
    required this.shareUrl,
    required this.fillImage,
    required this.fillAdjustMode,
    required this.fillAlignment,
    this.onFillImagePan,
    this.onFillImageDoubleTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool dark = isDarkMode(context);
    final Color surface = dark ? const Color(0xFF0F172A) : Colors.white;
    final Color textColor = dark ? Colors.white : const Color(0xFF111827);

    final startDate = DateTime.fromMillisecondsSinceEpoch(event.startAtSeconds * 1000);
    final endDate = DateTime.fromMillisecondsSinceEpoch(event.endAtSeconds * 1000);
    final dateFormatter = DateFormat('EEE, MMM d');
    final timeFormatter = DateFormat('h:mm a');
    final sameDay = dateFormatter.format(startDate) == dateFormatter.format(endDate);

    final dateLabel = sameDay
        ? '${dateFormatter.format(startDate)}'
        : '${dateFormatter.format(startDate)} – ${dateFormatter.format(endDate)}';
    final timeLabel = sameDay
        ? '${timeFormatter.format(startDate)} – ${timeFormatter.format(endDate)}'
        : timeFormatter.format(startDate);

    // Lowest ticket price for a quick summary
    double? lowestPrice;
    String? priceCurrency;
    for (final t in event.ticketTypes) {
      if (t.price > 0 && (lowestPrice == null || t.price < lowestPrice)) {
        lowestPrice = t.price;
        priceCurrency = t.currency;
      }
    }
    final bool hasFreeTicket = event.ticketTypes.any((t) => t.price == 0);
    final bool hasTickets = event.ticketTypes.isNotEmpty || event.ticketUrl.isNotEmpty;

    return Container(
      width: 360,
      constraints: const BoxConstraints(minHeight: 560),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        // Indigo/violet gradient to visually distinguish events from listings
        gradient: const LinearGradient(
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
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
            // Header row
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF4F46E5),
                  radius: 15,
                  child: Text(
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
                    'CaribTap Event'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                // "EVENT" pill badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'EVENT',
                    style: TextStyle(
                      color: Color(0xFF4F46E5),
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Event image
            if (event.posterImageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  height: 190,
                  width: double.infinity,
                  child: LayoutBuilder(
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
                          padding: fillImage
                              ? EdgeInsets.zero
                              : const EdgeInsets.all(8),
                          child: Image.network(
                            event.posterImageUrl,
                            fit: fillImage ? BoxFit.cover : BoxFit.contain,
                            alignment: fillImage ? fillAlignment : Alignment.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 190,
                  width: double.infinity,
                  color: const Color(0xFFEDE9FE),
                  child: const Icon(Icons.event, size: 48, color: Color(0xFF4F46E5)),
                ),
              ),

            const SizedBox(height: 12),

            // Title
            Text(
              event.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),

            // Date row
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: dateLabel,
              textColor: textColor,
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.access_time_outlined,
              text: timeLabel,
              textColor: textColor,
            ),

            // Venue
            if (event.venueName.isNotEmpty) ...[
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: event.venueName,
                textColor: textColor,
              ),
            ],

            // Tickets section
            if (hasTickets) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF4F46E5).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.confirmation_number_outlined,
                          size: 14,
                          color: Color(0xFF4F46E5),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tickets'.tr(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4F46E5),
                          ),
                        ),
                      ],
                    ),
                    if (event.ticketTypes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...event.ticketTypes.take(3).map((ticket) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    ticket.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: textColor.withOpacity(0.85),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  ticket.price == 0
                                      ? 'Free'.tr()
                                      : CurrencyFormatter().formatAmount(
                                          currencyCode: ticket.currency,
                                          amount: ticket.price,
                                        ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: ticket.price == 0
                                        ? const Color(0xFF059669)
                                        : textColor,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      if (event.ticketTypes.length > 3)
                        Text(
                          '+ ${event.ticketTypes.length - 3} more'.tr(),
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withOpacity(0.55),
                          ),
                        ),
                    ] else if (hasFreeTicket) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Free entry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ] else if (lowestPrice != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'From $priceCurrency ${lowestPrice.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),

            // QR + call-to-action
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
                    data: shareUrl,
                    version: QrVersions.auto,
                    size: 100,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Scan for details & tickets'.tr(),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasTickets
                            ? 'Get ticket info, venue directions, and updates in the CaribTap app.'.tr()
                            : 'Get full event details and updates in the CaribTap app.'.tr(),
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

            // Store badges
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color textColor;

  const _InfoRow({
    required this.icon,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: textColor.withOpacity(0.6)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.75)),
          ),
        ),
      ],
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
