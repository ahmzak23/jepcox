# Kafka Configuration File - Usage Guide

This guide explains how to use the `kafka-config.json` file to deploy Kafka configuration to your server.

## 📁 Files Included

1. **`kafka-config.json`** - Complete Kafka configuration (topics, partitions, retention, consumer groups)
2. **`apply-kafka-config.sh`** - Linux/Mac script to apply configuration
3. **`apply-kafka-config.bat`** - Windows script to apply configuration

## 📋 Configuration File Contents

The `kafka-config.json` file contains:

### ✅ Metadata
- Source environment information
- Export date and Kafka version
- Configuration description

### ✅ Broker Configuration
- Bootstrap servers
- Zookeeper connection
- Default settings

### ✅ Topics (4 total)
Each topic includes:
- **Name**: Topic identifier
- **Partitions**: Number of partitions (3)
- **Replication Factor**: Replication level (1)
- **Retention**: Message retention time (7 days)
- **Segment Size**: Log segment size (1 GB)
- **Cleanup Policy**: How old messages are handled
- **Compression**: Message compression type
- **Description**: Purpose and usage

**Topics:**
1. `hes-kaifa-outage-topic` - HES Kaifa smart meter events
2. `scada-outage-topic` - SCADA system alarms
3. `call_center_upstream_topic` - Call center tickets
4. `onu-events-topic` - ONU network events

### ✅ Consumer Groups (4 total)
Each consumer group includes:
- **Name**: Group identifier
- **Topics**: Topics consumed
- **Description**: Purpose
- **Auto Offset Reset**: Starting point for new consumers
- **Consumer Service**: Associated service name

**Consumer Groups:**
1. `hes-kaifa-consumer-group`
2. `scada-consumer-group`
3. `call-center-consumer-group`
4. `onu-consumer-group`

### ✅ Retention Policies
- Default retention: 7 days (604800000 ms)
- Segment size: 1 GB (1073741824 bytes)
- Cleanup policy: delete

### ✅ Performance Settings
- Network threads, IO threads
- Socket buffer sizes
- Replica settings

## 🚀 How to Use

### Step 1: Transfer Files to Server

Copy these files to your server:
```bash
# Using SCP
scp kafka-config.json apply-kafka-config.sh user@server:/path/to/destination/

# Or using rsync
rsync -avz kafka-config.json apply-kafka-config.sh user@server:/path/to/destination/
```

### Step 2: Run the Script on Server

#### Linux/Mac:
```bash
# Make script executable
chmod +x apply-kafka-config.sh

# Run the script
./apply-kafka-config.sh

# Or specify a custom config file
./apply-kafka-config.sh my-custom-config.json
```

#### Windows:
```batch
# Run the script
apply-kafka-config.bat

# Or specify a custom config file
apply-kafka-config.bat my-custom-config.json
```

### Step 3: Verify Configuration

The script automatically verifies the configuration, but you can also manually check:

```bash
# List all topics
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --list

# Describe a specific topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic hes-kaifa-outage-topic

# List consumer groups (after consumers start)
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list
```

## 📊 What the Script Does

1. ✅ **Validates** configuration file exists
2. ✅ **Checks** Kafka connectivity
3. ✅ **Displays** configuration metadata
4. ✅ **Creates** all topics with exact settings
5. ✅ **Documents** consumer groups
6. ✅ **Verifies** topic creation
7. ✅ **Provides** detailed summary

## 🎯 Expected Output

The script provides colored output showing:

```
╔═══════════════════════════════════════════════════════════╗
║     Apply Kafka Configuration from JSON                  ║
║     Automated Configuration Deployment                   ║
╚═══════════════════════════════════════════════════════════╝

📋 Configuration Metadata
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Source: APISIX Workshop Local Environment
Export Date: 2025-10-08
Kafka Version: 7.4.0

⏳ Checking Kafka connectivity...
✅ Kafka is accessible

Creating Kafka Topics
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Topic: hes-kaifa-outage-topic
Description: HES Kaifa smart meter outage events and alarms
Partitions: 3
Replication Factor: 1
Retention: 604800000 ms (7 days)
✅ Created successfully

[... more topics ...]

Topic Creation Summary:
  Created: 4
  Skipped: 0
  Failed: 0

╔═══════════════════════════════════════════════════════════╗
║     Configuration Applied Successfully!                  ║
╚═══════════════════════════════════════════════════════════╝
```

## 🔧 Customizing the Configuration

### Modify Retention Period

Edit `kafka-config.json`:
```json
{
  "topics": [
    {
      "name": "hes-kaifa-outage-topic",
      "configs": {
        "retention.ms": "1209600000"  // Change to 14 days
      }
    }
  ]
}
```

### Modify Partition Count

```json
{
  "topics": [
    {
      "name": "hes-kaifa-outage-topic",
      "partitions": 6  // Change from 3 to 6
    }
  ]
}
```

### Add New Topic

```json
{
  "topics": [
    {
      "name": "new-topic-name",
      "partitions": 3,
      "replication_factor": 1,
      "configs": {
        "retention.ms": "604800000",
        "segment.bytes": "1073741824"
      },
      "description": "Description of new topic"
    }
  ]
}
```

## ⚠️ Important Notes

### Consumer Groups
- Consumer groups are **automatically created** when consumers connect
- You don't need to manually create them
- The configuration file documents them for reference

### Replication Factor
- Current setup uses replication factor of 1 (suitable for development/testing)
- For production, consider increasing to 2 or 3 for fault tolerance

### Retention Period
- All topics retain messages for 7 days by default
- Adjust based on your storage capacity and requirements

### Segment Size
- 1 GB segment size is suitable for most use cases
- Smaller segments = more files, faster compaction
- Larger segments = fewer files, slower compaction

## 🔍 Troubleshooting

### Script Fails with "jq not found" (Linux/Mac only)

Install jq:
```bash
# Ubuntu/Debian
sudo apt-get install jq

# Mac
brew install jq

# CentOS/RHEL
sudo yum install jq
```

### Cannot Connect to Kafka

Check if Kafka is running:
```bash
docker ps | grep kafka
docker logs apisix-workshop-kafka --tail 20
```

### Topic Already Exists

The script safely skips existing topics. If you need to modify an existing topic:
```bash
# Delete topic (be careful!)
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --delete --topic topic-name

# Then run the script again
./apply-kafka-config.sh
```

### Configuration Not Applied

Verify the JSON file is valid:
```bash
# Linux/Mac
cat kafka-config.json | jq '.'

# Windows
type kafka-config.json
```

## 📚 Additional Commands

### Export Current Configuration

To export your current Kafka configuration:
```bash
# List all topics with details
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe > current-topics.txt

# List all consumer groups
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list > current-groups.txt
```

### Compare Configurations

```bash
# Show differences between local and server
diff kafka-config.json server-kafka-config.json
```

## ✅ Success Criteria

Your configuration is successfully applied when:

- ✅ All 4 topics are created
- ✅ Each topic has 3 partitions
- ✅ Replication factor is 1
- ✅ Retention is set to 7 days
- ✅ Segment size is 1 GB
- ✅ No errors in script output
- ✅ Topics appear in Kafka listing

## 🎉 Next Steps

After applying the configuration:

1. **Start your consumers** - Consumer groups will be created automatically
2. **Test message flow** - Send test messages to verify
3. **Monitor** - Check consumer lag and topic health
4. **Backup** - Keep the configuration file for future reference

---

**Configuration Version**: 1.0.0  
**Last Updated**: October 2025  
**Kafka Version**: 7.4.0
