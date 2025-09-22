@echo off
echo 🗑️  Resetting Outage Events Topic
echo ========================================

echo 🗑️  Step 1: Deleting outage-events topic...
docker exec oms-kafka kafka-topics --delete --topic outage-events --bootstrap-server localhost:29092

echo.
echo ⏳ Waiting 3 seconds...
timeout /t 3 /nobreak > nul

echo 🔄 Step 2: Recreating outage-events topic...
docker exec oms-kafka kafka-topics --create --topic outage-events --bootstrap-server localhost:29092 --partitions 1 --replication-factor 1

echo.
echo 🔍 Step 3: Verifying topic is empty...
docker exec oms-kafka kafka-console-consumer --topic outage-events --bootstrap-server localhost:29092 --from-beginning --timeout-ms 3000

echo.
echo 🎉 Outage events topic has been reset!
echo 💡 All previous messages have been removed
pause
