import 'package:cloud_firestore/cloud_firestore.dart';
import 'rental_config.dart';
import 'rental_evidence.dart';

enum RentalBookingStatus {
  pending, // Customer requested
  confirmed, // Lister confirmed
  active, // Currently in use
  completed, // Returned and verified
  cancelled, // Cancelled by either party
  disputed, // Damage or issue reported
}

class RentalBooking {
  final String id;
  final String listingId;
  final String rentalUnitId;
  final String customerId;
  final String listerId;
  
  // Booking details
  final DateTime startTime;
  final DateTime endTime;
  final RentalPricingUnit pricingUnit;
  final double unitPrice;
  final int quantity; // Number of units (hours, days, etc.)
  
  // Pricing
  final double subtotal;
  final double depositAmount;
  final double totalAmount;
  
  // Status
  final RentalBookingStatus status;
  
  // Evidence
  final RentalEvidence? checkoutEvidence;
  final RentalEvidence? checkinEvidence;

  // Lifecycle tracking
  final DateTime? collectedAt;
  final String? collectedBy;
  final DateTime? returnedAt;
  final String? returnedBy;
  final bool? returnedInGoodCondition;
  final String? returnIssueNote;
  
  // Vehicle-specific
  final int? startOdometer;
  final int? endOdometer;
  final double? mileageOverageCharge;
  
  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? cancellationReason;
  final String? disputeReason;

  RentalBooking({
    required this.id,
    required this.listingId,
    required this.rentalUnitId,
    required this.customerId,
    required this.listerId,
    required this.startTime,
    required this.endTime,
    required this.pricingUnit,
    required this.unitPrice,
    required this.quantity,
    required this.subtotal,
    required this.depositAmount,
    required this.totalAmount,
    required this.status,
    this.checkoutEvidence,
    this.checkinEvidence,
    this.collectedAt,
    this.collectedBy,
    this.returnedAt,
    this.returnedBy,
    this.returnedInGoodCondition,
    this.returnIssueNote,
    this.startOdometer,
    this.endOdometer,
    this.mileageOverageCharge,
    required this.createdAt,
    required this.updatedAt,
    this.cancellationReason,
    this.disputeReason,
  });

