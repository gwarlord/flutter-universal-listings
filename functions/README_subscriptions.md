# Subscriptions Setup (Native Billing + Firebase)

## Overview
This repo uses native store billing with Firebase entitlement verification.
- Client: Flutter `in_app_purchase`
- Server: Firebase Functions (Node 20 + TypeScript)
- Source of truth: Firestore `users/{uid}/entitlements/subscription`

---

## Required Secrets (Firebase Secret Manager)

Set these secrets:

```bash
firebase functions:secrets:set APPLE_SHARED_SECRET
firebase functions:secrets:set GOOGLE_SERVICE_ACCOUNT_JSON
firebase functions:secrets:set ENTITLEMENT_TOKEN_KEY
```

Notes:
- `APPLE_SHARED_SECRET`: App Store Connect shared secret for auto-renewable subscriptions.
- `GOOGLE_SERVICE_ACCOUNT_JSON`: JSON service account with Android Publisher access.
- `ENTITLEMENT_TOKEN_KEY`: Base64-encoded 32-byte key (AES-256-GCM) for encrypting purchase tokens/receipts.

Generate a token key:
```bash
# Example (Linux/macOS)
openssl rand -base64 32
```

---

## Google Play API Access

1. Go to Google Play Console → Settings → API Access.
2. Create a service account or link an existing one.
3. Assign role: **View financial data, manage orders and subscriptions**.
4. Download JSON key.
5. Store in Secret Manager as `GOOGLE_SERVICE_ACCOUNT_JSON`.

Required IAM roles:
- `roles/androidpublisher` (Android Publisher API)

---

## Apple App Store Setup

1. App Store Connect → Apps → In-App Purchases.
2. Create subscription products matching product IDs.
3. Go to App Store Connect → Users and Access → Keys (if using server API).
4. Create shared secret for auto-renewable subscriptions.
5. Store shared secret in `APPLE_SHARED_SECRET`.

---

## Firebase IAM Permissions

Ensure the Functions runtime service account has:
- `roles/datastore.user` or `roles/datastore.owner` (Firestore access)
- `roles/secretmanager.secretAccessor` (to read secrets)
- `roles/androidpublisher` (Play Store verification)

---

## Cloud Functions

### verifyPurchase (callable)
Input:
```json
{
  "platform": "android"|"ios",
  "productId": "string",
  "purchaseToken": "string" (android only),
  "packageName": "string" (android only),
  "receiptData": "string" (ios only)
}
```

Writes:
- `users/{uid}/entitlements/subscription`
- `users/{uid}/entitlements/subscription/purchases/{purchaseId}`

### refreshEntitlementsDaily (scheduled)
- Runs daily via Cloud Scheduler.
- Revalidates expiring entitlements using encrypted tokens/receipts.

---

## Product Mapping

Product IDs must match the mapping in both client and server:

- `caribtap_pro_t1_monthly` → tier 1
- `caribtap_pro_t1_annual` → tier 1
- `caribtap_pro_t2_monthly` → tier 2
- `caribtap_pro_t2_annual` → tier 2
- `caribtap_pro_t3_monthly` → tier 3
- `caribtap_pro_t3_annual` → tier 3

---

## Testing Steps

1. Enable Firebase emulator:
```bash
firebase emulators:start --only functions
```

2. Run the app on emulator/device.
3. Purchase a product (test account).
4. Confirm Firestore writes to `users/{uid}/entitlements/subscription`.
5. Verify audit log under `users/{uid}/entitlements/purchases`.

---

## Notes

- No store credentials are sent to the client.
- Tokens/receipts are encrypted before storage.
- Audit logs never store raw secrets.
