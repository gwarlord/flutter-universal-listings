import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:caribtap/core/utils/helper.dart';
import 'package:caribtap/listings/listings_app_config.dart';
import 'package:caribtap/listings/model/ad_targeting_model.dart';
import 'package:caribtap/listings/model/categories_model.dart';
import 'package:caribtap/listings/model/deal_ad_model.dart';
import 'package:caribtap/listings/model/deal_ad_quota.dart';
import 'package:caribtap/listings/listings_module/api/listings_api_manager.dart';
import 'package:caribtap/listings/services/deal_ad_service.dart';
import 'package:caribtap/listings/services/media_upload_service.dart';
import 'package:caribtap/listings/services/deal_ad_quota_manager.dart';
import 'package:caribtap/listings/ui/auth/authentication_bloc.dart';
import 'package:caribtap/listings/ui/deals/ad_card_preview.dart';
import 'package:caribtap/listings/utils/caribbean_countries.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

// Helper function to convert country code to flag emoji
String _countryCodeToFlag(String countryCode) {
  final code = countryCode.toUpperCase();
  if (code.length != 2) return '';
  return String.fromCharCode(code.codeUnitAt(0) - 65 + 0x1F1E6) +
      String.fromCharCode(code.codeUnitAt(1) - 65 + 0x1F1E6);
}

/// Review step in ad creation flow
/// Shows accurate preview of ad and allows user to go back to edit or confirm submission
class AdReviewScreen extends StatefulWidget {
  final List<dynamic>? availableCategories;
  // Draft data from upload screen
  final File? mediaFile;
  final String? existingMediaUrl;
  final String? existingThumbnailUrl;
  final String mediaType;
  final String caption;
  final int adDays;
  final DateTime? promoStartDate;
  final DateTime? promoEndDate;
  final String adType;
  final List<String> selectedCountryCodes;
  final AdTargeting targeting;
  final double pricePaid;
  
  // Redemption/Deal Settings
  final String redemptionType;
  final String? promoCode;
  final int? redemptionLimitTotal;
  final int? redemptionLimitPerUser;
  final DateTime expireAt;
  final DateTime? scheduleAt;
  
  // Context data
  final String listerId;
  final String listingId;
  
  // Edit mode
  final DealAdModel? adToEdit;
  final bool readOnly;
  final String? screenTitle;
  final String? instructionText;

  const AdReviewScreen({
    Key? key,
    this.mediaFile,
    this.existingMediaUrl,
    this.existingThumbnailUrl,
    required this.mediaType,
    required this.caption,
    required this.adDays,
    this.promoStartDate,
    this.promoEndDate,
    required this.adType,
    required this.selectedCountryCodes,
    required this.targeting,
    required this.pricePaid,
    this.redemptionType = 'IN_APP_CLAIM',
    this.promoCode,
    this.redemptionLimitTotal,
    this.redemptionLimitPerUser,
    required this.expireAt,
    this.scheduleAt,
    required this.listerId,
    required this.listingId,
    this.adToEdit,
    this.availableCategories,
    this.readOnly = false,
    this.screenTitle,
    this.instructionText,
  }) : super(key: key);

  @override
  State<AdReviewScreen> createState() => _AdReviewScreenState();
}

