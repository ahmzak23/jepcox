#!/bin/bash

echo "Restarting OMS API with CORS support..."

# Stop the OMS API service
docker compose stop oms-api

# Rebuild and start the OMS API service
docker compose up -d --build oms-api

# Wait a moment for the service to start
sleep 5

# Check if the service is running
docker compose ps oms-api

echo ""
echo "OMS API restarted with CORS support!"
echo "Dashboard should now be able to connect."
echo ""
echo "URLs:"
echo "- Dashboard: http://localhost:9200"
echo "- API: http://localhost:9100"
echo "- API Health: http://localhost:9100/health"
echo ""

