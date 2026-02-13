# Quick diagnostic script for Collaboration feature issues
# PowerShell version for Windows

Write-Host "🔍 CaribTap Collaboration Feature Diagnostics" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Step 1: Checking Firebase Functions..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"
Push-Location functions

$firebaseExists = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebaseExists) {
    Write-Host "❌ Firebase CLI not found. Install with: npm install -g firebase-tools" -ForegroundColor Red
    Pop-Location
    exit 1
}

Write-Host "✅ Firebase CLI found" -ForegroundColor Green
Write-Host ""
Write-Host "Checking deployed functions..." -ForegroundColor White

try {
    $functions = firebase functions:list 2>$null | Select-String -Pattern "collaboration|addListingCollaborator|removeListingCollaborator"
    if ($functions) {
        Write-Host "✅ Collaboration functions found:" -ForegroundColor Green
        $functions | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "⚠️  No collaboration functions found - they may need to be deployed" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not check deployed functions" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "📋 Step 2: Checking if functions need compilation..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"
if (-not (Test-Path "lib")) {
    Write-Host "⚠️  Functions not compiled. Building..." -ForegroundColor Yellow
    npm run build
} else {
    Write-Host "✅ Functions are compiled" -ForegroundColor Green
}

Pop-Location

Write-Host ""
Write-Host "📋 Step 3: Getting App Check Debug Token..." -ForegroundColor Yellow
Write-Host "-------------------------------------------"
Write-Host "To get your debug token:" -ForegroundColor White
Write-Host "  1. Run your Flutter app in debug mode" -ForegroundColor White
Write-Host "  2. Check Android Studio logcat for:" -ForegroundColor White
Write-Host "     'Firebase App Check debug token: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Or use this command while your app is running:" -ForegroundColor White
Write-Host "  adb logcat | Select-String -Pattern 'FirebaseAppCheck|debug token'" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 Step 4: Quick Actions" -ForegroundColor Yellow
Write-Host "-------------------------------------------"
Write-Host "1. Deploy functions:" -ForegroundColor White
Write-Host "   cd functions; npm run deploy" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. View function logs:" -ForegroundColor White
Write-Host "   cd functions; firebase functions:log" -ForegroundColor Cyan
Write-Host ""
Write-Host "3. Start emulator (local testing):" -ForegroundColor White
Write-Host "   cd functions; npm run serve" -ForegroundColor Cyan
Write-Host ""
Write-Host "4. Check specific function logs:" -ForegroundColor White
Write-Host "   cd functions; firebase functions:log --only addListingCollaborator" -ForegroundColor Cyan
Write-Host ""
Write-Host "📚 For detailed setup instructions, see:" -ForegroundColor Yellow
Write-Host "  - APP_CHECK_SETUP.md" -ForegroundColor Cyan
Write-Host "  - COLLABORATION_TROUBLESHOOTING.md" -ForegroundColor Cyan
Write-Host ""
