@echo off
echo Creating Grafana backup before upgrade...
echo.

REM Create backup directory
if not exist "grafana_backup" mkdir grafana_backup

REM Backup Grafana data
echo Backing up Grafana data...
docker cp docker-apisix-grafana-1:/var/lib/grafana grafana_backup/
docker cp docker-apisix-grafana-1:/etc/grafana grafana_backup/

echo.
echo Backup completed! Check grafana_backup folder.
echo.
pause

