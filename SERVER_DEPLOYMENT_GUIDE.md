# Server Deployment Guide

Complete guide for deploying Kong API Gateway and Kafka to a production server.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Kafka Setup](#kafka-setup)
3. [Kong Setup](#kong-setup)
4. [Verification](#verification)
5. [Troubleshooting](#troubleshooting)

## 🎯 Prerequisites

### Required Software
- Docker Engine 20.10+
- Docker Compose 2.0+
- curl or wget
- bash (Linux/Mac) or PowerShell/CMD (Windows)

### System Requirements
- **CPU**: 4+ cores recommended
- **RAM**: 8GB+ recommended
- **Disk**: 50GB+ free space
- **Network**: Stable internet connection

### Port Requirements
Ensure these ports are available:
- **8000-8002**: Kong (Proxy, Admin API, Manager)
- **1337**: Konga Admin UI
- **9093**: Kafka Broker
- **2181**: Zookeeper
- **5432**: PostgreSQL (Kong & Konga databases)

## 🚀 Quick Start

### One-Command Setup

**Linux/Mac:**
```bash
# Make scripts executable
chmod +x kafka-server-setup-standalone.sh setup-kong-endpoints.sh

# Setup Kafka
./kafka-server-setup-standalone.sh

# Setup Kong
./setup-kong-endpoints.sh
```

**Windows:**
```batch
# Setup Kafka
kafka-server-setup-standalone.bat

# Setup Kong
setup-kong-endpoints.bat
```

## 📦 Kafka Setup

### Option 1: Standalone Script (Recommended)

This script checks everything and sets up Kafka completely.

**Linux/Mac:**
```bash
chmod +x kafka-server-setup-standalone.sh
./kafka-server-setup-standalone.sh
```

**Windows:**
```batch
kafka-server-setup-standalone.bat
```

**What it does:**
- ✅ Checks prerequisites
- ✅ Verifies Kafka connectivity
- ✅ Creates 4 topics with proper configurations
- ✅ Documents consumer groups
- ✅ Tests Kafka functionality
- ✅ Provides detailed summary

### Option 2: Quick Topic Creation

If you just need to create topics quickly:

**Linux/Mac:**
```bash
chmod +x create-all-kafka-topics.sh
./create-all-kafka-topics.sh
```

**Windows:**
```batch
create-all-kafka-topics.bat
```

### Topics Created

| Topic Name | Partitions | Replication | Retention | Purpose |
|------------|------------|-------------|-----------|---------|
| hes-kaifa-outage-topic | 3 | 1 | 7 days | HES Kaifa smart meter outages |
| scada-outage-topic | 3 | 1 | 7 days | SCADA system alarms |
| call_center_upstream_topic | 3 | 1 | 7 days | Call center tickets |
| onu-events-topic | 3 | 1 | 7 days | ONU network events |

### Consumer Groups (Auto-created)

These groups are created automatically when consumers connect:
- `hes-kaifa-consumer-group`
- `scada-consumer-group`
- `call-center-consumer-group`
- `onu-consumer-group`

## 🌐 Kong Setup

### Option 1: Automated Setup Script

**Linux/Mac:**
```bash
chmod +x setup-kong-endpoints.sh
./setup-kong-endpoints.sh
```

**Windows:**
```batch
setup-kong-endpoints.bat
```

**PowerShell:**
```powershell
.\setup-kong-endpoints.ps1
```

**What it does:**
- ✅ Waits for Kong to be ready
- ✅ Creates 4 Kong services
- ✅ Creates 4 Kong routes
- ✅ Adds CORS plugins
- ✅ Tests all endpoints
- ✅ Provides detailed summary

### Services & Routes Created

| Service | Route Path | Methods | Upstream |
|---------|-----------|---------|----------|
| hes-mock-generator-service | /hes-mock-generator | GET, POST | kaifa_hes_upstram:80 |
| scada-mock-generator-service | /scada-mock-generator | GET, POST | scada_upstram:80 |
| call-center-ticket-generator-service | /call-center-ticket-generator | GET, POST | call_center_upstream:80 |
| onu-mock-generator-service | /onu-mock-generator | GET, POST | onu_upstream:80 |

### Kong Access Points

After setup, access Kong via:
- **Kong Proxy**: http://localhost:8000
- **Kong Admin API**: http://localhost:8001
- **Kong Manager**: http://localhost:8002
- **Konga Admin**: http://localhost:1337

## ✅ Verification

### Verify Kafka

```bash
# List all topics
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --list

# Check topic details
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --topic hes-kaifa-outage-topic

# List consumer groups
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list

# Check consumer group details
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group hes-kaifa-consumer-group \
  --describe
```

### Verify Kong

```bash
# Check Kong status
curl http://localhost:8001/status

# List all services
curl http://localhost:8001/services

# List all routes
curl http://localhost:8001/routes

# Test endpoints
curl http://localhost:8000/hes-mock-generator
curl http://localhost:8000/call-center-ticket-generator
curl http://localhost:8000/onu-mock-generator
```

### Test End-to-End Flow

```bash
# Test HES endpoint through Kong
curl -X GET http://localhost:8000/hes-mock-generator

# Expected response: Kafka publishing confirmation
{
  "kafka_info": {
    "offset": 123,
    "partition": 1,
    "topic": "hes-kaifa-outage-topic"
  },
  "kafka_published": true,
  "message": "Request published to Kafka"
}
```

## 🔧 Manual Setup Commands

### Kafka Manual Setup

```bash
# Create HES topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic hes-kaifa-outage-topic \
  --partitions 3 --replication-factor 1 \
  --config retention.ms=604800000 \
  --if-not-exists

# Create SCADA topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic scada-outage-topic \
  --partitions 3 --replication-factor 1 \
  --config retention.ms=604800000 \
  --if-not-exists

# Create Call Center topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic call_center_upstream_topic \
  --partitions 3 --replication-factor 1 \
  --config retention.ms=604800000 \
  --if-not-exists

# Create ONU topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic onu-events-topic \
  --partitions 3 --replication-factor 1 \
  --config retention.ms=604800000 \
  --if-not-exists
```

### Kong Manual Setup

```bash
# Create HES service
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hes-mock-generator-service",
    "url": "http://apisix-workshop-kaifa_hes_upstram-1:80"
  }'

# Create HES route
curl -X POST http://localhost:8001/services/hes-mock-generator-service/routes \
  -H "Content-Type: application/json" \
  -d '{
    "name": "hes-mock-generator-route",
    "paths": ["/hes-mock-generator"],
    "methods": ["GET", "POST"]
  }'

# Add CORS plugin
curl -X POST http://localhost:8001/services/hes-mock-generator-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "cors",
    "config": {
      "origins": ["*"],
      "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
      "credentials": true
    }
  }'
```

## 🚨 Troubleshooting

### Kafka Issues

**Problem: Cannot connect to Kafka**
```bash
# Check if Kafka is running
docker ps | grep kafka

# Check Kafka logs
docker logs apisix-workshop-kafka --tail 50

# Restart Kafka
docker-compose restart kafka

# Wait for Kafka to be ready
sleep 10
```

**Problem: Topics not created**
```bash
# Check Zookeeper connection
docker exec apisix-workshop-kafka \
  kafka-broker-api-versions --bootstrap-server localhost:9093

# Manually create topic
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --create --topic test-topic \
  --partitions 1 --replication-factor 1
```

**Problem: Consumer groups not appearing**
```bash
# This is normal - consumer groups appear when consumers connect
# Start your consumers and check again:
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --list
```

### Kong Issues

**Problem: Kong not responding**
```bash
# Check Kong status
docker ps | grep kong

# Check Kong logs
docker logs apisix-workshop-kong --tail 50

# Restart Kong
docker-compose restart kong

# Wait for Kong to be ready
sleep 10
```

**Problem: Routes returning 404**
```bash
# Verify services exist
curl http://localhost:8001/services

# Verify routes exist
curl http://localhost:8001/routes

# Check upstream services are running
docker ps | grep upstream
```

**Problem: CORS errors**
```bash
# Check CORS plugin is installed
curl http://localhost:8001/plugins | jq '.data[] | select(.name == "cors")'

# Reinstall CORS plugin
curl -X POST http://localhost:8001/services/<service-name>/plugins \
  -H "Content-Type: application/json" \
  -d '{"name": "cors", "config": {"origins": ["*"]}}'
```

### Container Issues

**Problem: Container not found**
```bash
# List all containers
docker ps -a

# Start all services
docker-compose up -d

# Check specific container
docker inspect <container-name>
```

**Problem: Port conflicts**
```bash
# Check what's using the port
netstat -an | grep 8000  # Linux/Mac
netstat -an | findstr 8000  # Windows

# Stop conflicting service or change port in docker-compose.yml
```

## 📊 Monitoring

### Kafka Monitoring

```bash
# Check broker status
docker exec apisix-workshop-kafka kafka-broker-api-versions \
  --bootstrap-server localhost:9093

# Monitor consumer lag
docker exec apisix-workshop-kafka kafka-consumer-groups \
  --bootstrap-server localhost:9093 \
  --group hes-kaifa-consumer-group \
  --describe

# Check under-replicated partitions
docker exec apisix-workshop-kafka kafka-topics \
  --bootstrap-server localhost:9093 \
  --describe --under-replicated-partitions
```

### Kong Monitoring

```bash
# Check Kong health
curl http://localhost:8001/status

# Monitor service health
curl http://localhost:8001/services/<service-name>/health

# Check route metrics
curl http://localhost:8001/routes/<route-name>
```

## 🔒 Security Considerations

### Production Checklist

- [ ] Change default passwords
- [ ] Enable authentication on Kong Admin API
- [ ] Configure SSL/TLS certificates
- [ ] Restrict CORS origins
- [ ] Enable rate limiting
- [ ] Set up firewall rules
- [ ] Configure network security groups
- [ ] Enable audit logging
- [ ] Set up monitoring alerts
- [ ] Regular backup schedule

### Recommended Plugins

```bash
# Rate limiting
curl -X POST http://localhost:8001/services/<service-name>/plugins \
  -d "name=rate-limiting" \
  -d "config.minute=100"

# IP restriction
curl -X POST http://localhost:8001/services/<service-name>/plugins \
  -d "name=ip-restriction" \
  -d "config.allow=10.0.0.0/8"

# Request logging
curl -X POST http://localhost:8001/services/<service-name>/plugins \
  -d "name=http-log" \
  -d "config.http_endpoint=http://your-log-server/logs"
```

## 📚 Additional Resources

- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Kong Documentation](https://docs.konghq.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [KAFKA_MIGRATION_GUIDE.md](./KAFKA_MIGRATION_GUIDE.md) - Detailed Kafka migration guide

## 🎉 Success Criteria

Your deployment is successful when:

✅ All Kafka topics are created (4 topics)
✅ Kafka is accepting connections
✅ All Kong services are created (4 services)
✅ All Kong routes are working (4 routes)
✅ Test messages flow through Kafka
✅ API requests flow through Kong
✅ Consumer groups are consuming messages
✅ No errors in container logs

## 📞 Support

If you encounter issues:

1. Check the troubleshooting section
2. Review container logs
3. Verify all prerequisites are met
4. Ensure ports are not in use
5. Check Docker and Docker Compose versions

---

**Last Updated**: October 2025
**Version**: 1.0.0
