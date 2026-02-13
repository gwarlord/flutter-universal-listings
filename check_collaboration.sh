#!/bin/bash
# Quick diagnostic script for Collaboration feature issues

echo "🔍 CaribTap Collaboration Feature Diagnostics"
echo "=============================================="
echo ""

echo "📋 Step 1: Checking Firebase Functions..."
echo "-------------------------------------------"
cd functions
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install with: npm install -g firebase-tools"
    exit 1
fi

echo "✅ Firebase CLI found"
echo ""
echo "Deployed functions:"
firebase functions:list 2>/dev/null | grep -E "collaboration|addListingCollaborator|removeListingCollaborator" || echo "⚠️  No collaboration functions found - they may need to be deployed"

echo ""
echo "📋 Step 2: Checking if functions need deployment..."
echo "-------------------------------------------"
if [ ! -d "lib" ]; then
    echo "⚠️  Functions not compiled. Building..."
    npm run build
fi

echo ""
echo "📋 Step 3: Getting App Check Debug Token..."
echo "-------------------------------------------"
echo "Run your Flutter app in debug mode and look for:"
echo "  'Firebase App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'"
echo ""
echo "Or use this command while your app is running:"
echo "  adb logcat | grep -i 'FirebaseAppCheck\\|debug token'"
echo ""

echo "📋 Step 4: Quick Actions"
echo "-------------------------------------------"
echo "1. Deploy functions:     npm run deploy"
echo "2. View function logs:   firebase functions:log"
echo "3. Start emulator:       npm run serve"
echo ""
echo "For detailed setup instructions, see:"
echo "  - APP_CHECK_SETUP.md"
echo "  - COLLABORATION_TROUBLESHOOTING.md"
