# OMS Setup Guide

## Complete Setup for Real-Time Outage Management

### 1. Environment Configuration

Create `.env` file next to `docker-compose.yml`:
```env
DATABASE_URL=postgresql://postgres:your_password@host.docker.internal:5432/oms_db
```

### 2. Build and Start OMS API

```bash
# Build and start the OMS ingestion API
docker compose up -d --build oms-api

# Verify it's running
curl http://localhost:9100/health
```

### 3. Run Initial Data Migration (One-time)

```bash
# Backfill existing data into OMS schema
docker compose run --rm oms-migrator
```

### 4. Enable Real-Time Correlation in Consumers

Set environment variables to enable OMS API calls in all consumers:

#### Option A: Docker Compose Environment
Add to each consumer service in `docker-compose.yml`:
```yaml
environment:
  - OMS_API_URL=http://oms-api:8000  # Inside Docker network
  - OMS_CORR_WINDOW_MIN=30
  - OMS_SPATIAL_RADIUS_M=1000
```

#### Option B: Shell Environment
```bash
export OMS_API_URL=http://localhost:9100
export OMS_CORR_WINDOW_MIN=30
export OMS_SPATIAL_RADIUS_M=1000
```

### 5. Restart Consumers with OMS Integration

```bash
# Restart all consumers to pick up OMS_API_URL
docker compose restart hes-consumer scada-consumer call-center-consumer onu-consumer
```

### 6. Verify Real-Time Correlation

#### Send Test Events
```bash
# Test SCADA event
curl -X POST http://localhost:9100/api/oms/events/correlate \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "outage",
    "source_type": "scada",
    "source_event_id": "test_scada_001",
    "timestamp": "2025-09-25T10:15:00Z",
    "latitude": 31.9454,
    "longitude": 35.9284,
    "correlation_window_minutes": 30,
    "spatial_radius_meters": 1000
  }'

# Test ONU event (should correlate with SCADA if within 30min/1000m)
curl -X POST http://localhost:9100/api/oms/events/correlate \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "outage",
    "source_type": "onu",
    "source_event_id": "test_onu_001",
    "timestamp": "2025-09-25T10:20:00Z",
    "latitude": 31.9455,
    "longitude": 35.9285,
    "correlation_window_minutes": 30,
    "spatial_radius_meters": 1000
  }'
```

#### Check Results in Database
```sql
-- View active outages with correlation
SELECT * FROM oms_active_outages ORDER BY first_detected_at DESC LIMIT 10;

-- View correlation summary
SELECT * FROM oms_correlation_summary ORDER BY outage_event_id LIMIT 10;

-- View event timeline
SELECT outage_event_id, event_type, status, timestamp, description
FROM oms_event_timeline
ORDER BY timestamp DESC LIMIT 20;
```

### 7. Optional: APISIX Gateway Integration

To expose OMS API through APISIX gateway:

```bash
# Add the OMS route to APISIX
curl -X POST http://localhost:9180/apisix/admin/routes/oms-api \
  -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
  -H "Content-Type: application/json" \
  -d @construction/apisix_oms_route.json
```

Then access via: `http://localhost:9080/oms/api/oms/events/correlate`

### 8. Monitoring and Validation

#### Quick Health Checks
```bash
# API health
curl http://localhost:9100/health

# Database connectivity from container
docker compose run --rm oms-migrator bash -c "psql \$DATABASE_URL -c 'select count(*) from oms_outage_events;'"

# Kafka UI (existing)
open http://localhost:8080
```

#### Event Flow Validation
1. **Producers** → Kafka topics
2. **Consumers** → Store in service DB + Call OMS API
3. **OMS API** → Correlate events in OMS DB
4. **Check results** in `oms_active_outages` view

### 9. Troubleshooting

#### Common Issues

**OMS API not reachable from consumers:**
- Use `http://oms-api:8000` inside Docker
- Use `http://localhost:9100` outside Docker

**Database connection errors:**
- Verify `.env` DATABASE_URL is correct
- Ensure PostgreSQL accepts connections from Docker
- Check firewall settings

**No correlation happening:**
- Verify `OMS_API_URL` is set in consumer environment
- Check consumer logs for "OMS API call failed" warnings
- Ensure events have valid timestamps and locations

**Low confidence scores:**
- Check source weights (SCADA=1.0, Kaifa=0.8, ONU=0.6, Call Center=0.4)
- Verify events are within correlation window (30min default)
- Check spatial proximity (1000m default)

### 10. Production Considerations

#### Security
- Create dedicated database user with minimal privileges
- Use proper authentication for OMS API
- Enable HTTPS for external access

#### Performance
- Monitor database performance with many events
- Consider connection pooling for high-volume scenarios
- Add database indexes as needed

#### Monitoring
- Set up alerts for failed OMS API calls
- Monitor correlation confidence scores
- Track event processing latency

#### Backup
- Schedule regular database backups
- Export OMS configuration (correlation rules, storm mode settings)

### 11. Next Steps

1. **Dashboard**: Build web UI using `oms_active_outages` and `oms_correlation_summary` views
2. **Notifications**: Implement customer notification system
3. **Crew Dispatch**: Add crew assignment and tracking
4. **Storm Mode**: Configure automatic storm mode activation
5. **Analytics**: Add reporting and analytics queries

