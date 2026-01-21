class BookingModel {
  String id;
  String listingId;
  String listingTitle;
  String listingPhoto;
  String listersUserId;
  String listersName;
  String listersEmail;
  String customerId;
  String customerName;
  String customerEmail;
  String customerPhone;
  DateTime checkInDate;
  DateTime checkOutDate;
  int numberOfGuests;
  String guestNotes;
  String timeBlock; // ✅ e.g., "09:00-10:00" if time blocks enabled
  num totalPrice;
  String currency;
  String status; // pending, confirmed, rejected, cancelled
  DateTime createdAt;
  DateTime updatedAt;
  Map<String, String> customAnswers; // ✅ question -> answer

  BookingModel({
    this.id = '',
    this.listingId = '',
    this.listingTitle = '',
    this.listingPhoto = '',
    this.listersUserId = '',
    this.listersName = '',
    this.listersEmail = '',
    this.customerId = '',
    this.customerName = '',
    this.customerEmail = '',
    this.customerPhone = '',
    required this.checkInDate,
    required this.checkOutDate,
    this.numberOfGuests = 1,
    this.guestNotes = '',
    this.timeBlock = '',
    this.totalPrice = 0,
    this.currency = 'USD',
    this.status = 'pending',
    Map<String, String>? customAnswers,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
      updatedAt = updatedAt ?? DateTime.now(),
      customAnswers = customAnswers ?? {};

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] ?? '',
      listingId: json['listingId'] ?? '',
      listingTitle: json['listingTitle'] ?? '',
      listingPhoto: json['listingPhoto'] ?? '',
      listersUserId: json['listersUserId'] ?? '',
      listersName: json['listersName'] ?? '',
      listersEmail: json['listersEmail'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      customerEmail: json['customerEmail'] ?? '',
      customerPhone: json['customerPhone'] ?? '',
      checkInDate: json['checkInDate'] != null
          ? DateTime.parse(json['checkInDate'] as String)
          : DateTime.now(),
      checkOutDate: json['checkOutDate'] != null
          ? DateTime.parse(json['checkOutDate'] as String)
          : DateTime.now(),
      numberOfGuests: json['numberOfGuests'] ?? 1,
      guestNotes: json['guestNotes'] ?? '',
      timeBlock: json['timeBlock'] ?? '',
      totalPrice: json['totalPrice'] ?? 0,
      currency: json['currency'] ?? 'USD',
      status: json['status'] ?? 'pending',
        customAnswers: Map<String, String>.from(json['customAnswers'] ?? {}),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'listingId': listingId,
      'listingTitle': listingTitle,
      'listingPhoto': listingPhoto,
      'listersUserId': listersUserId,
      'listersName': listersName,
      'listersEmail': listersEmail,
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'checkInDate': checkInDate.toIso8601String(),
      'checkOutDate': checkOutDate.toIso8601String(),
      'numberOfGuests': numberOfGuests,
      'guestNotes': guestNotes,
      'timeBlock': timeBlock,
      'totalPrice': totalPrice,
      'currency': currency,
      'status': status,
      'customAnswers': customAnswers,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  int get numberOfNights {
    return checkOutDate.difference(checkInDate).inDays;
  }

  bool get isPending => status == 'pending';
  bool get isConfirmed => status == 'confirmed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}
