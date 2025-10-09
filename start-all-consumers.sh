#!/bin/bash

################################################################################
# Start All Kafka Consumers
# This script starts all consumer applications for the 4 topics
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

echo -e "${GREEN}🚀 Starting All Kafka Consumers${NC}"
echo -e "${GREEN}=================================${NC}"
echo ""

# Check Kafka connectivity
echo -e "${CYAN}⏳ Checking Kafka connectivity...${NC}"
if ! docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
    echo -e "${RED}❌ Cannot connect to Kafka${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Kafka is accessible${NC}"
echo ""

# Function to start consumer in background
start_consumer() {
    local group_name=$1
    local topic_name=$2
    local description=$3
    local port=$4
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Starting Consumer: ${CYAN}$group_name${NC}"
    echo -e "${WHITE}Topic: ${NC}$topic_name"
    echo -e "${WHITE}Description: ${NC}$description"
    echo -e "${WHITE}Upstream Port: ${NC}$port"
    
    # Start consumer in background and capture PID
    docker exec -d $KAFKA_CONTAINER kafka-console-consumer \
        --bootstrap-server $KAFKA_BROKER \
        --topic "$topic_name" \
        --group "$group_name" \
        --from-beginning \
        --property print.key=true \
        --property print.value=true \
        --property key.separator=" | " \
        --property print.partition=true \
        --property print.offset=true > "/tmp/kafka-consumer-$group_name.log" 2>&1 &
    
    CONSUMER_PID=$!
    echo -e "${GREEN}✅ Consumer started (PID: $CONSUMER_PID)${NC}"
    echo -e "${CYAN}📝 Logs: /tmp/kafka-consumer-$group_name.log${NC}"
    echo ""
    
    # Store PID for cleanup later
    echo $CONSUMER_PID >> /tmp/kafka-consumer-pids.txt
}

# Create PID file
> /tmp/kafka-consumer-pids.txt

# Start all consumers
start_consumer "hes-kaifa-consumer-group" "hes-kaifa-outage-topic" "HES Kaifa smart meter outage events" "9085"
start_consumer "scada-consumer-group" "scada-outage-topic" "SCADA system outage events" "9086"
start_consumer "call-center-consumer-group" "call_center_upstream_topic" "Call Center ticket generation events" "9087"
start_consumer "onu-consumer-group" "onu-events-topic" "ONU device events and status updates" "9088"

# Wait a moment for consumers to start
echo -e "${CYAN}⏳ Waiting for consumers to initialize...${NC}"
sleep 3

# Check consumer groups status
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Consumer Groups Status:${NC}"
echo ""

docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | while read group; do
    if [[ "$group" =~ ^(hes-kaifa-consumer-group|scada-consumer-group|call-center-consumer-group|onu-consumer-group)$ ]]; then
        echo -e "${CYAN}👥 $group:${NC}"
        docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --bootstrap-server $KAFKA_BROKER \
            --group "$group" \
            --describe 2>/dev/null | grep -E "(GROUP|TOPIC|PARTITION)" | head -5
        echo ""
    fi
done

echo -e "${GREEN}✅ All consumers started successfully!${NC}"
echo ""
echo -e "${CYAN}📋 Management Commands:${NC}"
echo -e "${WHITE}• View consumer logs:${NC} tail -f /tmp/kafka-consumer-<group-name>.log"
echo -e "${WHITE}• Stop all consumers:${NC} ./stop-all-consumers.sh"
echo -e "${WHITE}• Check consumer status:${NC} docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list"
echo ""
echo -e "${CYAN}📊 Monitor in Kafka UI:${NC}"
echo -e "${WHITE}• URL:${NC} http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups"
echo -e "${WHITE}• You should now see consumers with 'STABLE' state and active members${NC}"
echo ""
echo -e "${GREEN}🎉 Consumers are now running and ready to process messages!${NC}"
