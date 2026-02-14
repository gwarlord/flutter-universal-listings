# Proof of Payment Feature - Integration Checklist

## ✅ COMPLETED COMPONENTS

### Data Layer
- [x] ProofOfPaymentModel created with serialization
- [x] BookingModel extended with proofOfPayment field
- [x] ListingModel extended with payments setting
- [x] pubspec.yaml updated with file_picker dependency

### Service Layer  
- [x] ProofOfPaymentService implemented with:
  - [x] uploadProofOfPayment() method
  - [x] submitProofOfPayment() method
  - [x] reviewProofOfPayment() method
  - [x] getProofOfPayment() method
  - [x] deleteProofOfPaymentFile() method
  - [x] File validation (size, type)
  - [x] Error handling with user messages

### UI Layer
- [x] ProofOfPaymentUploadWidget created with:
  - [x] Customer view (upload UI)
  - [x] Lister view (review UI)
  - [x] File pickers (camera, gallery, PDF)
  - [x] Status display
  - [x] Progress indicators
  - [x] Review dialog

### Cloud Functions
- [x] submitProofOfPayment callable function
- [x] reviewProofOfPayment callable function
- [x] Email notification integration
- [x] Push notification integration
- [x] Activity log integration
- [x] Cloud Functions exported in index.ts

---

## 🔄 INTEGRATION TASKS (IN PROGRESS)

### Priority 1: Security Rules (CRITICAL)
- [ ] **Task**: Update Firestore Rules
  - Location: `firestore.rules`
  - Add POP-specific read/write permissions
  - Rule should allow:
    - Customers to read their own orders
    - Listers to read orders in their listings
    - Collaborators with manageOrders to read/update
  - See PROOF_OF_PAYMENT_IMPLEMENTATION.md for exact rules

- [ ] **Task**: Update Storage Rules
  - Location: `storage.rules`
  - Add POP upload path permissions
  - Rule path: `proof_of_payment/{orderId}/{allPaths...}`
  - Allow upload only by order customer
  - Allow read by customer, lister, collaborators
  - See PROOF_OF_PAYMENT_IMPLEMENTATION.md for exact rules

### Priority 2: UI Integration (HIGH)
- [ ] **Task**: Add Widget to Customer Order Details
  - File: `lib/listings/listings_module/my_bookings/my_bookings_screen.dart` (or your custom location)
  - Location: After order status, before notes/comments
  - Import widget: `proof_of_payment_upload_widget.dart`
  - Code snippet:
    ```dart
    ProofOfPaymentUploadWidget(
      listingId: booking.listingId,
      orderId: booking.id,
      currentUserId: currentUser.userID,
      isLister: false,
      proofOfPayment: _parseProofOfPayment(booking.proofOfPayment),
      onUploadComplete: () => _refreshBookingDetails(),
    )
    ```
  - Test: Verify widget shows only if `payments.acceptProofOfPayment == true`

- [ ] **Task**: Add Widget to Lister Order Management
  - File: `lib/listings/listings_module/booking_management/booking_management_screen.dart` (or your custom location)
  - Location: Same position as customer view for consistency
  - Code snippet (same as above but `isLister: true`)
  - Test: Verify lister sees review button

### Priority 3: Settings UI (MEDIUM)
- [ ] **Task**: Add Payment Settings Toggle
  - File: Listing edit/manage screen (likely `add_listing_screen.dart` or `edit_listing_screen.dart`)
  - Location: Under "Store Settings" or "Payments" section
  - Create new section:
    ```dart
    SectionTitle('Payments'),
    ListTile(
      title: Text('Accept Proof of Payment'.tr()),
      subtitle: Text('Require customers to provide proof'.tr()),
      trailing: Switch(
        value: listing.payments['acceptProofOfPayment'] ?? false,
        onChanged: (value) async {
          listing.payments['acceptProofOfPayment'] = value;
          await _saveListing();
        },
      ),
    )
    ```
  - Ensure toggle persists to Firestore on save
  - Test: Toggle on, create order, verify POP section appears

---

## 🧪 TESTING CHECKLIST

### Unit Tests Needed
- [ ] ProofOfPaymentModel.fromJson() / .toJson()
- [ ] File size validation in ProofOfPaymentService
- [ ] File type validation for JPG, PNG, PDF
- [ ] ProofOfPaymentUploadWidget state management

### Integration Tests
- [ ] Upload flow: Customer → Service → Storage → Firestore
- [ ] Submit flow: Update Firestore → Trigger notifications
- [ ] Review flow: Cloud Function validation → Status update
- [ ] Permissions: Non-owner cannot review

