@echo off
echo Testing Kong UI Interfaces...
echo.

REM Test Kong Manager
echo 1. Testing Kong Manager (http://localhost:8002)...
curl -s -o nul -w "%%{http_code}" http://localhost:8002
if %errorlevel% equ 0 (
    echo [OK] Kong Manager is accessible
) else (
    echo [FAIL] Kong Manager is not accessible
)
echo.

REM Test Konga
echo 2. Testing Konga (http://localhost:1337)...
curl -s -o nul -w "%%{http_code}" http://localhost:1337
if %errorlevel% equ 0 (
    echo [OK] Konga is accessible
) else (
    echo [FAIL] Konga is not accessible
)
echo.

REM Test Kong Admin API
echo 3. Testing Kong Admin API...
curl -s http://localhost:8001/services
if %errorlevel% equ 0 (
    echo [OK] Kong Admin API is working
) else (
    echo [FAIL] Kong Admin API failed
)
echo.

REM Test Kong Health
echo 4. Testing Kong Health Check...
curl -s http://localhost:8000/kong-health
if %errorlevel% equ 0 (
    echo [OK] Kong Health Check passed
) else (
    echo [FAIL] Kong Health Check failed
)
echo.

REM Test Kong Status
echo 5. Testing Kong Status...
curl -s http://localhost:8001/status
if %errorlevel% equ 0 (
    echo [OK] Kong Status API working
) else (
    echo [FAIL] Kong Status API failed
)
echo.

echo ========================================
echo Kong UI Test Results:
echo ========================================
echo.
echo UI Access URLs:
echo - Kong Manager: http://localhost:8002
echo - Konga Admin:  http://localhost:1337
echo - Admin API:    http://localhost:8001
echo.
echo Quick Setup for Konga:
echo 1. Open http://localhost:1337
echo 2. Create admin account (first time only)
echo 3. Add Kong connection:
echo    - Name: "Local Kong"
echo    - Kong Admin URL: "http://kong:8001"
echo    - Leave username/password empty
echo.
echo Quick Setup for Kong Manager:
echo 1. Open http://localhost:8002
echo 2. No setup required - direct access
echo.
pause
