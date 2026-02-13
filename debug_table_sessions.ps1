# Debug script to check table sessions and orders with Table Mode
# This script helps diagnose table session visibility issues

Write-Host "`n=== Table Sessions Debug ===" -ForegroundColor Cyan
Write-Host "This script will check for table sessions and orders with tableSessionId`n" -ForegroundColor Gray

# Check if Firebase CLI is available
if (!(Get-Command firebase -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Firebase CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   npm install -g firebase-tools" -ForegroundColor Yellow
    exit 1
}

Write-Host "📊 Fetching table sessions from Firestore..." -ForegroundColor Yellow

# Get table sessions
$sessions = firebase firestore:get table_sessions --limit 10 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Table Sessions Query Successful" -ForegroundColor Green
    Write-Host $sessions
} else {
    Write-Host "`n⚠️ Could not fetch table sessions:" -ForegroundColor Yellow
    Write-Host $sessions
}

Write-Host "`n📊 Fetching recent orders with table mode..." -ForegroundColor Yellow

# Try to get orders (note: firestore:get doesn't support where clauses, so we get recent orders)
$orders = firebase firestore:get order_requests --limit 10 --order-by createdAt DESC 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Orders Query Successful" -ForegroundColor Green
    Write-Host $orders
} else {
    Write-Host "`n⚠️ Could not fetch orders:" -ForegroundColor Yellow
    Write-Host $orders
}

Write-Host "`n=== Debug Complete ===" -ForegroundColor Cyan
Write-Host "`nTo fix missing sessions:" -ForegroundColor Gray
Write-Host "1. Check if table_sessions collection has documents" -ForegroundColor Gray
Write-Host "2. Verify listingId matches between orders and sessions" -ForegroundColor Gray
Write-Host "3. Check session status (should be PENDING, ACTIVE, or CLOSED)" -ForegroundColor Gray
Write-Host "4. Ensure orders were placed AFTER creating a table session" -ForegroundColor Gray
