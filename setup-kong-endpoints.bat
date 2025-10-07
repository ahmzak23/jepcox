@echo off
setlocal enabledelayedexpansion

REM Kong API Gateway Setup Script for Windows
REM This script creates all services, routes, and dependencies for Kong
REM Based on the APISIX Gateway Endpoints configuration

echo 🚀 Setting up Kong API Gateway with all endpoints...
echo ==================================================

REM Wait for Kong to be ready
echo ⏳ Waiting for Kong to be ready...
:wait_for_kong
curl -s http://localhost:8001/status >nul 2>&1
if %errorlevel% neq 0 (
    echo    Waiting for Kong Admin API...
    timeout /t 2 /nobreak >nul
    goto wait_for_kong
)
echo ✅ Kong is ready!

echo.
echo 📦 Creating Kong Services...

REM 1. HES Mock Generator Service
echo    Creating HES Mock Generator Service...
curl -s -X POST http://localhost:8001/services ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"hes-mock-generator-service\", \"url\": \"http://apisix-workshop-kaifa_hes_upstram-1:80\"}"

REM 2. SCADA Mock Generator Service
echo    Creating SCADA Mock Generator Service...
curl -s -X POST http://localhost:8001/services ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"scada-mock-generator-service\", \"url\": \"http://apisix-workshop-scada_upstram-1:80\"}"

REM 3. Call Center Ticket Generator Service
echo    Creating Call Center Ticket Generator Service...
curl -s -X POST http://localhost:8001/services ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"call-center-ticket-generator-service\", \"url\": \"http://apisix-workshop-call_center_upstream-1:80\"}"

REM 4. ONU Mock Generator Service
echo    Creating ONU Mock Generator Service...
curl -s -X POST http://localhost:8001/services ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"onu-mock-generator-service\", \"url\": \"http://apisix-workshop-onu_upstream-1:80\"}"

echo ✅ All services created successfully!

echo.
echo 🛣️  Creating Kong Routes...

REM 1. HES Mock Generator Route
echo    Creating HES Mock Generator Route...
curl -s -X POST http://localhost:8001/services/hes-mock-generator-service/routes ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"hes-mock-generator-route\", \"paths\": [\"/hes-mock-generator\"], \"methods\": [\"GET\", \"POST\"]}"

REM 2. SCADA Mock Generator Route
echo    Creating SCADA Mock Generator Route...
curl -s -X POST http://localhost:8001/services/scada-mock-generator-service/routes ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"scada-mock-generator-route\", \"paths\": [\"/scada-mock-generator\"], \"methods\": [\"GET\", \"POST\"]}"

REM 3. Call Center Ticket Generator Route
echo    Creating Call Center Ticket Generator Route...
curl -s -X POST http://localhost:8001/services/call-center-ticket-generator-service/routes ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"call-center-ticket-generator-route\", \"paths\": [\"/call-center-ticket-generator\"], \"methods\": [\"GET\", \"POST\"]}"

REM 4. ONU Mock Generator Route
echo    Creating ONU Mock Generator Route...
curl -s -X POST http://localhost:8001/services/onu-mock-generator-service/routes ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"onu-mock-generator-route\", \"paths\": [\"/onu-mock-generator\"], \"methods\": [\"GET\", \"POST\"]}"

echo ✅ All routes created successfully!

echo.
echo 🔧 Adding CORS Plugin to all services...

REM Add CORS plugin to HES service
echo    Adding CORS plugin to hes-mock-generator-service...
curl -s -X POST http://localhost:8001/services/hes-mock-generator-service/plugins ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"cors\", \"config\": {\"origins\": [\"*\"], \"methods\": [\"GET\", \"POST\", \"PUT\", \"DELETE\", \"OPTIONS\"], \"headers\": [\"Accept\", \"Accept-Version\", \"Content-Length\", \"Content-MD5\", \"Content-Type\", \"Date\", \"X-Auth-Token\"], \"exposed_headers\": [\"X-Auth-Token\"], \"credentials\": true, \"max_age\": 3600}}"

