@echo off
setlocal enabledelayedexpansion

REM Kafka Migration Script for Windows
REM This script exports and imports Kafka topics, consumer groups, and configurations

set KAFKA_BROKER=localhost:9093
set KAFKA_CONTAINER=apisix-workshop-kafka
set EXPORT_DIR=kafka_export
set TIMESTAMP=%date:~-4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

echo 🚀 Kafka Migration Tool
echo ========================
echo.

REM Check if Kafka is running
echo ⏳ Checking Kafka connectivity...
docker exec %KAFKA_CONTAINER% kafka-broker-api-versions --bootstrap-server %KAFKA_BROKER% >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Cannot connect to Kafka
    exit /b 1
)
echo ✅ Kafka is accessible
echo.

REM Create export directory
if not exist %EXPORT_DIR% mkdir %EXPORT_DIR%
if not exist %EXPORT_DIR%\topics mkdir %EXPORT_DIR%\topics
if not exist %EXPORT_DIR%\consumer_groups mkdir %EXPORT_DIR%\consumer_groups
if not exist %EXPORT_DIR%\broker mkdir %EXPORT_DIR%\broker

REM Export Topics
echo 📦 Exporting Kafka Topics...
docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --list > %EXPORT_DIR%\topics\topic_list.txt 2>nul

REM Count topics (excluding internal topics)
set TOPIC_COUNT=0
for /f "tokens=*" %%a in (%EXPORT_DIR%\topics\topic_list.txt) do (
    set "line=%%a"
    if not "!line:~0,2!"=="__" (
        set /a TOPIC_COUNT+=1
        echo    Exporting topic: %%a
        
        REM Export topic configuration
        docker exec %KAFKA_CONTAINER% kafka-topics --bootstrap-server %KAFKA_BROKER% --describe --topic %%a > %EXPORT_DIR%\topics\%%a_config.txt 2>nul
        
        REM Export topic settings
        docker exec %KAFKA_CONTAINER% kafka-configs --bootstrap-server %KAFKA_BROKER% --entity-type topics --entity-name %%a --describe > %EXPORT_DIR%\topics\%%a_settings.txt 2>nul
    )
)
echo ✅ Exported %TOPIC_COUNT% topics to: %EXPORT_DIR%\topics\
echo.

REM Export Consumer Groups
echo 👥 Exporting Consumer Groups...
docker exec %KAFKA_CONTAINER% kafka-consumer-groups --bootstrap-server %KAFKA_BROKER% --list > %EXPORT_DIR%\consumer_groups\group_list.txt 2>nul

set GROUP_COUNT=0
for /f "tokens=*" %%a in (%EXPORT_DIR%\consumer_groups\group_list.txt) do (
    set /a GROUP_COUNT+=1
    echo    Exporting group: %%a
    
    REM Export group details
    docker exec %KAFKA_CONTAINER% kafka-consumer-groups --bootstrap-server %KAFKA_BROKER% --group %%a --describe > %EXPORT_DIR%\consumer_groups\%%a_details.txt 2>nul
    
    REM Export group offsets
    docker exec %KAFKA_CONTAINER% kafka-consumer-groups --bootstrap-server %KAFKA_BROKER% --group %%a --describe --offsets > %EXPORT_DIR%\consumer_groups\%%a_offsets.txt 2>nul
)
echo ✅ Exported %GROUP_COUNT% consumer groups to: %EXPORT_DIR%\consumer_groups\
echo.

REM Export Broker Configuration
echo ⚙️  Exporting Broker Configuration...
docker exec %KAFKA_CONTAINER% kafka-broker-api-versions --bootstrap-server %KAFKA_BROKER% > %EXPORT_DIR%\broker\broker_info.txt 2>nul
echo ✅ Broker configuration exported to: %EXPORT_DIR%\broker\
echo.

