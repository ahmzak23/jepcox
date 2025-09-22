# Database Setup for HES-Kaifa Events

This document explains how to use the PostgreSQL database with the HES-Kaifa consumer.

## Quick Start

The database is now automatically configured in `docker-compose.yml`:

```bash
# Start all services including PostgreSQL
docker-compose up -d

# Check if database is ready
docker-compose logs postgres

# Test database connection
python test_database.py
```

## Database Configuration

### PostgreSQL Service
- **Host**: `postgres` (internal) / `localhost:5432` (external)
- **Database**: `hes_kaifa_events`
- **User**: `hes_app_user`
- **Password**: `secure_password`
- **Port**: `5432`

### Automatic Schema Setup
The database schema is automatically created when PostgreSQL starts for the first time using the `database_schema.sql` file.

## Services Overview

### 1. PostgreSQL Database
```yaml
postgres:
  image: postgres:15-alpine
  environment:
    POSTGRES_DB: hes_kaifa_events
    POSTGRES_USER: hes_app_user
    POSTGRES_PASSWORD: secure_password
  volumes:
    - postgres_data:/var/lib/postgresql/data
    - ./database_schema.sql:/docker-entrypoint-initdb.d/01-schema.sql
```

### 2. HES Consumer (with Database)
```yaml
hes-consumer:
  depends_on:
    postgres:
      condition: service_healthy
  command: >
    python run_consumer.py --enable-database
```

## Database Features

### Tables Created
- `hes_events` - Main events table
- `event_headers` - Header information
- `event_payloads` - Payload data
- `event_details` - Key-value measurements
- `event_assets` - Asset information
- `event_status` - Status information
- `event_usage_points` - Usage point data
- `event_metadata` - Metadata
- `event_original_messages` - Original message data

### Views Available
- `v_complete_events` - Complete event view
- `v_event_details` - Event details with measurements

### Functions Available
- `insert_hes_event_from_json(json_data JSONB)` - Insert event from JSON

## Usage Examples

### Query All Events
```sql
SELECT * FROM v_complete_events ORDER BY event_timestamp DESC LIMIT 10;
```

### Query Events by Severity
```sql
SELECT severity, COUNT(*) as count 
FROM event_payloads 
GROUP BY severity 
ORDER BY count DESC;
```

### Query Event Measurements
```sql
SELECT * FROM v_event_details 
WHERE detail_name = 'Frequency' 
ORDER BY event_timestamp DESC;
```

## Testing

### Test Database Connection
```bash
python test_database.py
```

### Test Consumer with Database
```bash
# Send test message
curl -X POST http://localhost:9085/hes-mock-generator \
  -H "Content-Type: application/json" \
  -d '{"test": "database message"}'

# Check database
docker exec apisix-workshop-postgres psql -U hes_app_user -d hes_kaifa_events -c "SELECT COUNT(*) FROM hes_events;"
```

## Monitoring

### Check Database Status
```bash
# Check if PostgreSQL is running
docker-compose ps postgres

# Check database logs
docker-compose logs postgres

# Check database size
docker exec apisix-workshop-postgres psql -U hes_app_user -d hes_kaifa_events -c "SELECT pg_size_pretty(pg_database_size('hes_kaifa_events'));"
```

### Check Consumer Database Logs
```bash
# Check if consumer is connecting to database
docker-compose logs hes-consumer | grep -i database
```

## Troubleshooting

### Database Connection Issues
1. **Check if PostgreSQL is running**: `docker-compose ps postgres`
2. **Check database logs**: `docker-compose logs postgres`
3. **Test connection**: `python test_database.py`

### Schema Issues
1. **Check if schema was created**: 
   ```bash
   docker exec apisix-workshop-postgres psql -U hes_app_user -d hes_kaifa_events -c "\dt"
   ```

### Consumer Database Issues
1. **Check consumer logs**: `docker-compose logs hes-consumer`
2. **Verify database is healthy**: `docker-compose ps postgres`
3. **Check network connectivity**: Consumer should be able to reach `postgres:5432`

## Production Considerations

### Security
- Change default passwords
- Use environment variables for sensitive data
- Enable SSL connections
- Implement proper user roles

### Performance
- Monitor database performance
- Consider connection pooling
- Implement proper indexing
- Regular maintenance (VACUUM, ANALYZE)

### Backup
```bash
# Backup database
docker exec apisix-workshop-postgres pg_dump -U hes_app_user hes_kaifa_events > backup_$(date +%Y%m%d_%H%M%S).sql

# Restore database
docker exec -i apisix-workshop-postgres psql -U hes_app_user hes_kaifa_events < backup_file.sql
```

## Environment Variables

You can override database configuration using environment variables:

```bash
# Set database host
export DB_HOST=your-db-host

# Set database credentials
export DB_USER=your-username
export DB_PASSWORD=your-password
export DB_NAME=your-database
```

## Port Access

- **PostgreSQL**: `localhost:5432`
- **APISIX Gateway**: `localhost:9080`
- **Kafka UI**: `localhost:8080`
- **Web Services**: `localhost:9081`, `localhost:9085`
