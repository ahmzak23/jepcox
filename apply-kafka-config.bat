@echo off
setlocal enabledelayedexpansion

REM ################################################################################
REM Apply Kafka Configuration from JSON File - Windows Version
REM 
REM This script reads kafka-config.json and applies all configurations to Kafka
REM 
REM Usage: apply-kafka-config.bat [config-file]
REM Default config file: kafka-config.json
REM ################################################################################

set CONFIG_FILE=%1
if "%CONFIG_FILE%"=="" set CONFIG_FILE=kafka-config.json
set KAFKA_BROKER=localhost:9093
set KAFKA_CONTAINER=apisix-workshop-kafka

cls
echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║                                                           ║
echo ║     Apply Kafka Configuration from JSON                  ║
echo ║     Automated Configuration Deployment                   ║
echo ║                                                           ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Check if config file exists
if not exist "%CONFIG_FILE%" (
    echo ❌ Configuration file not found: %CONFIG_FILE%
    pause
    exit /b 1
)

echo 📋 Configuration File: %CONFIG_FILE%
echo.

REM Check Kafka connectivity
echo ⏳ Checking Kafka connectivity...
docker exec %KAFKA_CONTAINER% kafka-broker-api-versions --bootstrap-server %KAFKA_BROKER% >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Cannot connect to Kafka
    pause
    exit /b 1
)
echo ✅ Kafka is accessible
echo.

REM Create topics
echo ═══════════════════════════════════════════════════════════
echo Creating Kafka Topics
echo ═══════════════════════════════════════════════════════════
echo.

set created=0
set skipped=0
set failed=0

REM Topic 1: HES Kaifa Outage Topic
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Topic: hes-kaifa-outage-topic
echo Description: HES Kaifa smart meter outage events and alarms
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)
echo Segment Size: 1073741824 bytes ^(1 GB^)
echo Cleanup Policy: delete
echo Compression: producer
echo Min ISR: 1

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic hes-kaifa-outage-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --config cleanup.policy=delete --config compression.type=producer --config min.insync.replicas=1 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Created successfully
    set /a created+=1
) else (
    docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /x "hes-kaifa-outage-topic" >nul 2>&1
    if %errorlevel% equ 0 (
        echo ⚠️  Already exists ^(skipped^)
        set /a skipped+=1
    ) else (
        echo ❌ Failed to create
        set /a failed+=1
    )
)
echo.

REM Topic 2: SCADA Outage Topic
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Topic: scada-outage-topic
echo Description: SCADA system outage and alarm events
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)
echo Segment Size: 1073741824 bytes ^(1 GB^)
echo Cleanup Policy: delete
echo Compression: producer
echo Min ISR: 1

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic scada-outage-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --config cleanup.policy=delete --config compression.type=producer --config min.insync.replicas=1 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Created successfully
    set /a created+=1
) else (
    docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /x "scada-outage-topic" >nul 2>&1
    if %errorlevel% equ 0 (
        echo ⚠️  Already exists ^(skipped^)
        set /a skipped+=1
    ) else (
        echo ❌ Failed to create
        set /a failed+=1
    )
)
echo.

REM Topic 3: Call Center Upstream Topic
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Topic: call_center_upstream_topic
echo Description: Call center customer tickets and support requests
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)
echo Segment Size: 1073741824 bytes ^(1 GB^)
echo Cleanup Policy: delete
echo Compression: producer
echo Min ISR: 1

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic call_center_upstream_topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --config cleanup.policy=delete --config compression.type=producer --config min.insync.replicas=1 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Created successfully
    set /a created+=1
) else (
    docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /x "call_center_upstream_topic" >nul 2>&1
    if %errorlevel% equ 0 (
        echo ⚠️  Already exists ^(skipped^)
        set /a skipped+=1
    ) else (
        echo ❌ Failed to create
        set /a failed+=1
    )
)
echo.

