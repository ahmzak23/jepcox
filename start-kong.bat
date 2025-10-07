@echo off
echo Starting Kong API Gateway services...

REM Start Kong database
echo Starting Kong database...
docker-compose up -d kong-database

REM Wait for database to be ready
echo Waiting for Kong database to be ready...
timeout /t 10 /nobreak > nul

REM Run migrations
echo Running Kong migrations...
docker-compose up kong-migrations

REM Start Kong
echo Starting Kong API Gateway...
docker-compose up -d kong

REM Wait for Kong to be ready
echo Waiting for Kong to be ready...
timeout /t 10 /nobreak > nul

REM Start Konga (Kong Admin UI)
echo Starting Konga Admin UI...
docker-compose up -d konga

echo.
echo Kong API Gateway is now running!
echo.
echo Services:
echo - Kong Proxy: http://localhost:8000
echo - Kong Admin API: http://localhost:8001
echo - Kong Manager: http://localhost:8002
echo - Konga Admin UI: http://localhost:1337
echo - PostgreSQL Database: localhost:5432
echo.
echo Test Kong health: http://localhost:8000/kong-health
echo Test APISIX proxy through Kong: http://localhost:8000/apisix-proxy
echo.
pause