REM Create import script
echo 📝 Creating Import Script...
(
echo @echo off
echo setlocal enabledelayedexpansion
echo.
echo set KAFKA_BROKER=localhost:9093
echo set KAFKA_CONTAINER=apisix-workshop-kafka
echo set IMPORT_DIR=.
echo.
echo echo 🚀 Kafka Import Tool
echo echo ====================
echo echo.
echo.
echo echo 📦 Importing Topics...
echo if exist "%%IMPORT_DIR%%\topics\topic_list.txt" ^(
echo     for /f "tokens=*" %%%%a in ^(%%IMPORT_DIR%%\topics\topic_list.txt^) do ^(
echo         set "line=%%%%a"
echo         if not "!line:~0,2!"=="__" ^(
echo             echo    Creating topic: %%%%a
echo.
echo             REM Extract partition count from config
echo             set PARTITIONS=3
echo             set REPLICATION=1
echo.
echo             if exist "%%IMPORT_DIR%%\topics\%%%%a_config.txt" ^(
echo                 for /f "tokens=2" %%%%p in ^('findstr "PartitionCount:" "%%IMPORT_DIR%%\topics\%%%%a_config.txt"'^) do set PARTITIONS=%%%%p
echo                 for /f "tokens=2" %%%%r in ^('findstr "ReplicationFactor:" "%%IMPORT_DIR%%\topics\%%%%a_config.txt"'^) do set REPLICATION=%%%%r
echo             ^)
echo.
echo             docker exec %%KAFKA_CONTAINER%% kafka-topics --bootstrap-server %%KAFKA_BROKER%% --create --topic %%%%a --partitions !PARTITIONS! --replication-factor !REPLICATION! --if-not-exists 2^>nul
echo         ^)
echo     ^)
echo     echo ✅ Topics imported
echo ^)
echo.
echo echo.
echo echo ✅ Import completed!
echo echo Note: Consumer group offsets cannot be automatically restored.
echo echo Consumer groups will be recreated when consumers start.
echo pause
) > %EXPORT_DIR%\import_kafka.bat

echo ✅ Import script created: %EXPORT_DIR%\import_kafka.bat
echo.

REM Create backup info file
echo 📝 Creating backup info file...
(
echo Kafka Backup Information
echo ========================
echo Backup Date: %date% %time%
echo Kafka Broker: %KAFKA_BROKER%
echo Topics Exported: %TOPIC_COUNT%
echo Consumer Groups Exported: %GROUP_COUNT%
echo.
echo Export Contents:
echo - topics/topic_list.txt - List of all topics
echo - topics/*_config.txt - Topic configurations
echo - topics/*_settings.txt - Topic settings
echo - consumer_groups/group_list.txt - List of all consumer groups
echo - consumer_groups/*_details.txt - Consumer group details
echo - consumer_groups/*_offsets.txt - Consumer group offsets
echo - broker/broker_info.txt - Broker information
echo - import_kafka.bat - Import script for Windows
echo.
echo To import on another server:
echo 1. Copy the entire kafka_export folder to the target server
echo 2. Navigate to the kafka_export folder
echo 3. Run: import_kafka.bat
) > %EXPORT_DIR%\README.txt

echo ✅ Backup info created: %EXPORT_DIR%\README.txt
echo.

REM Display summary
echo ════════════════════════════════════════
echo ✅ Kafka Export Completed Successfully!
echo ════════════════════════════════════════
echo.
echo 📁 Export Directory: %EXPORT_DIR%
echo 📊 Topics Exported: %TOPIC_COUNT%
echo 👥 Consumer Groups Exported: %GROUP_COUNT%
echo.
echo 📋 Export Contents:
echo    - Topics configuration and settings
echo    - Consumer groups details and offsets
echo    - Broker information
echo    - Import script ^(import_kafka.bat^)
echo.
echo 🚀 To import on another server:
echo    1. Copy the %EXPORT_DIR% folder to target server
echo    2. Navigate to %EXPORT_DIR%
echo    3. Run: import_kafka.bat
echo.
pause
