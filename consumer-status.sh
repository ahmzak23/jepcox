#!/bin/bash

################################################################################
# Check Consumer Status
# This script shows the current status of all consumers
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

echo -e "${CYAN}📊 Kafka Consumer Status${NC}"
echo -e "${CYAN}========================${NC}"
echo ""

# Check Kafka connectivity
echo -e "${CYAN}⏳ Checking Kafka connectivity...${NC}"
if ! docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kafka${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kafka is accessible${NC}"
echo ""

# Check running consumer processes
echo -e "${CYAN}🔄 Running Consumer Processes:${NC}"
CONSUMER_PROCESSES=$(pgrep -f "kafka-console-consumer" 2>/dev/null || true)

if [ -z "$CONSUMER_PROCESSES" ]; then
    echo -e "${YELLOW}⚠️  No consumer processes found${NC}"
else
    echo "$CONSUMER_PROCESSES" | while read pid; do
        if [ ! -z "$pid" ]; then
            echo -e "${GREEN}✅ Consumer process running (PID: $pid)${NC}"
        fi
    done
fi
echo ""

# Check consumer groups
echo -e "${CYAN}👥 Consumer Groups Status:${NC}"
echo ""

# Get all consumer groups
CONSUMER_GROUPS=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null)

if [ -z "$CONSUMER_GROUPS" ]; then
    echo -e "${YELLOW}⚠️  No consumer groups found${NC}"
else
    echo "$CONSUMER_GROUPS" | while read group; do
        if [[ "$group" =~ ^(hes-kaifa-consumer-group|scada-consumer-group|call-center-consumer-group|onu-consumer-group)$ ]]; then
            echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${WHITE}Consumer Group: ${CYAN}$group${NC}"
            
            # Get detailed info
            DETAILS=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
                --bootstrap-server $KAFKA_BROKER \
                --group "$group" \
                --describe 2>/dev/null)
            
            # Extract key information
            STATE=$(echo "$DETAILS" | grep "STATE" | awk '{print $6}' || echo "UNKNOWN")
            MEMBERS=$(echo "$DETAILS" | grep "CONSUMER-ID" | wc -l)
            TOPICS=$(echo "$DETAILS" | grep "TOPIC" | awk '{print $2}' | sort -u | tr '\n' ' ')
            LAG=$(echo "$DETAILS" | grep "LAG" | awk '{sum+=$6} END {print sum+0}')
            
            echo -e "${WHITE}  State: ${NC}$STATE"
            echo -e "${WHITE}  Active Members: ${NC}$MEMBERS"
            echo -e "${WHITE}  Topics: ${NC}$TOPICS"
            echo -e "${WHITE}  Total Lag: ${NC}$LAG"
            
            if [ "$LAG" -gt 0 ]; then
                echo -e "${YELLOW}  ⚠️  Messages pending consumption${NC}"
            else
                echo -e "${GREEN}  ✅ No pending messages${NC}"
            fi
            echo ""
        fi
    done
fi

# Check log files
echo -e "${CYAN}📝 Consumer Log Files:${NC}"
if ls /tmp/kafka-consumer-*.log 1> /dev/null 2>&1; then
    for log_file in /tmp/kafka-consumer-*.log; do
        group_name=$(basename "$log_file" .log | sed 's/kafka-consumer-//')
        size=$(stat -c%s "$log_file" 2>/dev/null || echo "0")
        if [ "$size" -gt 0 ]; then
            echo -e "${GREEN}✅ $group_name: $log_file (${size} bytes)${NC}"
        else
            echo -e "${YELLOW}⚠️  $group_name: $log_file (empty)${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  No consumer log files found${NC}"
fi
echo ""

# Summary
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Quick Actions:${NC}"
echo -e "${GREEN}• Start all consumers:${NC} ./start-all-consumers.sh"
echo -e "${RED}• Stop all consumers:${NC} ./stop-all-consumers.sh"
echo -e "${CYAN}• View Kafka UI:${NC} http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
