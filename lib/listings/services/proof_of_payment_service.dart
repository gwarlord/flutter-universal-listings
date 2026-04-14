import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/proof_of_payment_model.dart';
import 'package:flutter/foundation.dart';

class ProofOfPaymentService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  static const String _popStoragePath = 'proof_of_payment';
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const List<String> _allowedImageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> _allowedDocExtensions = ['pdf'];

  Map<String, dynamic> _asStringKeyedMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      final map = <String, dynamic>{};
      value.forEach((key, val) {
        if (key != null) {
          map[key.toString()] = val;
        }
      });
      return map;
    }
    return <String, dynamic>{};
  }

  Timestamp _parseTimestampOrNow(dynamic value) {
    if (value is Timestamp) return value;
    if (value is DateTime) return Timestamp.fromDate(value);
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return Timestamp.fromDate(parsed);
      }
    }
    return Timestamp.now();
  }

  ProofOfPayment? _buildLegacyProofOfPayment(Map<String, dynamic> bookingData) {
    final payment = _asStringKeyedMap(bookingData['payment']);
    final proofUrl = (payment['proofOfPaymentUrl'] ?? '').toString().trim();
    if (proofUrl.isEmpty) return null;

    final legacyStatus =
        (payment['proofOfPaymentStatus'] ?? 'pending').toString().toLowerCase();
    final normalizedStatus = legacyStatus == 'approved'
        ? 'VERIFIED'
        : legacyStatus == 'rejected'
            ? 'REJECTED'
            : 'SUBMITTED';

    final uploadedAt = _parseTimestampOrNow(
      bookingData['updatedAt'] ?? bookingData['createdAt'],
    );

    return ProofOfPayment(
      enabledAtOrderTime: true,
      overallStatus: normalizedStatus,
      uploads: [
        ProofOfPaymentUpload(
          fileUrl: proofUrl,
          filePath: '',
          fileType: 'IMAGE',
          fileName: (payment['proofOfPaymentFileName'] ?? '').toString().trim().isEmpty
              ? 'proof_of_payment.jpg'
              : payment['proofOfPaymentFileName'].toString(),
          uploadedAt: uploadedAt,
          uploadedByUid: (bookingData['customerId'] ?? '').toString(),
          status: normalizedStatus,
          reviewerUid: (payment['proofReviewedBy'] ?? '').toString().trim().isEmpty
              ? null
              : payment['proofReviewedBy'].toString(),
          reviewedAt: payment['proofReviewedAt'] is Timestamp
              ? payment['proofReviewedAt'] as Timestamp
              : null,
          reviewerNote: (payment['proofRejectionReason'] ?? '').toString().trim().isEmpty
              ? null
              : payment['proofRejectionReason'].toString(),
        ),
      ],
    );
  }

  Future<void> _mirrorProofOfPaymentToUserCollections({
    required String orderId,
    required Map<String, dynamic> bookingData,
    required Map<String, dynamic> popData,
    required String updatedAt,
  }) async {
    final customerId = (bookingData['customerId'] ?? '').toString().trim();
    final listerId = (bookingData['listersUserId'] ?? '').toString().trim();

    if (customerId.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(customerId)
            .collection('myBookings')
            .doc(orderId)
            .update({
          'proofOfPayment': popData,
          'updatedAt': updatedAt,
        });
      } catch (e) {
        debugPrint('Mirror update skipped for myBookings ($orderId): $e');
      }
    }

    if (listerId.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(listerId)
            .collection('receivedBookings')
            .doc(orderId)
            .update({
          'proofOfPayment': popData,
          'updatedAt': updatedAt,
        });
      } catch (e) {
        debugPrint('Mirror update skipped for receivedBookings ($orderId): $e');
      }
    }
  }

  /// Upload proof of payment file to Firebase Storage
  /// Returns ProofOfPaymentUpload object with file metadata or throws exception
  Future<ProofOfPaymentUpload> uploadProofOfPayment({
    required File file,
    required String orderId,
    required String uploadedByUid,
    required String fileType, // "IMAGE" or "PDF"
    String? fileName,
  }) async {
    try {
      // Validate file size
      final fileBytes = await file.readAsBytes();
      if (fileBytes.length > _maxFileSizeBytes) {
        throw Exception('File size exceeds 10MB limit');
      }

      // Validate file type
      final extension = file.path.split('.').last.toLowerCase();
      if (fileType == 'IMAGE' && !_allowedImageExtensions.contains(extension)) {
        throw Exception('Invalid image format. Allowed: jpg, jpeg, png');
      }
      if (fileType == 'PDF' && !_allowedDocExtensions.contains(extension)) {
        throw Exception('Invalid document format. Only PDF allowed');
      }

      // Generate storage path: proof_of_payment/{orderId}/{timestamp}_{uid}.{ext}
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName_ = fileName ?? '${timestamp}_$uploadedByUid.$extension';
      final filePath = '$_popStoragePath/$orderId/$fileName_';

      // Upload file
      final ref = _storage.ref(filePath);
      final uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: fileType == 'PDF' ? 'application/pdf' : 'image/$extension',
          customMetadata: {
            'uploadedBy': uploadedByUid,
            'orderId': orderId,
            'fileType': fileType,
          },
        ),
      );

      // Wait for upload to complete
      final snapshot = await uploadTask;
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // Return upload object
      return ProofOfPaymentUpload(
        fileUrl: downloadUrl,
        filePath: filePath,
        fileType: fileType,
        fileName: fileName_,
        uploadedAt: Timestamp.now(),
        uploadedByUid: uploadedByUid,
        status: 'SUBMITTED',
      );
    } catch (e) {
      debugPrint('Error uploading proof of payment: $e');
      rethrow;
    }
  }

  /// Submit proof of payment - save to Firestore order document
  /// Called after successful file upload
  Future<void> submitProofOfPayment({
    required String listingId,
    required String orderId,
    required ProofOfPaymentUpload upload,
    required String customerUid,
  }) async {
    try {
      final orderRef = _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(orderId);

      // Get current booking doc
      final bookingSnap = await orderRef.get();
      if (!bookingSnap.exists) {
        throw Exception('Order not found');
      }

      final bookingData = bookingSnap.data() as Map<String, dynamic>;

      // Parse existing proofOfPayment or create new
      Map<String, dynamic> popData =
          _asStringKeyedMap(bookingData['proofOfPayment']);
      if (popData.isEmpty) {
        popData = {
        'enabledAtOrderTime': false,
        'uploads': [],
        'overallStatus': 'NONE',
      };
      }

      // Add new upload to uploads array
      List<dynamic> uploads = List<dynamic>.from(popData['uploads'] ?? const []);
      uploads.add(upload.toJson());

      // Update overall status
      popData['uploads'] = uploads;
      popData['overallStatus'] = 'SUBMITTED';
      final updatedAt = DateTime.now().toIso8601String();

      // Write back to Firestore
      await orderRef.update({
        'proofOfPayment': popData,
        'updatedAt': updatedAt,
      });

      final normalizedBookingData = Map<String, dynamic>.from(bookingData);
      normalizedBookingData['customerId'] =
          (normalizedBookingData['customerId'] ?? customerUid).toString();

      await _mirrorProofOfPaymentToUserCollections(
        orderId: orderId,
        bookingData: normalizedBookingData,
        popData: popData,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('Error submitting proof of payment to Firestore: $e');
      rethrow;
    }
  }

  /// Review proof of payment - lister/staff can verify or reject
  Future<void> reviewProofOfPayment({
    required String listingId,
    required String orderId,
    required String decision, // "VERIFIED" or "REJECTED"
    required String editorUid,
    String? reviewNote,
  }) async {
    try {
      final orderRef = _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(orderId);

      // Get current booking
      final bookingSnap = await orderRef.get();
      if (!bookingSnap.exists) {
        throw Exception('Order not found');
      }

      final bookingData = bookingSnap.data() as Map<String, dynamic>;
      Map<String, dynamic> popData =
          _asStringKeyedMap(bookingData['proofOfPayment']);

      // Update the latest upload with review data
      List<dynamic> uploads = List<dynamic>.from(popData['uploads'] ?? const []);
      if (uploads.isNotEmpty) {
        final latestUpload = _asStringKeyedMap(uploads.last);
        latestUpload['status'] = decision;
        latestUpload['reviewerUid'] = editorUid;
        latestUpload['reviewedAt'] = Timestamp.now();
        latestUpload['reviewerNote'] = reviewNote;
        uploads[uploads.length - 1] = latestUpload;
      }

      popData['uploads'] = uploads;
      popData['overallStatus'] = decision;
      final updatedAt = DateTime.now().toIso8601String();

      // Update Firestore
      await orderRef.update({
        'proofOfPayment': popData,
        'updatedAt': updatedAt,
      });

      await _mirrorProofOfPaymentToUserCollections(
        orderId: orderId,
        bookingData: bookingData,
        popData: popData,
        updatedAt: updatedAt,
      );
    } catch (e) {
      debugPrint('Error reviewing proof of payment: $e');
      rethrow;
    }
  }

  /// Delete a proof of payment file from Storage (cleanup)
  Future<void> deleteProofOfPaymentFile({
    required String filePath,
  }) async {
    try {
      await _storage.ref(filePath).delete();
    } catch (e) {
      debugPrint('Error deleting proof of payment file: $e');
      // Don't throw - just log, file deletion failures shouldn't block UX
    }
  }

  /// Get proof of payment data for an order
  Future<ProofOfPayment?> getProofOfPayment({
    required String listingId,
    required String orderId,
  }) async {
    try {
      final orderSnap = await _firestore
          .collection('listings')
          .doc(listingId)
          .collection('bookings')
          .doc(orderId)
          .get();

      if (!orderSnap.exists) return null;

      final data = orderSnap.data() as Map<String, dynamic>;
      final popData = _asStringKeyedMap(data['proofOfPayment']);

      if (popData.isEmpty) {
        return _buildLegacyProofOfPayment(data);
      }

      return ProofOfPayment.fromJson(popData);
    } catch (e) {
      debugPrint('Error fetching proof of payment: $e');
      return null;
    }
  }
}
