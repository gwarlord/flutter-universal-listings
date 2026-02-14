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
  
  // Reminder tracking fields
  DateTime? reminder24hSentAt;
  DateTime? reminder1hSentAt;
  String? timezone; // IANA timezone string (e.g., "America/Port_of_Spain")
  
  // Proof of Payment fields
  Map<String, dynamic>? proofOfPayment;
  bool listingAcceptsProofOfPayment = false; // ✅ Snapshot of listing's POP setting

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
    this.reminder24hSentAt,
    this.reminder1hSentAt,
    this.timezone,
    this.proofOfPayment,
    this.listingAcceptsProofOfPayment = false,
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
      reminder24hSentAt: json['reminder24hSentAt'] != null
          ? DateTime.parse(json['reminder24hSentAt'] as String)
          : null,
      reminder1hSentAt: json['reminder1hSentAt'] != null
          ? DateTime.parse(json['reminder1hSentAt'] as String)
          : null,
      timezone: json['timezone'] as String?,
      proofOfPayment: json['proofOfPayment'] as Map<String, dynamic>?,
      listingAcceptsProofOfPayment: json['listingAcceptsProofOfPayment'] ?? false,
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
      'reminder24hSentAt': reminder24hSentAt?.toIso8601String(),
      'reminder1hSentAt': reminder1hSentAt?.toIso8601String(),
      'timezone': timezone,
      'proofOfPayment': proofOfPayment,
      'listingAcceptsProofOfPayment': listingAcceptsProofOfPayment,
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
