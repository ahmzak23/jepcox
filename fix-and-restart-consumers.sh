#!/bin/bash

################################################################################
# Fix and Restart Consumer Services
# This script fixes the database issue and restarts consumers without database mode
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔧 Fixing and Restarting Consumer Services${NC}"
echo -e "${GREEN}==========================================${NC}"
echo ""

echo -e "${CYAN}📋 Issue Identified:${NC}"
echo -e "${WHITE}• Consumers were trying to connect to a PostgreSQL database${NC}"
echo -e "${WHITE}• Database mode has been disabled for now${NC}"
echo -e "${WHITE}• Consumers will run in file-only mode${NC}"
echo ""

echo -e "${CYAN}⏳ Stopping all consumer services...${NC}"
docker compose stop hes-consumer scada-consumer call-center-consumer onu-consumer

echo -e "${CYAN}⏳ Waiting for services to stop completely...${NC}"
sleep 5

echo -e "${CYAN}⏳ Starting consumer services (without database mode)...${NC}"
docker compose up -d hes-consumer scada-consumer call-center-consumer onu-consumer

echo -e "${CYAN}⏳ Waiting for services to initialize...${NC}"
sleep 15

echo -e "${CYAN}📊 Checking consumer status...${NC}"
echo ""
docker compose ps | grep consumer

echo ""
echo -e "${CYAN}📝 Checking HES Consumer logs...${NC}"
docker compose logs --tail=10 hes-consumer

echo ""
echo -e "${CYAN}📝 Checking SCADA Consumer logs...${NC}"
docker compose logs --tail=10 scada-consumer

echo ""
echo -e "${GREEN}✅ Consumer restart complete!${NC}"
echo ""

# Check if consumers are running properly
RUNNING_CONSUMERS=$(docker compose ps | grep consumer | grep "Up" | wc -l)
RESTARTING_CONSUMERS=$(docker compose ps | grep consumer | grep "Restarting" | wc -l)

if [ "$RESTARTING_CONSUMERS" -eq 0 ] && [ "$RUNNING_CONSUMERS" -gt 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS! All consumers are now running properly!${NC}"
    echo ""
    echo -e "${CYAN}📊 Consumer Status Summary:${NC}"
    echo -e "${GREEN}• Running: $RUNNING_CONSUMERS consumers${NC}"
    echo -e "${GREEN}• Restarting: $RESTARTING_CONSUMERS consumers${NC}"
    echo ""
    echo -e "${CYAN}📋 Next Steps:${NC}"
    echo -e "${WHITE}• Check Kafka UI:${NC} http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups"
    echo -e "${WHITE}• Monitor consumer logs:${NC} docker compose logs -f hes-consumer"
    echo -e "${WHITE}• Check output files:${NC} ls -la services/*/outbox/"
else
    echo -e "${YELLOW}⚠️  Some consumers are still having issues${NC}"
    echo ""
    echo -e "${CYAN}📊 Consumer Status Summary:${NC}"
    echo -e "${GREEN}• Running: $RUNNING_CONSUMERS consumers${NC}"
    echo -e "${RED}• Restarting: $RESTARTING_CONSUMERS consumers${NC}"
    echo ""
    echo -e "${YELLOW}💡 Run this command to check detailed logs:${NC}"
    echo -e "${WHITE}docker compose logs --tail=20 hes-consumer${NC}"
fi

echo ""
echo -e "${CYAN}📌 Note: Consumers are running in file-only mode (no database)${NC}"
echo -e "${CYAN}   JSON files will be saved to the outbox directories${NC}"
