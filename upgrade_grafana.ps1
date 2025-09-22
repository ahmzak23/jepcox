# Grafana Upgrade Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    GRAFANA UPGRADE SCRIPT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create backup
Write-Host "Step 1: Creating backup..." -ForegroundColor Yellow
if (!(Test-Path "grafana_backup")) {
    New-Item -ItemType Directory -Name "grafana_backup"
}
Write-Host "Backing up Grafana data..."
try {
    docker cp docker-apisix-grafana-1:/var/lib/grafana grafana_backup/
    docker cp docker-apisix-grafana-1:/etc/grafana grafana_backup/
    Write-Host "Backup completed!" -ForegroundColor Green
} catch {
    Write-Host "Backup failed or container not running" -ForegroundColor Red
}
Write-Host ""

# Step 2: Pull latest image
Write-Host "Step 2: Pulling latest Grafana image..." -ForegroundColor Yellow
docker pull grafana/grafana:latest
Write-Host ""

# Step 3: Stop Grafana
Write-Host "Step 3: Stopping Grafana service..." -ForegroundColor Yellow
docker-compose stop grafana
Write-Host ""

# Step 4: Start with latest version
Write-Host "Step 4: Starting Grafana with latest version..." -ForegroundColor Yellow
docker-compose up -d grafana
Write-Host ""

# Step 5: Wait and check
Write-Host "Step 5: Waiting for Grafana to start..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
Write-Host ""

# Step 6: Check status
Write-Host "Step 6: Checking Grafana status..." -ForegroundColor Yellow
$grafanaContainer = docker ps | Select-String "grafana"
if ($grafanaContainer) {
    Write-Host "Grafana is running:" -ForegroundColor Green
    Write-Host $grafanaContainer
} else {
    Write-Host "Grafana is not running!" -ForegroundColor Red
}
Write-Host ""

# Step 7: Check version
Write-Host "Step 7: Checking Grafana version..." -ForegroundColor Yellow
try {
    $version = docker exec docker-apisix-grafana-1 grafana-server --version 2>$null
    if ($version) {
        Write-Host "Grafana version: $version" -ForegroundColor Green
    } else {
        Write-Host "Could not get version" -ForegroundColor Yellow
    }
} catch {
    Write-Host "Could not check version" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    UPGRADE COMPLETED!" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Grafana should now be running on http://localhost:3000" -ForegroundColor Green
Write-Host "Login with admin/admin" -ForegroundColor Green
Write-Host ""
Write-Host "If you encounter any issues, check the backup in grafana_backup folder" -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to continue"

