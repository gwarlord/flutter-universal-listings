
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instaflutter/listings/ui/deals/ad_format_guidance_screen.dart';
import 'package:instaflutter/listings/ui/deals/ad_terms_and_conditions_screen.dart';
import 'package:instaflutter/listings/ui/deals/ad_pricing_selector.dart';
import 'package:uuid/uuid.dart';
import 'package:instaflutter/listings/services/media_upload_service.dart';
import 'package:instaflutter/listings/services/deal_ad_service.dart';
import 'package:instaflutter/listings/model/deal_ad_model.dart';
import 'package:instaflutter/listings/utils/ad_seasonality_helper.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/cupertino.dart';

// Video preview widget for local file
class _VideoPreviewWidget extends StatefulWidget {
  final File file;
  const _VideoPreviewWidget({required this.file});

  @override
  State<_VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends State<_VideoPreviewWidget> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.file(widget.file)
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.setLooping(true);
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
    if (!_initialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return AspectRatio(
      aspectRatio: _controller.value.aspectRatio,
      child: VideoPlayer(_controller),
    );
  }
}

class AdUploadScreen extends StatefulWidget {
  final VoidCallback? onAdSubmitted;
  const AdUploadScreen({Key? key, this.onAdSubmitted}) : super(key: key);

  @override
  State<AdUploadScreen> createState() => _AdUploadScreenState();
}

class _AdUploadScreenState extends State<AdUploadScreen> {
    double get _seasonalMultiplier => AdSeasonalityHelper.getSeasonalMultiplier(DateTime.now());
    String get _seasonLabel => AdSeasonalityHelper.getSeasonLabel(DateTime.now());
  File? _mediaFile;
  String? _mediaType; // 'image' or 'video'
  final TextEditingController _captionController = TextEditingController();
  int _adDays = 1;
  bool _acceptedTerms = false;
  bool _showTerms = false;

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final result = await showCupertinoModalPopup<String>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        message: const Text('Add media'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'image'),
            child: const Text('Choose Image from Gallery'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context, 'video'),
            child: const Text('Choose Video from Gallery'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (result == null) return;
    if (result == 'image') {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _mediaFile = File(pickedFile.path);
          _mediaType = 'image';
        });
      }
    } else if (result == 'video') {
      final pickedVideo = await picker.pickVideo(source: ImageSource.gallery);
      if (pickedVideo != null) {
        setState(() {
          _mediaFile = File(pickedVideo.path);
          _mediaType = 'video';
        });
      }
    }
  }

  void _showFormatGuidance() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdFormatGuidanceScreen()),
    );
  }

  void _showTermsAndConditions() {
    setState(() => _showTerms = true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdTermsAndConditionsScreen(
          onAccepted: () {
            setState(() {
              _acceptedTerms = true;
              _showTerms = false;
            });
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  bool _isSubmitting = false;

  Future<void> _submitAd() async {
    if (_mediaFile == null || !_acceptedTerms) return;
    setState(() => _isSubmitting = true);
    try {
      // TODO: Replace with actual listerId and listingId from user context
      final listerId = 'demoListerId';
      final listingId = 'demoListingId';
      final adId = const Uuid().v4();
      final mediaService = MediaUploadService();
      final mediaUrl = await mediaService.uploadAdMedia(_mediaFile!, listerId, adId);
      final now = DateTime.now();
      final pricePerDay = 10.0;
      final ad = DealAdModel(
        id: adId,
        listerId: listerId,
        listingId: listingId,
        mediaUrl: mediaUrl,
        mediaType: _mediaType ?? 'image',
        caption: _captionController.text.trim(),
        durationDays: _adDays,
        pricePaid: pricePerDay * _adDays * _seasonalMultiplier,
        startDate: now,
        endDate: now.add(Duration(days: _adDays)),
        status: 'pending',
        createdAt: now,
        approvedAt: null,
        reviewerId: null,
        authorID: listerId,
      );
      await DealAdService().submitAd(ad);
      if (widget.onAdSubmitted != null) widget.onAdSubmitted!();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ad submitted for review!')),
      );
      Navigator.pop(context);
    } catch (e, stack) {
      // Print error and stack trace for debugging
      debugPrint('Failed to submit ad: $e');
      debugPrintStack(stackTrace: stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit ad: $e')),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? Colors.grey[700]! : Colors.grey;
    final bgColor = isDark ? Colors.grey[900]! : Colors.grey[100]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload Deal/Promotion'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showFormatGuidance,
            tooltip: 'Format Guidance',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 100), // Increased bottom padding for floating buttons
          children: [
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(12),
                  color: bgColor,
                ),
                child: _mediaFile == null
                    ? Center(child: Text('Tap to select image or video', style: TextStyle(color: textColor)))
                    : _mediaType == 'image'
                        ? Image.file(_mediaFile!, fit: BoxFit.cover)
                        : _VideoPreviewWidget(file: _mediaFile!),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _captionController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Caption (optional)',
                labelStyle: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Theme(
              data: Theme.of(context).copyWith(
                cardColor: bgColor,
                textTheme: Theme.of(context).textTheme.apply(
                  bodyColor: textColor,
                  displayColor: textColor,
                ),
              ),
              child: AdPricingSelector(
                selectedDays: _adDays,
                onDaysChanged: (days) => setState(() => _adDays = days),
                pricePerDay: 10.0,
                seasonalMultiplier: _seasonalMultiplier,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                'Current: $_seasonLabel',
                style: TextStyle(
                  color: isDark ? Colors.amberAccent : Colors.orange,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _acceptedTerms,
                  onChanged: (val) {
                    if (!_acceptedTerms) _showTermsAndConditions();
                  },
                  checkColor: isDark ? Colors.black : null,
                  fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                    if (isDark) {
                      if (states.contains(MaterialState.selected)) {
                        return Colors.white;
                      }
                      return Colors.white54;
                    }
                    return Theme.of(context).colorScheme.primary;
                  }),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: _showTermsAndConditions,
                    child: Text('I accept the Terms & Conditions', style: TextStyle(color: textColor)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting || _mediaFile == null || !_acceptedTerms ? null : _submitAd,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit for Review'),
            ),
          ],
        ),
      ),
    );
  }
}
