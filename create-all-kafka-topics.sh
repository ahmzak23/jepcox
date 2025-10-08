#!/bin/bash

# Quick Kafka Topics Creation Script
# Creates all required topics for the APISIX workshop system

set -e

KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${GREEN}🚀 Creating All Kafka Topics${NC}"
echo -e "${GREEN}=============================${NC}"
echo ""

# Check Kafka connectivity
echo -e "${YELLOW}⏳ Checking Kafka connectivity...${NC}"
if ! docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kafka${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kafka is accessible${NC}"
echo ""

# Define topics with their configurations
# Format: "topic_name:partitions:replication_factor:retention_ms"
topics=(
    "hes-kaifa-outage-topic:3:1:604800000"
    "scada-outage-topic:3:1:604800000"
    "call_center_upstream_topic:3:1:604800000"
    "onu-events-topic:3:1:604800000"
)

echo -e "${CYAN}📦 Creating Topics...${NC}"
echo ""

created=0
skipped=0

for topic_config in "${topics[@]}"; do
    IFS=':' read -r topic partitions replication retention <<< "$topic_config"
    
    echo -e "   Creating: ${BLUE}$topic${NC}"
    echo -e "      Partitions: $partitions"
    echo -e "      Replication: $replication"
    echo -e "      Retention: $retention ms ($(($retention / 86400000)) days)"
    
    if docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --create \
        --topic $topic \
        --partitions $partitions \
        --replication-factor $replication \
        --config retention.ms=$retention \
        --if-not-exists 2>/dev/null; then
        echo -e "   ${GREEN}✅ Created successfully${NC}"
        ((created++))
    else
        echo -e "   ${YELLOW}⚠️  Already exists or creation failed${NC}"
        ((skipped++))
    fi
    echo ""
done

echo -e "${GREEN}════════════════════════════════${NC}"
echo -e "${GREEN}✅ Topic Creation Summary${NC}"
echo -e "${GREEN}════════════════════════════════${NC}"
echo -e "Topics created: ${GREEN}$created${NC}"
echo -e "Topics skipped: ${YELLOW}$skipped${NC}"
echo ""

# List all topics
echo -e "${CYAN}📋 Current Topics:${NC}"
docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $KAFKA_BROKER \
    --list | grep -v "^__" || true

echo ""
echo -e "${GREEN}✅ All topics are ready!${NC}"
