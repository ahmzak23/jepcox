# OMS Database Configuration Guide

## 🗄️ Database Setup

The OMS system now includes a dedicated PostgreSQL database for storing consumer data.

### Configuration Files

- **`oms.env`** - Environment variables for database configuration
- **`docker-compose.yml`** - Updated with PostgreSQL service and environment variables
- **Database schemas** - Automatically loaded from service directories

### Database Service

```yaml
oms-database:
  image: postgres:13
  container_name: apisix-workshop-oms-database
  environment:
    POSTGRES_DB: oms_db
    POSTGRES_USER: web
    POSTGRES_PASSWORD: 123456
  ports:
    - "5433:5432"  # External port 5433, internal 5432
```

### Environment Variables

All consumers now use these environment variables:

```bash
DB_HOST=oms-database
DB_PORT=5432
DB_NAME=oms_db
DB_USER=web
DB_PASSWORD=123456
DB_SSL_MODE=prefer
```

## 🚀 Quick Start

### 1. Start the System
```bash
chmod +x start-with-database.sh
./start-with-database.sh
```

### 2. Check Status
```bash
docker compose ps | grep -E "(oms-database|consumer)"
```

### 3. Access Database
```bash
# Connect to database
docker compose exec oms-database psql -U web -d oms_db

# Check tables
\dt

# View data
SELECT * FROM hes_kaifa_events LIMIT 5;
```

## 📊 Database Schemas

The following schemas are automatically created:

- **`kaifa_database_schema.sql`** - HES Kaifa events table
- **`scada_database_schema.sql`** - SCADA events table  
- **`call_center_database_schema.sql`** - Call center events table
- **`onu_database_schema.sql`** - ONU events table

## 🔧 Troubleshooting

### Database Connection Issues
```bash
# Check database status
docker compose logs oms-database

# Test connection from consumer
docker compose exec hes-consumer python -c "
import psycopg2
conn = psycopg2.connect(host='oms-database', port=5432, database='oms_db', user='web', password='123456')
print('✅ Connected!')
conn.close()
"
```

### Consumer Issues
```bash
# Check consumer logs
docker compose logs hes-consumer

# Restart consumers
docker compose restart hes-consumer scada-consumer call-center-consumer onu-consumer
```

## 🌐 Access Points

- **Database**: `localhost:5433`
- **Kafka UI**: `http://192.168.2.41:8080/ui/clusters/oms-cluster/consumer-groups`
- **OMS API**: `http://192.168.2.41:9100`

## 📝 Environment Customization

To customize the database configuration, edit `oms.env`:

```bash
# Production example
DB_HOST=your-production-db-host
DB_PORT=5432
DB_NAME=oms_production
DB_USER=your-db-user
DB_PASSWORD=your-secure-password
DB_SSL_MODE=require
```

Then restart the services:
```bash
docker compose down
./start-with-database.sh
```
