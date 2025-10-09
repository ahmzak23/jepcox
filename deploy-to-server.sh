#!/bin/bash

################################################################################
# Deploy to Server Script
# This script helps you deploy the OMS system to a server with proper database configuration
################################################################################

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}🚀 Deploy OMS to Server${NC}"
echo -e "${GREEN}=====================${NC}"
echo ""

# Check if we're on server or local
if [ -f "/etc/os-release" ] && grep -q "Ubuntu\|CentOS\|RHEL" /etc/os-release; then
    echo -e "${CYAN}🖥️  Detected Linux server environment${NC}"
    IS_SERVER=true
else
    echo -e "${CYAN}💻 Detected local development environment${NC}"
    IS_SERVER=false
fi
echo ""

# Function to setup server environment
setup_server_environment() {
    echo -e "${CYAN}⚙️  Setting up server environment...${NC}"
    
    # Copy server environment template
    if [ -f "oms.env.server" ]; then
        cp oms.env.server oms.env
        echo -e "${GREEN}✅ Copied server environment template${NC}"
    else
        echo -e "${RED}❌ oms.env.server not found${NC}"
        exit 1
    fi
    
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT: Update database settings in oms.env${NC}"
    echo ""
    echo -e "${CYAN}📝 Current server template settings:${NC}"
    echo -e "${WHITE}• DB_HOST=localhost${NC}"
    echo -e "${WHITE}• DB_PORT=5432${NC}"
    echo -e "${WHITE}• DB_NAME=oms_production${NC}"
    echo -e "${WHITE}• DB_USER=oms_user${NC}"
    echo -e "${WHITE}• DB_PASSWORD=your_secure_password_here${NC}"
    echo ""
    
    # Ask user for database settings
    echo -e "${CYAN}🔧 Database Configuration:${NC}"
    read -p "Enter your database host (default: localhost): " db_host
    db_host=${db_host:-localhost}
    
    read -p "Enter your database port (default: 5432): " db_port
    db_port=${db_port:-5432}
    
    read -p "Enter your database name (default: oms_production): " db_name
    db_name=${db_name:-oms_production}
    
    read -p "Enter your database user (default: oms_user): " db_user
    db_user=${db_user:-oms_user}
    
    read -s -p "Enter your database password: " db_password
    echo ""
    
    # Update oms.env with actual values
    sed -i "s/DB_HOST=.*/DB_HOST=$db_host/" oms.env
    sed -i "s/DB_PORT=.*/DB_PORT=$db_port/" oms.env
    sed -i "s/DB_NAME=.*/DB_NAME=$db_name/" oms.env
    sed -i "s/DB_USER=.*/DB_USER=$db_user/" oms.env
    sed -i "s/DB_PASSWORD=.*/DB_PASSWORD=$db_password/" oms.env
    sed -i "s|DATABASE_URL=.*|DATABASE_URL=postgresql://$db_user:$db_password@$db_host:$db_port/$db_name|" oms.env
    
    echo -e "${GREEN}✅ Updated oms.env with your database settings${NC}"
    echo ""
}

# Function to setup local environment
setup_local_environment() {
    echo -e "${CYAN}🏠 Setting up local development environment...${NC}"
    
    if [ -f "oms.env.local" ]; then
        cp oms.env.local oms.env
        echo -e "${GREEN}✅ Copied local environment configuration${NC}"
    else
        echo -e "${RED}❌ oms.env.local not found${NC}"
        exit 1
    fi
}

# Main logic
if [ "$IS_SERVER" = true ]; then
    setup_server_environment
else
    setup_local_environment
fi

echo -e "${CYAN}📋 Final Configuration:${NC}"
if [ -f "oms.env" ]; then
    echo -e "${WHITE}• DB_HOST: $(grep '^DB_HOST=' oms.env | cut -d'=' -f2)${NC}"
    echo -e "${WHITE}• DB_PORT: $(grep '^DB_PORT=' oms.env | cut -d'=' -f2)${NC}"
    echo -e "${WHITE}• DB_NAME: $(grep '^DB_NAME=' oms.env | cut -d'=' -f2)${NC}"
    echo -e "${WHITE}• DB_USER: $(grep '^DB_USER=' oms.env | cut -d'=' -f2)${NC}"
    echo -e "${WHITE}• Environment: $(grep '^ENVIRONMENT=' oms.env | cut -d'=' -f2)${NC}"
fi
echo ""

echo -e "${CYAN}🚀 Ready to start the system!${NC}"
echo ""
echo -e "${CYAN}📋 Next Steps:${NC}"
echo -e "${WHITE}• Start the system: ./start-with-database.sh${NC}"
echo -e "${WHITE}• Or start manually: docker compose up -d${NC}"
echo -e "${WHITE}• Check status: docker compose ps${NC}"
echo -e "${WHITE}• View logs: docker compose logs -f${NC}"
echo ""

# Ask if user wants to start the system now
read -p "Do you want to start the system now? (y/n): " start_now
if [[ $start_now =~ ^[Yy]$ ]]; then
    echo -e "${CYAN}⏳ Starting the system...${NC}"
    if [ -f "start-with-database.sh" ]; then
        chmod +x start-with-database.sh
        ./start-with-database.sh
    else
        docker compose up -d
        echo -e "${GREEN}✅ System started!${NC}"
        echo -e "${WHITE}Check status with: docker compose ps${NC}"
    fi
fi

echo ""
echo -e "${GREEN}🎉 Deployment setup complete!${NC}"
