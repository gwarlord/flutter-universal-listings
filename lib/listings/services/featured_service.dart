import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Result from requestFeaturedListing call
class FeaturedRequestResult {
  final String requestId;
  final String status; // 'activated', 'pending', 'rejected'
  final bool eligibilityPassed;
  final List<String> eligibilityReasons;
  final String? featuredUntil; // ISO date string if activated
  final int allocatedSlots;
  final int usedSlots;

  FeaturedRequestResult({
    required this.requestId,
    required this.status,
    required this.eligibilityPassed,
    required this.eligibilityReasons,
    this.featuredUntil,
    required this.allocatedSlots,
    required this.usedSlots,
  });

  factory FeaturedRequestResult.fromJson(Map<String, dynamic> json) {
    final eligibilityData = json['eligibility'];
    final eligibility = eligibilityData is Map<String, dynamic>
        ? eligibilityData
        : Map<String, dynamic>.from(eligibilityData as Map? ?? {});

    return FeaturedRequestResult(
      requestId: json['requestId'] as String? ?? '',
      status: json['status'] as String? ?? 'unknown',
      eligibilityPassed: eligibility['passed'] as bool? ?? false,
      eligibilityReasons: (eligibility['reasons'] as List<dynamic>?)?.cast<String>() ?? [],
      featuredUntil: json['featuredUntil'] as String?,
      allocatedSlots: json['allocatedSlots'] as int? ?? 0,
      usedSlots: json['usedSlots'] as int? ?? 0,
    );
  }
}

/// Featured usage data for a month
class FeaturedUsage {
  final String month;
  final String? tier;
  final int allocatedSlots;
  final int usedSlots;
  final int activeCount;
  final DateTime? updatedAt;

  FeaturedUsage({
    required this.month,
    this.tier,
    required this.allocatedSlots,
    required this.usedSlots,
    required this.activeCount,
    this.updatedAt,
  });

  factory FeaturedUsage.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return FeaturedUsage(
      month: data['month'] as String? ?? '',
      tier: data['tier'] as String?,
      allocatedSlots: data['allocatedSlots'] as int? ?? 0,
      usedSlots: data['usedSlots'] as int? ?? 0,
      activeCount: data['activeCount'] as int? ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  int get remainingSlots => allocatedSlots - usedSlots;
}

/// Featured request model
class FeaturedRequest {
  final String id;
  final String listingId;
  final String ownerUid;
  final String? country;
  final String? category;
  final DateTime createdAt;
  final String status; // 'pending', 'approved', 'rejected', 'canceled', 'activated', 'expired'
  final DateTime? requestedStart;
  final int durationDays;
  final String? tierAtRequest;
  final bool eligibilityPassed;
  final List<String> eligibilityReasons;
  final String? adminNote;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime? activatedAt;
  final DateTime? featuredUntil;

  FeaturedRequest({
    required this.id,
    required this.listingId,
    required this.ownerUid,
    this.country,
    this.category,
    required this.createdAt,
    required this.status,
    this.requestedStart,
    required this.durationDays,
    this.tierAtRequest,
    required this.eligibilityPassed,
    required this.eligibilityReasons,
    this.adminNote,
    this.approvedBy,
    this.approvedAt,
    this.activatedAt,
    this.featuredUntil,
  });

  factory FeaturedRequest.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    final eligibility = data['eligibilitySnapshot'] as Map<String, dynamic>? ?? {};

    return FeaturedRequest(
      id: snapshot.id,
      listingId: data['listingId'] as String? ?? '',
      ownerUid: data['ownerUid'] as String? ?? '',
      country: data['country'] as String?,
      category: data['category'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'unknown',
      requestedStart: (data['requestedStart'] as Timestamp?)?.toDate(),
      durationDays: data['durationDays'] as int? ?? 7,
      tierAtRequest: data['tierAtRequest'] as String?,
      eligibilityPassed: eligibility['passed'] as bool? ?? false,
      eligibilityReasons: (eligibility['reasons'] as List<dynamic>?)?.cast<String>() ?? [],
      adminNote: data['adminNote'] as String?,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate(),
      featuredUntil: (data['featuredUntil'] as Timestamp?)?.toDate(),
    );
  }
}

/// Featured grant (audit record)
class FeaturedGrant {
  final String id;
  final String listingId;
  final String requestId;
  final DateTime activatedAt;
  final DateTime featuredUntil;
  final String month;
  final String tier;
  final DateTime createdAt;

