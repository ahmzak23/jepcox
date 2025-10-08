# Kafka Migration Guide

Complete guide for migrating Kafka topics, consumer groups, and configurations to a new server.

## 🚀 Quick Start

### Automated Migration Scripts

#### Linux/Mac:
```bash
chmod +x setup-kafka-migration.sh
./setup-kafka-migration.sh export
```

#### Windows:
```batch
setup-kafka-migration.bat
```

## 📋 What Gets Migrated

### ✅ Topics
- Topic names
- Partition counts
- Replication factors
- Topic configurations
- Retention policies
- Compression settings

### ✅ Consumer Groups
- Group names
- Group details
- Current offsets
- Lag information

### ✅ Broker Configuration
- Broker information
- Cluster metadata
- API versions

## 🔧 Manual Migration Commands

### 1. Export Topics

#### List All Topics
```bash
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --list
```

#### Export Topic Configuration
```bash
# For each topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic <topic-name>
```

#### Export Topic Settings
```bash
docker exec apisix-workshop-kafka kafka-configs \
  --bootstrap-server localhost:9093 \
  --entity-type topics \
  --entity-name <topic-name> \
  --describe
```

### 2. Export Consumer Groups

#### List All Consumer Groups
```bash
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list
```

#### Export Consumer Group Details
```bash
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --describe
```

#### Export Consumer Group Offsets
```bash
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --describe --offsets
```

### 3. Import Topics to New Server

#### Create Topic
```bash
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create \
  --topic <topic-name> \
  --partitions <partition-count> \
  --replication-factor <replication-factor>
```

#### Create Topic with Configuration
```bash
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create \
  --topic <topic-name> \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=604800000 \
  --config compression.type=snappy
```

## 📊 Current Kafka Topics in Your System

Based on your APISIX configuration, these topics should exist:

### 1. HES-Kaifa Outage Topic
```bash
# Export
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic hes-kaifa-outage-topic

# Import
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic hes-kaifa-outage-topic \
  --partitions 3 --replication-factor 1 \
  --if-not-exists
```

### 2. SCADA Outage Topic
```bash
# Export
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic scada-outage-topic

# Import
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic scada-outage-topic \
  --partitions 3 --replication-factor 1 \
  --if-not-exists
```

### 3. Call Center Upstream Topic
```bash
# Export
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic call_center_upstream_topic

# Import
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic call_center_upstream_topic \
  --partitions 3 --replication-factor 1 \
  --if-not-exists
```

### 4. ONU Events Topic
```bash
# Export
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic onu-events-topic

# Import
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic onu-events-topic \
  --partitions 3 --replication-factor 1 \
  --if-not-exists
```

## 👥 Consumer Groups Migration

### Export Consumer Groups
```bash
# HES-Kaifa Consumer Group
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group hes-kaifa-consumer-group \
  --describe --offsets

# SCADA Consumer Group
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group scada-consumer-group \
  --describe --offsets

# Call Center Consumer Group
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group call-center-consumer-group \
  --describe --offsets

# ONU Consumer Group
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group onu-consumer-group \
  --describe --offsets
```

### Reset Consumer Group Offsets (if needed)
```bash
# Reset to earliest
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --reset-offsets --to-earliest \
  --topic <topic-name> \
  --execute

# Reset to latest
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --reset-offsets --to-latest \
  --topic <topic-name> \
  --execute

# Reset to specific offset
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --reset-offsets --to-offset <offset> \
  --topic <topic-name>:<partition> \
  --execute
```

## 🔄 Complete Migration Workflow

### Step 1: Export from Source Server
```bash
# Run export script
./setup-kafka-migration.sh export

# This creates:
# - kafka_export/ directory with all configurations
# - kafka_backup_YYYYMMDD_HHMMSS.tar.gz archive
```

### Step 2: Transfer to Target Server
```bash
# Copy the backup archive to target server
scp kafka_backup_*.tar.gz user@target-server:/path/to/destination/

# Or use rsync
rsync -avz kafka_export/ user@target-server:/path/to/destination/kafka_export/
```

