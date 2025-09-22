# External Database Setup for HES-Kaifa Events

This guide explains how to configure the HES-Kaifa consumer to use an external PostgreSQL database instead of a containerized one.

## Prerequisites

1. **PostgreSQL Database**: Ensure you have PostgreSQL installed and running
2. **Python Dependencies**: Install required Python packages
3. **Database Access**: Ensure you can connect to your PostgreSQL database

## Quick Setup

### 1. Run the Setup Script
```bash
python setup_database.py
```

This script will:
- Install required dependencies (`psycopg2-binary`)
- Create `database_config.py` from template
- Test database connection
- Set up database schema

### 2. Manual Configuration

If the setup script doesn't work, follow these manual steps:

#### Step 1: Install Dependencies
```bash
pip install psycopg2-binary
```

#### Step 2: Create Database Configuration
Copy the template and update with your database settings:
```bash
cp database_config_template.py database_config.py
```

Edit `database_config.py` and update the database configuration:
```python
# Update these values with your database configuration
self.host = 'your-database-host'  # e.g., 'localhost', '192.168.1.100'
self.port = 5432
self.database = 'hes_kaifa_events'  # Your database name
self.user = 'your-username'  # Your database user
self.password = 'your-password'  # Your database password
```

#### Step 3: Test Database Connection
```bash
python test_database.py
```

#### Step 4: Set Up Database Schema
```bash
# Connect to your database and run the schema
psql -h your-host -U your-user -d your-database -f database_schema.sql
```

## Configuration Options

### Environment Variables
You can use environment variables to configure the database connection:

```bash
# Set environment variables
export DB_HOST=your-database-host
export DB_PORT=5432
export DB_NAME=hes_kaifa_events
export DB_USER=your-username
export DB_PASSWORD=your-password
export DB_SSL_MODE=prefer

# Run the consumer
python Kaifa-HES-Events/run_consumer.py --enable-database
```

### Docker Configuration
If running the consumer in Docker but connecting to an external database:

```bash
# For Docker Desktop on Windows/Mac, use host.docker.internal
export DB_HOST=host.docker.internal

# For Linux or other Docker setups, use your host IP
export DB_HOST=192.168.1.100
```

## Database Schema

The database schema includes the following tables:

- `hes_events` - Main events table
- `event_headers` - Header information
- `event_payloads` - Payload data
- `event_details` - Key-value measurements
- `event_assets` - Asset information
- `event_status` - Status information
- `event_usage_points` - Usage point data
- `event_metadata` - Metadata
- `event_original_messages` - Original message data

## Running the Consumer

### With Database Enabled
```bash
python Kaifa-HES-Events/run_consumer.py --enable-database
```

### With Docker Compose
The consumer will automatically use the external database configuration when `--enable-database` is specified.

## Troubleshooting

### Common Issues

#### 1. Database Connection Failed
```
❌ Database connection test failed: connection to server at "localhost" (127.0.0.1), port 5432 failed: FATAL: password authentication failed for user "hes_app_user"
```

**Solution**: Check your database credentials in `database_config.py`

#### 2. Database Not Found
```
❌ Database connection test failed: FATAL: database "hes_kaifa_events" does not exist
```

**Solution**: Create the database:
```sql
CREATE DATABASE hes_kaifa_events;
```

#### 3. Permission Denied
```
❌ Database connection test failed: FATAL: role "hes_app_user" does not exist
```

**Solution**: Create the database user:
```sql
CREATE USER hes_app_user WITH PASSWORD 'secure_password';
GRANT ALL PRIVILEGES ON DATABASE hes_kaifa_events TO hes_app_user;
```

#### 4. Docker Network Issues
```
❌ Database connection test failed: could not translate host name "localhost" to address
```

**Solution**: Use `host.docker.internal` for Docker Desktop or your host IP address.

### Testing Database Connection

```bash
# Test from host
python test_database.py

# Test from Docker container
docker exec apisix-workshop-hes-consumer python test_database.py
```

### Checking Database Status

```bash
# Check if PostgreSQL is running
pg_isready -h your-host -p 5432

# Connect to database
psql -h your-host -U your-user -d your-database

# Check tables
\dt

# Check data
SELECT COUNT(*) FROM hes_events;
```

## Security Considerations

### Production Setup
1. **Use strong passwords**
2. **Enable SSL connections**
3. **Restrict database access**
4. **Use environment variables for sensitive data**
5. **Regular security updates**

### Example Production Configuration
```python
# database_config.py for production
self.host = os.getenv('DB_HOST', 'your-production-db-host')
self.port = int(os.getenv('DB_PORT', '5432'))
self.database = os.getenv('DB_NAME', 'hes_kaifa_events')
self.user = os.getenv('DB_USER', 'hes_app_user')
self.password = os.getenv('DB_PASSWORD')  # Set via environment
self.ssl_mode = os.getenv('DB_SSL_MODE', 'require')
```

## Monitoring

### Check Consumer Logs
```bash
# Check if consumer is connecting to database
docker-compose logs hes-consumer | grep -i database
```

### Check Database Performance
```sql
-- Check table sizes
SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Check recent events
SELECT COUNT(*) as total_events, 
       MAX(created_at) as latest_event
FROM hes_events;
```

## Backup and Recovery

### Backup Database
```bash
pg_dump -h your-host -U your-user -d your-database > backup_$(date +%Y%m%d_%H%M%S).sql
```

### Restore Database
```bash
psql -h your-host -U your-user -d your-database < backup_file.sql
```

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Verify your database configuration
3. Test database connection manually
4. Check consumer logs for specific error messages
5. Ensure all dependencies are installed correctly
