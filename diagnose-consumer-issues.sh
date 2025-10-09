#!/bin/bash

################################################################################
# Diagnose Consumer Issues
# This script helps identify why consumers are still restarting
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🔍 Diagnosing Consumer Issues${NC}"
echo -e "${GREEN}============================${NC}"
echo ""

echo -e "${CYAN}1. Checking OMS API Status...${NC}"
docker compose ps oms-api
echo ""

echo -e "${CYAN}2. Testing OMS API Connectivity...${NC}"
if curl -s http://localhost:9100/health > /dev/null 2>&1; then
    echo -e "${GREEN}✅ OMS API is responding${NC}"
else
    echo -e "${RED}❌ OMS API is not responding${NC}"
fi
echo ""

echo -e "${CYAN}3. Checking OMS API Logs...${NC}"
docker compose logs --tail=10 oms-api
echo ""

echo -e "${CYAN}4. Checking HES Consumer Logs...${NC}"
docker compose logs --tail=15 hes-consumer
echo ""

echo -e "${CYAN}5. Checking SCADA Consumer Logs...${NC}"
docker compose logs --tail=15 scada-consumer
echo ""

echo -e "${CYAN}6. Checking if requirements.txt exists...${NC}"
if [ -f "requirements.txt" ]; then
    echo -e "${GREEN}✅ requirements.txt exists${NC}"
    echo -e "${WHITE}Contents:${NC}"
    head -10 requirements.txt
else
    echo -e "${RED}❌ requirements.txt not found${NC}"
fi
echo ""

echo -e "${CYAN}7. Checking if consumer scripts exist...${NC}"
echo -e "${WHITE}HES Consumer:${NC}"
ls -la services/kaifa/consumer/run_consumer.py 2>/dev/null || echo -e "${RED}❌ run_consumer.py not found${NC}"

echo -e "${WHITE}SCADA Consumer:${NC}"
ls -la services/scada/consumer/scada_consumer.py 2>/dev/null || echo -e "${RED}❌ scada_consumer.py not found${NC}"

echo -e "${WHITE}Call Center Consumer:${NC}"
ls -la services/call_center/consumer/call_center_consumer.py 2>/dev/null || echo -e "${RED}❌ call_center_consumer.py not found${NC}"

echo -e "${WHITE}ONU Consumer:${NC}"
ls -la services/onu/consumer/onu_consumer.py 2>/dev/null || echo -e "${RED}❌ onu_consumer.py not found${NC}"
echo ""

echo -e "${CYAN}8. Testing Database Connection from OMS API...${NC}"
docker compose exec oms-api python -c "
try:
    import psycopg2
    conn = psycopg2.connect(host='oms-api', port=5432, database='oms_db', user='web', password='123456')
    print('✅ Database connection successful')
    conn.close()
except Exception as e:
    print(f'❌ Database connection failed: {e}')
" 2>/dev/null || echo -e "${RED}❌ Cannot test database connection${NC}"
echo ""

echo -e "${CYAN}9. Checking Docker Network Connectivity...${NC}"
docker compose exec hes-consumer ping -c 2 oms-api 2>/dev/null || echo -e "${RED}❌ Cannot ping oms-api from hes-consumer${NC}"
echo ""

echo -e "${GREEN}🔍 Diagnosis Complete!${NC}"
echo ""
echo -e "${YELLOW}💡 Common Issues:${NC}"
echo -e "${WHITE}• Missing requirements.txt or consumer scripts${NC}"
echo -e "${WHITE}• OMS API not running or not accessible${NC}"
echo -e "${WHITE}• Database connection issues${NC}"
echo -e "${WHITE}• Missing Python dependencies${NC}"
echo -e "${WHITE}• Network connectivity problems${NC}"
