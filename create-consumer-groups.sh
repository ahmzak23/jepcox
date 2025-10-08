#!/bin/bash

################################################################################
# Create Consumer Groups on Server
# This script manually creates consumer groups so they appear in the UI
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

echo -e "${GREEN}🚀 Creating Kafka Consumer Groups${NC}"
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

created=0
skipped=0

# Function to create consumer group
create_consumer_group() {
    local group_name=$1
    local topic_name=$2
    local description=$3
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Consumer Group: ${CYAN}$group_name${NC}"
    echo -e "${WHITE}Topic: ${NC}$topic_name"
    echo -e "${WHITE}Description: ${NC}$description"
    
    # Check if consumer group already exists
    if docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | grep -q "^$group_name$"; then
        echo -e "${YELLOW}⚠️  Consumer group already exists (skipped)${NC}"
        ((skipped++))
    else
        # Create consumer group by resetting offsets (this creates the group)
        if docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --bootstrap-server $KAFKA_BROKER \
            --group "$group_name" \
            --topic "$topic_name" \
            --reset-offsets --to-earliest --execute > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Created successfully${NC}"
            ((created++))
        else
            echo -e "${RED}❌ Failed to create${NC}"
        fi
    fi
    echo ""
}

# Create all consumer groups
create_consumer_group "hes-kaifa-consumer-group" "hes-kaifa-outage-topic" "Consumer group for HES Kaifa outage events"
create_consumer_group "scada-consumer-group" "scada-outage-topic" "Consumer group for SCADA outage events"
create_consumer_group "call-center-consumer-group" "call_center_upstream_topic" "Consumer group for Call Center ticket events"
create_consumer_group "onu-consumer-group" "onu-events-topic" "Consumer group for ONU device events"

# Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Consumer Group Creation Summary:${NC}"
echo -e "  ${GREEN}Created: $created${NC}"
echo -e "  ${YELLOW}Skipped: $skipped${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# List all consumer groups
echo -e "${CYAN}👥 All Consumer Groups:${NC}"
docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null
echo ""

echo -e "${GREEN}✅ Consumer groups setup complete!${NC}"
echo ""
echo -e "${CYAN}📌 Note: These consumer groups will now appear in your Kafka UI${NC}"
echo -e "${CYAN}   They will show as STABLE with 0 members until applications connect${NC}"
