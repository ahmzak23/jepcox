#!/bin/bash

################################################################################
# Check and Create Consumer Groups on Server
# This script helps verify consumer groups and provides commands to create them
################################################################################

KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔍 Checking Kafka Consumer Groups${NC}"
echo -e "${GREEN}===================================${NC}"
echo ""

# Check Kafka connectivity
echo -e "${CYAN}⏳ Checking Kafka connectivity...${NC}"
if ! docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kafka${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kafka is accessible${NC}"
echo ""

# List all topics
echo -e "${CYAN}📋 Available Topics:${NC}"
docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | grep -v "^__" | grep -v "^_schemas"
echo ""

# List consumer groups
echo -e "${CYAN}👥 Current Consumer Groups:${NC}"
CONSUMER_GROUPS=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null)

if [ -z "$CONSUMER_GROUPS" ] || [ "$CONSUMER_GROUPS" = "" ]; then
    echo -e "${YELLOW}⚠️  No consumer groups found${NC}"
    echo -e "${YELLOW}   This is normal - consumer groups are created when consumers start${NC}"
else
    echo "$CONSUMER_GROUPS"
fi
echo ""

# Expected consumer groups from local environment
echo -e "${CYAN}📝 Expected Consumer Groups (from local):${NC}"
echo "  • hes-kaifa-consumer-group"
echo "  • scada-consumer-group" 
echo "  • call-center-consumer-group"
echo "  • onu-consumer-group"
echo ""

echo -e "${CYAN}💡 Consumer Groups are created automatically when:${NC}"
echo "  1. A consumer application starts consuming from a topic"
echo "  2. A consumer subscribes to a topic for the first time"
echo "  3. You manually create them using kafka-consumer-groups command"
echo ""

# Show commands to manually create consumer groups (optional)
echo -e "${CYAN}🛠️  To manually create consumer groups (optional):${NC}"
echo ""
echo -e "${WHITE}# HES Kaifa Consumer Group${NC}"
echo "docker exec $KAFKA_CONTAINER kafka-consumer-groups \\"
echo "  --bootstrap-server $KAFKA_BROKER \\"
echo "  --group hes-kaifa-consumer-group \\"
echo "  --topic hes-kaifa-outage-topic \\"
echo "  --reset-offsets --to-earliest --execute"
echo ""

echo -e "${WHITE}# SCADA Consumer Group${NC}"
echo "docker exec $KAFKA_CONTAINER kafka-consumer-groups \\"
echo "  --bootstrap-server $KAFKA_BROKER \\"
echo "  --group scada-consumer-group \\"
echo "  --topic scada-outage-topic \\"
echo "  --reset-offsets --to-earliest --execute"
echo ""

echo -e "${WHITE}# Call Center Consumer Group${NC}"
echo "docker exec $KAFKA_CONTAINER kafka-consumer-groups \\"
echo "  --bootstrap-server $KAFKA_BROKER \\"
echo "  --group call-center-consumer-group \\"
echo "  --topic call_center_upstream_topic \\"
echo "  --reset-offsets --to-earliest --execute"
echo ""

echo -e "${WHITE}# ONU Consumer Group${NC}"
echo "docker exec $KAFKA_CONTAINER kafka-consumer-groups \\"
echo "  --bootstrap-server $KAFKA_BROKER \\"
echo "  --group onu-consumer-group \\"
echo "  --topic onu-events-topic \\"
echo "  --reset-offsets --to-earliest --execute"
echo ""

echo -e "${GREEN}✅ Consumer groups check complete!${NC}"
echo ""
echo -e "${CYAN}📌 Note: Consumer groups will appear in the UI when:${NC}"
echo "   • Your applications start consuming from the topics"
echo "   • You run the manual creation commands above"
echo "   • You start any Kafka consumer applications"

