# Table Mode (Dine-In Sessions) - Implementation Guide

## Overview

**Table Mode** allows restaurant owners to manage dine-in customer sessions using QR codes or manual table codes. Customers can scan QR codes to join a table session, summon waiters, and request bills. Staff can manage tables, assign waiters, and monitor active sessions in real-time.

This is a **Premium Feature** gated by RevenueCat ("CaribTap Pro" entitlement).

## Features Implemented

### ✅ Core Functionality

1. **In-App QR Code Generation**
   - QR codes generated directly in Flutter using `qr_flutter` package
   - Deep link format: `caribtap://table?listingId=X&tableId=Y&secret=Z`
   - Share QR codes via `share_plus` (image + text)
   - No external QR generation tools needed

2. **Customer Flow**
   - Scan QR code using `mobile_scanner` (full-screen camera)
   - Manual table code entry (fallback option)
   - Session states: PENDING → ACTIVE → CLOSED
   - Summon waiter with purpose selection (ASSISTANCE/REFILL/QUESTION/OTHER)
   - Request bill with payment method (CASH/CARD/BANK_TRANSFER)
   - Real-time session updates via Firestore streaming

3. **Staff Flow**
   - Table management (create, edit, deactivate)
   - QR code generation and sharing
   - Session dashboard with 3 tabs: Pending/Active/Closed
   - Badge counters for pending/active sessions
   - Assign waiters to sessions (activates PENDING → ACTIVE)
   - Acknowledge customer summons
   - Close table sessions

4. **Anti-Spam & Rate Limiting**
   - **Sessions**: 3 sessions per user per hour
   - **Summons**: Cooldown between summons (default 120 seconds)
   - **Summon Cap**: Maximum 20 summons per session per hour
   - **Bill Requests**: 60-second cooldown
   - All limits enforced server-side in Cloud Functions

5. **Security Model**
   - All critical operations via Cloud Functions (no client writes)
   - Premium verification via RevenueCat API
   - `tableSecret` never exposed as text (only in QR code)
   - Firestore rules deny all client writes
   - Server-side timestamps prevent client timestamp manipulation

### ✅ Technical Implementation

#### Backend (Cloud Functions)

**File**: `functions/src/tableMode.ts` (850 lines)

**9 Callable Functions**:
1. `setTableModeSettings` - Configure Table Mode for listing (Premium-gated, owner only)
2. `upsertTable` - Create or update table (generates secure 8-char code)
3. `deactivateTable` - Toggle table active status
4. `createTableSession` - Customer creates session (QR or manual, rate-limited)
5. `assignWaiterToSession` - Staff assigns waiter (activates PENDING sessions)
6. `summonWaiter` - Customer summons waiter (cooldown-enforced)
7. `acknowledgeSummon` - Staff acknowledges summon
8. `requestBill` - Customer requests bill (60s cooldown)
9. `closeTableSession` - Close active session

**Security Features**:
- All functions check Firebase Auth
- Management functions verify Premium via RevenueCat API
- Rate limiting via Firestore queries (count recent sessions/summons)
- Server timestamps (`admin.firestore.FieldValue.serverTimestamp()`)
- Push notifications for all events

#### Frontend (Flutter/Dart)

**Data Models**: `lib/listings/model/table_mode_models.dart` (450 lines)
- `TableModeSettings` - Listing configuration
- `TableModel` - Table definition with QR payload generation
- `TableSessionModel` - Customer session with cooldown checks
- `SessionEventModel` - Audit log events
- `AssignedStaff` - Waiter assignment
- Enums: `TableSessionStatus`, `SessionEventType`, `SummonPurpose`, `PaymentMethod`, `ActorRole`

**Repository Layer**: `lib/listings/api/table_mode_repository.dart` (150 lines)
- Abstract interface for all Table Mode operations
- Methods for settings, tables, sessions, events
- Repository pattern for testability

