@echo off
echo Starting Kong API Gateway with Enhanced UI...
echo.

REM Start Kong database
echo [1/6] Starting Kong database...
docker-compose up -d kong-database

REM Start Konga database
echo [2/6] Starting Konga database...
docker-compose up -d konga-database

REM Wait for databases to be ready
echo [3/6] Waiting for databases to be ready...
timeout /t 15 /nobreak > nul

REM Run Kong migrations
echo [4/6] Running Kong migrations...
docker-compose up kong-migrations

REM Start Kong
echo [5/6] Starting Kong API Gateway...
docker-compose up -d kong

REM Wait for Kong to be ready
echo [6/6] Waiting for Kong to be ready...
timeout /t 15 /nobreak > nul

REM Start Konga
echo Starting Konga Admin UI...
docker-compose up -d konga

echo.
echo ========================================
echo Kong API Gateway with UI is now running!
echo ========================================
echo.
echo 🎯 UI Dashboard: Open kong-ui-dashboard.html in your browser
echo.
echo UI Interfaces:
echo - Kong Manager (Official): http://localhost:8002
echo - Konga (Advanced Admin):  http://localhost:1337
echo - Kong Admin API:          http://localhost:8001
echo.
echo Gateway Endpoints:
echo - Kong Proxy:              http://localhost:8000
echo - Health Check:            http://localhost:8000/kong-health
echo.
echo Test Commands:
echo - curl http://localhost:8000/kong-health
echo - curl http://localhost:8001/services
echo.
echo First-time Konga Setup:
echo 1. Go to http://localhost:1337
echo 2. Create admin account
echo 3. Add Kong connection:
echo    - Name: Local Kong
echo    - Kong Admin URL: http://kong:8001
echo    - Username: (leave empty)
echo    - Password: (leave empty)
echo.
echo Opening UI Dashboard...
start kong-ui-dashboard.html
echo.
pause
