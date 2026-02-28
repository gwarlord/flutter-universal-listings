import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caribtap/listings/model/pro_doc_shared.dart';

/// Where payment details should be displayed
enum PaymentDisplayMode {
  private('private', 'Only You'),
  invoiceOnly('invoice_only', 'Invoice Only'),
  publicListing('public_listing', 'On Listings');

  final String value;
  final String displayText;

  const PaymentDisplayMode(this.value, this.displayText);

  static PaymentDisplayMode fromString(String? value) {
    switch (value) {
      case 'invoice_only':
        return PaymentDisplayMode.invoiceOnly;
      case 'public_listing':
        return PaymentDisplayMode.publicListing;
      default:
        return PaymentDisplayMode.private;
    }
  }
}

/// Payment app types
enum PaymentAppType {
  paypal('paypal', 'PayPal'),
  cashApp('cashapp', 'Cash App'),
  zelle('zelle', 'Zelle'),
  wise('wise', 'Wise'),
  venmo('venmo', 'Venmo'),
  revolut('revolut', 'Revolut'),
  linx('linx', 'Linx'),
  wipay('wipay', 'WiPay'),
  other('other', 'Other');

  final String value;
  final String displayText;

  const PaymentAppType(this.value, this.displayText);

  static PaymentAppType fromString(String? value) {
    switch (value) {
      case 'paypal':
        return PaymentAppType.paypal;
      case 'cashapp':
        return PaymentAppType.cashApp;
      case 'zelle':
        return PaymentAppType.zelle;
      case 'wise':
        return PaymentAppType.wise;
      case 'venmo':
        return PaymentAppType.venmo;
      case 'revolut':
        return PaymentAppType.revolut;
      case 'linx':
        return PaymentAppType.linx;
      case 'wipay':
        return PaymentAppType.wipay;
      default:
        return PaymentAppType.other;
    }
  }
}

/// Bank transfer details
class BankTransferDetails {
  final bool enabled;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String branch;
  final String swiftBic;
  final String iban;
  final String currency;
  final String instructions;

  const BankTransferDetails({
    this.enabled = false,
    this.bankName = '',
    this.accountName = '',
    this.accountNumber = '',
    this.branch = '',
    this.swiftBic = '',
    this.iban = '',
    this.currency = '',
    this.instructions = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'bankName': bankName,
      'accountName': accountName,
      'accountNumber': accountNumber,
      'branch': branch,
      'swiftBic': swiftBic,
      'iban': iban,
      'currency': currency,
      'instructions': instructions,
    };
  }

  factory BankTransferDetails.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BankTransferDetails();
    return BankTransferDetails(
      enabled: json['enabled'] as bool? ?? false,
      bankName: json['bankName']?.toString() ?? '',
      accountName: json['accountName']?.toString() ?? '',
      accountNumber: json['accountNumber']?.toString() ?? '',
      branch: json['branch']?.toString() ?? '',
      swiftBic: json['swiftBic']?.toString() ?? '',
      iban: json['iban']?.toString() ?? '',
      currency: json['currency']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
    );
  }

  BankTransferDetails copyWith({
    bool? enabled,
    String? bankName,
    String? accountName,
    String? accountNumber,
    String? branch,
    String? swiftBic,
    String? iban,
    String? currency,
    String? instructions,
  }) {
    return BankTransferDetails(
      enabled: enabled ?? this.enabled,
      bankName: bankName ?? this.bankName,
      accountName: accountName ?? this.accountName,
      accountNumber: accountNumber ?? this.accountNumber,
      branch: branch ?? this.branch,
      swiftBic: swiftBic ?? this.swiftBic,
      iban: iban ?? this.iban,
      currency: currency ?? this.currency,
      instructions: instructions ?? this.instructions,
    );
  }

  bool get isValid {
    return enabled && 
           bankName.isNotEmpty && 
           accountName.isNotEmpty && 
           accountNumber.isNotEmpty;
  }
}

/// Payment app details
class PaymentApp {
  final PaymentAppType type;
  final String label;
  final String handle;
  final String url;
  final String region;
  final bool enabled;

  const PaymentApp({
    required this.type,
    this.label = '',
    this.handle = '',
    this.url = '',
    this.region = '',
    this.enabled = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.value,
      'label': label,
      'handle': handle,
      'url': url,
      'region': region,
      'enabled': enabled,
    };
  }

