#!/bin/bash

################################################################################
# Restart Consumer Services with Fixed Configuration
# This script restarts all consumer services after fixing database configuration
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔄 Restarting Consumer Services${NC}"
echo -e "${GREEN}===============================${NC}"
echo ""

echo -e "${CYAN}⏳ Stopping all consumer services...${NC}"
docker-compose stop hes-consumer scada-consumer call-center-consumer onu-consumer

echo -e "${CYAN}⏳ Waiting for services to stop completely...${NC}"
sleep 5

echo -e "${CYAN}⏳ Starting consumer services with fixed configuration...${NC}"
docker-compose up -d hes-consumer scada-consumer call-center-consumer onu-consumer

echo -e "${CYAN}⏳ Waiting for services to initialize...${NC}"
sleep 10

echo -e "${CYAN}📊 Checking consumer status...${NC}"
echo ""
docker-compose ps | grep consumer

echo ""
echo -e "${CYAN}📝 Recent logs from HES Consumer:${NC}"
docker-compose logs --tail=10 hes-consumer

echo ""
echo -e "${GREEN}✅ Consumer restart complete!${NC}"
echo ""
echo -e "${CYAN}📋 Next Steps:${NC}"
echo -e "${WHITE}• Check consumer logs:${NC} docker-compose logs -f hes-consumer"
echo -e "${WHITE}• Monitor in Kafka UI:${NC} http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups"
echo -e "${WHITE}• Check all consumer status:${NC} docker-compose ps | grep consumer"
echo ""
echo -e "${YELLOW}💡 If consumers are still restarting, check the logs for any remaining issues${NC}"