**Firebase Implementation**: `lib/listings/api/firebase/table_mode_firebase.dart` (350 lines)
- Wraps all 9 Cloud Functions callables
- Firestore queries for tables, sessions, events
- Streaming support for real-time updates
- Global instance: `tableModeRepository`

**Customer UI**: `lib/listings/ui/table_mode/customer_table_mode_screen.dart` (500 lines)
- QR scanner with camera overlay
- Manual table code entry
- Session status display
- Summon waiter with purpose dialog
- Request bill with payment method dialog
- Cooldown timer UI (updates every second)
- Real-time session streaming

**Staff Table Management**: `lib/listings/ui/table_mode/staff_tables_screen.dart` (400 lines)
- Table list with status indicators
- Add/edit/deactivate tables
- QR code generation screen
- Share QR via native sharing
- Copy table code to clipboard
- Instructions card for restaurant staff

**Staff Session Dashboard**: `lib/listings/ui/table_mode/staff_table_sessions_screen.dart` (350 lines)
- Tabbed view: Pending/Active/Closed
- Real-time session streaming
- Badge counters
- Assign waiter button
- Acknowledge summon button
- Close session button
- Session cards with customer info and elapsed time

#### Security Rules

**File**: `firestore.rules` (added 40 lines)

```plaintext
match /listings/{listingId}/tables/{tableId} {
  allow read: if isSignedIn() && canManageListing(listingId);
  allow write: if false;
}

match /table_sessions/{sessionId} {
  allow read: if isSignedIn() && (
    request.auth.uid == resource.data.customerUid ||
    canManageListing(resource.data.listingId)
  );
  allow write: if false;
  
  match /events/{eventId} {
    allow read: if isSignedIn() && (
      request.auth.uid == get(/databases/$(database)/documents/table_sessions/$(sessionId)).data.customerUid ||
      canManageListing(get(/databases/$(database)/documents/table_sessions/$(sessionId)).data.listingId)
    );
    allow write: if false;
  }
}
```

**Security Principles**:
- Tables: Staff can read (protects `tableSecret` from customers)
- Sessions: Customer can read own session, staff can read for managed listings
- Events: Same access as parent session
- All writes denied (enforced via Cloud Functions)

## Required Firestore Indexes

Add these composite indexes in Firebase Console or `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "table_sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "listingId", "order": "ASCENDING" },
        { "fieldPath": "customerUid", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "table_sessions",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "listingId", "order": "ASCENDING" },
        { "fieldPath": "status", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    },
    {
      "collectionGroup": "events",
      "queryScope": "COLLECTION_GROUP",
      "fields": [
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ]
}
```

