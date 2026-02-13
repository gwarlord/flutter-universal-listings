# Table Mode Deployment Script (PowerShell)
# Run this script to deploy all Table Mode components

Write-Host "🚀 Starting Table Mode Deployment..." -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
$firebaseCmd = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseCmd) {
    Write-Host "❌ Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

# Check if logged in to Firebase
Write-Host "📋 Checking Firebase authentication..." -ForegroundColor Yellow
$loginCheck = firebase projects:list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Not logged in to Firebase. Please run:" -ForegroundColor Red
    Write-Host "   firebase login" -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Firebase CLI ready" -ForegroundColor Green
Write-Host ""

# Step 1: Build Cloud Functions
Write-Host "🔨 Step 1/4: Building Cloud Functions..." -ForegroundColor Cyan
Push-Location functions
npm run build
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Cloud Functions built successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to build Cloud Functions" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host ""

# Step 2: Deploy Firestore Indexes
Write-Host "📊 Step 2/4: Deploying Firestore Indexes..." -ForegroundColor Cyan
Write-Host "⚠️  Note: Index creation can take 10-30 minutes" -ForegroundColor Yellow
firebase deploy --only firestore:indexes
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Firestore indexes deployment started" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to deploy indexes" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 3: Deploy Firestore Security Rules
Write-Host "🔒 Step 3/4: Deploying Firestore Security Rules..." -ForegroundColor Cyan
firebase deploy --only firestore:rules
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Security rules deployed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to deploy security rules" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Step 4: Deploy Cloud Functions
Write-Host "☁️  Step 4/4: Deploying Cloud Functions..." -ForegroundColor Cyan
firebase deploy --only functions
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Cloud Functions deployed successfully" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to deploy Cloud Functions" -ForegroundColor Red
    exit 1
}
Write-Host ""

# Deployment complete
Write-Host "🎉 Table Mode Deployment Complete!" -ForegroundColor Green
Write-Host ""
Write-Host "📝 Next Steps:" -ForegroundColor Cyan
Write-Host "   1. Wait 10-30 minutes for Firestore indexes to build"
Write-Host "   2. Check Firebase Console → Firestore → Indexes"
Write-Host "   3. Run 'flutter clean && flutter pub get' to refresh dependencies"
Write-Host "   4. Test the app with 'flutter run'"
Write-Host ""
Write-Host "📚 Documentation:" -ForegroundColor Cyan
Write-Host "   - TABLE_MODE_IMPLEMENTATION.md - Full feature guide"
Write-Host "   - TABLE_MODE_INTEGRATION_COMPLETE.md - Integration summary"
Write-Host ""
Write-Host "🧪 Testing:" -ForegroundColor Cyan
Write-Host "   - Create a table and generate QR code"
Write-Host "   - Scan QR code from customer app"
Write-Host "   - Test summon waiter and bill request"
Write-Host "   - Place Mini Store order while in active session"
Write-Host "   - Verify order is tagged with table session"
Write-Host ""
Write-Host "✅ All deployments successful!" -ForegroundColor Green