### Step 3: Import on Target Server
```bash
# Extract the archive
tar -xzf kafka_backup_*.tar.gz

# Navigate to export directory
cd kafka_export

# Run import script
./import_kafka.sh
```

### Step 4: Verify Migration
```bash
# List topics on new server
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --list

# Verify topic configurations
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic <topic-name>

# Check consumer groups
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list
```

## 📦 All-in-One Migration Script

### Create All Topics at Once
```bash
#!/bin/bash
KAFKA_BROKER="localhost:9093"
KAFKA_CONTAINER="apisix-workshop-kafka"

# Array of topics with their configurations
declare -A topics=(
    ["hes-kaifa-outage-topic"]="3:1"
    ["scada-outage-topic"]="3:1"
    ["call_center_upstream_topic"]="3:1"
    ["onu-events-topic"]="3:1"
)

echo "Creating Kafka topics..."
for topic in "${!topics[@]}"; do
    IFS=':' read -r partitions replication <<< "${topics[$topic]}"
    echo "Creating topic: $topic (partitions=$partitions, replication=$replication)"
    
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --create --topic $topic \
        --partitions $partitions \
        --replication-factor $replication \
        --if-not-exists
done

echo "✅ All topics created!"
```

## 🔍 Verification Commands

### Check Topic Health
```bash
# List all topics
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --list

# Check topic details
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe

# Check under-replicated partitions
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --under-replicated-partitions
```

### Check Consumer Group Health
```bash
# List all consumer groups
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list

# Check consumer group lag
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --describe

# Check all groups state
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --all-groups --describe --state
```

### Test Message Production/Consumption
```bash
# Produce test message
echo "test message" | docker exec -i apisix-workshop-kafka \
  kafka-console-producer \
  --bootstrap-server localhost:9093 \
  --topic test-topic

# Consume test message
docker exec apisix-workshop-kafka \
  kafka-console-consumer \
  --bootstrap-server localhost:9093 \
  --topic test-topic \
  --from-beginning \
  --max-messages 1
```

## 🚨 Troubleshooting

### Topics Not Created
```bash
# Check Kafka logs
docker logs apisix-workshop-kafka --tail 50

# Verify Kafka is running
docker ps | grep kafka

# Check Zookeeper connection
docker exec apisix-workshop-kafka \
  kafka-broker-api-versions --bootstrap-server localhost:9093
```

### Consumer Groups Not Working
```bash
# Delete and recreate consumer group
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --delete

# Consumer groups will be recreated automatically when consumers start
```

### Partition Rebalancing Issues
```bash
# Trigger rebalance
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group <group-name> \
  --reset-offsets --to-current \
  --all-topics \
  --execute
```

## 📝 Best Practices

1. **Always backup before migration**
   - Use the automated export script
   - Keep multiple backup copies
   - Test restore on non-production first

2. **Verify topic configurations**
   - Check partition counts
   - Verify replication factors
   - Confirm retention policies

3. **Handle consumer offsets carefully**
   - Consumer groups recreate automatically
   - Consider resetting offsets if needed
   - Monitor lag after migration

4. **Test thoroughly**
   - Produce test messages
   - Verify consumer consumption
   - Check all consumer groups

5. **Monitor after migration**
   - Watch for under-replicated partitions
   - Monitor consumer lag
   - Check broker health

## 🎯 Migration Checklist

- [ ] Export all topics from source
- [ ] Export all consumer groups
- [ ] Export broker configuration
- [ ] Create backup archive
- [ ] Transfer to target server
- [ ] Import topics on target
- [ ] Verify topic creation
- [ ] Start consumers
- [ ] Verify consumer groups
- [ ] Test message flow
- [ ] Monitor for 24 hours
- [ ] Document any issues

## 📊 Expected Results

After successful migration, you should have:
- **4 Kafka topics** created
- **4 Consumer groups** (recreated by consumers)
- **Same partition counts** as source
- **All configurations** preserved
- **Working message flow** end-to-end
