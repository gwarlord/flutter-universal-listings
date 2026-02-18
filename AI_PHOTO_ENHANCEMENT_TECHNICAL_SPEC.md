# AI Photo Enhancement - Technical Implementation Spec
## CaribTap Flutter App

---

## PROJECT STRUCTURE

```
lib/
├─ listings/
│  ├─ ui/
│  │  └─ photo_enhancement/
│  │     ├─ widgets/
│  │     │  ├─ enhancement_entry_button.dart
│  │     │  ├─ enhancement_modal.dart
│  │     │  ├─ category_selector_modal.dart
│  │     │  ├─ processing_indicator.dart
│  │     │  ├─ before_after_comparison.dart
│  │     │  ├─ approval_actions.dart
│  │     │  ├─ quota_indicator.dart
│  │     │  ├─ tier_upsell_modal.dart
│  │     │  ├─ limit_reached_modal.dart
│  │     │  ├─ enhancement_error_modal.dart
│  │     │  └─ disclosure_badge.dart
│  │     │
│  │     ├─ cubit/
│  │     │  ├─ photo_enhancement_cubit.dart
│  │     │  └─ photo_enhancement_state.dart
│  │     │
│  │     ├─ models/
│  │     │  ├─ enhancement_request.dart
│  │     │  ├─ enhancement_response.dart
│  │     │  ├─ enhancement_quota.dart
│  │     │  ├─ image_variant.dart
│  │     │  └─ enhancement_specs.dart
│  │     │
│  │     └─ services/
│  │        ├─ photo_enhancement_service.dart
│  │        ├─ quota_manager.dart
│  │        ├─ offline_queue_manager.dart
│  │        └─ enhancement_analytics.dart
│  │
│  └─ listings_module/
│     └─ add_listing/
│        └─ (Integrate enhancement_entry_button here)
│
├─ models/
│  └─ (Update listing_model.dart to include imageVariants)
│
└─ core/
   └─ utils/
      └─ photo_enhancement_utils.dart
```

---

## DETAILED FILE SPECS

### 1. Models

#### 1a. `models/enhancement_request.dart`

```dart
import 'package:caribtap/core/model/user.dart';

class EnhancementRequest {
  final String listingId;
  final String imageId;
  final String imageUrl;
  final String category; // 'product' | 'service' | 'person'
  final String userTier; // 'professional', etc.
  
  EnhancementRequest({
    required this.listingId,
    required this.imageId,
    required this.imageUrl,
    required this.category,
    required this.userTier,
  });

  Map<String, dynamic> toJson() => {
    'listing_id': listingId,
    'image_id': imageId,
    'image_url': imageUrl,
    'category': category,
    'user_tier': userTier,
  };
}
```

#### 1b. `models/enhancement_response.dart`

```dart
class EnhancementResponse {
  final String enhancedImageUrl;
  final String variantId;
  final List<EnhancementSpec> specs;
  final DateTime timestamp;

  EnhancementResponse({
    required this.enhancedImageUrl,
    required this.variantId,
    required this.specs,
    required this.timestamp,
  });

  factory EnhancementResponse.fromJson(Map<String, dynamic> json) {
    return EnhancementResponse(
      enhancedImageUrl: json['enhanced_image_url'] as String,
      variantId: json['variant_id'] as String,
      specs: (json['specs'] as List<dynamic>)
          .map((spec) => EnhancementSpec.fromJson(spec as Map<String, dynamic>))
          .toList(),
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

class EnhancementSpec {
  final String type; // 'lighting', 'clarity', 'framing', etc.
  final bool applied;

  EnhancementSpec({
    required this.type,
    required this.applied,
  });

  factory EnhancementSpec.fromJson(Map<String, dynamic> json) {
    return EnhancementSpec(
      type: json['type'] as String,
      applied: json['applied'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'applied': applied,
  };
}
```

