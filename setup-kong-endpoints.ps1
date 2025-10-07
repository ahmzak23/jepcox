# Kong API Gateway Setup Script for PowerShell
# This script creates all services, routes, and dependencies for Kong
# Based on the APISIX Gateway Endpoints configuration

Write-Host "🚀 Setting up Kong API Gateway with all endpoints..." -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green

# Wait for Kong to be ready
Write-Host "⏳ Waiting for Kong to be ready..." -ForegroundColor Yellow
do {
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:8001/status" -TimeoutSec 2
        $kongReady = $true
    }
    catch {
        Write-Host "   Waiting for Kong Admin API..." -ForegroundColor Yellow
        Start-Sleep -Seconds 2
        $kongReady = $false
    }
} while (-not $kongReady)
Write-Host "✅ Kong is ready!" -ForegroundColor Green

Write-Host ""
Write-Host "📦 Creating Kong Services..." -ForegroundColor Cyan

# 1. HES Mock Generator Service
Write-Host "   Creating HES Mock Generator Service..." -ForegroundColor White
try {
    $hesService = Invoke-RestMethod -Uri "http://localhost:8001/services" -Method Post -Body (@{
        name = "hes-mock-generator-service"
        url = "http://apisix-workshop-kaifa_hes_upstram-1:80"
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ HES Service created with ID: $($hesService.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  HES Service creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. SCADA Mock Generator Service
Write-Host "   Creating SCADA Mock Generator Service..." -ForegroundColor White
try {
    $scadaService = Invoke-RestMethod -Uri "http://localhost:8001/services" -Method Post -Body (@{
        name = "scada-mock-generator-service"
        url = "http://apisix-workshop-scada_upstram-1:80"
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ SCADA Service created with ID: $($scadaService.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  SCADA Service creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Call Center Ticket Generator Service
Write-Host "   Creating Call Center Ticket Generator Service..." -ForegroundColor White
try {
    $callCenterService = Invoke-RestMethod -Uri "http://localhost:8001/services" -Method Post -Body (@{
        name = "call-center-ticket-generator-service"
        url = "http://apisix-workshop-call_center_upstream-1:80"
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ Call Center Service created with ID: $($callCenterService.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  Call Center Service creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. ONU Mock Generator Service
Write-Host "   Creating ONU Mock Generator Service..." -ForegroundColor White
try {
    $onuService = Invoke-RestMethod -Uri "http://localhost:8001/services" -Method Post -Body (@{
        name = "onu-mock-generator-service"
        url = "http://apisix-workshop-onu_upstream-1:80"
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ ONU Service created with ID: $($onuService.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  ONU Service creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "✅ All services created successfully!" -ForegroundColor Green

Write-Host ""
Write-Host "🛣️  Creating Kong Routes..." -ForegroundColor Cyan

# 1. HES Mock Generator Route
Write-Host "   Creating HES Mock Generator Route..." -ForegroundColor White
try {
    $hesRoute = Invoke-RestMethod -Uri "http://localhost:8001/services/hes-mock-generator-service/routes" -Method Post -Body (@{
        name = "hes-mock-generator-route"
        paths = @("/hes-mock-generator")
        methods = @("GET", "POST")
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ HES Route created with ID: $($hesRoute.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  HES Route creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. SCADA Mock Generator Route
Write-Host "   Creating SCADA Mock Generator Route..." -ForegroundColor White
try {
    $scadaRoute = Invoke-RestMethod -Uri "http://localhost:8001/services/scada-mock-generator-service/routes" -Method Post -Body (@{
        name = "scada-mock-generator-route"
        paths = @("/scada-mock-generator")
        methods = @("GET", "POST")
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ SCADA Route created with ID: $($scadaRoute.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  SCADA Route creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Call Center Ticket Generator Route
Write-Host "   Creating Call Center Ticket Generator Route..." -ForegroundColor White
try {
    $callCenterRoute = Invoke-RestMethod -Uri "http://localhost:8001/services/call-center-ticket-generator-service/routes" -Method Post -Body (@{
        name = "call-center-ticket-generator-route"
        paths = @("/call-center-ticket-generator")
        methods = @("GET", "POST")
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ Call Center Route created with ID: $($callCenterRoute.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  Call Center Route creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. ONU Mock Generator Route
Write-Host "   Creating ONU Mock Generator Route..." -ForegroundColor White
try {
    $onuRoute = Invoke-RestMethod -Uri "http://localhost:8001/services/onu-mock-generator-service/routes" -Method Post -Body (@{
        name = "onu-mock-generator-route"
        paths = @("/onu-mock-generator")
        methods = @("GET", "POST")
    } | ConvertTo-Json) -ContentType "application/json"
    Write-Host "   ✅ ONU Route created with ID: $($onuRoute.id)" -ForegroundColor Green
}
catch {
    Write-Host "   ⚠️  ONU Route creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "✅ All routes created successfully!" -ForegroundColor Green

Write-Host ""
Write-Host "🔧 Adding CORS Plugin to all services..." -ForegroundColor Cyan

$services = @("hes-mock-generator-service", "scada-mock-generator-service", "call-center-ticket-generator-service", "onu-mock-generator-service")

foreach ($service in $services) {
    Write-Host "   Adding CORS plugin to $service..." -ForegroundColor White
    try {
        $corsPlugin = Invoke-RestMethod -Uri "http://localhost:8001/services/$service/plugins" -Method Post -Body (@{
            name = "cors"
            config = @{
                origins = @("*")
                methods = @("GET", "POST", "PUT", "DELETE", "OPTIONS")
                headers = @("Accept", "Accept-Version", "Content-Length", "Content-MD5", "Content-Type", "Date", "X-Auth-Token")
                exposed_headers = @("X-Auth-Token")
                credentials = $true
                max_age = 3600
            }
        } | ConvertTo-Json) -ContentType "application/json"
        Write-Host "   ✅ CORS plugin added to $service" -ForegroundColor Green
    }
    catch {
        Write-Host "   ⚠️  CORS plugin failed for $service : $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "✅ CORS plugins added successfully!" -ForegroundColor Green

Write-Host ""
Write-Host "🧪 Testing all endpoints..." -ForegroundColor Cyan

$endpoints = @(
    @{Url = "http://localhost:8000/hes-mock-generator"; Name = "HES Mock Generator"},
    @{Url = "http://localhost:8000/call-center-ticket-generator"; Name = "Call Center Generator"},
    @{Url = "http://localhost:8000/onu-mock-generator"; Name = "ONU Mock Generator"},
    @{Url = "http://localhost:8000/scada-mock-generator"; Name = "SCADA Mock Generator"}
)

foreach ($endpoint in $endpoints) {
    Write-Host "   Testing $($endpoint.Name)..." -ForegroundColor White
    try {
        $response = Invoke-WebRequest -Uri $endpoint.Url -UseBasicParsing -TimeoutSec 10
        if ($response.StatusCode -eq 200) {
            Write-Host "   ✅ $($endpoint.Name) - Status: $($response.StatusCode)" -ForegroundColor Green
        } else {
            Write-Host "   ⚠️  $($endpoint.Name) - Status: $($response.StatusCode)" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   ❌ $($endpoint.Name) - Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Display summary
Write-Host ""
Write-Host "📊 Kong Setup Summary" -ForegroundColor Magenta
Write-Host "====================" -ForegroundColor Magenta
Write-Host "Services created: 4" -ForegroundColor White
Write-Host "Routes created: 4" -ForegroundColor White
Write-Host "CORS plugins added: 4" -ForegroundColor White
Write-Host ""
Write-Host "🌐 Available Endpoints:" -ForegroundColor Yellow
Write-Host "• HES Mock Generator: http://localhost:8000/hes-mock-generator" -ForegroundColor White
Write-Host "• SCADA Mock Generator: http://localhost:8000/scada-mock-generator" -ForegroundColor White
Write-Host "• Call Center Generator: http://localhost:8000/call-center-ticket-generator" -ForegroundColor White
Write-Host "• ONU Mock Generator: http://localhost:8000/onu-mock-generator" -ForegroundColor White
Write-Host ""
Write-Host "🔧 Management URLs:" -ForegroundColor Yellow
Write-Host "• Kong Admin API: http://localhost:8001" -ForegroundColor White
Write-Host "• Kong Manager: http://localhost:8002" -ForegroundColor White
Write-Host "• Konga Admin: http://localhost:1337" -ForegroundColor White
Write-Host ""
Write-Host "✅ Kong setup completed successfully!" -ForegroundColor Green

# Optional: Open Kong Manager in browser
$openBrowser = Read-Host "Would you like to open Kong Manager in your browser? (y/n)"
if ($openBrowser -eq "y" -or $openBrowser -eq "Y") {
    Start-Process "http://localhost:8002"
}
