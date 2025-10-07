# Kong API Gateway Setup Commands

This document provides all the commands needed to set up Kong API Gateway with your endpoints on the server.

## 🚀 Quick Setup Scripts

### For Linux/Mac Servers:
```bash
chmod +x setup-kong-endpoints.sh
./setup-kong-endpoints.sh
```

### For Windows Servers:
```batch
setup-kong-endpoints.bat
```

## 📋 Manual Setup Commands

### Prerequisites
Ensure Kong is running and accessible:
```bash
# Check Kong status
curl http://localhost:8001/status

# Expected response: Kong server status JSON
```

### 1. Create Kong Services

#### HES Mock Generator Service
```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hes-mock-generator-service",
    "url": "http://apisix-workshop-kaifa_hes_upstram-1:80"
  }'
```

#### SCADA Mock Generator Service
```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "scada-mock-generator-service",
    "url": "http://apisix-workshop-scada_upstram-1:80"
  }'
```

#### Call Center Ticket Generator Service
```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "call-center-ticket-generator-service",
    "url": "http://apisix-workshop-call_center_upstream-1:80"
  }'
```

#### ONU Mock Generator Service
```bash
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "onu-mock-generator-service",
    "url": "http://apisix-workshop-onu_upstream-1:80"
  }'
```

### 2. Create Kong Routes

#### HES Mock Generator Route
```bash
curl -X POST http://localhost:8001/services/hes-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hes-mock-generator-route",
    "paths": ["/hes-mock-generator"],
    "methods": ["GET", "POST"]
  }'
```

#### SCADA Mock Generator Route
```bash
curl -X POST http://localhost:8001/services/scada-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "scada-mock-generator-route",
    "paths": ["/scada-mock-generator"],
    "methods": ["GET", "POST"]
  }'
```

#### Call Center Ticket Generator Route
```bash
curl -X POST http://localhost:8001/services/call-center-ticket-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "call-center-ticket-generator-route",
    "paths": ["/call-center-ticket-generator"],
    "methods": ["GET", "POST"]
  }'
```

#### ONU Mock Generator Route
```bash
curl -X POST http://localhost:8001/services/onu-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "onu-mock-generator-route",
    "paths": ["/onu-mock-generator"],
    "methods": ["GET", "POST"]
  }'
```

### 3. Add CORS Plugin to All Services

#### Add CORS to HES Service
```bash
curl -X POST http://localhost:8001/services/hes-mock-generator-service/plugins \
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
  }'
```

#### Add CORS to SCADA Service
```bash
curl -X POST http://localhost:8001/services/scada-mock-generator-service/plugins \
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
  }'
```

#### Add CORS to Call Center Service
```bash
curl -X POST http://localhost:8001/services/call-center-ticket-generator-service/plugins \
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
  }'
```

#### Add CORS to ONU Service
```bash
curl -X POST http://localhost:8001/services/onu-mock-generator-service/plugins \
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
  }'
```

## 🧪 Test Commands

### Test All Endpoints
```bash
# Test HES Mock Generator
curl http://localhost:8000/hes-mock-generator

# Test SCADA Mock Generator
curl http://localhost:8000/scada-mock-generator

# Test Call Center Generator
curl http://localhost:8000/call-center-ticket-generator

# Test ONU Mock Generator
curl http://localhost:8000/onu-mock-generator
```

### Test SCADA with POST Data
```bash
curl -X POST http://localhost:8000/scada-mock-generator \
  -H "Content-Type: application/json" \
  -d '{
    "eventType": "alarm",
    "substationId": "SUB001",
    "feederId": "FEED001",
    "mainStationId": "MAIN001",
    "alarmType": "voltage",
    "timestamp": "2025-10-07T12:00:00Z",
    "voltage": 220.5
  }'
```

## 🔍 Verification Commands

### List All Services
```bash
curl http://localhost:8001/services | jq '.data[] | {name: .name, host: .host, port: .port}'
```

### List All Routes
```bash
curl http://localhost:8001/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods}'
```

### List All Plugins
```bash
curl http://localhost:8001/plugins | jq '.data[] | {name: .name, service: .service.name}'
```

### Check Specific Service
```bash
curl http://localhost:8001/services/hes-mock-generator-service | jq '.'
```

### Check Specific Route
```bash
curl http://localhost:8001/routes/hes-mock-generator-route | jq '.'
```

## 🗑️ Cleanup Commands

### Delete All Routes
```bash
# Get all route IDs and delete them
curl http://localhost:8001/routes | jq -r '.data[].id' | xargs -I {} curl -X DELETE http://localhost:8001/routes/{}
```

### Delete All Services
```bash
# Get all service IDs and delete them
curl http://localhost:8001/services | jq -r '.data[].id' | xargs -I {} curl -X DELETE http://localhost:8001/services/{}
```

### Delete All Plugins
```bash
# Get all plugin IDs and delete them
curl http://localhost:8001/plugins | jq -r '.data[].id' | xargs -I {} curl -X DELETE http://localhost:8001/plugins/{}
```

## 🔧 Management Commands

### Update Service
```bash
curl -X PATCH http://localhost:8001/services/hes-mock-generator-service \
  -H "Content-Type: application/json" \
  -d '{"connect_timeout": 60000, "write_timeout": 60000, "read_timeout": 60000}'
```

### Update Route
```bash
curl -X PATCH http://localhost:8001/routes/hes-mock-generator-route \
  -H "Content-Type: application/json" \
  -d '{"strip_path": true, "preserve_host": false}'
```

### Add Rate Limiting Plugin
```bash
curl -X POST http://localhost:8001/services/hes-mock-generator-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 100,
      "hour": 1000
    }
  }'
```

## 📊 Monitoring Commands

### Check Kong Status
```bash
curl http://localhost:8001/status
```

### Check Kong Health
```bash
curl http://localhost:8000/kong-health
```

### View Kong Logs (if using Docker)
```bash
docker logs apisix-workshop-kong --tail 50
```

## 🌐 Access URLs

After setup, your endpoints will be available at:

- **HES Mock Generator**: http://localhost:8000/hes-mock-generator
- **SCADA Mock Generator**: http://localhost:8000/scada-mock-generator
- **Call Center Generator**: http://localhost:8000/call-center-ticket-generator
- **ONU Mock Generator**: http://localhost:8000/onu-mock-generator

### Management Interfaces:
- **Kong Admin API**: http://localhost:8001
- **Kong Manager**: http://localhost:8002
- **Konga Admin**: http://localhost:1337

## 🚨 Troubleshooting

### If Kong is not responding:
```bash
# Check if Kong container is running
docker ps | grep kong

# Restart Kong if needed
docker-compose restart kong

# Check Kong logs
docker logs apisix-workshop-kong --tail 20
```

### If endpoints return 404:
```bash
# Verify routes exist
curl http://localhost:8001/routes

# Check if upstream services are running
docker ps | grep upstream

# Test upstream services directly
curl http://localhost:9085  # HES
curl http://localhost:9086  # SCADA
curl http://localhost:9087  # Call Center
curl http://localhost:9088  # ONU
```

### If CORS issues occur:
```bash
# Verify CORS plugin is installed
curl http://localhost:8001/plugins | jq '.data[] | select(.name == "cors")'
```

This comprehensive command set will allow you to set up Kong API Gateway with all your endpoints on any server environment.
