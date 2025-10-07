#!/bin/bash

# Kong API Gateway Setup Script
# This script creates all services, routes, and dependencies for Kong
# Based on the APISIX Gateway Endpoints configuration

echo "🚀 Setting up Kong API Gateway with all endpoints..."
echo "=================================================="

# Wait for Kong to be ready
echo "⏳ Waiting for Kong to be ready..."
until curl -s http://localhost:8001/status > /dev/null; do
    echo "   Waiting for Kong Admin API..."
    sleep 2
done
echo "✅ Kong is ready!"

# Create Kong Services
echo ""
echo "📦 Creating Kong Services..."

# 1. HES Mock Generator Service
echo "   Creating HES Mock Generator Service..."
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hes-mock-generator-service",
    "url": "http://apisix-workshop-kaifa_hes_upstram-1:80"
  }' | jq -r '.name + " created with ID: " + .id'

# 2. SCADA Mock Generator Service
echo "   Creating SCADA Mock Generator Service..."
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "scada-mock-generator-service",
    "url": "http://apisix-workshop-scada_upstram-1:80"
  }' | jq -r '.name + " created with ID: " + .id'

# 3. Call Center Ticket Generator Service
echo "   Creating Call Center Ticket Generator Service..."
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "call-center-ticket-generator-service",
    "url": "http://apisix-workshop-call_center_upstream-1:80"
  }' | jq -r '.name + " created with ID: " + .id'

# 4. ONU Mock Generator Service
echo "   Creating ONU Mock Generator Service..."
curl -s -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "onu-mock-generator-service",
    "url": "http://apisix-workshop-onu_upstream-1:80"
  }' | jq -r '.name + " created with ID: " + .id'

echo "✅ All services created successfully!"

# Create Kong Routes
echo ""
echo "🛣️  Creating Kong Routes..."

# 1. HES Mock Generator Route
echo "   Creating HES Mock Generator Route..."
curl -s -X POST http://localhost:8001/services/hes-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hes-mock-generator-route",
    "paths": ["/hes-mock-generator"],
    "methods": ["GET", "POST"]
  }' | jq -r '.name + " created with ID: " + .id'

# 2. SCADA Mock Generator Route
echo "   Creating SCADA Mock Generator Route..."
curl -s -X POST http://localhost:8001/services/scada-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "scada-mock-generator-route",
    "paths": ["/scada-mock-generator"],
    "methods": ["GET", "POST"]
  }' | jq -r '.name + " created with ID: " + .id'

# 3. Call Center Ticket Generator Route
echo "   Creating Call Center Ticket Generator Route..."
curl -s -X POST http://localhost:8001/services/call-center-ticket-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "call-center-ticket-generator-route",
    "paths": ["/call-center-ticket-generator"],
    "methods": ["GET", "POST"]
  }' | jq -r '.name + " created with ID: " + .id'

# 4. ONU Mock Generator Route
echo "   Creating ONU Mock Generator Route..."
curl -s -X POST http://localhost:8001/services/onu-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "onu-mock-generator-route",
    "paths": ["/onu-mock-generator"],
    "methods": ["GET", "POST"]
  }' | jq -r '.name + " created with ID: " + .id'

echo "✅ All routes created successfully!"

# Add CORS Plugin to all services
echo ""
echo "🔧 Adding CORS Plugin to all services..."

services=("hes-mock-generator-service" "scada-mock-generator-service" "call-center-ticket-generator-service" "onu-mock-generator-service")

for service in "${services[@]}"; do
    echo "   Adding CORS plugin to $service..."
    curl -s -X POST http://localhost:8001/services/$service/plugins \
      -H "Content-Type: application/json" \
      -d '{
        "name": "cors",
        "config": {
          "origins": ["*"],
          "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
          "headers": ["Accept", "Accept-Version", "Content-Length", "Content-MD5", "Content-Type", "Date", "X-Auth-Token"],
          "exposed_headers": ["X-Auth-Token"],
          "credentials": true,
          "max_age": 3600
        }
      }' | jq -r '.name + " plugin added to " + (.service.id // "service")'
done

echo "✅ CORS plugins added successfully!"

# Test all endpoints
echo ""
echo "🧪 Testing all endpoints..."

endpoints=(
    "http://localhost:8000/hes-mock-generator:HES Mock Generator"
    "http://localhost:8000/call-center-ticket-generator:Call Center Generator"
    "http://localhost:8000/onu-mock-generator:ONU Mock Generator"
    "http://localhost:8000/scada-mock-generator:SCADA Mock Generator"
)

for endpoint_info in "${endpoints[@]}"; do
    endpoint=$(echo $endpoint_info | cut -d':' -f1)
    name=$(echo $endpoint_info | cut -d':' -f2)
    
    echo "   Testing $name..."
    response=$(curl -s -w "%{http_code}" -o /dev/null "$endpoint")
    
    if [ "$response" = "200" ]; then
        echo "   ✅ $name - Status: $response"
    else
        echo "   ⚠️  $name - Status: $response"
    fi
done

# Display summary
echo ""
echo "📊 Kong Setup Summary"
echo "===================="
echo "Services created: 4"
echo "Routes created: 4"
echo "CORS plugins added: 4"
echo ""
echo "🌐 Available Endpoints:"
echo "• HES Mock Generator: http://localhost:8000/hes-mock-generator"
echo "• SCADA Mock Generator: http://localhost:8000/scada-mock-generator"
echo "• Call Center Generator: http://localhost:8000/call-center-ticket-generator"
echo "• ONU Mock Generator: http://localhost:8000/onu-mock-generator"
echo ""
echo "🔧 Management URLs:"
echo "• Kong Admin API: http://localhost:8001"
echo "• Kong Manager: http://localhost:8002"
echo "• Konga Admin: http://localhost:1337"
echo ""
echo "✅ Kong setup completed successfully!"
