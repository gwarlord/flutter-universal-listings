# Payment Details - Quick Reference

## 🎯 Purpose
Allow Pro tier listers to store and display payment information (bank transfer + payment apps).

## 🔐 Security Level
- **Private by default**
- User controls visibility
- No credit card storage

## 📊 Subscription Requirement
- **Professional tier (tier 2)** or above
- Free/Basic users see upsell

## 🗂️ Firestore Paths
```
users/{uid}/payment_details/profile  → Private (owner only)
users/{uid}/payment_details/public   → Public snapshot (authenticated read)
```

## 🎚️ Display Modes
1. **Private**: Store only, don't show publicly
2. **Invoice Only**: Show on quotes/invoices
3. **Public Listing**: Show on listings + invoices

## 💳 Payment Methods
### Bank Transfer
- Bank name, account name, account number (required if enabled)
- Branch, SWIFT/BIC, IBAN, currency, instructions (optional)

### Payment Apps
PayPal • Cash App • Zelle • Wise • Venmo • Revolut • Linx • WiPay • Other

## 📱 UI Access
Settings → **Business Settings** → **Payment Details**

## 🔌 Integration

### Display payment methods on any screen:
```dart
import 'package:caribtap/listings/ui/widgets/payment_methods_stream_widget.dart';

PaymentMethodsStreamWidget(userId: listerUid)
```

### Get data programmatically:
```dart
// Public snapshot
final paymentDetails = await PaymentDetailsService().getPublic(userId);

// Private profile (owner only)
final profile = await PaymentDetailsService().getProfile(userId);
```

## ✅ Validation
- Bank transfer enabled → requires bank name, account name, account number
- Payment app enabled → requires handle OR url
- Auto-validates on save

## 🎨 Features
- ✅ Copy-to-clipboard for account numbers
- ✅ Copy-to-clipboard for payment handles  
- ✅ Open payment app links
- ✅ Expandable optional fields
- ✅ Add/remove payment apps
- ✅ Enable/disable per method

## 🧪 Quick Test
1. Create Professional subscription user
2. Navigate to Settings → Payment Details
3. Enable + add bank details
4. Set display mode to "Public Listing"
5. Save
6. View on listing detail page
7. Verify payment methods widget appears
8. Test copy buttons

## 🚨 Common Issues
| Issue | Solution |
|-------|----------|
| "Requires Professional tier" | Upgrade subscription |
| Widget not showing on listing | Check displayMode = "public_listing" |
| Cannot save | Fill required fields for enabled methods |
| Public doc not updating | Check Firestore security rules |

## 📦 Files
```
Models:      lib/listings/model/payment_details_model.dart
Service:     lib/listings/services/payment_details_service.dart
Cubit:       lib/listings/ui/profile/payment_details/payment_details_cubit.dart
Screen UI:   lib/listings/ui/profile/payment_details/payment_details_screen.dart
Display:     lib/listings/ui/widgets/payment_methods_widget.dart
Rules:       firestore.rules (users/{uid}/payment_details/*)
```

## 🎯 Remember
- **ADDITIVE ONLY** - No changes to existing schemas
- **PRIVATE BY DEFAULT** - User must opt-in to display
- **NO CARD NUMBERS** - Only bank transfer info
- **USER CONTROLLED** - Lister decides what's visible
