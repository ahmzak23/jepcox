#!/bin/bash

################################################################################
# Kafka Server Setup - Standalone Script
# 
# This script sets up Kafka with all topics, consumer groups, and configurations
# based on the APISIX workshop environment
#
# Usage: ./kafka-server-setup-standalone.sh
# 
# Requirements:
# - Docker and Docker Compose installed
# - Kafka container running (apisix-workshop-kafka or similar)
################################################################################

set -e

# Configuration
KAFKA_BROKER="${KAFKA_BROKER:-localhost:9093}"
KAFKA_CONTAINER="${KAFKA_CONTAINER:-apisix-workshop-kafka}"
ZOOKEEPER_CONTAINER="${ZOOKEEPER_CONTAINER:-apisix-workshop-zookeeper}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Banner
clear
echo -e "${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║     Kafka Server Setup - Standalone Deployment           ║
║     APISIX Workshop Environment                          ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Function to print section headers
print_header() {
    echo -e "\n${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}\n"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}❌ Docker is not installed${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Docker is installed${NC}"
    
    # Check if Kafka container exists
    if ! docker ps -a | grep -q $KAFKA_CONTAINER; then
        echo -e "${RED}❌ Kafka container '$KAFKA_CONTAINER' not found${NC}"
        echo -e "${YELLOW}Please ensure Kafka is running via docker-compose${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Kafka container found${NC}"
    
    # Check if Kafka is running
    if ! docker ps | grep -q $KAFKA_CONTAINER; then
        echo -e "${YELLOW}⚠️  Kafka container is not running. Starting...${NC}"
        docker start $KAFKA_CONTAINER
        sleep 5
    fi
    echo -e "${GREEN}✅ Kafka container is running${NC}"
    
    # Check Kafka connectivity
    echo -e "${YELLOW}⏳ Checking Kafka connectivity...${NC}"
    local retries=0
    local max_retries=30
    
    while [ $retries -lt $max_retries ]; do
        if docker exec $KAFKA_CONTAINER kafka-broker-api-versions --bootstrap-server $KAFKA_BROKER > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Kafka is accessible${NC}"
            return 0
        fi
        retries=$((retries + 1))
        echo -e "${YELLOW}   Waiting for Kafka... ($retries/$max_retries)${NC}"
        sleep 2
    done
    
    echo -e "${RED}❌ Cannot connect to Kafka after $max_retries attempts${NC}"
    exit 1
}

# Function to create topics
create_topics() {
    print_header "Creating Kafka Topics"
    
    # Topic configurations: name:partitions:replication:retention_ms:description
    local topics=(
        "hes-kaifa-outage-topic:3:1:604800000:HES Kaifa outage events from smart meters"
        "scada-outage-topic:3:1:604800000:SCADA system outage and alarm events"
        "call_center_upstream_topic:3:1:604800000:Call center customer tickets and reports"
        "onu-events-topic:3:1:604800000:ONU (Optical Network Unit) events and status"
    )
    
    local created=0
    local skipped=0
    local failed=0
    
    for topic_config in "${topics[@]}"; do
        IFS=':' read -r topic partitions replication retention description <<< "$topic_config"
        
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}Topic: ${CYAN}$topic${NC}"
        echo -e "${WHITE}Description: ${NC}$description"
        echo -e "${WHITE}Partitions: ${NC}$partitions"
        echo -e "${WHITE}Replication Factor: ${NC}$replication"
        echo -e "${WHITE}Retention: ${NC}$retention ms ($(($retention / 86400000)) days)"
        
        if docker exec $KAFKA_CONTAINER kafka-topics \
            --bootstrap-server $KAFKA_BROKER \
            --create \
            --topic $topic \
            --partitions $partitions \
            --replication-factor $replication \
            --config retention.ms=$retention \
            --config segment.bytes=1073741824 \
            --if-not-exists 2>/dev/null; then
            echo -e "${GREEN}✅ Created successfully${NC}"
            ((created++))
        else
            # Check if topic already exists
            if docker exec $KAFKA_CONTAINER kafka-topics \
                --bootstrap-server $KAFKA_BROKER \
                --list 2>/dev/null | grep -q "^${topic}$"; then
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
}

# Function to verify topics
verify_topics() {
    print_header "Verifying Topics"
    
    echo -e "${CYAN}📋 Current Topics:${NC}\n"
    
    local topics=$(docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --list 2>/dev/null | grep -v "^__" | grep -v "^_schemas" || true)
    
    if [ -z "$topics" ]; then
        echo -e "${RED}❌ No topics found${NC}"
        return 1
    fi
    
    for topic in $topics; do
        echo -e "${BLUE}Topic: ${WHITE}$topic${NC}"
        docker exec $KAFKA_CONTAINER kafka-topics \
            --bootstrap-server $KAFKA_BROKER \
            --describe --topic $topic 2>/dev/null | grep -E "PartitionCount|Partition:" | sed 's/^/  /'
        echo ""
    done
}

