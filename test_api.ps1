Write-Host "🚀 Testing OMS API" -ForegroundColor Green

# Test health endpoint
Write-Host "`n🔍 Testing Health Endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -Method GET
    Write-Host "✅ Health check successful" -ForegroundColor Green
    Write-Host "   Kafka connected: $($health.kafka_connected)" -ForegroundColor Cyan
    Write-Host "   Total outages: $($health.stats.total_outages)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test outages endpoint
Write-Host "`n🔍 Testing Outages Endpoint..." -ForegroundColor Yellow
try {
    $outages = Invoke-RestMethod -Uri "http://localhost:5000/api/outages" -Method GET
    Write-Host "✅ Outages API successful" -ForegroundColor Green
    Write-Host "   Total outages: $($outages.total)" -ForegroundColor Cyan
    
    if ($outages.outages.Count -gt 0) {
        Write-Host "📋 Outages found:" -ForegroundColor Green
        foreach ($outage in $outages.outages) {
            Write-Host "   - $($outage.event_id): $($outage.severity) - $($outage.location)" -ForegroundColor Cyan
        }
    } else {
        Write-Host "⚠️  No outages found" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Outages API failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n💡 Next steps:" -ForegroundColor Yellow
Write-Host "   1. Publish a message to Kafka" -ForegroundColor White
Write-Host "   2. Check if OMS App Mock processes it" -ForegroundColor White
Write-Host "   3. Verify API returns the data" -ForegroundColor White
