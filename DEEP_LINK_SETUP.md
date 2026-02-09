# CaribTap Deep Link Configuration

This document provides instructions for configuring deep links for listing sharing in the CaribTap app.

## iOS Configuration

To enable deep links on iOS, you need to add the custom URL scheme to `ios/Runner/Info.plist`.

**Location:** `ios/Runner/Info.plist`

Find the `CFBundleURLTypes` array and add the following entry **before** the closing `</array>` tag:

```xml
<dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.caribtap.instaflutter</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>caribtap</string>
    </array>
</dict>
```

### Complete CFBundleURLTypes Section Should Look Like:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>fb285315185217069</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.443422962164-5d1okj2k0krl1vh1qi3bkovte3mg0lum</string>
        </array>
    </dict>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.caribtap.instaflutter</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>caribtap</string>
        </array>
    </dict>
</array>
```

### iOS Universal Links (Optional)

For production, you should also set up Universal Links. Add the following to your `Info.plist`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:caribtap.com</string>
</array>
```

And create an `apple-app-site-association` file on your server at:
- `https://caribtap.com/.well-known/apple-app-site-association`
- `https://caribtap.com/apple-app-site-association`

Example file content:
```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "YOUR_TEAM_ID.com.caribtap.instaflutter.ios",
        "paths": ["/l/*"]
      }
    ]
  }
}
```

## Android Configuration

✅ **Already configured!** The Android manifest has been updated with the deep link intent filters.

The configuration includes:
- Web-based deep links: `https://caribtap.com/l/<listingId>`
- Custom scheme deep links: `caribtap://listing/<listingId>`

### Android App Links (For Production)

For verified Android App Links, you need to:

1. Generate a Digital Asset Links file at:
   `https://caribtap.com/.well-known/assetlinks.json`

2. Get your app's signing certificate SHA-256 fingerprint:
   ```bash
   keytool -list -v -keystore your-release-key.keystore
   ```

3. Create the assetlinks.json file:
   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "com.caribtap.instaflutter.android",
       "sha256_cert_fingerprints": ["YOUR_SHA256_FINGERPRINT"]
     }
   }]
   ```

## Deep Link Format

### Primary (Web-based)
```
https://caribtap.com/l/<listingId>
```

### Fallback (Custom scheme)
```
caribtap://listing/<listingId>
```

## Testing Deep Links

### iOS Testing
```bash
xcrun simctl openurl booted "caribtap://listing/test123"
xcrun simctl openurl booted "https://caribtap.com/l/test123"
```

### Android Testing
```bash
adb shell am start -W -a android.intent.action.VIEW -d "caribtap://listing/test123"
adb shell am start -W -a android.intent.action.VIEW -d "https://caribtap.com/l/test123"
```

## Domain Configuration

**Important:** Before going to production, replace `caribtap.com` with your actual domain in:

1. `lib/listings/services/deep_link_service.dart` - Update `_baseDomain` constant
2. `android/app/src/main/AndroidManifest.xml` - Update host in intent-filter
3. `ios/Runner/Info.plist` - Update associated domains

## Features Implemented

✅ Share button on listing detail screens
✅ Deep link service for creating shareable URLs
✅ Deep link handling for incoming links
✅ Navigation to listing detail from deep links
✅ Android intent filters configured
✅ iOS URL scheme support (manual step required above)
✅ Fallback handling for missing listings
✅ Integration with OS share sheet

## Usage

Users can tap the share icon on any listing detail screen to:
1. Generate a shareable link
2. Share via WhatsApp, SMS, email, social media, etc.
3. Recipients with the app installed will open directly to the listing
4. Recipients without the app can install from the shared link (when web landing page is set up)

## Next Steps (Optional Enhancements)

1. **Set up Firebase Dynamic Links** for better link management and analytics
2. **Create a web landing page** at `https://caribtap.com/l/*` to:
   - Show listing preview
   - Provide app store download buttons
   - Handle SEO and social media previews
3. **Add link shortening** for cleaner looking URLs
4. **Implement analytics** to track shares and conversions
5. **Add social meta tags** to the web landing page for rich previews

## Troubleshooting

### Deep links not working on iOS
- Ensure you've added the URL scheme to Info.plist
- Clean build folder: `flutter clean`
- Rebuild the app

### Deep links not working on Android
- Check intent filters in AndroidManifest.xml
- Verify autoVerify is set to true for web links
- Test with `adb` commands first

### Listing not found error
- Verify the listing ID is correct
- Check Firestore permissions
- Ensure the listing document exists in the `listings` collection

## Support

For issues or questions, refer to:
- Flutter app_links package: https://pub.dev/packages/app_links
- Android App Links: https://developer.android.com/training/app-links
- iOS Universal Links: https://developer.apple.com/ios/universal-links/
