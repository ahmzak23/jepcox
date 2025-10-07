# Kong API Gateway Setup

This document describes how to run Kong API Gateway alongside your existing APISIX setup.

## Architecture Overview

Your system now has two API gateways running in parallel:

- **APISIX**: Running on ports 9080 (proxy), 9180 (admin), 9000 (dashboard)
- **Kong**: Running on ports 8000 (proxy), 8001 (admin), 8002 (manager), 1337 (konga)

## Services Added

### Kong Services
- `kong-database`: PostgreSQL database for Kong configuration
- `kong-migrations`: Database migration service (runs once)
- `kong`: Main Kong API Gateway
- `konga`: Web-based Kong administration interface

### Port Mapping
- **8000**: Kong Proxy (main gateway endpoint)
- **8001**: Kong Admin API
- **8002**: Kong Manager (web UI)
- **1337**: Konga (advanced admin UI)
- **5432**: PostgreSQL database

## Quick Start

### Windows
```batch
# Start Kong services
start-kong.bat

# Configure Kong (after services are running)
configure-kong.bat
```

### Linux/Mac
```bash
# Start Kong services
./start-kong.sh

# Configure Kong (after services are running)
# Wait for Kong to be ready, then run:
docker exec apisix-workshop-kong kong config db_import /kong_conf/kong.yml
```

## Manual Start (Alternative)

```bash
# Start all services including Kong
docker-compose up -d

# Check Kong status
docker-compose ps | grep kong
```

## Configuration

### Pre-configured Routes
The following routes are automatically configured:

1. **Health Check**: `http://localhost:8000/kong-health`
   - Proxies to Kong's own health endpoint

2. **APISIX Proxy**: `http://localhost:8000/apisix-proxy`
   - Routes requests to your existing APISIX gateway
   - Allows Kong to proxy requests to APISIX

3. **Web1 Proxy**: `http://localhost:8000/web1`
   - Direct proxy to your web1 service

### CORS Plugin
A CORS plugin is configured to allow cross-origin requests.

## Management Interfaces

### Kong Manager (Web UI)
- URL: http://localhost:8002
- Modern, official Kong administration interface
- Built-in to Kong

### Konga (Advanced Admin UI)
- URL: http://localhost:1337
- More feature-rich administration interface
- Third-party tool with advanced features

### Admin API
- Base URL: http://localhost:8001
- RESTful API for Kong management
- Example: `curl http://localhost:8001/services`

## Testing the Setup

### Test Kong Health
```bash
curl http://localhost:8000/kong-health
```

### Test APISIX through Kong
```bash
curl http://localhost:8000/apisix-proxy/apisix/status
```

### Test Direct APISIX (still works)
```bash
curl http://localhost:9080/apisix/status
```

## Configuration Files

- `kong_conf/kong.yml`: Kong declarative configuration
- `docker-compose.yml`: Updated with Kong services

## Database

Kong uses PostgreSQL for storing configuration:
- Database: `kong`
- User: `kong`
- Password: `kongpassword`
- Host: `kong-database:5432` (internal)
- External access: `localhost:5432`

## Troubleshooting

### Check Service Status
```bash
docker-compose ps
```

### View Kong Logs
```bash
docker-compose logs kong
```

### Restart Kong Services
```bash
docker-compose restart kong
```

### Reset Kong Database
```bash
docker-compose down
docker volume rm apisix-workshop_kong_database_data
docker-compose up -d
```

## Next Steps

1. **Access Konga**: Go to http://localhost:1337 to explore Kong's features
2. **Create Routes**: Use Konga or Admin API to create additional routes
3. **Configure Plugins**: Add authentication, rate limiting, etc.
4. **Load Balancing**: Set up upstream services for load balancing
5. **Monitoring**: Integrate with your monitoring stack

## Coexistence with APISIX

Both gateways can run simultaneously:
- Use APISIX for existing services and workflows
- Use Kong for new services or specific use cases
- Route traffic between gateways as needed
- Compare features and performance

## Security Notes

- Default Kong configuration allows all admin access
- Change default passwords in production
- Configure proper authentication for admin interfaces
- Review and restrict CORS settings as needed