**Index Usage**:
1. **First index**: Rate limiting check (count user's recent sessions)
2. **Second index**: Staff session queries (filter by listing + status)
3. **Third index**: Fetch session events ordered by time

## Required Dependencies

Add to `pubspec.yaml` if not already present:

```yaml
dependencies:
  qr_flutter: ^4.1.0       # QR code generation
  mobile_scanner: ^3.5.0   # QR code scanning
  share_plus: ^7.2.1       # Share QR codes
```

Run: `flutter pub get`

## Integration Tasks

### 🔲 1. Push Notification Routing

Handle table session notifications in your push notification handler:

**Notification Payload**:
```json
{
  "type": "table_session",
  "sessionId": "session_123",
  "listingId": "listing_456",
  "scope": "LISTING_TABLE_MODE",
  "title": "Customer needs assistance",
  "body": "Table T-05 customer requested help"
}
```

**Staff Notifications**:
- Pending session created
- Customer summoned waiter
- Customer requested bill

**Customer Notifications**:
- Waiter assigned to session
- Staff acknowledged summon

**Implementation Example**:
```dart
// In your FCM handler
if (payload['type'] == 'table_session') {
  final sessionId = payload['sessionId'];
  final listingId = payload['listingId'];
  
  // Navigate to staff session dashboard
  Navigator.pushNamed(
    context,
    '/listing/$listingId/table-sessions',
    arguments: {'sessionId': sessionId},
  );
}
```

### 🔲 2. Mini Store Order Integration

Tag orders with table session info when customer is in an active session:

**Order Document Fields**:
```dart
{
  'tableSessionId': 'session_123',  // Link to table session
  'tableId': 'table_456',           // For reporting
  'tableName': 'T-05',              // Display on order
  // ... existing order fields
}
```

**Implementation Approach**:
1. Check if user has active table session for listing
2. If yes, include session ID in order creation
3. Display table info on staff order screens
4. Filter orders by table session in reports

**Example Code** (in order creation function):
```dart
// Before creating order, check for active session
final activeSessions = await tableModeRepository.getSessionsForUser(
  listingId: listingId,
  userId: currentUserId,
  status: TableSessionStatus.ACTIVE,
);

final orderData = {
  // ... existing fields
  if (activeSessions.isNotEmpty) ...{
    'tableSessionId': activeSessions.first.id,
    'tableId': activeSessions.first.tableId,
    'tableName': activeSessions.first.tableName,
  },
};
```

### 🔲 3. Table Mode Settings Screen

Create UI for listing owners to enable and configure Table Mode:

**Settings to Expose**:
- `enabled` (bool) - Enable/disable Table Mode
- `summonCooldownSeconds` (int) - Cooldown between summons (default: 120)
- `sessionMaxMinutes` (int, optional) - Auto-close sessions after X minutes

**Implementation**:
```dart
// Staff settings screen
class TableModeSettingsScreen extends StatelessWidget {
  final String listingId;
  
  Future<void> _saveSettings() async {
    await tableModeRepository.setTableModeSettings(
      listingId: listingId,
      enabled: _enabledController.value,
      summonCooldownSeconds: _cooldownController.value.toInt(),
      sessionMaxMinutes: _maxMinutesController.value?.toInt(),
    );
  }
}
```

**Navigation**:
Add button in listing management screen → "Table Mode Settings"

### 🔲 4. Navigation Integration

Add routes for Table Mode screens:

**Customer Route**:
```dart
'/table-mode': (context) => CustomerTableModeScreen(
  listingId: args['listingId'],
),
```

**Staff Routes**:
```dart
'/listing/:id/tables': (context) => StaffTablesScreen(
  listingId: args['listingId'],
),
'/listing/:id/table-sessions': (context) => StaffTableSessionsScreen(
  listingId: args['listingId'],
),
```

**Deep Link Handling**:
```dart
// Handle caribtap://table?listingId=X&tableId=Y&secret=Z
Uri.parse(link).queryParameters;
Navigator.pushNamed(context, '/table-mode', arguments: params);
```

## Testing Checklist

### Pre-Deployment
- [ ] Deploy Cloud Functions: `firebase deploy --only functions:tableModeCallables`
- [ ] Add Firestore composite indexes via Firebase Console
- [ ] Verify RevenueCat integration (Premium entitlement check)
- [ ] Test QR code generation and scanning
- [ ] Test deep link handling

### Customer Flow
- [ ] Scan QR code → Create session (PENDING state)
- [ ] Enter manual table code → Create session
- [ ] Rate limiting: Try creating 4 sessions in 1 hour (should fail on 4th)
- [ ] Session becomes ACTIVE when waiter assigned
- [ ] Summon waiter with different purposes
- [ ] Summon cooldown: Button disabled for 120 seconds
- [ ] Summon cap: Try 21 summons in 1 hour (should fail on 21st)
- [ ] Request bill with payment method
- [ ] Bill cooldown: Try requesting twice within 60s (should fail on 2nd)
- [ ] Real-time updates: Session status changes reflect immediately

### Staff Flow
- [ ] Premium gate: Non-premium users cannot access Table Mode
- [ ] Create table → QR code generated
- [ ] Share QR code via native share
- [ ] Copy table code to clipboard
- [ ] Edit table name and capacity
- [ ] Deactivate table → Cannot create sessions for inactive table
- [ ] View pending sessions → Badge counter updates
- [ ] Assign waiter → Session moves to Active tab
- [ ] Acknowledge summon → Customer gets notification
- [ ] Close session → Moves to Closed tab
- [ ] Real-time updates: New sessions appear instantly

### Security
- [ ] Non-authenticated users cannot call any Cloud Function
- [ ] Non-premium users cannot create/edit tables
- [ ] Non-staff cannot view tables or sessions
- [ ] Customer cannot read another customer's session
- [ ] Client writes to Firestore denied
- [ ] tableSecret never exposed in Firestore queries

### Push Notifications
- [ ] Staff receives notification when customer creates session
- [ ] Staff receives notification when customer summons waiter
- [ ] Staff receives notification when customer requests bill
- [ ] Customer receives notification when waiter assigned
- [ ] Customer receives notification when summon acknowledged

## Data Model

### Table Mode Settings
**Collection**: `listings/{listingId}`
**Fields**:
```dart
{
  'tableModeSettings': {
    'enabled': bool,
    'summonCooldownSeconds': int,
    'sessionMaxMinutes': int?,
    'enabledAt': Timestamp,
  }
}
```

### Tables
**Collection**: `listings/{listingId}/tables/{tableId}`
**Fields**:
```dart
{
  'id': String,
  'name': String,              // e.g., "T-05"
  'capacity': int,             // Max guests
  'isActive': bool,
  'tableCode': String,         // 8-char unique code
  'tableSecret': String,       // Secret for QR validation
  'qrCodeUrl': String?,        // Optional pre-generated QR URL
  'createdAt': Timestamp,
  'createdBy': String,
  'updatedAt': Timestamp,
}
```

### Table Sessions
**Collection**: `table_sessions/{sessionId}`
**Fields**:
```dart
{
  'id': String,
  'listingId': String,
  'tableId': String,
  'tableName': String,
  'customerUid': String,
  'customerName': String,
  'status': String,            // PENDING, ACTIVE, CLOSED
  'createdAt': Timestamp,
  'activatedAt': Timestamp?,
  'closedAt': Timestamp?,
  'assignedStaff': {
    'staffUid': String,
    'staffName': String,
    'role': String,            // e.g., "Waiter"
  }?,
  'lastSummonAt': Timestamp?,
  'billRequestedAt': Timestamp?,
  'billPaymentMethod': String?,  // CASH, CARD, BANK_TRANSFER
}
```

### Session Events
**Collection**: `table_sessions/{sessionId}/events/{eventId}`
**Fields**:
```dart
{
  'id': String,
  'type': String,              // SESSION_CREATED, WAITER_ASSIGNED, etc.
  'actorRole': String,         // CUSTOMER, STAFF
  'actorUid': String,
  'actorName': String,
  'metadata': Map<String, dynamic>,
  'createdAt': Timestamp,
}
```

## Phase 2 Features (OUT OF SCOPE)

The following features were explicitly excluded from this implementation:

- ❌ Bulk PDF QR pack export
- ❌ Rotating/expiring QR tokens
- ❌ Payment processing integration
- ❌ Advanced analytics dashboards
- ❌ Automated session auto-close jobs (Cloud Scheduler)
- ❌ SMS notifications
- ❌ Multiple language support for customer UI
- ❌ Table reservation system
- ❌ Order history in session view

## Constants & Configuration

**Rate Limits** (in `functions/src/tableMode.ts`):
```typescript
const MAX_SESSIONS_PER_USER_PER_HOUR = 3;
const MAX_SUMMONS_PER_SESSION_PER_HOUR = 20;
const SESSION_RATE_LIMIT_WINDOW = 3600000; // 1 hour in ms
const SUMMON_RATE_LIMIT_WINDOW = 3600000;  // 1 hour in ms
```

**Default Cooldowns** (in Cloud Functions):
```typescript
const DEFAULT_SUMMON_COOLDOWN = 120;  // 120 seconds
const BILL_REQUEST_COOLDOWN = 60;     // 60 seconds
```

**To Modify**:
1. Change constants in `functions/src/tableMode.ts`
2. Redeploy Cloud Functions
3. Or make configurable via `TableModeSettings`

## Troubleshooting

### QR Scanning Issues
- **Camera permission denied**: Check `Info.plist` (iOS) and `AndroidManifest.xml` (Android) for camera permissions
- **Deep link not working**: Verify deep link configuration in `AndroidManifest.xml` and `Info.plist`
- **Invalid table code**: Ensure `tableSecret` matches between QR payload and Firestore

### Session Creation Fails
- **Rate limited**: User created 3+ sessions in past hour
- **Invalid table**: Table is inactive or doesn't exist
- **Invalid secret**: QR code `secret` doesn't match Firestore `tableSecret`

### Summon Button Disabled
- **Cooldown active**: Last summon was < 120 seconds ago
- **Summon cap reached**: 20 summons in past hour
- **Session not active**: Session must be ACTIVE to summon

### Premium Gate Issues
- **RevenueCat API error**: Check Cloud Functions logs
- **Entitlement not found**: User must have "CaribTap Pro" subscription
- **Token expired**: User needs to refresh RevenueCat token

### Real-time Updates Not Working
- **Firestore rules**: Verify read permissions for sessions
- **Stream not disposed**: Check `StreamSubscription.cancel()` in dispose
- **No internet**: Firestore offline persistence may delay updates

## Files Modified/Created

### NEW Files
1. `lib/listings/model/table_mode_models.dart` (450 lines)
2. `functions/src/tableMode.ts` (850 lines)
3. `lib/listings/api/table_mode_repository.dart` (150 lines)
4. `lib/listings/api/firebase/table_mode_firebase.dart` (350 lines)
5. `lib/listings/ui/table_mode/customer_table_mode_screen.dart` (500 lines)
6. `lib/listings/ui/table_mode/staff_tables_screen.dart` (400 lines)
7. `lib/listings/ui/table_mode/staff_table_sessions_screen.dart` (350 lines)

### MODIFIED Files
1. `functions/src/index.ts` - Added export for table mode functions
2. `firestore.rules` - Added security rules for tables and sessions

## Deployment Steps

### 1. Install Dependencies
```bash
flutter pub get
cd functions && npm install && cd ..
```

### 2. Deploy Cloud Functions
```bash
firebase deploy --only functions:tableModeCallables
```

### 3. Add Firestore Indexes
Go to Firebase Console → Firestore Database → Indexes → Add indexes from JSON above

### 4. Update Security Rules
```bash
firebase deploy --only firestore:rules
```

### 5. Build and Test App
```bash
flutter clean
flutter pub get
flutter build android --debug  # or ios
```

### 6. Enable Deep Links
Verify `AndroidManifest.xml` and `Info.plist` have `caribtap://` scheme configured

## Support & Maintenance

### Monitoring
- Cloud Functions logs: Firebase Console → Functions → Logs
- Firestore queries: Firebase Console → Firestore → Usage
- RevenueCat API: Check for errors in Cloud Functions logs

### Performance Optimization
- Add pagination to session queries (currently fetches all)
- Cache table list in staff screens
- Optimize real-time listeners (unsubscribe when not visible)

### Future Enhancements
- Add session analytics (average duration, summon frequency)
- Export session history to CSV
- Add table status indicators (occupied/available)
- Implement table reservation system

---

**Implementation Date**: 2024
**Status**: ✅ Core Implementation Complete
**Next Steps**: Push notification routing, Mini Store integration, settings screen
