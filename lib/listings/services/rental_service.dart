import 'package:cloud_firestore/cloud_firestore.dart';
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

    final docRef = await _rentalBookingsRef.add(booking.toJson());
    return docRef.id;
  }

  /// Update booking status
  Future<void> updateBookingStatus({
    required String bookingId,
    required RentalBookingStatus newStatus,
    String? reason, // For cancellations or disputes
  }) async {
    final updateData = {
      'status': newStatus.toString().split('.').last,
      'updatedAt': Timestamp.now(),
    };

    if (reason != null) {
      if (newStatus == RentalBookingStatus.cancelled) {
        updateData['cancellationReason'] = reason;
      } else if (newStatus == RentalBookingStatus.disputed) {
        updateData['disputeReason'] = reason;
      }
    }

    await _rentalBookingsRef.doc(bookingId).update(updateData);
  }

  /// Add checkout evidence
  Future<void> addCheckoutEvidence({
    required String bookingId,
    required RentalEvidence evidence,
  }) async {
    await _rentalBookingsRef.doc(bookingId).update({
      'checkoutEvidence': evidence.toJson(),
      'startOdometer': evidence.odometerReading,
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
