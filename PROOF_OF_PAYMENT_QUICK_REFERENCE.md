# Proof of Payment Feature - Quick Reference

## 🎯 FEATURE OVERVIEW
Customers can upload proof of payment (image or PDF) for mini-store orders. Only when listing owner enables "Accept proof of payment" setting. Lister can review and mark as verified or rejected.

## 📁 FILES CREATED

| File | Purpose | Lines |
|------|---------|-------|
| `lib/listings/model/proof_of_payment_model.dart` | Data models for POP uploads | 169 |
| `lib/listings/services/proof_of_payment_service.dart` | Service layer for uploads/reviews | 188 |
| `lib/listings/listings_module/proof_of_payment/proof_of_payment_upload_widget.dart` | Flutter UI widget | 420 |
| `functions/src/proof_of_payment_functions.ts` | Cloud Functions callables | 345 |

## 📝 FILES MODIFIED

| File | Changes |
|------|---------|
| `pubspec.yaml` | Added `file_picker: ^8.0.0` |
| `lib/listings/model/booking_model.dart` | Added `proofOfPayment` field + JSON serialization |
| `lib/listings/model/listing_model.dart` | Added `payments` field with `acceptProofOfPayment` toggle |
| `functions/src/index.ts` | Added export for `proof_of_payment_functions` |

## 🔧 IMPLEMENTATION CHECKLIST

- [x] Data models created
- [x] Service layer implemented
- [x] UI widget built
- [x] Cloud Functions written
- [x] Cloud Functions exported in index.ts ✅
- [ ] Firestore security rules updated (see PROOF_OF_PAYMENT_IMPLEMENTATION.md)
- [ ] Firebase Storage rules updated (see PROOF_OF_PAYMENT_IMPLEMENTATION.md)
- [ ] Widget integrated into customer order details
- [ ] Widget integrated into lister order management
- [ ] Settings toggle added to listing management
- [ ] Manual testing completed

## 🚀 HOW TO USE

### For Developers
1. Run `flutter pub get` (file_picker dependency)
2. Review `PROOF_OF_PAYMENT_IMPLEMENTATION.md` for integration steps
3. Deploy Cloud Functions: `firebase deploy --only functions`
4. Update Firestore rules with provided rules
5. Add widget to order details screens

### For Customers
1. Go to order details for eligible order
2. Find "Proof of Payment" section
3. Upload image from camera, gallery, or PDF file
4. Wait for lister verification

### For Listers
1. Enable "Accept Proof of Payment" in store settings
2. View orders with POP uploads
3. Click "Review" to verify or reject
4. Optionally add rejection note

## 📊 DATA STRUCTURE

```dart
// In BookingModel
Map<String, dynamic>? proofOfPayment {
  bool enabledAtOrderTime,        // Frozen at order creation
  List<Map> uploads,              // Array of ProofOfPaymentUpload objects
  String overallStatus            // NONE|SUBMITTED|VERIFIED|REJECTED
}

// In ListingModel
Map<String, dynamic> payments {
  bool acceptProofOfPayment       // Lister toggle
}

// ProofOfPaymentUpload object structure
{
  String fileUrl,                 // Firebase Storage download URL
  String filePath,                // Storage path (for cleanup)
  String fileType,                // IMAGE|PDF
  String fileName,                // Original file name
  String status,                  // SUBMITTED|VERIFIED|REJECTED
  int uploadedAt,                 // Timestamp in ms
  String uploadedByUid,           // Customer's UID
  int? reviewedAt,                // Null if not reviewed yet
  String? reviewerUid,            // Lister's UID
  String? reviewerNote            // Optional rejection reason
}
```

## 🔐 SECURITY
- Only customers can upload to their orders
- Only listing owner/collaborators can review
- Files limited to 10MB
- Storage paths include orderId (prevents cross-order access)
- All writes validated in Cloud Functions

## 📱 UI LOCATIONS