### Functional Tests (Manual)
See PROOF_OF_PAYMENT_IMPLEMENTATION.md section "MANUAL TESTING STEPS"
- [ ] Test 1: Enable Feature on Listing
- [ ] Test 2: Customer Upload (Mobile)
- [ ] Test 3: Customer Upload (Web)
- [ ] Test 4: Lister Review (Verify)
- [ ] Test 5: Lister Review (Reject)
- [ ] Test 6: Customer Sees Decision
- [ ] Test 7: File Viewing
- [ ] Test 8: Edge Cases (File validation)
- [ ] Test 9: Notifications (Email & Push)
- [ ] Test 10: Activity Log

### Security Tests
- [ ] Customer cannot access other customers' POPs
- [ ] Non-lister cannot see/review POPs
- [ ] File size enforcement (>10MB rejected)
- [ ] Malicious file types rejected
- [ ] Storage rules prevent unauthorized access

---

## 📋 DEPLOYMENT STEPS

### Step 1: Code Preparation
- [ ] Review all Dart files for syntax errors: `flutter analyze`
- [ ] Review all TypeScript files for syntax errors: `npm run lint` (in functions/)
- [ ] Verify imports are correct in all files
- [ ] Check that models serialize/deserialize properly

### Step 2: Dependency Management
- [ ] Run `flutter pub get` to download file_picker
- [ ] Verify file_picker is working: `flutter test`
- [ ] In functions/, verify npm dependencies: `npm install` (already done)

### Step 3: Firebase Configuration
- [ ] Update Firestore Security Rules (see Priority 1 above)
- [ ] Update Firebase Storage Rules (see Priority 1 above)
- [ ] Verify Cloud Functions are deployed: `firebase deploy --only functions`
- [ ] Check function logs for deployment errors: `firebase functions:log`

### Step 4: UI Integration
- [ ] Complete all Priority 2 integration tasks
- [ ] Complete Priority 3 settings UI
- [ ] Run `flutter build` to verify no compilation errors
- [ ] Test on both Android and iOS (if mobile)

### Step 5: Testing
- [ ] Execute all manual testing steps (see above)
- [ ] Test on different device types (phone, tablet, web)
- [ ] Test with different network conditions (offline, slow)
- [ ] Have QA team review before production

### Step 6: Deployment
- [ ] Merge all code to main/production branch
- [ ] Tag release: `git tag v1.0-proof-of-payment`
- [ ] Deploy: `flutter build apk` / `flutter build ios` / `firebase deploy`
- [ ] Monitor Cloud Functions logs for errors
- [ ] Monitor Firestore quota usage

### Step 7: Post-Deployment
- [ ] Communicate feature to users
- [ ] Monitor error rates in Firebase
- [ ] Gather user feedback
- [ ] Document any issues in GitHub Issues
- [ ] Plan improvements for next version

---

## 📊 SUCCESS CRITERIA

- [x] Code is written and compiles without errors
- [x] Cloud Functions are deployed
- [ ] Firestore/Storage rules are updated
- [ ] Widget appears in customer order details
- [ ] Widget appears in lister order management
- [ ] Settings toggle works in listing management
- [ ] Customer can upload image/PDF
- [ ] Lister can review and verify/reject
- [ ] Notifications are sent correctly
- [ ] No security vulnerabilities
- [ ] All manual tests pass
- [ ] Feature is documented
- [ ] QA team approves

---

## 🚨 ROLLBACK PLAN

If issues occur after deployment:

### Quick Rollback
1. Remove Cloud Functions export from `functions/src/index.ts`
2. Redeploy: `firebase deploy --only functions`
3. Hide UI widget by removing from screens (or wrap in feature flag)
4. Revert Firestore/Storage rules to previous version

### Code Changes Cleanup
```bash
git revert <commit_hash>  # Revert specific changes
git push origin main      # Push revert to production
```

### User Communication
- Notify users of temporary outage
- Explain what went wrong
- Provide ETA for fix
- Follow up with resolution

---

## 💡 FEATURE FLAGS (Optional)

Consider adding feature flag to enable/disable POP feature globally:

```dart
// In your config service
bool isProofOfPaymentEnabled() {
  return remoteConfig.getBool('enable_proof_of_payment') ?? true;
}

// In widget visibility
if (isProofOfPaymentEnabled() && listing.payments['acceptProofOfPayment']) {
  ProofOfPaymentUploadWidget(...)
}
```

This allows safe rollback without code changes.

---

## 📞 SUPPORT CONTACTS

- **Cloud Functions Issues**: Check Firebase Console → Functions → Logs
- **Storage Issues**: Check Firebase Console → Storage
- **Firestore Issues**: Check Firebase Console → Firestore → Backups/Activity
- **Flutter Issues**: Run `flutter doctor` and check dependency versions
- **File Picker Issues**: Check [file_picker package docs](https://pub.dev/packages/file_picker)

---

## 📝 SIGN-OFF

- [ ] **Developer**: Code review completed
- [ ] **QA Lead**: Testing completed
- [ ] **Product Manager**: Feature approved for release
- [ ] **DevOps**: Deployment completed successfully

---

**Created**: 2025
**Last Updated**: Now
**Status**: Ready for Integration
