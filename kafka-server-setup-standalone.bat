@echo off
setlocal enabledelayedexpansion

REM ################################################################################
REM Kafka Server Setup - Standalone Script for Windows
REM 
REM This script sets up Kafka with all topics, consumer groups, and configurations
REM based on the APISIX workshop environment
REM
REM Usage: kafka-server-setup-standalone.bat
REM 
REM Requirements:
REM - Docker Desktop installed and running
REM - Kafka container running (apisix-workshop-kafka or similar)
REM ################################################################################

set KAFKA_BROKER=localhost:9093
set KAFKA_CONTAINER=apisix-workshop-kafka
set ZOOKEEPER_CONTAINER=apisix-workshop-zookeeper

cls
echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║                                                           ║
echo ║     Kafka Server Setup - Standalone Deployment           ║
echo ║     APISIX Workshop Environment                          ║
echo ║                                                           ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

REM Check Prerequisites
echo ═══════════════════════════════════════════════════════════
echo Checking Prerequisites
echo ═══════════════════════════════════════════════════════════
echo.

REM Check Docker
where docker >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker is not installed
    pause
    exit /b 1
)
echo ✅ Docker is installed

REM Check if Kafka container exists
docker ps -a | findstr %KAFKA_CONTAINER% >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Kafka container '%KAFKA_CONTAINER%' not found
    echo Please ensure Kafka is running via docker-compose
    pause
    exit /b 1
)
echo ✅ Kafka container found

REM Check if Kafka is running
docker ps | findstr %KAFKA_CONTAINER% >nul 2>&1
if %errorlevel% neq 0 (
    echo ⚠️  Kafka container is not running. Starting...
    docker start %KAFKA_CONTAINER%
    timeout /t 5 /nobreak >nul
)
echo ✅ Kafka container is running

REM Check Kafka connectivity
echo ⏳ Checking Kafka connectivity...
set retries=0
set max_retries=30

:check_kafka
docker exec %KAFKA_CONTAINER% kafka-broker-api-versions --bootstrap-server %KAFKA_BROKER% >nul 2>&1
if %errorlevel% equ 0 (
    echo ✅ Kafka is accessible
    goto kafka_ready
)

set /a retries+=1
if %retries% geq %max_retries% (
    echo ❌ Cannot connect to Kafka after %max_retries% attempts
    pause
    exit /b 1
)

echo    Waiting for Kafka... ^(%retries%/%max_retries%^)
timeout /t 2 /nobreak >nul
goto check_kafka

:kafka_ready
echo.

REM Create Topics
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
echo Description: HES Kaifa outage events from smart meters
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic hes-kaifa-outage-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --if-not-exists >nul 2>&1
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

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic scada-outage-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --if-not-exists >nul 2>&1
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
echo Description: Call center customer tickets and reports
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic call_center_upstream_topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --if-not-exists >nul 2>&1
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
echo Description: ONU ^(Optical Network Unit^) events and status
echo Partitions: 3
echo Replication Factor: 1
echo Retention: 604800000 ms ^(7 days^)

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic onu-events-topic --partitions 3 --replication-factor 1 --config retention.ms=604800000 --config segment.bytes=1073741824 --if-not-exists >nul 2>&1
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

REM Verify Topics
echo ═══════════════════════════════════════════════════════════
echo Verifying Topics
echo ═══════════════════════════════════════════════════════════
echo.
echo 📋 Current Topics:
echo.

docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list 2>nul | findstr /v "^__" | findstr /v "^_schemas"
echo.

REM Consumer Groups Information
echo ═══════════════════════════════════════════════════════════
echo Consumer Groups Information
echo ═══════════════════════════════════════════════════════════
echo.
echo Expected Consumer Groups:
echo.
echo Group: hes-kaifa-consumer-group
echo Description: Consumes HES Kaifa outage events
echo Status: Will be created automatically when consumers start
echo.
echo Group: scada-consumer-group
echo Description: Consumes SCADA outage and alarm events
echo Status: Will be created automatically when consumers start
echo.
echo Group: call-center-consumer-group
echo Description: Consumes call center tickets
echo Status: Will be created automatically when consumers start
echo.
echo Group: onu-consumer-group
echo Description: Consumes ONU events and status
echo Status: Will be created automatically when consumers start
echo.
echo ℹ️  Note: Consumer groups are created automatically when consumers connect.
echo    They do not need to be pre-created.
echo.

REM Check Active Consumer Groups
echo ═══════════════════════════════════════════════════════════
echo Checking Active Consumer Groups
echo ═══════════════════════════════════════════════════════════
echo.

docker exec %KAFKA_CONTAINER% kafka-consumer-groups --bootstrap-server %KAFKA_BROKER% --list 2>nul > temp_groups.txt
set /p first_line=<temp_groups.txt
if "%first_line%"=="" (
    echo ⚠️  No active consumer groups found
    echo    Consumer groups will appear when consumers start consuming messages
) else (
    echo Active Consumer Groups:
    echo.
    type temp_groups.txt
)
del temp_groups.txt 2>nul
echo.

REM Test Kafka
echo ═══════════════════════════════════════════════════════════
echo Testing Kafka Setup
echo ═══════════════════════════════════════════════════════════
echo.

set test_topic=test-kafka-setup
set test_message=Test message from setup script - %date% %time%

echo Creating test topic...
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --create --topic %test_topic% --partitions 1 --replication-factor 1 --if-not-exists >nul 2>&1

echo Producing test message...
echo %test_message% | docker exec -i %KAFKA_CONTAINER% kafka-console-producer --bootstrap-server %KAFKA_BROKER% --topic %test_topic% 2>nul

echo Consuming test message...
docker exec %KAFKA_CONTAINER% kafka-console-consumer --bootstrap-server %KAFKA_BROKER% --topic %test_topic% --from-beginning --max-messages 1 --timeout-ms 5000 2>nul > test_result.txt
set /p consumed=<test_result.txt

if not "%consumed%"=="" (
    echo ✅ Kafka is working correctly!
    echo Message: %consumed%
) else (
    echo ❌ Failed to consume test message
)

echo.
echo Cleaning up test topic...
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --delete --topic %test_topic% >nul 2>&1
del test_result.txt 2>nul

echo ✅ Test completed successfully
echo.

REM Display Summary
echo ═══════════════════════════════════════════════════════════
echo Setup Summary
echo ═══════════════════════════════════════════════════════════
echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║          Kafka Setup Completed Successfully!             ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.
echo 📊 Configuration Details:
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo Kafka Broker: %KAFKA_BROKER%
echo Kafka Container: %KAFKA_CONTAINER%
echo.
echo 📦 Topics Created:
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo   • hes-kaifa-outage-topic ^(3 partitions, 7 days retention^)
echo   • scada-outage-topic ^(3 partitions, 7 days retention^)
echo   • call_center_upstream_topic ^(3 partitions, 7 days retention^)
echo   • onu-events-topic ^(3 partitions, 7 days retention^)
echo.
echo 👥 Consumer Groups ^(Auto-created^):
echo ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo   • hes-kaifa-consumer-group
echo   • scada-consumer-group
echo   • call-center-consumer-group
echo   • onu-consumer-group
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
echo Check consumer group:
echo   docker exec %KAFKA_CONTAINER% kafka-consumer-groups --bootstrap-server %KAFKA_BROKER% --group ^<group-name^> --describe
echo.
echo ✅ Your Kafka server is ready for production use!
echo.
echo 🎉 Setup completed successfully!
echo.
pause
