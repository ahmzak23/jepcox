#!/bin/bash

################################################################################
# Stop All Kafka Consumers
# This script stops all running consumer applications
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

echo -e "${RED}🛑 Stopping All Kafka Consumers${NC}"
echo -e "${RED}===============================${NC}"
echo ""

stopped=0

# Stop consumers by PIDs if PID file exists
if [ -f "/tmp/kafka-consumer-pids.txt" ]; then
    echo -e "${CYAN}⏳ Stopping consumers by PID...${NC}"
    while read pid; do
        if [ ! -z "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            echo -e "${GREEN}✅ Stopped consumer (PID: $pid)${NC}"
            ((stopped++))
        fi
    done < /tmp/kafka-consumer-pids.txt
    rm -f /tmp/kafka-consumer-pids.txt
fi

# Also stop any remaining kafka-console-consumer processes
echo -e "${CYAN}⏳ Stopping any remaining kafka-console-consumer processes...${NC}"
REMAINING_PIDS=$(pgrep -f "kafka-console-consumer" 2>/dev/null || true)

if [ ! -z "$REMAINING_PIDS" ]; then
    echo "$REMAINING_PIDS" | while read pid; do
        if [ ! -z "$pid" ]; then
            kill "$pid" 2>/dev/null
            echo -e "${GREEN}✅ Stopped remaining consumer (PID: $pid)${NC}"
            ((stopped++))
        fi
    done
fi

# Clean up log files
echo -e "${CYAN}🧹 Cleaning up log files...${NC}"
rm -f /tmp/kafka-consumer-*.log

# Wait a moment for processes to stop
sleep 2

# Check consumer groups status
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${WHITE}Consumer Groups Status (should show 0 members):${NC}"
echo ""

docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --list 2>/dev/null | while read group; do
    if [[ "$group" =~ ^(hes-kaifa-consumer-group|scada-consumer-group|call-center-consumer-group|onu-consumer-group)$ ]]; then
        echo -e "${CYAN}👥 $group:${NC}"
        docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --bootstrap-server $KAFKA_BROKER \
            --group "$group" \
            --describe 2>/dev/null | grep -E "(GROUP|TOPIC|PARTITION)" | head -3
        echo ""
    fi
done

echo -e "${GREEN}✅ All consumers stopped successfully!${NC}"
echo ""
echo -e "${CYAN}📊 Check Kafka UI:${NC}"
echo -e "${WHITE}• URL:${NC} http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups"
echo -e "${WHITE}• Consumer groups should now show 0 members and EMPTY state${NC}"
echo ""
echo -e "${YELLOW}💡 To restart consumers: ./start-all-consumers.sh${NC}"
