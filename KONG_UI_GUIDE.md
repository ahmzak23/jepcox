# Kong UI Setup Guide

This guide covers all Kong UI interfaces and their setup.

## Available Kong UI Interfaces

### 1. Kong Manager (Official UI)
- **URL**: http://localhost:8002
- **Type**: Official Kong web interface
- **Features**: 
  - Service and route management
  - Plugin configuration
  - Consumer management
  - Real-time monitoring
  - Declarative configuration
- **Setup**: No setup required - direct access

### 2. Konga (Advanced Admin UI)
- **URL**: http://localhost:1337
- **Type**: Third-party advanced administration interface
- **Features**:
  - Advanced service management
  - Plugin marketplace
  - Multi-Kong instance management
  - Advanced monitoring and analytics
  - User management
  - Import/export configurations
- **Setup**: Requires initial admin account creation

### 3. Kong Admin API
- **URL**: http://localhost:8001
- **Type**: RESTful API interface
- **Features**: Programmatic access to all Kong features
- **Usage**: Direct API calls or integration with tools

## Quick Start

### Start All Kong Services with UI
```bash
# Windows
start-kong-ui.bat

# Linux/Mac
./start-kong-ui.sh
```

### Test All UI Interfaces
```bash
test-kong-ui.bat
```

## Detailed Setup Instructions

### Kong Manager Setup
1. **Access**: Navigate to http://localhost:8002
2. **No Authentication**: Direct access (development mode)
3. **Features Available**:
   - View all services, routes, and plugins
   - Create and modify configurations
   - Monitor real-time traffic
   - Export/import configurations

### Konga Setup (First Time)
1. **Access**: Navigate to http://localhost:1337
2. **Create Admin Account**:
   - Fill in required fields
   - Set username and password
   - Complete registration

3. **Add Kong Connection**:
   - Click "Add New Connection"
   - **Connection Name**: `Local Kong`
   - **Kong Admin URL**: `http://kong:8001`
   - **Username**: (leave empty)
   - **Password**: (leave empty)
   - Click "Save Connection"

4. **Select Connection**: Choose your Kong instance from the dropdown

### Konga Features
- **Services Management**: Create, edit, delete services
- **Routes Management**: Configure routing rules
- **Plugins**: Browse and configure plugins
- **Consumers**: Manage API consumers
- **Monitoring**: View metrics and logs
- **Snapshots**: Export/import configurations

## UI Comparison

| Feature | Kong Manager | Konga |
|---------|--------------|-------|
| Official Support | ✅ | ❌ |
| Ease of Use | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Advanced Features | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| Multi-Instance | ❌ | ✅ |
| Plugin Marketplace | ❌ | ✅ |
| User Management | ❌ | ✅ |
| Analytics | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |

## Common Tasks

### Creating a Service
**Kong Manager**:
1. Go to Services → Add Service
2. Fill in service details
3. Save

**Konga**:
1. Go to Services → New Service
2. Fill in service details
3. Save

### Adding a Route
**Kong Manager**:
1. Go to Routes → Add Route
2. Configure path and methods
3. Associate with service
4. Save

**Konga**:
1. Go to Routes → New Route
2. Configure routing rules
3. Save

### Installing Plugins
**Kong Manager**:
1. Go to Plugins → Add Plugin
2. Select plugin type
3. Configure settings
4. Save

**Konga**:
1. Go to Plugins → Available Plugins
2. Browse marketplace
3. Install and configure
4. Save

## Troubleshooting

### Kong Manager Not Loading
```bash
# Check Kong status
curl http://localhost:8001/status

# Restart Kong
docker-compose restart kong
```

### Konga Connection Issues
```bash
# Check Konga logs
docker-compose logs konga

# Restart Konga
docker-compose restart konga
```

### Database Issues
```bash
# Check database status
docker-compose ps | grep database

# Reset Kong database
docker-compose down
docker volume rm apisix-workshop_kong_database_data
docker-compose up -d
```

## Advanced Configuration

### Kong Manager Customization
- Modify Kong configuration in `kong_conf/kong.yml`
- Restart Kong to apply changes

### Konga Customization
- Access Konga database for advanced settings
- Configure user permissions
- Set up multi-environment management

### Security Considerations
- Change default passwords in production
- Configure proper authentication
- Restrict admin access to specific IPs
- Enable HTTPS in production

## Monitoring and Analytics

### Built-in Monitoring
- **Kong Manager**: Basic metrics and logs
- **Konga**: Advanced analytics and monitoring
- **Admin API**: Programmatic access to metrics

### External Monitoring
- Prometheus integration available
- Grafana dashboards supported
- Custom monitoring solutions

## Backup and Recovery

### Configuration Backup
```bash
# Export Kong configuration
curl http://localhost:8001/config > kong-config.json

# Import Kong configuration
curl -X POST http://localhost:8001/config -d @kong-config.json
```

### Database Backup
```bash
# Backup Kong database
docker exec apisix-workshop-kong-database pg_dump -U kong kong > kong-backup.sql

# Backup Konga database
docker exec apisix-workshop-konga-database pg_dump -U konga konga > konga-backup.sql
```

## Best Practices

1. **Use Kong Manager** for basic operations and monitoring
2. **Use Konga** for advanced features and multi-instance management
3. **Use Admin API** for automation and integration
4. **Regular Backups** of both configuration and database
5. **Monitor Performance** using built-in tools
6. **Security Hardening** for production environments
