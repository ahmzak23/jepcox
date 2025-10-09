#!/bin/bash

################################################################################
# Start OMS System with Database Configuration
# This script starts the database first, then all consumers with proper configuration
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Starting OMS System with Database Configuration${NC}"
echo -e "${GREEN}=================================================${NC}"
echo ""

echo -e "${CYAN}📋 Configuration:${NC}"
echo -e "${WHITE}• Database: PostgreSQL 13 (oms-database)${NC}"
echo -e "${WHITE}• Database Port: 5433 (external), 5432 (internal)${NC}"
echo -e "${WHITE}• Database Name: oms_db${NC}"
echo -e "${WHITE}• Database User: web${NC}"
echo -e "${WHITE}• Environment: Using oms.env configuration${NC}"
echo ""

# Load environment variables
if [ -f "oms.env" ]; then
    echo -e "${CYAN}⏳ Loading environment configuration from oms.env...${NC}"
    export $(grep -v '^#' oms.env | xargs)
    echo -e "${GREEN}✅ Environment configuration loaded${NC}"
else
    echo -e "${YELLOW}⚠️  oms.env not found, using defaults${NC}"
fi
echo ""

echo -e "${CYAN}⏳ Starting PostgreSQL database...${NC}"
docker compose up -d oms-database

echo -e "${CYAN}⏳ Waiting for database to initialize...${NC}"
sleep 10

echo -e "${CYAN}⏳ Testing database connection...${NC}"
if docker compose exec oms-database pg_isready -U web -d oms_db; then
    echo -e "${GREEN}✅ Database is ready${NC}"
else
    echo -e "${YELLOW}⚠️  Database might still be initializing, continuing...${NC}"
fi
echo ""

echo -e "${CYAN}⏳ Starting all consumer services...${NC}"
docker compose up -d hes-consumer scada-consumer call-center-consumer onu-consumer

echo -e "${CYAN}⏳ Waiting for consumers to initialize...${NC}"
sleep 15

echo -e "${CYAN}📊 Checking service status...${NC}"
echo ""
docker compose ps | grep -E "(oms-database|consumer)"

echo ""
echo -e "${CYAN}📝 Checking database connection from HES consumer...${NC}"
docker compose exec hes-consumer python -c "
import os
print(f'DB_HOST: {os.getenv(\"DB_HOST\")}')
print(f'DB_PORT: {os.getenv(\"DB_PORT\")}')
print(f'DB_NAME: {os.getenv(\"DB_NAME\")}')
print(f'DB_USER: {os.getenv(\"DB_USER\")}')
try:
    import psycopg2
    conn = psycopg2.connect(
        host=os.getenv('DB_HOST', 'oms-database'),
        port=int(os.getenv('DB_PORT', '5432')),
        database=os.getenv('DB_NAME', 'oms_db'),
        user=os.getenv('DB_USER', 'web'),
        password=os.getenv('DB_PASSWORD', '123456')
    )
    print('✅ Database connection successful!')
    conn.close()
except Exception as e:
    print(f'❌ Database connection failed: {e}')
"

echo ""
echo -e "${CYAN}📝 Checking HES Consumer logs...${NC}"
docker compose logs --tail=10 hes-consumer

echo ""
echo -e "${GREEN}✅ OMS System startup complete!${NC}"
echo ""

# Check final status
RUNNING_CONSUMERS=$(docker compose ps | grep consumer | grep "Up" | wc -l)
RESTARTING_CONSUMERS=$(docker compose ps | grep consumer | grep "Restarting" | wc -l)
DATABASE_STATUS=$(docker compose ps | grep oms-database | grep "Up" | wc -l)

echo -e "${CYAN}📊 Final Status Summary:${NC}"
echo -e "${GREEN}• Database: $DATABASE_STATUS running${NC}"
echo -e "${GREEN}• Consumers Running: $RUNNING_CONSUMERS${NC}"
echo -e "${RED}• Consumers Restarting: $RESTARTING_CONSUMERS${NC}"
echo ""

if [ "$RESTARTING_CONSUMERS" -eq 0 ] && [ "$RUNNING_CONSUMERS" -gt 0 ]; then
    echo -e "${GREEN}🎉 SUCCESS! All consumers are running with database support!${NC}"
    echo ""
    echo -e "${CYAN}📋 Access Points:${NC}"
    echo -e "${WHITE}• Database: localhost:5433${NC}"
    echo -e "${WHITE}• Kafka UI: http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups${NC}"
    echo -e "${WHITE}• OMS API: http://192.168.2.41:9100${NC}"
    echo ""
    echo -e "${CYAN}📋 Management Commands:${NC}"
    echo -e "${WHITE}• View consumer logs: docker compose logs -f hes-consumer${NC}"
    echo -e "${WHITE}• Check database: docker compose exec oms-database psql -U web -d oms_db${NC}"
    echo -e "${WHITE}• Stop all: docker compose stop${NC}"
else
    echo -e "${YELLOW}⚠️  Some consumers are still having issues${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting:${NC}"
    echo -e "${WHITE}• Check detailed logs: docker compose logs --tail=20 hes-consumer${NC}"
    echo -e "${WHITE}• Check database logs: docker compose logs oms-database${NC}"
    echo -e "${WHITE}• Restart consumers: docker compose restart hes-consumer scada-consumer call-center-consumer onu-consumer${NC}"
fi

echo ""
echo -e "${CYAN}📌 Note: Database schemas are automatically created on first startup${NC}"
