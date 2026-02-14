import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instaflutter/listings/model/proof_of_payment_model.dart';
import 'package:flutter/foundation.dart';

class ProofOfPaymentService {
  final _storage = FirebaseStorage.instance;
  final _firestore = FirebaseFirestore.instance;

  static const String _popStoragePath = 'proof_of_payment';
  static const int _maxFileSizeBytes = 10 * 1024 * 1024; // 10MB
  static const List<String> _allowedImageExtensions = ['jpg', 'jpeg', 'png'];
  static const List<String> _allowedDocExtensions = ['pdf'];

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
      Map<String, dynamic> popData = bookingData['proofOfPayment'] ?? {
        'enabledAtOrderTime': false,
        'uploads': [],
        'overallStatus': 'NONE',
      };

      // Add new upload to uploads array
      List<dynamic> uploads = popData['uploads'] ?? [];
      uploads.add(upload.toJson());

      // Update overall status
      popData['uploads'] = uploads;
      popData['overallStatus'] = 'SUBMITTED';

      // Write back to Firestore
      await orderRef.update({
        'proofOfPayment': popData,
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Also update user's booking copy for quick access
      await _firestore
          .collection('users')
          .doc(customerUid)
          .collection('myBookings')
          .doc(orderId)
          .update({
        'proofOfPayment': popData,
        'updatedAt': DateTime.now().toIso8601String(),
      });
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
      Map<String, dynamic> popData = bookingData['proofOfPayment'] ?? {};

      // Update the latest upload with review data
      List<dynamic> uploads = popData['uploads'] ?? [];
      if (uploads.isNotEmpty) {
        final latestUpload = uploads.last as Map<String, dynamic>;
        latestUpload['status'] = decision;
        latestUpload['reviewerUid'] = editorUid;
        latestUpload['reviewedAt'] = Timestamp.now();
        latestUpload['reviewerNote'] = reviewNote;
      }

      popData['uploads'] = uploads;
      popData['overallStatus'] = decision;

      // Update Firestore
      await orderRef.update({
        'proofOfPayment': popData,
        'updatedAt': DateTime.now().toIso8601String(),
      });
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
      final popData = data['proofOfPayment'] as Map<String, dynamic>?;

      if (popData == null) return null;

      return ProofOfPayment.fromJson(popData);
    } catch (e) {
      debugPrint('Error fetching proof of payment: $e');
      return null;
    }
  }
}
