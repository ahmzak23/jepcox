#!/bin/bash
# Setup Kafka Topics for OMS System

echo "🚀 Setting up Kafka topics for OMS system..."

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
sleep 10

# Create topics for OMS system
echo "📊 Creating Kafka topics..."

# Outage Events Topic
docker exec oms-kafka kafka-topics --create \
  --topic outage-events \
  --bootstrap-server localhost:29092 \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

# Meter Readings Topic
docker exec oms-kafka kafka-topics --create \
  --topic meter-readings \
  --bootstrap-server localhost:29092 \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

# System Health Topic
docker exec oms-kafka kafka-topics --create \
  --topic system-health \
  --bootstrap-server localhost:29092 \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

# Network Events Topic
docker exec oms-kafka kafka-topics --create \
  --topic network-events \
  --bootstrap-server localhost:29092 \
  --partitions 3 \
  --replication-factor 1 \
  --if-not-exists

echo "✅ Kafka topics created successfully!"

# List all topics
echo "📋 Available topics:"
docker exec oms-kafka kafka-topics --list --bootstrap-server localhost:29092

echo ""
echo "🎯 Next steps:"
echo "1. Check Kafka UI: http://localhost:8080"
echo "2. Test web2 Kafka integration: http://localhost:9080/hes-mock-generator"
echo "3. Monitor Kafka topics: http://localhost:8080/topics"
