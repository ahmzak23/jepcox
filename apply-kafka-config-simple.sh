#!/bin/bash

################################################################################
# Apply Kafka Configuration - Simplified Version
# This script reads kafka-config.json and creates all topics
################################################################################

CONFIG_FILE="${1:-kafka-config.json}"
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

echo -e "${GREEN}🚀 Applying Kafka Configuration${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}⚠️  jq not found, using fallback method${NC}"
    USE_JQ=false
else
    USE_JQ=true
fi

# Check Kafka connectivity
echo -e "${CYAN}⏳ Checking Kafka connectivity...${NC}"
if ! docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kafka${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kafka is accessible${NC}"
echo ""

echo -e "${CYAN}Creating Kafka Topics${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

created=0
skipped=0

# Topic 1: HES Kaifa Outage Topic
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Topic: ${CYAN}hes-kaifa-outage-topic${NC}"
echo -e "${WHITE}Partitions: ${NC}3"
echo -e "${WHITE}Replication: ${NC}1"
echo -e "${WHITE}Retention: ${NC}7 days"

if docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $KAFKA_BROKER \
    --create \
    --topic hes-kaifa-outage-topic \
    --partitions 3 \
    --replication-factor 1 \
    --config retention.ms=604800000 \
    --config segment.bytes=1073741824 \
    --config cleanup.policy=delete \
    --config compression.type=producer \
    --config min.insync.replicas=1 \
    --if-not-exists 2>/dev/null; then
    echo -e "${GREEN}✅ Created successfully${NC}"
    ((created++))
else
    echo -e "${YELLOW}⚠️  Already exists (skipped)${NC}"
    ((skipped++))
fi
echo ""

# Topic 2: SCADA Outage Topic
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Topic: ${CYAN}scada-outage-topic${NC}"
echo -e "${WHITE}Partitions: ${NC}3"
echo -e "${WHITE}Replication: ${NC}1"
echo -e "${WHITE}Retention: ${NC}7 days"

if docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $KAFKA_BROKER \
    --create \
    --topic scada-outage-topic \
    --partitions 3 \
    --replication-factor 1 \
    --config retention.ms=604800000 \
    --config segment.bytes=1073741824 \
    --config cleanup.policy=delete \
    --config compression.type=producer \
    --config min.insync.replicas=1 \
    --if-not-exists 2>/dev/null; then
    echo -e "${GREEN}✅ Created successfully${NC}"
    ((created++))
else
    echo -e "${YELLOW}⚠️  Already exists (skipped)${NC}"
    ((skipped++))
fi
echo ""

# Topic 3: Call Center Upstream Topic
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Topic: ${CYAN}call_center_upstream_topic${NC}"
echo -e "${WHITE}Partitions: ${NC}3"
echo -e "${WHITE}Replication: ${NC}1"
echo -e "${WHITE}Retention: ${NC}7 days"

if docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $KAFKA_BROKER \
    --create \
    --topic call_center_upstream_topic \
    --partitions 3 \
    --replication-factor 1 \
    --config retention.ms=604800000 \
    --config segment.bytes=1073741824 \
    --config cleanup.policy=delete \
    --config compression.type=producer \
    --config min.insync.replicas=1 \
    --if-not-exists 2>/dev/null; then
    echo -e "${GREEN}✅ Created successfully${NC}"
    ((created++))
else
    echo -e "${YELLOW}⚠️  Already exists (skipped)${NC}"
    ((skipped++))
fi
echo ""

# Topic 4: ONU Events Topic
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Topic: ${CYAN}onu-events-topic${NC}"
echo -e "${WHITE}Partitions: ${NC}3"
echo -e "${WHITE}Replication: ${NC}1"
echo -e "${WHITE}Retention: ${NC}7 days"

if docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $KAFKA_BROKER \
    --create \
    --topic onu-events-topic \
    --partitions 3 \
    --replication-factor 1 \
    --config retention.ms=604800000 \
    --config segment.bytes=1073741824 \
    --config cleanup.policy=delete \
    --config compression.type=producer \
    --config min.insync.replicas=1 \
    --if-not-exists 2>/dev/null; then
    echo -e "${GREEN}✅ Created successfully${NC}"
    ((created++))
else
    echo -e "${YELLOW}⚠️  Already exists (skipped)${NC}"
    ((skipped++))
fi
echo ""

# Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Topic Creation Summary:${NC}"
echo -e "  ${GREEN}Created: $created${NC}"
echo -e "  ${YELLOW}Skipped: $skipped${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# List all topics
echo -e "${CYAN}📋 All Topics:${NC}"
docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | grep -v "^__" | grep -v "^_schemas"
echo ""

echo -e "${GREEN}✅ Configuration applied successfully!${NC}"
echo ""

# Consumer Groups Info
echo -e "${CYAN}👥 Consumer Groups (Auto-created when consumers start):${NC}"
echo "  • hes-kaifa-consumer-group"
echo "  • scada-consumer-group"
echo "  • call-center-consumer-group"
echo "  • onu-consumer-group"
echo ""

echo -e "${GREEN}🎉 Kafka setup complete!${NC}"
