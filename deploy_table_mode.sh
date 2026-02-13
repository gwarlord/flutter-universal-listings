#!/bin/bash
# Table Mode Deployment Script
# Run this script to deploy all Table Mode components

set -e  # Exit on error

echo "🚀 Starting Table Mode Deployment..."
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Please install it first:"
    echo "   npm install -g firebase-tools"
    exit 1
fi

# Check if logged in to Firebase
echo "📋 Checking Firebase authentication..."
firebase projects:list > /dev/null 2>&1 || {
    echo "❌ Not logged in to Firebase. Please run:"
    echo "   firebase login"
    exit 1
}

echo "✅ Firebase CLI ready"
echo ""

# Step 1: Build Cloud Functions
echo "🔨 Step 1/4: Building Cloud Functions..."
cd functions
npm run build
if [ $? -eq 0 ]; then
    echo "✅ Cloud Functions built successfully"
else
    echo "❌ Failed to build Cloud Functions"
    exit 1
fi
cd ..
echo ""

# Step 2: Deploy Firestore Indexes
echo "📊 Step 2/4: Deploying Firestore Indexes..."
echo "⚠️  Note: Index creation can take 10-30 minutes"
firebase deploy --only firestore:indexes
if [ $? -eq 0 ]; then
    echo "✅ Firestore indexes deployment started"
else
    echo "❌ Failed to deploy indexes"
    exit 1
fi
echo ""

# Step 3: Deploy Firestore Security Rules
echo "🔒 Step 3/4: Deploying Firestore Security Rules..."
firebase deploy --only firestore:rules
if [ $? -eq 0 ]; then
    echo "✅ Security rules deployed successfully"
else
    echo "❌ Failed to deploy security rules"
    exit 1
fi
echo ""

# Step 4: Deploy Cloud Functions
echo "☁️  Step 4/4: Deploying Cloud Functions..."
firebase deploy --only functions
if [ $? -eq 0 ]; then
    echo "✅ Cloud Functions deployed successfully"
else
    echo "❌ Failed to deploy Cloud Functions"
    exit 1
fi
echo ""

# Deployment complete
echo "🎉 Table Mode Deployment Complete!"
echo ""
echo "📝 Next Steps:"
echo "   1. Wait 10-30 minutes for Firestore indexes to build"
echo "   2. Check Firebase Console → Firestore → Indexes"
echo "   3. Run 'flutter clean && flutter pub get' to refresh dependencies"
echo "   4. Test the app with 'flutter run'"
echo ""
echo "📚 Documentation:"
echo "   - TABLE_MODE_IMPLEMENTATION.md - Full feature guide"
echo "   - TABLE_MODE_INTEGRATION_COMPLETE.md - Integration summary"
echo ""
echo "🧪 Testing:"
echo "   - Create a table and generate QR code"
echo "   - Scan QR code from customer app"
echo "   - Test summon waiter and bill request"
echo "   - Place Mini Store order while in active session"
echo "   - Verify order is tagged with table session"
echo ""
echo "✅ All deployments successful!"
