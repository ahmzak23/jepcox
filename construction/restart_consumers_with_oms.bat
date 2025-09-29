@echo off
echo Restarting all consumers with OMS API integration...

REM Stop all consumers
docker compose stop hes-consumer scada-consumer call-center-consumer onu-consumer

REM Start them again with the new OMS_API_URL environment variable
docker compose up -d hes-consumer scada-consumer call-center-consumer onu-consumer

REM Wait a moment for services to start
timeout /t 10 /nobreak > nul

REM Check status
docker compose ps hes-consumer scada-consumer call-center-consumer onu-consumer

echo.
echo All consumers restarted with OMS API integration!
echo.
echo Now when you generate new events, they should:
echo 1. Be processed by the consumer
echo 2. Stored in the local database
echo 3. Sent to OMS API for correlation
echo 4. Appear in the dashboard
echo.
echo URLs:
echo - Dashboard: http://localhost:9200
echo - OMS API: http://localhost:9100
echo.
pause

