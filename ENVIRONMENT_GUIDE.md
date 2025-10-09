# Environment Configuration Guide

## 🎯 Problem Solved

The Docker Compose file now properly uses environment variables from `.env` files, allowing you to have different database configurations for local development and server deployment.

## 📁 Environment Files

### 1. **`oms.env.local`** - Local Development
```bash
DB_HOST=oms-database
DB_PORT=5433
DB_NAME=oms_db
DB_USER=web
DB_PASSWORD=123456
```

### 2. **`oms.env.server`** - Server Template
```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=oms_production
DB_USER=oms_user
DB_PASSWORD=your_secure_password_here
```

### 3. **`oms.env`** - Active Configuration
This is the file that Docker Compose actually uses. It gets created by copying one of the templates above.

## 🚀 Quick Setup Commands

### For Local Development:
```bash
# Setup local environment
chmod +x setup-environment.sh
./setup-environment.sh
# Choose option 2 (Local development)

# Start the system
./start-with-database.sh
```

### For Server Deployment:
```bash
# Setup server environment
chmod +x deploy-to-server.sh
./deploy-to-server.sh

# The script will ask for your database settings
# Then start the system automatically
```

## 🔧 Manual Setup

### Step 1: Choose Environment Template
```bash
# For local development
cp oms.env.local oms.env

# For server deployment
cp oms.env.server oms.env
```

### Step 2: Update Server Settings (if needed)
Edit `oms.env` with your actual server database settings:
```bash
nano oms.env
```

### Step 3: Start the System
```bash
docker compose up -d
```

## 📊 Docker Compose Configuration

The `docker-compose.yml` now includes:
```yaml
services:
  oms-database:
    env_file:
      - oms.env
    environment:
      POSTGRES_DB: ${DB_NAME:-oms_db}
      POSTGRES_USER: ${DB_USER:-web}
      POSTGRES_PASSWORD: ${DB_PASSWORD:-123456}
  
  hes-consumer:
    env_file:
      - oms.env
    environment:
      - DB_HOST=${DB_HOST:-oms-database}
      - DB_PORT=${DB_PORT:-5432}
      # ... other variables
```

## 🎯 Key Benefits

1. **Environment Separation**: Different configs for local vs server
2. **No Hardcoded Values**: All database settings use environment variables
3. **Easy Deployment**: Just copy the right template and update settings
4. **Secure**: Passwords and sensitive data in environment files
5. **Flexible**: Easy to customize for different environments

## 🔒 Security Notes

- **Never commit `oms.env`** to version control (it's in `.gitignore`)
- **Use strong passwords** for production databases
- **Update default passwords** in server environments
- **Use SSL** (`DB_SSL_MODE=require`) for production

## 🐛 Troubleshooting

### Database Connection Issues:
```bash
# Check current configuration
cat oms.env

# Test database connection
docker compose exec hes-consumer python -c "
import psycopg2
import os
conn = psycopg2.connect(
    host=os.getenv('DB_HOST'),
    port=int(os.getenv('DB_PORT')),
    database=os.getenv('DB_NAME'),
    user=os.getenv('DB_USER'),
    password=os.getenv('DB_PASSWORD')
)
print('✅ Connected!')
conn.close()
"
```

### Environment Not Loading:
```bash
# Check if env_file is specified
grep -A 5 "env_file:" docker-compose.yml

# Verify oms.env exists
ls -la oms.env

# Check environment variables in container
docker compose exec hes-consumer env | grep DB_
```

## 📋 Deployment Checklist

- [ ] Copy correct environment template (`oms.env.local` or `oms.env.server`)
- [ ] Update database settings in `oms.env`
- [ ] Ensure database server is running and accessible
- [ ] Test database connection
- [ ] Start the system: `docker compose up -d`
- [ ] Verify all services are running: `docker compose ps`
- [ ] Check consumer logs: `docker compose logs hes-consumer`
