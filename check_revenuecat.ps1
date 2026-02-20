# RevenueCat Quick Diagnostic Script
# Run this to check your current setup status

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "RevenueCat Setup Diagnostic" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$issues = @()
$warnings = @()
$success = @()

# Check 1: Verify pubspec.yaml has purchases_flutter
Write-Host "Checking Flutter packages..." -ForegroundColor Yellow
$pubspec = Get-Content "pubspec.yaml" -Raw
if ($pubspec -match "purchases_flutter:\s*\^?\d+\.\d+\.\d+") {
    $success += "✅ purchases_flutter package found"
    Write-Host "  ✅ purchases_flutter installed" -ForegroundColor Green
} else {
    $issues += "❌ purchases_flutter package not found in pubspec.yaml"
    Write-Host "  ❌ purchases_flutter NOT found" -ForegroundColor Red
}

# Check 2: Verify revenue_cat_service.dart exists
Write-Host "`nChecking service file..." -ForegroundColor Yellow
if (Test-Path "lib\listings\services\revenue_cat_service.dart") {
    $success += "✅ RevenueCatService file exists"
    Write-Host "  ✅ revenue_cat_service.dart found" -ForegroundColor Green
    
    # Check API keys
    $serviceContent = Get-Content "lib\listings\services\revenue_cat_service.dart" -Raw
    if ($serviceContent -match "_androidApiKey\s*=\s*'([^']+)'") {
        $androidKey = $matches[1]
        if ($androidKey -match "^goog_") {
            $success += "✅ Android API key format correct"
            Write-Host "  ✅ Android API key: $androidKey" -ForegroundColor Green
        } else {
            $warnings += "⚠️ Android API key doesn't start with 'goog_'"
            Write-Host "  ⚠️ Android API key format may be incorrect" -ForegroundColor Yellow
        }
    }
    
    if ($serviceContent -match "_iosApiKey\s*=\s*'([^']+)'") {
        $iosKey = $matches[1]
        if ($iosKey -match "^(appl_|goog_)") {
            $success += "✅ iOS API key found"
            Write-Host "  ✅ iOS API key: $iosKey" -ForegroundColor Green
            if ($iosKey -match "^goog_" -and $iosKey -eq $androidKey) {
                $warnings += "⚠️ iOS and Android using same key (OK if Android-only)"
                Write-Host "  ⚠️ iOS using same key as Android" -ForegroundColor Yellow
            }
        } else {
            $warnings += "⚠️ iOS API key format unusual"
            Write-Host "  ⚠️ iOS API key format may be incorrect" -ForegroundColor Yellow
        }
    }
    
    # Check entitlement name
    if ($serviceContent -match "caribTapProEntitlement\s*=\s*'([^']+)'") {
        $entitlement = $matches[1]
        $success += "✅ Entitlement identifier: $entitlement"
        Write-Host "  ✅ Entitlement: '$entitlement'" -ForegroundColor Green
    }
    
    # Check product IDs
    if ($serviceContent -match "monthlyProductId\s*=\s*'([^']+)'") {
        $monthly = $matches[1]
        Write-Host "  ✅ Monthly product: '$monthly'" -ForegroundColor Green
    }
    if ($serviceContent -match "yearlyProductId\s*=\s*'([^']+)'") {
        $yearly = $matches[1]
        Write-Host "  ✅ Yearly product: '$yearly'" -ForegroundColor Green
    }
    if ($serviceContent -match "lifetimeProductId\s*=\s*'([^']+)'") {
        $lifetime = $matches[1]
        Write-Host "  ✅ Lifetime product: '$lifetime'" -ForegroundColor Green
    }
} else {
    $issues += "❌ revenue_cat_service.dart not found"
    Write-Host "  ❌ Service file not found" -ForegroundColor Red
}

