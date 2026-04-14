import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../model/rental_unit.dart';
import '../model/rental_booking.dart';
import '../model/rental_evidence.dart';
import '../model/rental_config.dart';

class RentalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Collection references
  CollectionReference get _rentalBookingsRef =>
      _firestore.collection('rental_bookings');

  CollectionReference _rentalUnitsRef(String listingId) =>
      _firestore.collection('listings').doc(listingId).collection('rental_units');

    DocumentReference _rentalCatalogItemRef(String listingId, String rentalUnitId) =>
      _firestore.collection('listings').doc(listingId).collection('rental_catalog').doc(rentalUnitId);

  // ============= RENTAL UNITS =============

  /// Create a new rental unit for a listing
  Future<String> createRentalUnit(RentalUnit unit) async {
    final docRef = await _rentalUnitsRef(unit.listingId).add(unit.toJson());
    return docRef.id;
  }

  /// Update an existing rental unit
  Future<void> updateRentalUnit(RentalUnit unit) async {
    await _rentalUnitsRef(unit.listingId).doc(unit.id).update(unit.toJson());
  }

  /// Delete a rental unit
  Future<void> deleteRentalUnit(String listingId, String unitId) async {
    await _rentalUnitsRef(listingId).doc(unitId).delete();
  }

  /// Get all rental units for a listing
  Stream<List<RentalUnit>> getRentalUnits(String listingId) {
    return _rentalUnitsRef(listingId).snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => RentalUnit.fromJson(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Get a single rental unit
  Future<RentalUnit?> getRentalUnit(String listingId, String unitId) async {
    try {
      final doc = await _rentalUnitsRef(listingId).doc(unitId).get();
      if (!doc.exists) return null;
      return RentalUnit.fromJson(doc.data() as Map<String, dynamic>, doc.id);
    } catch (e) {
      // Silently fail if permission denied or other error
      return null;
    }
  }

  // ============= AVAILABILITY CHECKING =============

  /// Check if a rental unit is available for a given time range
  Future<bool> checkAvailability({
    required String listingId,
    required String rentalUnitId,
    required DateTime startTime,
    required DateTime endTime,
    required int bufferMinutes,
    String? excludeBookingId, // For rescheduling
  }) async {
    // Get the rental unit
    final unit = await getRentalUnit(listingId, rentalUnitId);
    if (unit == null || unit.status != RentalUnitStatus.available) {
      return false;
    }

    // Query for overlapping bookings
    final bookings = await _rentalBookingsRef
        .where('rentalUnitId', isEqualTo: rentalUnitId)
        .where('status', whereIn: [
      RentalBookingStatus.pending.toString().split('.').last,
      RentalBookingStatus.confirmed.toString().split('.').last,
      RentalBookingStatus.active.toString().split('.').last,
    ]).get();

    // Check for overlaps with buffer
    for (final doc in bookings.docs) {
      if (excludeBookingId != null && doc.id == excludeBookingId) {
        continue;
      }

      final booking = RentalBooking.fromJson(
          doc.data() as Map<String, dynamic>, doc.id);
      
      // Apply buffer to existing booking times
      final bufferedStart = booking.startTime.subtract(Duration(minutes: bufferMinutes));
      final bufferedEnd = booking.endTime.add(Duration(minutes: bufferMinutes));

      // Check for overlap
      if (_timesOverlap(startTime, endTime, bufferedStart, bufferedEnd)) {
        return false;
      }
    }

    return true;
  }

  /// Helper to check if two time ranges overlap
  bool _timesOverlap(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }

  /// Get available rental units for a time range
  Future<List<RentalUnit>> getAvailableUnits({
    required String listingId,
    required DateTime startTime,
    required DateTime endTime,
    required int bufferMinutes,
  }) async {
    final allUnits = await _rentalUnitsRef(listingId)
        .where('status', isEqualTo: RentalUnitStatus.available.toString().split('.').last)
        .get();

    final availableUnits = <RentalUnit>[];
    
    for (final doc in allUnits.docs) {
      final unit = RentalUnit.fromJson(doc.data() as Map<String, dynamic>, doc.id);
      final isAvailable = await checkAvailability(
        listingId: listingId,
        rentalUnitId: unit.id,
        startTime: startTime,
        endTime: endTime,
        bufferMinutes: bufferMinutes,
      );
      
      if (isAvailable) {
        availableUnits.add(unit);
      }
    }

    return availableUnits;
  }

  // ============= RENTAL BOOKINGS =============

  /// Create a new rental booking
  Future<String> createRentalBooking(RentalBooking booking) async {
    final listingDoc = await _firestore.collection('listings').doc(booking.listingId).get();
    final listingAcceptsProofOfPayment =
        listingDoc.data()?['payments']?['acceptProofOfPayment'] == true;

    final catalogRef = _rentalCatalogItemRef(booking.listingId, booking.rentalUnitId);
    final catalogDoc = await catalogRef.get();
    if (!catalogDoc.exists) {
      throw Exception('This rental item is no longer available.');
    }

    final catalogData = catalogDoc.data() as Map<String, dynamic>;
    final isCatalogAvailable = catalogData['isAvailable'] != false;
    final stockQty = (catalogData['stockQty'] as num?)?.toInt() ?? 0;
    if (!isCatalogAvailable || stockQty <= 0) {
      throw Exception('This item is currently rented and not available.');
    }

    // Verify availability before creating
    final isAvailable = await checkAvailability(
      listingId: booking.listingId,
      rentalUnitId: booking.rentalUnitId,
      startTime: booking.startTime,
      endTime: booking.endTime,
      bufferMinutes: 30, // Default buffer
    );

    if (!isAvailable) {
      throw Exception('Rental unit is not available for the selected time range');
    }

    final bookingRef = _rentalBookingsRef.doc();
    final bookingData = booking.toJson()
      ..putIfAbsent('inventoryReserved', () => false)
      ..['listingAcceptsProofOfPayment'] =
          booking.listingAcceptsProofOfPayment || listingAcceptsProofOfPayment;

    await _firestore.runTransaction((transaction) async {
      final latestCatalogDoc = await transaction.get(catalogRef);
      if (!latestCatalogDoc.exists) {
        throw Exception('This rental item is no longer available.');
      }

      final latestCatalogData = latestCatalogDoc.data() as Map<String, dynamic>;
      final latestAvailable = latestCatalogData['isAvailable'] != false;
      final latestStockQty = (latestCatalogData['stockQty'] as num?)?.toInt() ?? 0;
      if (!latestAvailable || latestStockQty <= 0) {
        throw Exception('This item was just rented and is no longer available.');
      }

      transaction.set(bookingRef, bookingData);
    });

    return bookingRef.id;
  }

  /// Update booking status
  Future<void> updateBookingStatus({
    required String bookingId,
    required RentalBookingStatus newStatus,
    String? reason, // For cancellations or disputes
    bool? returnedInGoodCondition,
    String? returnIssueNote,
  }) async {
    final bookingDoc = await _rentalBookingsRef.doc(bookingId).get();
    if (!bookingDoc.exists) {
      throw Exception('Booking not found');
    }

    final currentBooking = RentalBooking.fromJson(
      bookingDoc.data() as Map<String, dynamic>,
      bookingDoc.id,
    );
    final bookingData = bookingDoc.data() as Map<String, dynamic>;
    final inventoryReserved = bookingData['inventoryReserved'] == true;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCustomer =
        currentUserId != null && currentUserId == currentBooking.customerId;
    final isLister =
      currentUserId != null && currentUserId == currentBooking.listerId;

    if (newStatus == RentalBookingStatus.cancelled) {
      final alreadyCollected = currentBooking.collectedAt != null;
      final alreadyNonCancellable =
          currentBooking.status == RentalBookingStatus.active ||
              currentBooking.status == RentalBookingStatus.completed ||
              currentBooking.status == RentalBookingStatus.disputed ||
              currentBooking.status == RentalBookingStatus.cancelled;

      if (alreadyCollected || alreadyNonCancellable) {
        throw Exception(
          isCustomer
              ? 'This booking can no longer be cancelled because the item was already collected.'
              : 'Cannot cancel a booking that has already been collected or completed.',
        );
      }
    }

    // Prevent stale updates from reactivating cancelled bookings.
    if (currentBooking.status == RentalBookingStatus.cancelled &&
        (newStatus == RentalBookingStatus.active ||
            newStatus == RentalBookingStatus.completed ||
            newStatus == RentalBookingStatus.disputed)) {
      throw Exception('Cannot change a cancelled booking to an active/completed state.');
    }

    final updateData = <String, dynamic>{
      'status': newStatus.toString().split('.').last,
      'updatedAt': Timestamp.now(),
    };

    final shouldReserveInventory =
      newStatus == RentalBookingStatus.confirmed ||
      newStatus == RentalBookingStatus.active;
    final shouldReleaseInventory =
      newStatus == RentalBookingStatus.cancelled ||
      newStatus == RentalBookingStatus.completed ||
      newStatus == RentalBookingStatus.disputed;

    final reserveInventoryNow = shouldReserveInventory && !inventoryReserved;
    final releaseInventoryNow = shouldReleaseInventory && inventoryReserved;

    // Keep explicit collection/return lifecycle fields in sync with status changes.
    if (newStatus == RentalBookingStatus.active) {
      updateData['collectedAt'] = FieldValue.serverTimestamp();
    }
    if (newStatus == RentalBookingStatus.completed ||
        newStatus == RentalBookingStatus.disputed) {
      updateData['returnedAt'] = FieldValue.serverTimestamp();
      updateData['returnedInGoodCondition'] =
          returnedInGoodCondition ?? (newStatus == RentalBookingStatus.completed);

      if (returnIssueNote != null) {
        final trimmed = returnIssueNote.trim();
        updateData['returnIssueNote'] = trimmed.isEmpty ? null : trimmed;
      } else if (returnedInGoodCondition == true) {
        // Clear any previous issue note when marking return as good.
        updateData['returnIssueNote'] = null;
      }
    }

    if (reason != null) {
      final trimmedReason = reason.trim();
      if (newStatus == RentalBookingStatus.cancelled) {
        updateData['cancellationReason'] = trimmedReason;
      } else if (newStatus == RentalBookingStatus.disputed) {
        updateData['disputeReason'] = trimmedReason;
      }
    }

    if (newStatus == RentalBookingStatus.cancelled) {
      updateData['cancelledFromStatus'] =
          currentBooking.status.toString().split('.').last;
      if (isLister) {
        updateData['cancelledByRole'] = 'lister';
      } else if (isCustomer) {
        updateData['cancelledByRole'] = 'customer';
      } else {
        updateData['cancelledByRole'] = 'system';
      }
      if (currentUserId != null && currentUserId.isNotEmpty) {
        updateData['cancelledByUserId'] = currentUserId;
      }
    }

    final bookingRef = _rentalBookingsRef.doc(bookingId);
    final catalogRef = _rentalCatalogItemRef(
      currentBooking.listingId,
      currentBooking.rentalUnitId,
    );

    await _firestore.runTransaction((transaction) async {
      final txUpdateData = Map<String, dynamic>.from(updateData);

      if (reserveInventoryNow || releaseInventoryNow) {
        final catalogSnap = await transaction.get(catalogRef);

        if (catalogSnap.exists) {
          final catalogData = catalogSnap.data() as Map<String, dynamic>;
          final currentStockQty = (catalogData['stockQty'] as num?)?.toInt() ?? 0;

          if (reserveInventoryNow) {
            if (currentStockQty <= 0) {
              throw Exception('This item is currently rented and not available.');
            }

            final nextStockQty = currentStockQty - 1;
            transaction.update(catalogRef, {
              'stockQty': nextStockQty,
              'isAvailable': nextStockQty > 0,
              'updatedAt': Timestamp.now(),
            });

            txUpdateData['inventoryReserved'] = true;
          }

          if (releaseInventoryNow) {
            final nextStockQty = currentStockQty + 1;
            transaction.update(catalogRef, {
              'stockQty': nextStockQty,
              'isAvailable': true,
              'updatedAt': Timestamp.now(),
            });

            txUpdateData['inventoryReserved'] = false;
          }
        }
      }

      transaction.update(bookingRef, txUpdateData);
    });
  }

  /// Add checkout evidence
  Future<void> addCheckoutEvidence({
    required String bookingId,
    required RentalEvidence evidence,
  }) async {
    await _rentalBookingsRef.doc(bookingId).update({
      'checkoutEvidence': evidence.toJson(),
      'startOdometer': evidence.odometerReading,
      'collectedAt': FieldValue.serverTimestamp(),
      'collectedBy': evidence.capturedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  /// Add checkin evidence and calculate overage charges
  Future<void> addCheckinEvidence({
    required String bookingId,
    required RentalEvidence evidence,
    required RentalConfig rentalConfig,
  }) async {
    final updateData = <String, dynamic>{
      'checkinEvidence': evidence.toJson(),
      'endOdometer': evidence.odometerReading,
      'returnedAt': FieldValue.serverTimestamp(),
      'returnedBy': evidence.capturedBy,
      'returnedInGoodCondition': !evidence.damageReported,
        'returnIssueNote': evidence.damageReported
          ? (evidence.damageDescription?.trim().isNotEmpty == true
            ? evidence.damageDescription!.trim()
            : null)
          : null,
      'updatedAt': Timestamp.now(),
    };

    // Calculate mileage overage for vehicles
    if (rentalConfig.rentalType == RentalType.vehicle &&
        evidence.odometerReading != null) {
      final bookingDoc = await _rentalBookingsRef.doc(bookingId).get();
      final booking = RentalBooking.fromJson(
          bookingDoc.data() as Map<String, dynamic>, bookingDoc.id);

      if (booking.startOdometer != null) {
        final kmDriven = evidence.odometerReading! - booking.startOdometer!;
        final allowedKm = (rentalConfig.dailyMileageLimit ?? 0) * booking.quantity;
        
        if (kmDriven > allowedKm && rentalConfig.overagePricePerKm != null) {
          final overageKm = kmDriven - allowedKm;
          final overageCharge = overageKm * rentalConfig.overagePricePerKm!;
          updateData['mileageOverageCharge'] = overageCharge;
        }
      }
    }

    await _rentalBookingsRef.doc(bookingId).update(updateData);
  }

  /// Get bookings for a customer
  Stream<List<RentalBooking>> getCustomerBookings(String customerId) {
    return _rentalBookingsRef
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RentalBooking.fromJson(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Get bookings for a lister
  Stream<List<RentalBooking>> getListerBookings(String listerId) {
    return _rentalBookingsRef
        .where('listerId', isEqualTo: listerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RentalBooking.fromJson(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Get bookings for a specific listing
  Stream<List<RentalBooking>> getListingBookings(String listingId) {
    return _rentalBookingsRef
        .where('listingId', isEqualTo: listingId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RentalBooking.fromJson(
              doc.data() as Map<String, dynamic>, doc.id))
          .toList();
    });
  }

  /// Get a single booking
  Future<RentalBooking?> getBooking(String bookingId) async {
    final doc = await _rentalBookingsRef.doc(bookingId).get();
    if (!doc.exists) return null;
    return RentalBooking.fromJson(doc.data() as Map<String, dynamic>, doc.id);
  }

  // ============= STORAGE =============

  /// Upload rental evidence media (photos/videos)
  Future<String> uploadEvidenceMedia({
    required String bookingId,
    required String filePath,
    required EvidenceType evidenceType,
    required bool isVideo,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = isVideo ? 'mp4' : 'jpg';
    final type = evidenceType == EvidenceType.checkout ? 'checkout' : 'checkin';
    
    final ref = _storage.ref().child(
        'rental_evidence/$bookingId/$type/${timestamp}.$extension');
    
    final uploadTask = await ref.putFile(
      // Note: In production, you'd pass File object, not String path
      // This is a placeholder for the actual implementation
      throw UnimplementedError('File upload requires platform-specific implementation'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  /// Upload rental unit photos
  Future<String> uploadUnitPhoto({
    required String listingId,
    required String unitId,
    required String filePath,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child(
        'rental_units/$listingId/$unitId/$timestamp.jpg');
    
    final uploadTask = await ref.putFile(
      // Note: In production, you'd pass File object, not String path
      throw UnimplementedError('File upload requires platform-specific implementation'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  /// Upload license photos
  Future<String> uploadLicensePhoto({
    required String bookingId,
    required String filePath,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ref = _storage.ref().child(
        'rental_licenses/$bookingId/$timestamp.jpg');
    
    final uploadTask = await ref.putFile(
      // Note: In production, you'd pass File object, not String path
      throw UnimplementedError('File upload requires platform-specific implementation'),
    );

    return await uploadTask.ref.getDownloadURL();
  }

  // ============= PRICING CALCULATIONS =============

  /// Calculate rental price based on time range and pricing unit
  double calculateRentalPrice({
    required DateTime startTime,
    required DateTime endTime,
    required RentalPricingUnit pricingUnit,
    required double unitPrice,
  }) {
    final duration = endTime.difference(startTime);
    int quantity;

    switch (pricingUnit) {
      case RentalPricingUnit.hourly:
        quantity = (duration.inMinutes / 60).ceil();
        break;
      case RentalPricingUnit.daily:
        quantity = (duration.inHours / 24).ceil();
        break;
      case RentalPricingUnit.weekly:
        quantity = (duration.inDays / 7).ceil();
        break;
      case RentalPricingUnit.monthly:
        quantity = (duration.inDays / 30).ceil();
        break;
    }

    return quantity * unitPrice;
  }

  /// Calculate quantity (number of units) for a time range
  int calculateQuantity({
    required DateTime startTime,
    required DateTime endTime,
    required RentalPricingUnit pricingUnit,
  }) {
    final duration = endTime.difference(startTime);

    switch (pricingUnit) {
      case RentalPricingUnit.hourly:
        return (duration.inMinutes / 60).ceil();
      case RentalPricingUnit.daily:
        return (duration.inHours / 24).ceil();
      case RentalPricingUnit.weekly:
        return (duration.inDays / 7).ceil();
      case RentalPricingUnit.monthly:
        return (duration.inDays / 30).ceil();
    }
  }
}