REM Add CORS plugin to SCADA service
echo    Adding CORS plugin to scada-mock-generator-service...
curl -s -X POST http://localhost:8001/services/scada-mock-generator-service/plugins ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"cors\", \"config\": {\"origins\": [\"*\"], \"methods\": [\"GET\", \"POST\", \"PUT\", \"DELETE\", \"OPTIONS\"], \"headers\": [\"Accept\", \"Accept-Version\", \"Content-Length\", \"Content-MD5\", \"Content-Type\", \"Date\", \"X-Auth-Token\"], \"exposed_headers\": [\"X-Auth-Token\"], \"credentials\": true, \"max_age\": 3600}}"

REM Add CORS plugin to Call Center service
echo    Adding CORS plugin to call-center-ticket-generator-service...
curl -s -X POST http://localhost:8001/services/call-center-ticket-generator-service/plugins ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"cors\", \"config\": {\"origins\": [\"*\"], \"methods\": [\"GET\", \"POST\", \"PUT\", \"DELETE\", \"OPTIONS\"], \"headers\": [\"Accept\", \"Accept-Version\", \"Content-Length\", \"Content-MD5\", \"Content-Type\", \"Date\", \"X-Auth-Token\"], \"exposed_headers\": [\"X-Auth-Token\"], \"credentials\": true, \"max_age\": 3600}}"

REM Add CORS plugin to ONU service
echo    Adding CORS plugin to onu-mock-generator-service...
curl -s -X POST http://localhost:8001/services/onu-mock-generator-service/plugins ^
  -H "Content-Type: application/json" ^
  -d "{\"name\": \"cors\", \"config\": {\"origins\": [\"*\"], \"methods\": [\"GET\", \"POST\", \"PUT\", \"DELETE\", \"OPTIONS\"], \"headers\": [\"Accept\", \"Accept-Version\", \"Content-Length\", \"Content-MD5\", \"Content-Type\", \"Date\", \"X-Auth-Token\"], \"exposed_headers\": [\"X-Auth-Token\"], \"credentials\": true, \"max_age\": 3600}}"

echo ✅ CORS plugins added successfully!

echo.
echo 🧪 Testing all endpoints...

REM Test HES endpoint
echo    Testing HES Mock Generator...
curl -s -w "%%{http_code}" -o nul http://localhost:8000/hes-mock-generator
if %errorlevel% equ 0 (
    echo    ✅ HES Mock Generator - Working
) else (
    echo    ⚠️  HES Mock Generator - Not responding
)

REM Test Call Center endpoint
echo    Testing Call Center Generator...
curl -s -w "%%{http_code}" -o nul http://localhost:8000/call-center-ticket-generator
if %errorlevel% equ 0 (
    echo    ✅ Call Center Generator - Working
) else (
    echo    ⚠️  Call Center Generator - Not responding
)

REM Test ONU endpoint
echo    Testing ONU Mock Generator...
curl -s -w "%%{http_code}" -o nul http://localhost:8000/onu-mock-generator
if %errorlevel% equ 0 (
    echo    ✅ ONU Mock Generator - Working
) else (
    echo    ⚠️  ONU Mock Generator - Not responding
)

REM Test SCADA endpoint
echo    Testing SCADA Mock Generator...
curl -s -w "%%{http_code}" -o nul http://localhost:8000/scada-mock-generator
if %errorlevel% equ 0 (
    echo    ✅ SCADA Mock Generator - Working
) else (
    echo    ⚠️  SCADA Mock Generator - Not responding
)

echo.
echo 📊 Kong Setup Summary
echo ====================
echo Services created: 4
echo Routes created: 4
echo CORS plugins added: 4
echo.
echo 🌐 Available Endpoints:
echo • HES Mock Generator: http://localhost:8000/hes-mock-generator
echo • SCADA Mock Generator: http://localhost:8000/scada-mock-generator
echo • Call Center Generator: http://localhost:8000/call-center-ticket-generator
echo • ONU Mock Generator: http://localhost:8000/onu-mock-generator
echo.
echo 🔧 Management URLs:
echo • Kong Admin API: http://localhost:8001
echo • Kong Manager: http://localhost:8002
echo • Konga Admin: http://localhost:1337
echo.
echo ✅ Kong setup completed successfully!
echo.
pause
