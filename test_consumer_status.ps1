Write-Host "🔍 Testing OMS App Mock Consumer Status" -ForegroundColor Green

# Check health endpoint
Write-Host "`n🔍 Checking Health Endpoint..." -ForegroundColor Yellow
try {
    $health = Invoke-RestMethod -Uri "http://localhost:5000/api/health" -Method GET
    Write-Host "✅ Health check successful" -ForegroundColor Green
    Write-Host "   Status: $($health.status)" -ForegroundColor Cyan
    Write-Host "   Kafka connected: $($health.kafka_connected)" -ForegroundColor Cyan
    Write-Host "   Consumer running: $($health.consumer_running)" -ForegroundColor Cyan
    Write-Host "   Consumer thread alive: $($health.consumer_thread_alive)" -ForegroundColor Cyan
    Write-Host "   Total outages: $($health.stats.total_outages)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Health check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Check outages endpoint
Write-Host "`n🔍 Checking Outages Endpoint..." -ForegroundColor Yellow
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

Write-Host "`n💡 Analysis:" -ForegroundColor Yellow
Write-Host "   - If 'Consumer running' is false, the consumer thread failed" -ForegroundColor White
Write-Host "   - If 'Consumer thread alive' is false, the consumer object is null" -ForegroundColor White
Write-Host "   - If both are true but no outages, check Kafka connection" -ForegroundColor White
