@echo off
echo Testing Kong API Gateway Installation...
echo.

REM Test Kong health endpoint
echo 1. Testing Kong health endpoint...
curl -s http://localhost:8000/kong-health
if %errorlevel% equ 0 (
    echo [OK] Kong health check passed
) else (
    echo [FAIL] Kong health check failed
)
echo.

REM Test Kong Admin API
echo 2. Testing Kong Admin API...
curl -s http://localhost:8001/services
if %errorlevel% equ 0 (
    echo [OK] Kong Admin API is accessible
) else (
    echo [FAIL] Kong Admin API is not accessible
)
echo.

REM Test APISIX proxy through Kong
echo 3. Testing APISIX proxy through Kong...
curl -s http://localhost:8000/apisix-proxy
if %errorlevel% equ 0 (
    echo [OK] APISIX proxy through Kong is working
) else (
    echo [FAIL] APISIX proxy through Kong failed
)
echo.

REM Test direct APISIX (should still work)
echo 4. Testing direct APISIX access...
curl -s http://localhost:9080/apisix/status
if %errorlevel% equ 0 (
    echo [OK] Direct APISIX access is working
) else (
    echo [FAIL] Direct APISIX access failed
)
echo.

echo Kong API Gateway test completed!
echo.
echo Available endpoints:
echo - Kong Proxy: http://localhost:8000
echo - Kong Admin: http://localhost:8001
echo - Kong Manager: http://localhost:8002
echo - Konga UI: http://localhost:1337
echo - APISIX (direct): http://localhost:9080
echo.
pause