class _AdReviewScreenState extends State<AdReviewScreen> {
  bool _isSubmitting = false;
  late final Future<List<CategoriesModel>> _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _loadCategories();
  }

  Future<List<CategoriesModel>> _loadCategories() async {
    if ((widget.availableCategories ?? []).isNotEmpty) {
      return (widget.availableCategories ?? []).cast<CategoriesModel>();
    }
    if (widget.targeting.categories.isEmpty) {
      return const <CategoriesModel>[];
    }
    return listingApiManager.getCategories();
  }

  bool _isPaidTier(String? rawTier) {
    final tier = (rawTier ?? '').trim().toLowerCase();
    return tier.contains('professional') ||
        tier.contains('premium') ||
        tier == 'pro' ||
        tier.contains('business');
  }

  Future<void> _validateSubmitAccess({
    required String userId,
    required String listingId,
  }) async {
    final firestore = FirebaseFirestore.instance;
    if (listingId.trim().isEmpty) {
      throw 'Selected listing is invalid. Please reselect and try again.';
    }

    final userDoc = await firestore
        .collection('users')
        .doc(userId)
        .get(const GetOptions(source: Source.server));
    if (!userDoc.exists) {
      throw 'Your user profile was not found. Please sign out and sign in again.';
    }
    final userData = userDoc.data() ?? const <String, dynamic>{};
    if (!_isPaidTier(userData['subscriptionTier'] as String?)) {
      throw 'Your current subscription tier is not allowed to submit ads.';
    }

    final listingDoc = await firestore
        .collection('listings')
        .doc(listingId)
        .get(const GetOptions(source: Source.server));
    if (!listingDoc.exists) {
      throw 'Selected listing no longer exists.';
    }

    final listingData = listingDoc.data() ?? const <String, dynamic>{};
    final listingAuthor = (listingData['authorID'] as String?) ?? '';
    if (listingAuthor != userId) {
      throw 'You can only submit ads for listings you own.';
    }

    final freshness = listingData['freshness'];
    if (freshness is Map<String, dynamic>) {
      final status = (freshness['status'] as String?) ?? '';
      if (status.toUpperCase() == 'HIDDEN') {
        throw 'This listing is hidden and cannot be used for ads.';
      }
    }
  }

  Future<String?> _diagnosePermissionDenied({
    required String authUid,
    required String listingId,
  }) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final listingDoc = await firestore
          .collection('listings')
          .doc(listingId)
          .get(const GetOptions(source: Source.server));
      if (!listingDoc.exists) {
        return 'Selected listing does not exist on server.';
      }

      final listingData = listingDoc.data() ?? const <String, dynamic>{};
      final listingAuthor = (listingData['authorID'] as String?) ?? '';
      if (listingAuthor != authUid) {
        return 'Server says this listing is owned by another account.';
      }

      final freshness = listingData['freshness'];
      if (freshness is Map<String, dynamic>) {
        final status = (freshness['status'] as String?) ?? '';
        if (status.toUpperCase() == 'HIDDEN') {
          return 'Listing freshness status is HIDDEN on server.';
        }
      }

      final userDoc = await firestore
          .collection('users')
          .doc(authUid)
          .get(const GetOptions(source: Source.server));
      final userTier = (userDoc.data()?['subscriptionTier'] as String?) ?? '';
      if (!_isPaidTier(userTier)) {
        return 'Server user profile tier is "$userTier".';
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  void _showFullScreenPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullScreenAdPreview(
          mediaFile: widget.mediaFile,
          mediaUrl: widget.existingMediaUrl,
          mediaType: widget.mediaType,
          caption: widget.caption,
          adType: widget.adType,
          startDate: widget.adType == 'promo' && widget.promoStartDate != null 
              ? widget.promoStartDate! 
              : DateTime.now(),
          endDate: widget.adType == 'promo' && widget.promoEndDate != null 
              ? widget.promoEndDate! 
              : DateTime.now().add(Duration(days: widget.adDays)),
          visibilityCountries: widget.selectedCountryCodes,
          redemptionType: widget.redemptionType,
          redemptionLimitTotal: widget.redemptionLimitTotal,
          redemptionLimitPerUser: widget.redemptionLimitPerUser,
          promoCode: widget.promoCode,
        ),
      ),
    );
  }

  Future<void> _confirmAndSubmit() async {
    setState(() => _isSubmitting = true);
    var stage = 'initialize';
    try {
      // Get current user data from context
      final authBloc = context.read<AuthenticationBloc>();
      final user = authBloc.user;
      final firebaseUser = auth.FirebaseAuth.instance.currentUser;
      final authUid = firebaseUser?.uid;
      
      if (user == null || authUid == null || authUid.isEmpty) {
        throw 'User not authenticated';
      }

      stage = 'preflight_validation';
      await _validateSubmitAccess(
        userId: authUid,
        listingId: widget.listingId,
      );

      final normalizedTier = DealAdQuota.normalizeTier(user.subscriptionTier);

      // Check if this is an edit (editing existing ads doesn't count against quota)
      if (widget.adToEdit == null) {
        stage = 'quota_precheck';
        // Check quota for new ads
        final quotaManager = DealAdQuotaManager();
        final hasQuota = await quotaManager.hasRemainingQuota(
          authUid,
          normalizedTier,
        );

        if (!hasQuota) {
          if (!mounted) return;
          final resetDate = await quotaManager.getResetDateString(authUid, normalizedTier);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                normalizedTier == 'free'
                    ? 'Upgrade to Professional or Premium to post ads'
                    : 'Monthly ad posting quota exhausted. Try again $resetDate',
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 4),
            ),
          );
          setState(() => _isSubmitting = false);
          return;
        }
      }

      final adId = widget.adToEdit?.id ?? const Uuid().v4();
      final mediaService = MediaUploadService();

      String? mediaUrl = widget.existingMediaUrl;
      String? thumbnailUrl = widget.existingThumbnailUrl;

      // Handle new media upload
      if (widget.mediaFile != null) {
        if (widget.mediaType == 'video') {
          final thumbPath = await VideoThumbnail.thumbnailFile(
            video: widget.mediaFile!.path,
            thumbnailPath: (await getTemporaryDirectory()).path,
            imageFormat: ImageFormat.JPEG,
            maxHeight: 300,
            quality: 75,
          );
          if (thumbPath != null) {
            thumbnailUrl = await mediaService.uploadAdThumbnail(File(thumbPath), widget.listerId, adId);
          }
        }
        mediaUrl = await mediaService.uploadAdMedia(widget.mediaFile!, widget.listerId, adId);
      }

      final now = DateTime.now();
      final startDate = widget.adType == 'promo' && widget.promoStartDate != null 
          ? widget.promoStartDate! 
          : now;
      final endDate = widget.adType == 'promo' && widget.promoEndDate != null 
          ? widget.promoEndDate! 
          : now.add(Duration(days: widget.adDays));

      final ad = DealAdModel(
        id: adId,
        listerId: authUid,
        listingId: widget.listingId,
        mediaUrl: mediaUrl!,
        mediaType: widget.mediaType,
        thumbnailUrl: thumbnailUrl,
        caption: widget.caption,
        durationDays: widget.adDays,
        pricePaid: widget.pricePaid,
        startDate: startDate,
        endDate: endDate,
        expireAt: widget.expireAt,
        scheduleAt: widget.scheduleAt,
        status: widget.adToEdit?.status ?? 'pending',
        createdAt: widget.adToEdit?.createdAt ?? now,
        approvedAt: widget.adToEdit?.approvedAt,
        reviewerId: widget.adToEdit?.reviewerId,
        authorID: authUid,
        adType: widget.adType,
        visibilityCountries: widget.selectedCountryCodes,
        targeting: widget.targeting,
        redemptionType: widget.redemptionType,
        promoCode: widget.promoCode,
        redemptionLimitTotal: widget.redemptionLimitTotal,
        redemptionLimitPerUser: widget.redemptionLimitPerUser,
      );

      stage = 'submit_ad';
      await DealAdService().submitAd(ad);
      
      // Increment quota after successful submission (new ads only)
      if (widget.adToEdit == null && authUid.isNotEmpty) {
        try {
          stage = 'quota_increment';
          final quotaManager = DealAdQuotaManager();
          await quotaManager.incrementAdPosted(authUid, normalizedTier);
        } catch (quotaError) {
          // Non-fatal: ad already submitted. Keep UX successful and log for follow-up.
          print('⚠️ Quota increment failed after ad submission: $quotaError');
        }
      }
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.adToEdit != null 
              ? 'Ad updated successfully!' 
              : 'Ad submitted for review!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Pop twice to go back to the original screen
      Navigator.pop(context);
      Navigator.pop(context);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      print('❌ FirebaseException during ad submit at stage=$stage code=${e.code} message=${e.message}');
      String message;
      if (e.code == 'permission-denied') {
        final authUid = auth.FirebaseAuth.instance.currentUser?.uid;
        final diagnostic = (authUid != null && authUid.isNotEmpty)
            ? await _diagnosePermissionDenied(
                authUid: authUid,
                listingId: widget.listingId,
              )
            : null;
        message = diagnostic != null
            ? 'Permission denied at $stage: $diagnostic'
            : 'Permission denied at $stage. Please verify your access and try again.';
      } else {
        message = 'Failed at $stage: ${e.message ?? e.code}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit ad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = isDarkMode(context);
    final primaryColor = Color(colorPrimary);
    final adaptiveTextColor = isDark ? Colors.white : Colors.black87;
    final screenTitle = widget.screenTitle ?? 'Review Your Ad';
    final instructionText = widget.instructionText ??
        'Review how your ad will appear to users. You can go back to edit or confirm to submit.';

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(
          screenTitle,
          style: TextStyle(
            color: adaptiveTextColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(color: adaptiveTextColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Instruction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      instructionText,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Section: Ad Preview
            Text(
              'Ad Preview',
              style: TextStyle(
                color: adaptiveTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            
            AdCardPreview(
              mediaFile: widget.mediaFile,
              mediaUrl: widget.existingMediaUrl,
              mediaType: widget.mediaType,
              caption: widget.caption,
              thumbnailUrl: widget.existingThumbnailUrl,
              showBorder: true,
              ad: widget.adToEdit != null ? widget.adToEdit : (null),
              redemptionType: widget.redemptionType,
              redemptionLimitTotal: widget.redemptionLimitTotal,
              redemptionLimitPerUser: widget.redemptionLimitPerUser,
              promoCode: widget.promoCode,
            ),
            // Redemption/Claim Info (for draft preview)
            if (widget.adToEdit == null && widget.redemptionType != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                child: _buildRedemptionInfo(context),
              ),
            const SizedBox(height: 16),
            
            // Preview Full View Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showFullScreenPreview,
                icon: const Icon(Icons.fullscreen),
                label: const Text('Preview Full View'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryColor,
                  side: BorderSide(color: primaryColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Section: Summary Details
            Text(
              'Campaign Details',
              style: TextStyle(
                color: adaptiveTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildDetailCard(
              isDark: isDark,
              icon: Icons.category,
              label: 'Type',
              value: widget.adType == 'promo' ? 'Promotion' : 'Advert',
              primaryColor: primaryColor,
            ),
            
            const SizedBox(height: 12),
            
            _buildDetailCard(
              isDark: isDark,
              icon: Icons.calendar_today,
              label: 'Duration',
              value: '${widget.adDays} day${widget.adDays > 1 ? 's' : ''}',
              primaryColor: primaryColor,
            ),
            
            if (widget.adType == 'promo' && widget.promoStartDate != null && widget.promoEndDate != null) ...[
              const SizedBox(height: 12),
              _buildDetailCard(
                isDark: isDark,
                icon: Icons.date_range,
                label: 'Promo Period',
                value: '${DateFormat('MMM dd, yyyy').format(widget.promoStartDate!)} - ${DateFormat('MMM dd, yyyy').format(widget.promoEndDate!)}',
                primaryColor: primaryColor,
              ),
            ],
            
            const SizedBox(height: 12),
            
            _buildDetailCard(
              isDark: isDark,
              icon: Icons.attach_money,
              label: 'Total Cost',
              value: '\$${widget.pricePaid.toStringAsFixed(2)}',
              primaryColor: primaryColor,
            ),
            
            const SizedBox(height: 32),
            
            // Section: Targeting Summary
            Text(
              'Targeting',
              style: TextStyle(
                color: adaptiveTextColor,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Locations
                  if (widget.targeting.locations.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Locations',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.targeting.locations.map((loc) => _buildChip(loc, isDark, primaryColor)).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Categories
                  if (widget.targeting.categories.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.category, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Categories',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<CategoriesModel>>(
                      future: _categoriesFuture,
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? const <CategoriesModel>[];
                        return Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.targeting.categories.map((catId) {
                            final cat = categories
                                .where((c) => c.id == catId)
                                .firstOrNull;
                            final catName = cat?.title.isNotEmpty == true
                                ? cat!.title
                                : catId;
                            return _buildChip(catName, isDark, primaryColor);
                          }).toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Audience
                  if (widget.targeting.audience.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.people, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Audience',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.targeting.audience.map((aud) => 
                        _buildChip(_formatAudience(aud), isDark, primaryColor)
                      ).toList(),
                    ),
                    const SizedBox(height: 12),
                  ],
                  
                  // Countries
                  if (widget.selectedCountryCodes.isNotEmpty) ...[
                    Row(
                      children: [
                        Icon(Icons.public, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'Countries',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.selectedCountryCodes.map((code) {
                        final country = CaribbeanCountries.byCode(code);
                        return _buildChip(country?.name ?? code, isDark, primaryColor);
                      }).toList(),
                    ),
                  ] else ...[
                    Row(
                      children: [
                        Icon(Icons.public, size: 16, color: primaryColor),
                        const SizedBox(width: 8),
                        Text(
                          'All Countries',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            if (widget.readOnly)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: Text('Close'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _confirmAndSubmit,
                        icon: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.check_circle),
                        label: Text(
                            _isSubmitting ? 'Submitting...' : 'Confirm & Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionInfo(BuildContext context) {
    final redemptionType = widget.redemptionType;
    final redemptionLimitTotal = widget.redemptionLimitTotal;
    final redemptionLimitPerUser = widget.redemptionLimitPerUser;
    final promoCode = widget.promoCode;

    if (redemptionType == null) return SizedBox.shrink();

    List<Widget> info = [];
    if (redemptionType == 'PROMO_CODE') {
      info.add(Row(
        children: [
          Icon(Icons.confirmation_number, size: 16, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 6),
          Text('Promo Code', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ));
      if (promoCode != null && promoCode.isNotEmpty) {
        info.add(Text('Code: $promoCode'));
      }
      if (redemptionLimitTotal != null) {
        info.add(Text('Total Uses: $redemptionLimitTotal'));
      }
      if (redemptionLimitPerUser != null) {
        info.add(Text('Per User: $redemptionLimitPerUser'));
      }
    }
    if (info.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: info,
    );
  }

  Widget _buildDetailCard({
    required bool isDark,
    required IconData icon,
    required String label,
    required String value,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String text, bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: primaryColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _formatAudience(String audience) {
    switch (audience) {
      case 'ALL':
        return 'All Users';
      case 'INTEREST_BASED':
        return 'Interest-Based';
      case 'NEAR_ME':
        return 'Near Location';
      case 'VIEWED_SIMILAR':
        return 'Viewed Similar';
      case 'FAVORITED':
        return 'Favorited';
      default:
        return audience;
    }
  }
}
// Full-screen preview widget that replicates the deals feed view
class _FullScreenAdPreview extends StatefulWidget {
  final File? mediaFile;
  final String? mediaUrl;
  final String mediaType;
  final String caption;
  final String adType;
  final DateTime startDate;
  final DateTime endDate;
  final List<String> visibilityCountries;
  final String? redemptionType;
  final int? redemptionLimitTotal;
  final int? redemptionLimitPerUser;
  final String? promoCode;

  const _FullScreenAdPreview({
    this.mediaFile,
    this.mediaUrl,
    required this.mediaType,
    required this.caption,
    required this.adType,
    required this.startDate,
    required this.endDate,
    required this.visibilityCountries,
    this.redemptionType,
    this.redemptionLimitTotal,
    this.redemptionLimitPerUser,
    this.promoCode,
  });

  @override
  State<_FullScreenAdPreview> createState() => _FullScreenAdPreviewState();
}

class _FullScreenAdPreviewState extends State<_FullScreenAdPreview> {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    if (widget.mediaType == 'video') {
      if (widget.mediaFile != null) {
        _videoController = VideoPlayerController.file(widget.mediaFile!);
      } else if (widget.mediaUrl != null) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaUrl!));
      }
      
      _videoController?.initialize().then((_) {
        if (mounted) {
          setState(() => _isInitialized = true);
          _videoController!.setLooping(true);
          _videoController!.setVolume(0);
          _videoController!.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Ad Preview', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox(
        width: size.width,
        height: size.height,
        child: Stack(
          children: [
            // Background Blur
            Positioned.fill(
              child: widget.mediaType == 'video'
                  ? (_isInitialized
                      ? ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: FittedBox(
                            fit: BoxFit.cover,
                            child: SizedBox(
                              width: _videoController!.value.size.width,
                              height: _videoController!.value.size.height,
                              child: VideoPlayer(_videoController!),
                            ),
                          ),
                        )
                      : Container(color: Colors.black))
                  : widget.mediaFile != null
                      ? ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Image.file(widget.mediaFile!, fit: BoxFit.cover),
                        )
                      : widget.mediaUrl != null
                          ? ImageFiltered(
                              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Image.network(widget.mediaUrl!, fit: BoxFit.cover),
                            )
                          : Container(color: Colors.black),
            ),

            // Main Content
            Positioned.fill(
              child: Center(
                child: widget.mediaType == 'video'
                    ? (_isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const CircularProgressIndicator(color: Colors.white))
                    : widget.mediaFile != null
                        ? Image.file(widget.mediaFile!, fit: BoxFit.contain)
                        : widget.mediaUrl != null
                            ? Image.network(widget.mediaUrl!, fit: BoxFit.contain)
                            : const SizedBox.shrink(),
              ),
            ),

            // Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.8),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Bottom Info
            Positioned(
              bottom: 30 + bottomPadding,
              left: 16,
              right: 80,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isExpanded = !_isExpanded),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.caption,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                          maxLines: _isExpanded ? null : 2,
                          overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        ),
                        if (widget.caption.length > 60)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _isExpanded ? '...see less' : '...see more',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          widget.adType.toUpperCase(),
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
                        ),
                      ),
                      if (widget.visibilityCountries.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Flexible(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: widget.visibilityCountries.take(3).map((countryCode) {
                              final country = CaribbeanCountries.byCode(countryCode);
                              if (country == null) return const SizedBox.shrink();
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _countryCodeToFlag(countryCode),
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      country.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (widget.visibilityCountries.length > 3) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '+${widget.visibilityCountries.length - 3}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.white70, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'Period: ${DateFormat('MMM d').format(widget.startDate)} - ${DateFormat('MMM d, yyyy').format(widget.endDate)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRedemptionInfo(BuildContext context) {
    final redemptionType = widget.redemptionType;
    final redemptionLimitTotal = widget.redemptionLimitTotal;
    final redemptionLimitPerUser = widget.redemptionLimitPerUser;
    final promoCode = widget.promoCode;

    if (redemptionType == null) return SizedBox.shrink();

    List<Widget> info = [];
    if (redemptionType == 'PROMO_CODE') {
      info.add(Row(
        children: [
          Icon(Icons.confirmation_number, size: 16, color: Theme.of(context).colorScheme.primary),
          SizedBox(width: 6),
          Text('Promo Code', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ));
      if (promoCode != null && promoCode.isNotEmpty) {
        info.add(Text('Code: $promoCode'));
      }
      if (redemptionLimitTotal != null) {
        info.add(Text('Total Uses: $redemptionLimitTotal'));
      }
      if (redemptionLimitPerUser != null) {
        info.add(Text('Per User: $redemptionLimitPerUser'));
      }
    }
    if (info.isEmpty) return SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: info,
    );
  }
}
