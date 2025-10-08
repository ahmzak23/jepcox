@echo off
setlocal enabledelayedexpansion

REM Quick Kafka Topics Creation Script for Windows
REM Creates all required topics for the APISIX workshop system

set KAFKA_BROKER=localhost:9093
set KAFKA_CONTAINER=apisix-workshop-kafka

echo 🚀 Creating All Kafka Topics
echo =============================
echo.

REM Check Kafka connectivity
echo ⏳ Checking Kafka connectivity...
docker exec %KAFKA_CONTAINER% kafka-broker-api-versions --bootstrap-server %KAFKA_BROKER% >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Cannot connect to Kafka
    exit /b 1
)
echo ✅ Kafka is accessible
echo.

echo 📦 Creating Topics...
echo.

set created=0
set skipped=0

REM 1. HES-Kaifa Outage Topic
echo    Creating: hes-kaifa-outage-topic
echo       Partitions: 3
echo       Replication: 1
echo       Retention: 604800000 ms ^(7 days^)
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic hes-kaifa-outage-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Created successfully
    set /a created+=1
) else (
    echo    ⚠️  Already exists or creation failed
    set /a skipped+=1
)
echo.

REM 2. SCADA Outage Topic
echo    Creating: scada-outage-topic
echo       Partitions: 3
echo       Replication: 1
echo       Retention: 604800000 ms ^(7 days^)
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic scada-outage-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Created successfully
    set /a created+=1
) else (
    echo    ⚠️  Already exists or creation failed
    set /a skipped+=1
)
echo.

REM 3. Call Center Upstream Topic
echo    Creating: call_center_upstream_topic
echo       Partitions: 3
echo       Replication: 1
echo       Retention: 604800000 ms ^(7 days^)
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic call_center_upstream_topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Created successfully
    set /a created+=1
) else (
    echo    ⚠️  Already exists or creation failed
    set /a skipped+=1
)
echo.

REM 4. ONU Events Topic
echo    Creating: onu-events-topic
echo       Partitions: 3
echo       Replication: 1
echo       Retention: 604800000 ms ^(7 days^)
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic onu-events-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo    ✅ Created successfully
    set /a created+=1
) else (
    echo    ⚠️  Already exists or creation failed
    set /a skipped+=1
)
echo.

echo ════════════════════════════════
echo ✅ Topic Creation Summary
echo ════════════════════════════════
echo Topics created: %created%
echo Topics skipped: %skipped%
echo.

REM List all topics
echo 📋 Current Topics:
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /v "^__"
echo.

echo ✅ All topics are ready!
echo.
pause
