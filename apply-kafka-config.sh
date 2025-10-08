#!/bin/bash

################################################################################
# Apply Kafka Configuration from JSON File
# 
# This script reads kafka-config.json and applies all configurations to Kafka
# 
# Usage: ./apply-kafka-config.sh [config-file]
# Default config file: kafka-config.json
################################################################################

set -e

# Configuration
CONFIG_FILE="${1:-kafka-config.json}"
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}❌ jq is not installed. Please install jq to parse JSON.${NC}"
    echo -e "${YELLOW}Install with: sudo apt-get install jq (Ubuntu/Debian) or brew install jq (Mac)${NC}"
    exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}❌ Configuration file not found: $CONFIG_FILE${NC}"
    exit 1
fi

# Banner
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     Apply Kafka Configuration from JSON                  ║
║     Automated Configuration Deployment                   ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Display configuration metadata
echo -e "${CYAN}📋 Configuration Metadata${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
jq -r '.metadata | "Source: \(.source)\nExport Date: \(.export_date)\nKafka Version: \(.kafka_version)\nDescription: \(.description)"' "$CONFIG_FILE"
echo ""

# Check Kafka connectivity
echo -e "${CYAN}⏳ Checking Kafka connectivity...${NC}"
if ! docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kafka${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kafka is accessible${NC}"
echo ""

# Create topics
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}Creating Kafka Topics${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

topics_count=$(jq '.topics | length' "$CONFIG_FILE")
created=0
skipped=0
failed=0

for ((i=0; i<$topics_count; i++)); do
    topic_name=$(jq -r ".topics[$i].name" "$CONFIG_FILE")
    partitions=$(jq -r ".topics[$i].partitions" "$CONFIG_FILE")
    replication=$(jq -r ".topics[$i].replication_factor" "$CONFIG_FILE")
    description=$(jq -r ".topics[$i].description" "$CONFIG_FILE")
    retention_ms=$(jq -r ".topics[$i].configs.\"retention.ms\"" "$CONFIG_FILE")
    segment_bytes=$(jq -r ".topics[$i].configs.\"segment.bytes\"" "$CONFIG_FILE")
    cleanup_policy=$(jq -r ".topics[$i].configs.\"cleanup.policy\"" "$CONFIG_FILE")
    compression_type=$(jq -r ".topics[$i].configs.\"compression.type\"" "$CONFIG_FILE")
    min_isr=$(jq -r ".topics[$i].configs.\"min.insync.replicas\"" "$CONFIG_FILE")
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Topic: ${CYAN}$topic_name${NC}"
    echo -e "${WHITE}Description: ${NC}$description"
    echo -e "${WHITE}Partitions: ${NC}$partitions"
    echo -e "${WHITE}Replication Factor: ${NC}$replication"
    echo -e "${WHITE}Retention: ${NC}$retention_ms ms ($(($retention_ms / 86400000)) days)"
    echo -e "${WHITE}Segment Size: ${NC}$segment_bytes bytes ($(($segment_bytes / 1073741824)) GB)"
    echo -e "${WHITE}Cleanup Policy: ${NC}$cleanup_policy"
    echo -e "${WHITE}Compression: ${NC}$compression_type"
    echo -e "${WHITE}Min ISR: ${NC}$min_isr"
    
    # Build config string
    configs="retention.ms=$retention_ms"
    configs="$configs,segment.bytes=$segment_bytes"
    configs="$configs,cleanup.policy=$cleanup_policy"
    configs="$configs,compression.type=$compression_type"
    configs="$configs,min.insync.replicas=$min_isr"
    
    # Create topic
    if docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --create \
        --topic "$topic_name" \
        --partitions $partitions \
        --replication-factor $replication \
        --config "$configs" \
        --if-not-exists 2>/dev/null; then
        echo -e "${GREEN}✅ Created successfully${NC}"
        ((created++))
    else
        if docker exec $KAFKA_CONTAINER kafka-topics \
            --bootstrap-server $KAFKA_BROKER \
            --list 2>/dev/null | grep -q "^${topic_name}$"; then
            echo -e "${YELLOW}⚠️  Already exists (skipped)${NC}"
            ((skipped++))
        else
            echo -e "${RED}❌ Failed to create${NC}"
            ((failed++))
        fi
    fi
    echo ""
done

echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Topic Creation Summary:${NC}"
echo -e "  ${GREEN}Created: $created${NC}"
echo -e "  ${YELLOW}Skipped: $skipped${NC}"
echo -e "  ${RED}Failed: $failed${NC}"
echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Display consumer groups information
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}Consumer Groups Configuration${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

groups_count=$(jq '.consumer_groups | length' "$CONFIG_FILE")

for ((i=0; i<$groups_count; i++)); do
    group_name=$(jq -r ".consumer_groups[$i].name" "$CONFIG_FILE")
    group_desc=$(jq -r ".consumer_groups[$i].description" "$CONFIG_FILE")
    group_topics=$(jq -r ".consumer_groups[$i].topics[]" "$CONFIG_FILE")
    auto_offset=$(jq -r ".consumer_groups[$i].auto_offset_reset" "$CONFIG_FILE")
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Group: ${CYAN}$group_name${NC}"
    echo -e "${WHITE}Description: ${NC}$group_desc"
    echo -e "${WHITE}Topics: ${NC}$group_topics"
    echo -e "${WHITE}Auto Offset Reset: ${NC}$auto_offset"
    echo -e "${WHITE}Status: ${YELLOW}Will be created when consumers connect${NC}"
    echo ""
done

echo -e "${YELLOW}ℹ️  Note: Consumer groups are created automatically when consumers start.${NC}"
echo ""

# Verify topics
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}Verifying Topics${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${CYAN}📋 Current Topics:${NC}\n"

topics=$(docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $KAFKA_BROKER \
    --list 2>/dev/null | grep -v "^__" | grep -v "^_schemas" || true)

for topic in $topics; do
    echo -e "${BLUE}Topic: ${WHITE}$topic${NC}"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --describe --topic $topic 2>/dev/null | grep -E "PartitionCount|Partition:" | sed 's/^/  /'
    echo ""
done

# Display configuration summary
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}Configuration Summary${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Configuration Applied Successfully!                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}📊 Applied Configuration:${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Configuration File: ${NC}$CONFIG_FILE"
echo -e "${WHITE}Kafka Broker: ${NC}$KAFKA_BROKER"
echo -e "${WHITE}Topics Created/Verified: ${NC}$topics_count"
echo -e "${WHITE}Consumer Groups Configured: ${NC}$groups_count"
echo ""

echo -e "${CYAN}📦 Topics:${NC}"
jq -r '.topics[] | "  • \(.name) (\(.partitions) partitions, \(.replication_factor) replication)"' "$CONFIG_FILE"
echo ""

echo -e "${CYAN}👥 Consumer Groups:${NC}"
jq -r '.consumer_groups[] | "  • \(.name)"' "$CONFIG_FILE"
echo ""

echo -e "${CYAN}⚙️  Retention Policy:${NC}"
jq -r '.retention_policies | "  • Default Retention: \(.default_retention_days) days\n  • Segment Size: \(.segment_bytes / 1073741824) GB\n  • Cleanup Policy: \(.cleanup_policy)"' "$CONFIG_FILE"
echo ""

echo -e "${CYAN}🔧 Useful Commands:${NC}"
echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}List topics:${NC}"
echo -e "  docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --list"
echo ""
echo -e "${YELLOW}Describe topic:${NC}"
echo -e "  docker exec $KAFKA_CONTAINER kafka-topics --bootstrap-server $KAFKA_BROKER --describe --topic <topic-name>"
echo ""
echo -e "${YELLOW}List consumer groups:${NC}"
echo -e "  docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list"
echo ""

echo -e "${GREEN}✅ Kafka configuration has been applied successfully!${NC}"
echo -e "${GREEN}🎉 Your Kafka cluster is ready for production use!${NC}"
echo ""