  factory RentalBooking.fromJson(Map<String, dynamic> json, String id) {
    return RentalBooking(
      id: id,
      listingId: json['listingId'] ?? '',
      rentalUnitId: json['rentalUnitId'] ?? '',
      customerId: json['customerId'] ?? '',
      listerId: json['listerId'] ?? '',
      startTime: (json['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (json['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pricingUnit: RentalPricingUnit.values.firstWhere(
        (e) => e.toString() == 'RentalPricingUnit.${json['pricingUnit']}',
        orElse: () => RentalPricingUnit.daily,
      ),
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      quantity: json['quantity'] ?? 1,
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      depositAmount: (json['depositAmount'] ?? 0.0).toDouble(),
      totalAmount: (json['totalAmount'] ?? 0.0).toDouble(),
      status: RentalBookingStatus.values.firstWhere(
        (e) => e.toString() == 'RentalBookingStatus.${json['status']}',
        orElse: () => RentalBookingStatus.pending,
      ),
      checkoutEvidence: json['checkoutEvidence'] != null
          ? RentalEvidence.fromJson(json['checkoutEvidence'] as Map<String, dynamic>)
          : null,
      checkinEvidence: json['checkinEvidence'] != null
          ? RentalEvidence.fromJson(json['checkinEvidence'] as Map<String, dynamic>)
          : null,
        collectedAt: (json['collectedAt'] as Timestamp?)?.toDate(),
        collectedBy: json['collectedBy'],
        returnedAt: (json['returnedAt'] as Timestamp?)?.toDate(),
        returnedBy: json['returnedBy'],
        returnedInGoodCondition: json['returnedInGoodCondition'],
        returnIssueNote: json['returnIssueNote'],
      startOdometer: json['startOdometer'],
      endOdometer: json['endOdometer'],
      mileageOverageCharge: json['mileageOverageCharge']?.toDouble(),
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      cancellationReason: json['cancellationReason'],
      disputeReason: json['disputeReason'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'rentalUnitId': rentalUnitId,
      'customerId': customerId,
      'listerId': listerId,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'pricingUnit': pricingUnit.toString().split('.').last,
      'unitPrice': unitPrice,
      'quantity': quantity,
      'subtotal': subtotal,
      'depositAmount': depositAmount,
      'totalAmount': totalAmount,
      'status': status.toString().split('.').last,
      'checkoutEvidence': checkoutEvidence?.toJson(),
      'checkinEvidence': checkinEvidence?.toJson(),
      'collectedAt': collectedAt != null ? Timestamp.fromDate(collectedAt!) : null,
      'collectedBy': collectedBy,
      'returnedAt': returnedAt != null ? Timestamp.fromDate(returnedAt!) : null,
      'returnedBy': returnedBy,
      'returnedInGoodCondition': returnedInGoodCondition,
      'returnIssueNote': returnIssueNote,
      'startOdometer': startOdometer,
      'endOdometer': endOdometer,
      'mileageOverageCharge': mileageOverageCharge,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'cancellationReason': cancellationReason,
      'disputeReason': disputeReason,
    };
  }

  RentalBooking copyWith({
    String? id,
    String? listingId,
    String? rentalUnitId,
    String? customerId,
    String? listerId,
    DateTime? startTime,
    DateTime? endTime,
    RentalPricingUnit? pricingUnit,
    double? unitPrice,
    int? quantity,
    double? subtotal,
    double? depositAmount,
    double? totalAmount,
    RentalBookingStatus? status,
    RentalEvidence? checkoutEvidence,
    RentalEvidence? checkinEvidence,
    DateTime? collectedAt,
    String? collectedBy,
    DateTime? returnedAt,
    String? returnedBy,
    bool? returnedInGoodCondition,
    String? returnIssueNote,
    int? startOdometer,
    int? endOdometer,
    double? mileageOverageCharge,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? cancellationReason,
    String? disputeReason,
  }) {
    return RentalBooking(
      id: id ?? this.id,
      listingId: listingId ?? this.listingId,
      rentalUnitId: rentalUnitId ?? this.rentalUnitId,
      customerId: customerId ?? this.customerId,
      listerId: listerId ?? this.listerId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pricingUnit: pricingUnit ?? this.pricingUnit,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
      subtotal: subtotal ?? this.subtotal,
      depositAmount: depositAmount ?? this.depositAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      checkoutEvidence: checkoutEvidence ?? this.checkoutEvidence,
      checkinEvidence: checkinEvidence ?? this.checkinEvidence,
        collectedAt: collectedAt ?? this.collectedAt,
        collectedBy: collectedBy ?? this.collectedBy,
        returnedAt: returnedAt ?? this.returnedAt,
        returnedBy: returnedBy ?? this.returnedBy,
        returnedInGoodCondition:
          returnedInGoodCondition ?? this.returnedInGoodCondition,
        returnIssueNote: returnIssueNote ?? this.returnIssueNote,
      startOdometer: startOdometer ?? this.startOdometer,
      endOdometer: endOdometer ?? this.endOdometer,
      mileageOverageCharge: mileageOverageCharge ?? this.mileageOverageCharge,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      disputeReason: disputeReason ?? this.disputeReason,
    );
  }

  // Calculate total kilometers driven (for vehicles)
  int? get totalKilometersDriven {
    if (startOdometer != null && endOdometer != null) {
      return endOdometer! - startOdometer!;
    }
    return null;
  }

  // Check if booking is currently active
  bool get isActive {
    final now = DateTime.now();
    return status == RentalBookingStatus.active &&
        now.isAfter(startTime) &&
        now.isBefore(endTime);
  }

  // Check if booking is overdue for return
  bool get isOverdue {
    return status == RentalBookingStatus.active && DateTime.now().isAfter(endTime);
  }
}