### Customer View
**Screen**: Order Details / My Bookings → Order Item
**Section**: Below order status, above order notes
**Components**:
- File picker buttons: "Take Photo", "Choose Image", "Choose PDF"
- Upload progress indicator
- Status badge: SUBMITTED | VERIFIED | REJECTED
- View & Replace buttons

### Lister View
**Screen**: Order Management / Booking Details
**Section**: Same location as customer
**Components**:
- File display with download link
- Status badge
- "Review" button → opens verification dialog
- Review dialog: Verify/Reject + optional note

### Settings
**Screen**: Listing Management / Store Settings → Payments tab
**Component**: Switch/Toggle "Accept Proof of Payment"

## 📦 DEPENDENCIES
- `file_picker: ^8.0.0` - Cross-platform file selection
- `image_picker: ^1.1.2` - Camera/gallery (already present)
- `url_launcher: ^6.0.0` - Open files (already present)
- `easy_localization: ^3.0.0` - I18n (already present)
- Firebase: Firestore, Storage, Cloud Functions, Messaging (already configured)

## 🧪 QUICK TEST
```bash
# 1. Navigate to your project
cd flutter_universal_listings

# 2. Get dependencies
flutter pub get

# 3. Review generated models
# Check that booking_model.dart includes proofOfPayment
# Check that listing_model.dart includes payments

# 4. Deploy functions (after testing)
cd functions
npm run deploy:functions
# or: firebase deploy --only functions
```

## 📞 KEY FUNCTIONS

### Service: `ProofOfPaymentService`
```dart
uploadProofOfPayment()          // Upload file to Storage, return metadata
submitProofOfPayment()          // Save upload metadata to Firestore
reviewProofOfPayment()          // Mark upload as verified/rejected
getProofOfPayment()             // Fetch POP data for order
deleteProofOfPaymentFile()      // Clean up from Storage
```

### Cloud Functions
```typescript
submitProofOfPayment            // Callable: customer submits POP
  → Validates customer owns order
  → Checks listing POP enabled
  → Sends email to lister
  → Sends push to lister
  → Logs to activity_log

reviewProofOfPayment            // Callable: lister reviews POP
  → Validates reviewer permissions
  → Updates upload status
  → Sends decision email to customer
  → Sends push to customer
  → Logs to activity_log
```

## 🎨 UI WIDGET API
```dart
ProofOfPaymentUploadWidget(
  listingId: 'listing-123',                    // Required
  orderId: 'order-456',                        // Required
  currentUserId: 'user-789',                   // Required
  isLister: false,                             // false=customer, true=lister/staff
  proofOfPayment: popObject,                   // Existing POP data or null
  onUploadComplete: () { ... },                // Refresh after upload
  onReviewComplete: () { ... },                // Refresh after review
)
```

## ⚠️ COMMON ISSUES & SOLUTIONS

| Issue | Solution |
|-------|----------|
| Widget not showing | Check `payments.acceptProofOfPayment == true` on listing |
| Upload fails | Verify Firebase Storage rules allow write access |
| Notification not sent | Check SENDGRID_API_KEY in Cloud Functions env |
| File won't open | Ensure device has PDF viewer (or web browser has PDF support) |
| Review button missing | Check `isLister: true` prop passed to widget |

## 📌 IMPORTANT NOTES
1. **Backward Compatible**: Feature disabled by default for all listings
2. **One Order = One Active POP**: Latest upload is current; replace overwrites (array stores history)
3. **enabledAtOrderTime Snapshot**: Prevents toggle change from affecting existing orders
4. **No Breaking Changes**: All new fields optional in existing documents
5. **Activity Log**: All operations logged for audit trail

## 🔗 RELATED DOCUMENTS
- `PROOF_OF_PAYMENT_IMPLEMENTATION.md` - Full integration guide
- `proof_of_payment_model.dart` - Data model definitions
- `proof_of_payment_service.dart` - Service implementation
- `proof_of_payment_upload_widget.dart` - UI widget code
- `proof_of_payment_functions.ts` - Cloud Functions code

---

**Status**: ✅ Implementation Complete - Ready for Integration & Testing
**Date**: 2025
**Maintained By**: Development Team