# Check 3: Verify initialization in auth
Write-Host "`nChecking initialization..." -ForegroundColor Yellow
if (Test-Path "lib\listings\ui\auth\api\firebase\auth_firebase.dart") {
    $authContent = Get-Content "lib\listings\ui\auth\api\firebase\auth_firebase.dart" -Raw
    if ($authContent -match "RevenueCatService\(\)\.initialize") {
        $success += "✅ RevenueCat initialized in auth flow"
        Write-Host "  ✅ Initialization found in auth_firebase.dart" -ForegroundColor Green
    } else {
        $warnings += "⚠️ RevenueCat initialization not found in auth"
        Write-Host "  ⚠️ Initialization not found (may be elsewhere)" -ForegroundColor Yellow
    }
}

# Check 4: Verify paywall screen exists
Write-Host "`nChecking UI screens..." -ForegroundColor Yellow
if (Test-Path "lib\listings\ui\subscription\paywall_screen.dart") {
    $success += "✅ Paywall screen exists"
    Write-Host "  ✅ paywall_screen.dart found" -ForegroundColor Green
} else {
    $warnings += "⚠️ Paywall screen not found"
    Write-Host "  ⚠️ paywall_screen.dart not found" -ForegroundColor Yellow
}

# Check 5: Android configuration
Write-Host "`nChecking Android config..." -ForegroundColor Yellow
if (Test-Path "android\app\build.gradle") {
    $buildGradle = Get-Content "android\app\build.gradle" -Raw
    if ($buildGradle -match "applicationId\s*=?\s*[`"]([^`"]+)[`"]") {
        $packageName = $matches[1]
        $success += "✅ Package name: $packageName"
        Write-Host "  ✅ Package name: $packageName" -ForegroundColor Green
    }
    if ($buildGradle -match "minSdk\s*=?\s*(\d+)") {
        $minSdk = $matches[1]
        if ([int]$minSdk -ge 24) {
            $success += "✅ minSdk $minSdk (RevenueCat requires 24+)"
            Write-Host "  ✅ minSdk: $minSdk" -ForegroundColor Green
        } else {
            $issues += "❌ minSdk $minSdk is too low (need 24+)"
            Write-Host "  ❌ minSdk: $minSdk (need 24+)" -ForegroundColor Red
        }
    }
}

# Check 6: Check for existing documentation
Write-Host "`nChecking documentation..." -ForegroundColor Yellow
$docs = @(
    "REVENUECAT_MASTER_SETUP.md",
    "REVENUECAT_SETUP.md",
    "REVENUECAT_QUICKSTART.md",
    "REVENUECAT_INTEGRATION_COMPLETE.md"
)
foreach ($doc in $docs) {
    if (Test-Path $doc) {
        Write-Host "  📄 $doc" -ForegroundColor Cyan
    }
}

# Summary
Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "SUMMARY" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

Write-Host "`n✅ Successes ($($success.Count)):" -ForegroundColor Green
foreach ($item in $success) {
    Write-Host "  $item" -ForegroundColor Green
}

if ($warnings.Count -gt 0) {
    Write-Host "`n⚠️  Warnings ($($warnings.Count)):" -ForegroundColor Yellow
    foreach ($item in $warnings) {
        Write-Host "  $item" -ForegroundColor Yellow
    }
}

if ($issues.Count -gt 0) {
    Write-Host "`n❌ Issues ($($issues.Count)):" -ForegroundColor Red
    foreach ($item in $issues) {
        Write-Host "  $item" -ForegroundColor Red
    }
}

Write-Host "`n==================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Review REVENUECAT_MASTER_SETUP.md for complete guide" -ForegroundColor White
Write-Host "2. Set up RevenueCat dashboard (https://app.revenuecat.com/)" -ForegroundColor White
Write-Host "3. Create products in Google Play Console" -ForegroundColor White
Write-Host "4. Update API keys in revenue_cat_service.dart" -ForegroundColor White
Write-Host "5. Test subscription flow" -ForegroundColor White
Write-Host ""

# Exit code based on issues
if ($issues.Count -gt 0) {
    exit 1
} else {
    exit 0
}
