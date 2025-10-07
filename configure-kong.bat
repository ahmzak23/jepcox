@echo off
echo Configuring Kong API Gateway...

REM Wait for Kong to be ready
echo Waiting for Kong to be ready...
timeout /t 15 /nobreak > nul

REM Apply Kong configuration
echo Applying Kong configuration...
docker exec apisix-workshop-kong kong config db_import /kong_conf/kong.yml

REM Verify configuration
echo Verifying Kong configuration...
curl -s http://localhost:8001/services | findstr "kong-health-check"

echo.
echo Kong configuration applied successfully!
echo.
echo Available routes:
echo - Health check: http://localhost:8000/kong-health
echo - APISIX proxy: http://localhost:8000/apisix-proxy
echo - Web1 proxy: http://localhost:8000/web1
echo.
pause