  FeaturedGrant({
    required this.id,
    required this.listingId,
    required this.requestId,
    required this.activatedAt,
    required this.featuredUntil,
    required this.month,
    required this.tier,
    required this.createdAt,
  });

  factory FeaturedGrant.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snapshot) {
    final data = snapshot.data() ?? {};
    return FeaturedGrant(
      id: snapshot.id,
      listingId: data['listingId'] as String? ?? '',
      requestId: data['requestId'] as String? ?? '',
      activatedAt: (data['activatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      featuredUntil: (data['featuredUntil'] as Timestamp?)?.toDate() ?? DateTime.now(),
      month: data['month'] as String? ?? '',
      tier: data['tier'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

/// Service for managing featured listings
class FeaturedService {
  static final FeaturedService _instance = FeaturedService._internal();

  factory FeaturedService() => _instance;

  FeaturedService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Request featured placement for a listing
  Future<FeaturedRequestResult> requestFeaturedListing(String listingId) async {
    final callable = _functions.httpsCallable('requestFeaturedListing');
    final result = await callable.call({'listingId': listingId});
    return FeaturedRequestResult.fromJson(Map<String, dynamic>.from(result.data));
  }

  /// Admin approve a featured request
  Future<void> adminApproveFeaturedRequest(String requestId, {String? adminNote}) async {
    final callable = _functions.httpsCallable('adminApproveFeaturedRequest');
    await callable.call({
      'requestId': requestId,
      if (adminNote != null) 'adminNote': adminNote,
    });
  }

  /// Get current month key (YYYY-MM in UTC)
  String getCurrentMonthKey() {
    final now = DateTime.now().toUtc();
    final year = now.year;
    final month = now.month.toString().padLeft(2, '0');
    return '$year-$month';
  }

  /// Stream featured usage for a specific month
  Stream<FeaturedUsage?> streamUsage(String userId, String monthKey) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('featured_usage')
        .doc(monthKey)
        .snapshots()
        .map((snapshot) => snapshot.exists ? FeaturedUsage.fromFirestore(snapshot) : null);
  }

  /// Stream current month's usage
  Stream<FeaturedUsage?> streamCurrentUsage(String userId) {
    return streamUsage(userId, getCurrentMonthKey());
  }

  /// Fetch featured usage for a month
  Future<FeaturedUsage?> fetchUsage(String userId, String monthKey) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('featured_usage')
        .doc(monthKey)
        .get();
    return snapshot.exists ? FeaturedUsage.fromFirestore(snapshot) : null;
  }

  /// Fetch current month's usage
  Future<FeaturedUsage?> fetchCurrentUsage(String userId) async {
    return fetchUsage(userId, getCurrentMonthKey());
  }

  /// Stream user's featured requests
  Stream<List<FeaturedRequest>> streamMyRequests(String userId) {
    return _firestore
        .collection('featured_requests')
        .where('ownerUid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FeaturedRequest.fromFirestore(doc)).toList());
  }

  /// Stream all pending featured requests (admin)
  Stream<List<FeaturedRequest>> streamPendingRequests() {
    return _firestore
        .collection('featured_requests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FeaturedRequest.fromFirestore(doc)).toList());
  }

  /// Fetch user's grants (history)
  Future<List<FeaturedGrant>> fetchMyGrants(String userId, {int limit = 20}) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('featured_grants')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) => FeaturedGrant.fromFirestore(doc)).toList();
  }

  /// Stream user's grants
  Stream<List<FeaturedGrant>> streamMyGrants(String userId, {int limit = 20}) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('featured_grants')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FeaturedGrant.fromFirestore(doc)).toList());
  }
}
