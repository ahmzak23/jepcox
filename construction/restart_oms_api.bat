@echo off
echo Restarting OMS API with CORS support...

REM Stop the OMS API service
docker compose stop oms-api

REM Rebuild and start the OMS API service
docker compose up -d --build oms-api

REM Wait a moment for the service to start
timeout /t 5 /nobreak > nul

REM Check if the service is running
docker compose ps oms-api

echo.
echo OMS API restarted with CORS support!
echo Dashboard should now be able to connect.
echo.
echo URLs:
echo - Dashboard: http://localhost:9200
echo - API: http://localhost:9100
echo - API Health: http://localhost:9100/health
echo.
pause
