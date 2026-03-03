# Google Location Fix Notes

## What fixed it
- Unified all Places key usage through shared key selection in `lib/constants.dart`.
- Made listings Places details use the same selected key in `lib/listings/main.dart`.
- Added direct Places autocomplete probe logs in:
  - `lib/listings/listings_module/add_listing/add_listing_screen.dart`
  - `lib/listings/listings_module/events/create_event_screen.dart`
- Added Firestore `events` rules so event feed queries are allowed in `firestore.rules`.

## Key configuration that works
- Android package name: `com.caribtap.instaflutter.android`
- Android SHA-1 used in runtime header logs: `2EDC5D5E857233914F8335C5D4EE9E09FC8F61F9`
- Active key source should log as one of:
  - `GOOGLE_PLACES_API_KEY` (preferred)
  - `GOOGLE_ANDROID_API_KEY`

## Fast recovery checklist (if it breaks again)
1. Confirm runtime key source in logs:
   - `[Places] Add Listing using ...`
   - `[Places] Create Event using ...`
2. Check probe output:
   - `[PlacesProbe:AddListing] ... status=... error=...`
   - `[PlacesProbe:CreateEvent] ... status=... error=...`
3. In Google Cloud Console (Credentials):
   - Key application restriction = **Android apps**
   - Add package `com.caribtap.instaflutter.android`
   - Add SHA-1 `2EDC5D5E857233914F8335C5D4EE9E09FC8F61F9`
4. Ensure APIs enabled + billing active:
   - Places API
   - Place Details API path used by app (`maps.googleapis.com/maps/api/place/details/json`)
5. Restart app fully after key updates (not just hot reload).
6. If Firestore event feed fails with permission-denied, redeploy rules:
   - `npx firebase-tools deploy --only firestore:rules`

## Recommended env pattern
- Keep this in `.env` (local only):
  - `GOOGLE_PLACES_API_KEY=` (preferred dedicated Places key)
  - `GOOGLE_ANDROID_API_KEY=` (android fallback)
  - `GOOGLE_API_KEY=` / `GOOGLE_MAPS_API_KEY=` (general fallback)

## Notes
- Do not commit real API keys.
- If using key rotation, verify `.env` points to the **new** key after rotation.