# Function to setup consumer groups
setup_consumer_groups() {
    print_header "Consumer Groups Information"
    
    echo -e "${CYAN}Expected Consumer Groups:${NC}\n"
    
    local groups=(
        "hes-kaifa-consumer-group:Consumes HES Kaifa outage events"
        "scada-consumer-group:Consumes SCADA outage and alarm events"
        "call-center-consumer-group:Consumes call center tickets"
        "onu-consumer-group:Consumes ONU events and status"
    )
    
    for group_info in "${groups[@]}"; do
        IFS=':' read -r group description <<< "$group_info"
        echo -e "${WHITE}Group: ${CYAN}$group${NC}"
        echo -e "${WHITE}Description: ${NC}$description"
        echo -e "${WHITE}Status: ${YELLOW}Will be created automatically when consumers start${NC}"
        echo ""
    done
    
    echo -e "${YELLOW}ℹ️  Note: Consumer groups are created automatically when consumers connect.${NC}"
    echo -e "${YELLOW}   They do not need to be pre-created.${NC}"
}

# Function to check current consumer groups
check_consumer_groups() {
    print_header "Checking Active Consumer Groups"
    
    local groups=$(docker exec $KAFKA_CONTAINER kafka-consumer-groups \
        --bootstrap-server $KAFKA_BROKER \
        --list 2>/dev/null || true)
    
    if [ -z "$groups" ]; then
        echo -e "${YELLOW}⚠️  No active consumer groups found${NC}"
        echo -e "${YELLOW}   Consumer groups will appear when consumers start consuming messages${NC}"
        return 0
    fi
    
    echo -e "${CYAN}Active Consumer Groups:${NC}\n"
    
    for group in $groups; do
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${WHITE}Group: ${CYAN}$group${NC}\n"
        docker exec $KAFKA_CONTAINER kafka-consumer-groups \
            --bootstrap-server $KAFKA_BROKER \
            --group $group \
            --describe 2>/dev/null || echo -e "${YELLOW}  No active members${NC}"
        echo ""
    done
}

# Function to test Kafka
test_kafka() {
    print_header "Testing Kafka Setup"
    
    local test_topic="test-kafka-setup"
    local test_message="Test message from setup script - $(date)"
    
    echo -e "${CYAN}Creating test topic...${NC}"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --create --topic $test_topic \
        --partitions 1 --replication-factor 1 \
        --if-not-exists 2>/dev/null
    
    echo -e "${CYAN}Producing test message...${NC}"
    echo "$test_message" | docker exec -i $KAFKA_CONTAINER \
        kafka-console-producer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $test_topic 2>/dev/null
    
    echo -e "${CYAN}Consuming test message...${NC}"
    local consumed=$(docker exec $KAFKA_CONTAINER \
        kafka-console-consumer \
        --bootstrap-server $KAFKA_BROKER \
        --topic $test_topic \
        --from-beginning \
        --max-messages 1 \
        --timeout-ms 5000 2>/dev/null || true)
    
    if [ -n "$consumed" ]; then
        echo -e "${GREEN}✅ Kafka is working correctly!${NC}"
        echo -e "${WHITE}Message: ${NC}$consumed"
    else
        echo -e "${RED}❌ Failed to consume test message${NC}"
        return 1
    fi
    
    echo -e "\n${CYAN}Cleaning up test topic...${NC}"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $KAFKA_BROKER \
        --delete --topic $test_topic 2>/dev/null || true
    
    echo -e "${GREEN}✅ Test completed successfully${NC}"
}

# Function to display summary
display_summary() {
    print_header "Setup Summary"
    
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          Kafka Setup Completed Successfully!             ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${CYAN}📊 Configuration Details:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${WHITE}Kafka Broker:${NC} $KAFKA_BROKER"
    echo -e "${WHITE}Kafka Container:${NC} $KAFKA_CONTAINER"
    echo ""
    
    echo -e "${CYAN}📦 Topics Created:${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  • hes-kaifa-outage-topic (3 partitions, 7 days retention)"
    echo -e "  • scada-outage-topic (3 partitions, 7 days retention)"
    echo -e "  • call_center_upstream_topic (3 partitions, 7 days retention)"
    echo -e "  • onu-events-topic (3 partitions, 7 days retention)"
    echo ""
    
    echo -e "${CYAN}👥 Consumer Groups (Auto-created):${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  • hes-kaifa-consumer-group"
    echo -e "  • scada-consumer-group"
    echo -e "  • call-center-consumer-group"
    echo -e "  • onu-consumer-group"
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
    echo -e "${YELLOW}Check consumer group:${NC}"
    echo -e "  docker exec $KAFKA_CONTAINER kafka-consumer-groups --bootstrap-server $KAFKA_BROKER --group <group-name> --describe"
    echo ""
    
    echo -e "${GREEN}✅ Your Kafka server is ready for production use!${NC}"
    echo ""
}

# Main execution
main() {
    check_prerequisites
    create_topics
    verify_topics
    setup_consumer_groups
    check_consumer_groups
    test_kafka
    display_summary
    
    echo -e "${GREEN}🎉 Setup completed successfully!${NC}\n"
}

# Run main function
main "$@"