REM Topic 4: ONU Events Topic
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Topic: onu-events-topic
echo Description: ONU ^(Optical Network Unit^) events and status updates
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)
echo Segment Size: 1073741824 bytes ^(1 GB^)
echo Cleanup Policy: delete
echo Compression: producer
echo Min ISR: 1

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic onu-events-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --config cleanup.policy=delete --config compression.type=producer --config min.insync.replicas=1 --if-not-exists >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Created successfully
    set /a created+=1
) else (
    docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /x "onu-events-topic" >nul 2>&1
    if %errorlevel% equ 0 (
        echo ⚠️  Already exists ^(skipped^)
        set /a skipped+=1
    ) else (
        echo ❌ Failed to create
        set /a failed+=1
    )
)
echo.

echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Topic Creation Summary:
echo   Created: %created%
echo   Skipped: %skipped%
echo   Failed: %failed%
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo.

REM Consumer Groups Information
echo ═══════════════════════════════════════════════════════════
echo Consumer Groups Configuration
echo ═══════════════════════════════════════════════════════════
echo.

echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Group: hes-kaifa-consumer-group
echo Description: Consumes HES Kaifa outage events for processing and storage
echo Topics: hes-kaifa-outage-topic
echo Auto Offset Reset: earliest
echo Status: Will be created when consumers connect
echo.

echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Group: scada-consumer-group
echo Description: Consumes SCADA outage and alarm events
echo Topics: scada-outage-topic
echo Auto Offset Reset: earliest
echo Status: Will be created when consumers connect
echo.

echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Group: call-center-consumer-group
echo Description: Consumes call center tickets and customer reports
echo Topics: call_center_upstream_topic
echo Auto Offset Reset: earliest
echo Status: Will be created when consumers connect
echo.

echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Group: onu-consumer-group
echo Description: Consumes ONU events and network status updates
echo Topics: onu-events-topic
echo Auto Offset Reset: earliest
echo Status: Will be created when consumers connect
echo.

echo ℹ️  Note: Consumer groups are created automatically when consumers start.
echo.

REM Verify topics
echo ═══════════════════════════════════════════════════════════
echo Verifying Topics
echo ═══════════════════════════════════════════════════════════
echo.
echo 📋 Current Topics:
echo.

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /v "^__" | findstr /v "^_schemas"
echo.

REM Configuration Summary
echo ═══════════════════════════════════════════════════════════
echo Configuration Summary
echo ═══════════════════════════════════════════════════════════
echo.

echo ╔═══════════════════════════════════════════════════════════╗
echo ║     Configuration Applied Successfully!                  ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

echo 📊 Applied Configuration:
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Configuration File: %CONFIG_FILE%
echo Kafka Broker: %KAFKA_BROKER%
echo Topics Created/Verified: 4
echo Consumer Groups Configured: 4
echo.

echo 📦 Topics:
echo   • hes-kaifa-outage-topic ^(3 partitions, 1 replication^)
echo   • scada-outage-topic ^(3 partitions, 1 replication^)
echo   • call_center_upstream_topic ^(3 partitions, 1 replication^)
echo   • onu-events-topic ^(3 partitions, 1 replication^)
echo.

echo 👥 Consumer Groups:
echo   • hes-kaifa-consumer-group
echo   • scada-consumer-group
echo   • call-center-consumer-group
echo   • onu-consumer-group
echo.

echo ⚙️  Retention Policy:
echo   • Default Retention: 7 days
echo   • Segment Size: 1 GB
echo   • Cleanup Policy: delete
echo.

echo 🔧 Useful Commands:
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo List topics:
echo   docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list
echo.
echo Describe topic:
echo   docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --describe --topic ^<topic-name^>
echo.
echo List consumer groups:
echo   docker exec %KAFKA_CONTAINER% kafka-consumer-groups --bootstrap-server %KAFKA_BROKER% --list
echo.

echo ✅ Kafka configuration has been applied successfully!
echo 🎉 Your Kafka cluster is ready for production use!
echo.
pause