  factory PaymentApp.fromJson(Map<String, dynamic> json) {
    return PaymentApp(
      type: PaymentAppType.fromString(json['type']?.toString()),
      label: json['label']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      url: json['url']?.toString() ?? '',
      region: json['region']?.toString() ?? '',
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  PaymentApp copyWith({
    PaymentAppType? type,
    String? label,
    String? handle,
    String? url,
    String? region,
    bool? enabled,
  }) {
    return PaymentApp(
      type: type ?? this.type,
      label: label ?? this.label,
      handle: handle ?? this.handle,
      url: url ?? this.url,
      region: region ?? this.region,
      enabled: enabled ?? this.enabled,
    );
  }

  bool get isValid {
    return enabled && (handle.isNotEmpty || url.isNotEmpty);
  }
}

/// Complete payment details profile (private)
class PaymentDetailsProfile {
  final bool isEnabled;
  final PaymentDisplayMode displayMode;
  final DateTime? updatedAt;
  final BankTransferDetails bankTransfer;
  final List<PaymentApp> paymentApps;
  final String notes;

  const PaymentDetailsProfile({
    this.isEnabled = false,
    this.displayMode = PaymentDisplayMode.invoiceOnly,
    this.updatedAt,
    this.bankTransfer = const BankTransferDetails(),
    this.paymentApps = const [],
    this.notes = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'isEnabled': isEnabled,
      'displayMode': displayMode.value,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'bankTransfer': bankTransfer.toJson(),
      'paymentApps': paymentApps.map((app) => app.toJson()).toList(),
      'notes': notes,
    };
  }

  factory PaymentDetailsProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaymentDetailsProfile();
    
    return PaymentDetailsProfile(
      isEnabled: json['isEnabled'] as bool? ?? false,
      displayMode: PaymentDisplayMode.fromString(json['displayMode']?.toString()),
      updatedAt: readDateTime(json['updatedAt']),
      bankTransfer: BankTransferDetails.fromJson(json['bankTransfer'] as Map<String, dynamic>?),
      paymentApps: (json['paymentApps'] as List<dynamic>?)
              ?.map((app) => PaymentApp.fromJson(app as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes']?.toString() ?? '',
    );
  }

  PaymentDetailsProfile copyWith({
    bool? isEnabled,
    PaymentDisplayMode? displayMode,
    DateTime? updatedAt,
    BankTransferDetails? bankTransfer,
    List<PaymentApp>? paymentApps,
    String? notes,
  }) {
    return PaymentDetailsProfile(
      isEnabled: isEnabled ?? this.isEnabled,
      displayMode: displayMode ?? this.displayMode,
      updatedAt: updatedAt ?? this.updatedAt,
      bankTransfer: bankTransfer ?? this.bankTransfer,
      paymentApps: paymentApps ?? this.paymentApps,
      notes: notes ?? this.notes,
    );
  }

  bool get hasAnyPaymentMethod {
    return bankTransfer.isValid || paymentApps.any((app) => app.isValid);
  }
}

/// Public snapshot of payment details (safe for display)
class PaymentDetailsPublic {
  final BankTransferDetails? bankTransfer;
  final List<PaymentApp> paymentApps;
  final String notes;
  final DateTime? updatedAt;

  const PaymentDetailsPublic({
    this.bankTransfer,
    this.paymentApps = const [],
    this.notes = '',
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      if (bankTransfer != null) 'bankTransfer': bankTransfer!.toJson(),
      'paymentApps': paymentApps.map((app) => app.toJson()).toList(),
      'notes': notes,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
    };
  }

  factory PaymentDetailsPublic.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PaymentDetailsPublic();
    
    return PaymentDetailsPublic(
      bankTransfer: json['bankTransfer'] != null
          ? BankTransferDetails.fromJson(json['bankTransfer'] as Map<String, dynamic>)
          : null,
      paymentApps: (json['paymentApps'] as List<dynamic>?)
              ?.map((app) => PaymentApp.fromJson(app as Map<String, dynamic>))
              .toList() ??
          [],
      notes: json['notes']?.toString() ?? '',
      updatedAt: readDateTime(json['updatedAt']),
    );
  }

  bool get hasAnyPaymentMethod {
    return (bankTransfer?.isValid ?? false) || paymentApps.any((app) => app.isValid);
  }

  /// Generate public snapshot from private profile
  factory PaymentDetailsPublic.fromProfile(PaymentDetailsProfile profile) {
    // Only include enabled methods
    return PaymentDetailsPublic(
      bankTransfer: profile.bankTransfer.enabled ? profile.bankTransfer : null,
      paymentApps: profile.paymentApps.where((app) => app.enabled).toList(),
      notes: profile.notes,
      updatedAt: DateTime.now(),
    );
  }
}
