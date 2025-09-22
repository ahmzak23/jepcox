@echo off
echo ========================================
echo    GRAFANA UPGRADE SCRIPT
echo ========================================
echo.

echo Step 1: Creating backup...
if not exist "grafana_backup" mkdir grafana_backup
echo Backing up Grafana data...
docker cp docker-apisix-grafana-1:/var/lib/grafana grafana_backup/ 2>nul
docker cp docker-apisix-grafana-1:/etc/grafana grafana_backup/ 2>nul
echo Backup completed!
echo.

echo Step 2: Pulling latest Grafana image...
docker pull grafana/grafana:latest
echo.

echo Step 3: Stopping Grafana service...
docker-compose stop grafana
echo.

echo Step 4: Starting Grafana with latest version...
docker-compose up -d grafana
echo.

echo Step 5: Waiting for Grafana to start...
timeout /t 10 /nobreak >nul
echo.

echo Step 6: Checking Grafana status...
docker ps | findstr grafana
echo.

echo Step 7: Checking Grafana version...
docker exec docker-apisix-grafana-1 grafana-server --version 2>nul
echo.

echo ========================================
echo    UPGRADE COMPLETED!
echo ========================================
echo.
echo Grafana should now be running on http://localhost:3000
echo Login with admin/admin
echo.
echo If you encounter any issues, check the backup in grafana_backup folder
echo.
pause