#### 1c. `models/enhancement_quota.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancementQuota {
  final String listingId;
  final int year;
  final int month;
  final int usedCount; // 0–10
  final DateTime monthResetDate;

  const EnhancementQuota({
    required this.listingId,
    required this.year,
    required this.month,
    required this.usedCount,
    required this.monthResetDate,
  });

  int get remaining => (10 - usedCount).clamp(0, 10);
  bool get isAtLimit => usedCount >= 10;

  factory EnhancementQuota.fromJson(Map<String, dynamic> json) {
    return EnhancementQuota(
      listingId: json['listing_id'] as String? ?? '',
      year: json['year'] as int? ?? DateTime.now().year,
      month: json['month'] as int? ?? DateTime.now().month - 1,
      usedCount: json['used_count'] as int? ?? 0,
      monthResetDate: (json['month_reset_date'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'listing_id': listingId,
    'year': year,
    'month': month,
    'used_count': usedCount,
    'month_reset_date': Timestamp.fromDate(monthResetDate),
  };

  EnhancementQuota copyWith({
    String? listingId,
    int? year,
    int? month,
    int? usedCount,
    DateTime? monthResetDate,
  }) =>
      EnhancementQuota(
        listingId: listingId ?? this.listingId,
        year: year ?? this.year,
        month: month ?? this.month,
        usedCount: usedCount ?? this.usedCount,
        monthResetDate: monthResetDate ?? this.monthResetDate,
      );
}
```

#### 1d. `models/image_variant.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class ImageVariant {
  final String id;
  final String listingId;
  final String originalImageId;
  final String variantUrl;
  final String category; // 'product', 'service', 'person'
  final List<String> enhancements; // ['lighting', 'clarity', 'framing']
  final bool hasDisclosure;
  final DateTime enhancedAt;
  final String tier; // 'professional', 'professional_plus', 'professional_pro'

  const ImageVariant({
    required this.id,
    required this.listingId,
    required this.originalImageId,
    required this.variantUrl,
    required this.category,
    required this.enhancements,
    required this.hasDisclosure,
    required this.enhancedAt,
    required this.tier,
  });

  factory ImageVariant.fromJson(String id, Map<String, dynamic> json) {
    return ImageVariant(
      id: id,
      listingId: json['listing_id'] as String? ?? '',
      originalImageId: json['original_image_id'] as String,
      variantUrl: json['variant_url'] as String,
      category: json['category'] as String,
      enhancements: List<String>.from(json['enhancements'] as List? ?? []),
      hasDisclosure: json['has_disclosure'] as bool? ?? true,
      enhancedAt: (json['enhanced_at'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      tier: json['tier'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'listing_id': listingId,
    'original_image_id': originalImageId,
    'variant_url': variantUrl,
    'category': category,
    'enhancements': enhancements,
    'has_disclosure': hasDisclosure,
    'enhanced_at': Timestamp.fromDate(enhancedAt),
    'tier': tier,
  };
}
```

#### 1e. `models/enhancement_specs.dart`

```dart
class EnhancementSpecsInfo {
  // Tier 1 - Professional
  static const tier1 = [
    'Auto-crop & framing optimization',
    'Lighting normalization',
    'Sharpness & clarity enhancement',
    'Subtle background blur',
  ];

  // Tier 2 - Professional Plus (includes tier 1)
  static const tier2 = [
    ...tier1,
    'Background cleanup / neutralization',
    'Subject isolation',
    'Studio-style neutral background options',
    'Face cleanup (subtle only)',
    'Multiple aspect ratio exports',
  ];

  // Tier 3 - Professional Pro (includes tier 1+2)
  static const tier3 = [
    ...tier2,
    'Logo watermarking',
    'Position presets',
    'Opacity control',
    'Optional branded overlay',
  ];

  static List<String> getSpecsForTier(String tier) {
    switch (tier) {
      case 'professional':
        return tier1;
      case 'professional_plus':
        return tier2;
      case 'professional_pro':
        return tier3;
      default:
        return [];
    }
  }

  static List<String> getDisplaySpecs(String tier, String category) {
    switch (category) {
      case 'product':
        return [
          'Auto-crop & framing',
          'Lighting normalization',
          'Clarity enhancement',
          if (tier == 'professional_plus' || tier == 'professional_pro')
            'Background cleanup',
          if (tier == 'professional_pro') 'Logo watermark',
        ];
      case 'service':
        return [
          'Lighting optimization',
          'Clarity enhancement',
          if (tier == 'professional_plus' || tier == 'professional_pro')
            'Background neutralization',
          if (tier == 'professional_pro') 'Logo watermark',
        ];
      case 'person':
        return [
          'Lighting & tone normalization',
          'Clarity enhancement',
          if (tier == 'professional_plus' || tier == 'professional_pro')
            'Face cleanup (subtle)',
          if (tier == 'professional_pro') 'Logo watermark',
        ];
      default:
        return [];
    }
  }
}
```

---

### 2. Cubit (State Management)

#### 2a. `cubit/photo_enhancement_state.dart`

```dart
import 'package:equatable/equatable.dart';
import 'enhancement_response.dart';

abstract class PhotoEnhancementState extends Equatable {
  const PhotoEnhancementState();

  @override
  List<Object?> get props => [];
}

class PhotoEnhancementInitial extends PhotoEnhancementState {
  const PhotoEnhancementInitial();
}

class EnhancementLoading extends PhotoEnhancementState {
  final int progress; // 0-100
  const EnhancementLoading({this.progress = 0});

  @override
  List<Object?> get props => [progress];
}

class EnhancementReady extends PhotoEnhancementState {
  final String originalImageUrl;
  final String enhancedImageUrl;
  final List<EnhancementSpec> specs;

  const EnhancementReady({
    required this.originalImageUrl,
    required this.enhancedImageUrl,
    required this.specs,
  });

  @override
  List<Object?> get props => [originalImageUrl, enhancedImageUrl, specs];
}

class EnhancementApproved extends PhotoEnhancementState {
  final String variantId;
  final String enhancedImageUrl;

  const EnhancementApproved({
    required this.variantId,
    required this.enhancedImageUrl,
  });

  @override
  List<Object?> get props => [variantId, enhancedImageUrl];
}

class EnhancementDiscarded extends PhotoEnhancementState {
  const EnhancementDiscarded();
}

class EnhancementError extends PhotoEnhancementState {
  final String message;
  final String? errorCode; // 'offline', 'processing_failed', 'quota_exceeded'

  const EnhancementError({
    required this.message,
    this.errorCode,
  });

  @override
  List<Object?> get props => [message, errorCode];
}

class QuotaExceeded extends PhotoEnhancementState {
  final int remaining;
  final DateTime nextResetDate;

  const QuotaExceeded({
    required this.remaining,
    required this.nextResetDate,
  });

  @override
  List<Object?> get props => [remaining, nextResetDate];
}

class NotSubscribed extends PhotoEnhancementState {
  final String currentTier; // 'free', 'basic', etc.

  const NotSubscribed({required this.currentTier});

  @override
  List<Object?> get props => [currentTier];
}

class OfflineError extends PhotoEnhancementState {
  const OfflineError();
}
```

#### 2b. `cubit/photo_enhancement_cubit.dart`

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'photo_enhancement_state.dart';
import '../services/photo_enhancement_service.dart';
import '../services/quota_manager.dart';
import '../models/enhancement_request.dart';

class PhotoEnhancementCubit extends Cubit<PhotoEnhancementState> {
  final PhotoEnhancementService _enhancementService;
  final QuotaManager _quotaManager;
  final Connectivity _connectivity;

  PhotoEnhancementCubit({
    required PhotoEnhancementService enhancementService,
    required QuotaManager quotaManager,
    Connectivity? connectivity,
  })  : _enhancementService = enhancementService,
        _quotaManager = quotaManager,
        _connectivity = connectivity ?? Connectivity(),
        super(const PhotoEnhancementInitial());

  Future<void> startEnhancement({
    required String listingId,
    required String imageId,
    required String imageUrl,
    required String category,
    required String userTier,
  }) async {
    // 1. Check subscription
    if (!_isSubscribedToEnhancement(userTier)) {
      emit(NotSubscribed(currentTier: userTier));
      return;
    }

    // 2. Check internet
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      emit(const OfflineError());
      return;
    }

    // 3. Check quota
    final canEnhance = await _quotaManager.canEnhance(listingId);
    if (!canEnhance) {
      final quota = await _quotaManager.getQuota(listingId);
      emit(QuotaExceeded(
        remaining: quota.remaining,
        nextResetDate: quota.monthResetDate,
      ));
      return;
    }

    // 4. Record attempt BEFORE processing
    await _quotaManager.recordEnhancementAttempt(listingId);

    // 5. Start processing
    emit(const EnhancementLoading(progress: 0));

    try {
      final request = EnhancementRequest(
        listingId: listingId,
        imageId: imageId,
        imageUrl: imageUrl,
        category: category,
        userTier: userTier,
      );

      final response = await _enhancementService.enhance(request);

      emit(EnhancementReady(
        originalImageUrl: imageUrl,
        enhancedImageUrl: response.enhancedImageUrl,
        specs: response.specs,
      ));
    } on Exception catch (e) {
      emit(EnhancementError(
        message: _getErrorMessage(e),
        errorCode: _getErrorCode(e),
      ));
    }
  }

  Future<void> approveEnhancement({
    required String listingId,
    required String imageId,
    required String variantId,
    required String enhancedImageUrl,
    required String category,
    required String userTier,
  }) async {
    try {
      emit(const EnhancementLoading(progress: 50));

      await _enhancementService.saveVariant(
        listingId: listingId,
        imageId: imageId,
        variantId: variantId,
        enhancedImageUrl: enhancedImageUrl,
        category: category,
        userTier: userTier,
      );

      emit(EnhancementApproved(
        variantId: variantId,
        enhancedImageUrl: enhancedImageUrl,
      ));
    } on Exception catch (e) {
      emit(EnhancementError(message: _getErrorMessage(e)));
    }
  }

  void discardEnhancement() {
    emit(const EnhancementDiscarded());
  }

  void reset() {
    emit(const PhotoEnhancementInitial());
  }

  bool _isSubscribedToEnhancement(String tierId) {
    return tierId == 'professional' ||
        tierId == 'professional_plus' ||
        tierId == 'professional_pro';
  }

  String _getErrorMessage(Exception e) {
    if (e is OfflineException) {
      return 'You need internet to enhance photos. Please reconnect.';
    } else if (e is ProcessingFailedException) {
      return 'We couldn\'t process this image. Check your internet & try again.';
    } else if (e is InvalidCategoryException) {
      return 'Invalid category selected. Please try again.';
    } else {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  String? _getErrorCode(Exception e) {
    if (e is OfflineException) return 'offline';
    if (e is ProcessingFailedException) return 'processing_failed';
    if (e is InvalidCategoryException) return 'invalid_category';
    return null;
  }
}

// Custom exceptions
class OfflineException implements Exception {
  final String message = 'No internet connection';
  @override
  String toString() => message;
}

class ProcessingFailedException implements Exception {
  final String message;
  ProcessingFailedException([this.message = 'Image processing failed']);
  @override
  String toString() => message;
}

class InvalidCategoryException implements Exception {
  final String category;
  InvalidCategoryException(this.category);
  @override
  String toString() => 'Invalid category: $category';
}
```

---

### 3. Services

#### 3a. `services/photo_enhancement_service.dart`

```dart
import 'package:cloud_functions/cloud_functions.dart';
import '../models/enhancement_request.dart';
import '../models/enhancement_response.dart';
import '../cubit/photo_enhancement_cubit.dart';

class PhotoEnhancementService {
  final FirebaseFunctions _functions;

  PhotoEnhancementService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<EnhancementResponse> enhance(EnhancementRequest request) async {
    try {
      final callable = _functions.httpsCallable('enhancePhoto');
      
      final response = await callable.call({
        'listing_id': request.listingId,
        'image_id': request.imageId,
        'image_url': request.imageUrl,
        'category': request.category,
        'user_tier': request.userTier,
      });

      if (response.data == null) {
        throw ProcessingFailedException('Empty response from server');
      }

      return EnhancementResponse.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'resource-exhausted') {
        throw ProcessingFailedException('Quota exceeded');
      } else if (e.code == 'unauthenticated') {
        throw ProcessingFailedException('Not authenticated');
      } else if (e.code == 'invalid-argument') {
        throw InvalidCategoryException(
          (response.data as Map?)?['category'] ?? 'unknown',
        );
      } else {
        throw ProcessingFailedException(e.message ?? 'Processing failed');
      }
    } catch (e) {
      throw ProcessingFailedException('Unexpected error: $e');
    }
  }

  Future<void> saveVariant({
    required String listingId,
    required String imageId,
    required String variantId,
    required String enhancedImageUrl,
    required String category,
    required String userTier,
  }) async {
    try {
      final callable = _functions.httpsCallable('saveEnhancementVariant');

      await callable.call({
        'listing_id': listingId,
        'image_id': imageId,
        'variant_id': variantId,
        'enhanced_image_url': enhancedImageUrl,
        'category': category,
        'user_tier': userTier,
      });
    } catch (e) {
      throw ProcessingFailedException('Failed to save variant: $e');
    }
  }
}
```

#### 3b. `services/quota_manager.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/enhancement_quota.dart';

class QuotaManager {
  final FirebaseFirestore _firestore;
  static const _limitsPerMonth = 10;

  QuotaManager({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get remaining enhancements for a listing this month
  Future<int> getRemainingQuota(String listingId) async {
    final quota = await getQuota(listingId);
    return quota.remaining;
  }

  /// Get full quota info
  Future<EnhancementQuota> getQuota(String listingId) async {
    try {
      final doc = await _firestore
          .collection('listings')
          .doc(listingId)
          .get();

      if (!doc.exists) {
        return _createNewQuota(listingId);
      }

      final quotaData = doc.data()?['enhancement_quota'] as Map?;

      if (quotaData == null) {
        return _createNewQuota(listingId);
      }

      final quota = EnhancementQuota.fromJson(quotaData as Map<String, dynamic>);

      // Check if month has changed
      final now = DateTime.now();
      if (quota.year != now.year || quota.month != now.month - 1) {
        // Month changed; reset quota
        await _resetQuota(listingId);
        return _createNewQuota(listingId);
      }

      return quota;
    } catch (e) {
      throw QuotaException('Failed to fetch quota: $e');
    }
  }

  /// Check if enhancement is allowed
  Future<bool> canEnhance(String listingId) async {
    final quota = await getQuota(listingId);
    return !quota.isAtLimit;
  }

  /// Record enhancement attempt (called when AI processing starts)
  Future<void> recordEnhancementAttempt(String listingId) async {
    try {
      await _firestore
          .collection('listings')
          .doc(listingId)
          .update({
        'enhancement_quota.used_count': FieldValue.increment(1),
      });
    } catch (e) {
      throw QuotaException('Failed to record attempt: $e');
    }
  }

  /// Reset quota for new month
  Future<void> _resetQuota(String listingId) async {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    await _firestore
        .collection('listings')
        .doc(listingId)
        .update({
      'enhancement_quota': {
        'year': now.year,
        'month': now.month - 1, // 0-indexed
        'used_count': 0,
        'month_reset_date': Timestamp.fromDate(nextMonth),
      }
    });
  }

  /// Initialize quota for new listing
  EnhancementQuota _createNewQuota(String listingId) {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    return EnhancementQuota(
      listingId: listingId,
      year: now.year,
      month: now.month - 1,
      usedCount: 0,
      monthResetDate: nextMonth,
    );
  }
}

class QuotaException implements Exception {
  final String message;
  QuotaException(this.message);
  @override
  String toString() => message;
}
```

#### 3c. `services/offline_queue_manager.dart`

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/enhancement_request.dart';

class OfflineQueueManager {
  final SharedPreferences _prefs;
  static const _queueKey = 'enhancement_queue';

  OfflineQueueManager({SharedPreferences? prefs})
      : _prefs = prefs ?? throw ArgumentError('SharedPreferences required');

  /// Queue enhancement for processing when online
  Future<void> queueEnhancement(EnhancementRequest request) async {
    final queue = _getQueue();
    queue.add(request.toJson());
    await _prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Get all queued enhancements
  List<EnhancementRequest> getQueuedEnhancements() {
    final queue = _getQueue();
    return queue
        .map((json) => EnhancementRequest(
              listingId: json['listing_id'] as String,
              imageId: json['image_id'] as String,
              imageUrl: json['image_url'] as String,
              category: json['category'] as String,
              userTier: json['user_tier'] as String,
            ))
        .toList();
  }

  /// Remove enhancement from queue
  Future<void> removeFromQueue(String listingId, String imageId) async {
    final queue = _getQueue();
    queue.removeWhere(
      (item) =>
          item['listing_id'] == listingId && item['image_id'] == imageId,
    );
    await _prefs.setString(_queueKey, jsonEncode(queue));
  }

  /// Clear entire queue
  Future<void> clearQueue() async {
    await _prefs.remove(_queueKey);
  }

  List<Map<String, dynamic>> _getQueue() {
    final json = _prefs.getString(_queueKey);
    if (json == null || json.isEmpty) return [];
    return List<Map<String, dynamic>>.from(jsonDecode(json) as List);
  }
}
```

#### 3d. `services/enhancement_analytics.dart`

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class EnhancementAnalytics {
  final FirebaseFirestore _firestore;

  EnhancementAnalytics({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Log enhancement attempt
  Future<void> logEnhancementAttempt({
    required String listingId,
    required String category,
    required String tier,
    required String status, // 'started', 'success', 'failed'
  }) async {
    await _firestore.collection('analytics_events').add({
      'event': 'ai_enhance_attempt',
      'listing_id': listingId,
      'category': category,
      'tier': tier,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Log enhancement approval
  Future<void> logEnhancementApproval({
    required String listingId,
    required String imageId,
    required String variantId,
    required String category,
    required String tier,
  }) async {
    await _firestore.collection('analytics_events').add({
      'event': 'ai_enhance_approval',
      'listing_id': listingId,
      'image_id': imageId,
      'variant_id': variantId,
      'category': category,
      'tier': tier,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Log enhancement discard
  Future<void> logEnhancementDiscard({
    required String listingId,
    required String imageId,
    required String reason,
  }) async {
    await _firestore.collection('analytics_events').add({
      'event': 'ai_enhance_discard',
      'listing_id': listingId,
      'image_id': imageId,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Log quota limit reached
  Future<void> logQuotaLimitReached({
    required String listingId,
    required String tier,
  }) async {
    await _firestore.collection('analytics_events').add({
      'event': 'ai_enhance_quota_limit',
      'listing_id': listingId,
      'tier': tier,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
```

---

### 4. Widgets (Continued in next section due to length)

#### 4a. `widgets/enhancement_entry_button.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:caribtap/constant.dart';

class EnhancementEntryButton extends StatelessWidget {
  final String listingId;
  final String imageId;
  final String imageUrl;
  final String userTier;
  final int remaining;
  final VoidCallback onPressed;
  final bool isEnabled;

  const EnhancementEntryButton({
    Key? key,
    required this.listingId,
    required this.imageId,
    required this.imageUrl,
    required this.userTier,
    required this.remaining,
    required this.onPressed,
    required this.isEnabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
        color: isEnabled ? Colors.blue.shade50 : Colors.grey.shade100,
      ),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: isEnabled ? Colors.blue : Colors.grey,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Enhance photo (Professional)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? Colors.black87 : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI-assisted improvements for better clarity & framing',
                style: TextStyle(
                  fontSize: 12,
                  color: isEnabled ? Colors.black54 : Colors.grey[500],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isEnabled ? Colors.green.shade50 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Remaining: $remaining of 10 this month',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: isEnabled ? Colors.green[700] : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

#### 4b. `widgets/category_selector_modal.dart`

```dart
import 'package:flutter/material.dart';

class CategorySelectorModal extends StatefulWidget {
  final Function(String) onCategorySelected;
  final VoidCallback onCancel;

  const CategorySelectorModal({
    Key? key,
    required this.onCategorySelected,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<CategorySelectorModal> createState() => _CategorySelectorModalState();
}

class _CategorySelectorModalState extends State<CategorySelectorModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'What are you enhancing?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCancel,
                  child: Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Select category for best results',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 24),
            _buildCategoryTile(
              icon: '📷',
              title: 'Product Photo',
              subtitle: 'Objects, items, merchandise',
              onTap: () => widget.onCategorySelected('product'),
            ),
            const SizedBox(height: 12),
            _buildCategoryTile(
              icon: '🏢',
              title: 'Service Environment',
              subtitle: 'Business space, setup',
              onTap: () => widget.onCategorySelected('service'),
            ),
            const SizedBox(height: 12),
            _buildCategoryTile(
              icon: '👤',
              title: 'Person / Service Provider',
              subtitle: 'Headshots, professional photo',
              onTap: () => widget.onCategorySelected('person'),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryTile({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
```

(Continued in next section...)

---

## INTEGRATION CHECKLIST

- [ ] Add `connectivity_plus` to `pubspec.yaml`
- [ ] Update `listing_model.dart` with `imageVariants` and `enhancementQuota` fields
- [ ] Create all model files
- [ ] Create cubit with state management
- [ ] Implement all service classes
- [ ] Build widget components
- [ ] Wire cubit into existing listing edit flow
- [ ] Create Cloud Function for backend processing
- [ ] Set up Firebase Firestore rules for image variants
- [ ] Add analytics logging
- [ ] Test offline scenarios
- [ ] Test quota enforcement
- [ ] Implement feature flag for gradual rollout

---

## NEXT STEPS

1. **Backend setup**: Deploy Cloud Function for `enhancePhoto`
2. **Widget integration**: Add enhancement button to listing image edit flow
3. **Testing**: End-to-end flow testing with real images
4. **Analytics**: Monitor adoption and error rates
5. **Iteration**: Gather user feedback and improve UX
