# OMS Meter Correlation Enhancement - README

## 📋 Overview

This enhancement establishes **comprehensive meter correlation** across all four OMS data providers (SCADA, ONU, KAIFA, CALL CENTER), enabling **automatic outage detection** when SCADA substation events occur.

## 🎯 Problem Solved

### Before Enhancement
- ❌ No unified meter registry
- ❌ SCADA events only tracked substations, not individual meters
- ❌ No automatic meter status checking when substation fails
- ❌ Manual correlation required between infrastructure and customer impact

### After Enhancement
- ✅ **Central meter registry** (`oms_meters`) - single source of truth
- ✅ **Substation-to-meter mapping** - know which meters each substation controls
- ✅ **Automatic meter checking** - SCADA events trigger meter status pings
- ✅ **Intelligent outage detection** - offline meters = outage events
- ✅ **Multi-source correlation** - events from all 4 providers linked to same outage

## 📁 Files Created

### Core Schema Files
```
construction/
├── oms_meter_correlation_enhancement.sql    # Main enhancement schema
├── oms_meter_migration_script.sql           # Data migration from existing tables
├── OMS_METER_CORRELATION_GUIDE.md          # Complete documentation
└── README_METER_CORRELATION.md             # This file
```

### Alter Scripts (for existing databases)
```
construction/alter_scripts/
├── 01_alter_scada_schema.sql               # SCADA schema updates
├── 02_alter_onu_schema.sql                 # ONU schema updates
├── 03_alter_kaifa_schema.sql               # KAIFA schema updates
└── 04_alter_callcenter_schema.sql          # CALL CENTER schema updates
```

## 🚀 Quick Start

### Option A: New Installation

```bash
# 1. Apply base OMS schema (if not already applied)
psql -U postgres -d oms_db -f construction/oms_correlated_schema.sql

# 2. Apply meter correlation enhancement
psql -U postgres -d oms_db -f construction/oms_meter_correlation_enhancement.sql

# 3. Migrate existing data
psql -U postgres -d oms_db -f construction/oms_meter_migration_script.sql

# 4. Apply service-specific alterations
psql -U postgres -d oms_db -f construction/alter_scripts/01_alter_scada_schema.sql
psql -U postgres -d oms_db -f construction/alter_scripts/02_alter_onu_schema.sql
psql -U postgres -d oms_db -f construction/alter_scripts/03_alter_kaifa_schema.sql
psql -U postgres -d oms_db -f construction/alter_scripts/04_alter_callcenter_schema.sql
```

### Option B: Existing Installation (Incremental)

```bash
# 1. Apply only the meter correlation enhancement
psql -U postgres -d oms_db -f construction/oms_meter_correlation_enhancement.sql

# 2. Apply alter scripts to existing service schemas
psql -U postgres -d oms_db -f construction/alter_scripts/01_alter_scada_schema.sql
psql -U postgres -d oms_db -f construction/alter_scripts/02_alter_onu_schema.sql
psql -U postgres -d oms_db -f construction/alter_scripts/03_alter_kaifa_schema.sql
psql -U postgres -d oms_db -f construction/alter_scripts/04_alter_callcenter_schema.sql

# 3. Migrate existing data
psql -U postgres -d oms_db -f construction/oms_meter_migration_script.sql
```

## 🗂️ Database Structure

### New Core Tables

| Table | Purpose |
|-------|---------|
| `oms_meters` | Central registry for ALL meters from all sources |
| `network_substation_meters` | Maps substations to meters they control |
| `network_feeder_meters` | Maps feeders to meters they supply |
| `oms_meter_status_events` | Audit trail of all meter status changes |
| `scada_event_affected_meters` | Links SCADA events to checked meters |

### Integration Points

| Service | Integration Method | Link Field |
|---------|-------------------|------------|
| **SCADA** | Via substation/feeder topology | `substation_id`, `feeder_id` |
| **ONU** | Direct link via ONU ID | `onu_id`, `onu_serial_no` |
| **KAIFA** | Via asset/usage point mRID | `asset_mrid`, `usage_point_mrid` |
| **CALL CENTER** | Via meter number string | `meter_number` |

## 🔄 Workflow: SCADA Event Processing

```
┌─────────────────────────────────────────────────────────────┐
│  1. SCADA Breaker Trip Event Received                       │
│     - Substation: SS001                                     │
│     - Feeder: FD002                                         │
│     - Timestamp: 2025-09-30 10:00:00                        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Query All Meters Under Substation/Feeder               │
│     - Uses: network_substation_meters                       │
│     - Uses: network_feeder_meters                           │
│     - Result: 150 meters found                              │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Check Status of Each Meter                              │
│     For each meter:                                         │
│     - Check power_status                                    │
│     - Check communication_status                            │
│     - Check last_communication (timeout if > 15 min)        │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  4. Identify Offline Meters                                 │
│     - 45 meters offline (power_status = 'off')             │
│     - 95 meters online                                      │
│     - 10 meters unknown                                     │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  5. Record Affected Meters                                  │
│     - Insert into: scada_event_affected_meters              │
│     - Update oms_meters: set power_status = 'off'          │
│     - Insert into: oms_meter_status_events                  │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  6. Create OMS Outage Event                                 │
│     - Event ID: OMS_SCADA_1727686800_a3f8b2c1              │
│     - Affected customers: 45                                │
│     - Confidence: 0.9 (high - from SCADA)                   │
│     - Status: detected                                      │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  7. Link SCADA Event to Outage                              │
│     - Insert into: oms_event_sources                        │
│     - Update scada_events.outage_event_id                   │
│     - Insert timeline entry                                 │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│  8. Return Summary                                          │
│     {                                                       │
│       "total_meters": 150,                                  │
│       "offline_meters": 45,                                 │
│       "outage_event_id": "uuid"                             │
│     }                                                       │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Key Functions

### 1. `process_scada_event_meters()`
**Purpose**: Check all meters when SCADA event occurs

```sql
SELECT * FROM process_scada_event_meters(
    p_scada_event_id := 'uuid-here',
    p_substation_id := 'SS001',
    p_feeder_id := 'FD002',
    p_event_timestamp := NOW()
);
-- Returns: total_meters, offline_meters, online_meters, unknown_meters, outage_event_id
```

### 2. `insert_scada_event_with_meter_check()`
**Purpose**: Insert SCADA event + automatically check meters

```sql
SELECT insert_scada_event_with_meter_check('{
  "eventType": "breaker_trip",
  "substationId": "SS001",
  "feederId": "FD002",
  "timestamp": "2025-09-30T10:00:00Z",
  "voltage": 0.0,
  "alarmType": "fault",
  "severity": "critical"
}'::jsonb);
```

### 3. `get_meters_by_substation()`
**Purpose**: Query all meters under a substation

```sql
SELECT * FROM get_meters_by_substation('SS001');
```

### 4. `get_meters_by_feeder()`
**Purpose**: Query all meters on a feeder

```sql
SELECT * FROM get_meters_by_feeder('FD002');
```

### 5. `update_meter_status()`
**Purpose**: Update individual meter status with audit trail

```sql
SELECT update_meter_status(
    p_meter_number := 'M12345678',
    p_new_status := 'off',
    p_event_type := 'power_off',
    p_source_type := 'onu',
    p_source_event_id := 'ONU_EVENT_123'
);
```

## 📊 Useful Views

### Network Substations with Meter Counts
```sql
SELECT * FROM network_substations_with_meters;
-- Shows: substation, total/online/offline/unknown meter counts
```

### Meters with Full Topology
```sql
SELECT * FROM oms_meters_with_topology
WHERE power_status = 'off';
-- Shows: meter + customer + substation + feeder + DP info
```

### Active Outages
```sql
SELECT * FROM oms_active_outages;
-- Shows: current outages with source counts and infrastructure
```

## 🔍 Common Queries

### Find Offline Meters by Substation
```sql
SELECT 
    m.meter_number,
    m.power_status,
    m.last_communication,
    c.phone as customer_phone,
    ns.name as substation_name
FROM oms_meters m
JOIN network_substation_meters nsm ON m.id = nsm.meter_id
JOIN network_substations ns ON nsm.substation_id = ns.id
LEFT JOIN oms_customers c ON m.customer_id = c.id
WHERE ns.substation_id = 'SS001'
AND (m.power_status = 'off' OR m.communication_status = 'offline')
ORDER BY nsm.priority ASC;
```

### SCADA Events with Meter Impact
```sql
SELECT 
    se.substation_id,
    se.feeder_id,
    se.event_timestamp,
    se.affected_meter_count,
    oe.event_id as outage_event_id,
    oe.affected_customers_count
FROM scada_events se
LEFT JOIN oms_outage_events oe ON se.outage_event_id = oe.id
WHERE se.event_timestamp >= NOW() - INTERVAL '24 hours'
AND se.affected_meter_count > 0
ORDER BY se.event_timestamp DESC;
```

### Meter Status History
```sql
SELECT 
    mse.event_timestamp,
    mse.event_type,
    mse.source_type,
    mse.previous_status || ' → ' || mse.new_status as status_change,
    mse.confidence_score
FROM oms_meter_status_events mse
JOIN oms_meters m ON mse.meter_id = m.id
WHERE m.meter_number = 'M12345678'
ORDER BY mse.event_timestamp DESC
LIMIT 20;
```

## 🔄 Consumer Updates Required

### SCADA Consumer
```python
# In services/scada/consumer/scada_consumer.py
# Change from:
cursor.execute("SELECT insert_scada_event_from_json(%s)", ...)

# To:
result = cursor.execute(
    "SELECT insert_scada_event_with_meter_check(%s)", 
    (json.dumps(event_data),)
).fetchone()
logger.info(f"SCADA: {result['offline_meters']} meters offline")
```

### ONU Consumer
```python
# In services/onu/consumer/onu_consumer.py
# Change from:
cursor.execute("SELECT insert_onu_event_from_json(%s)", ...)

# To:
cursor.execute("SELECT insert_onu_event_from_json_with_meter_sync(%s)", ...)
```

### KAIFA Consumer
```python
# In services/kaifa/consumer/hes_kaifa_consumer.py
# Change from:
cursor.execute("SELECT insert_kaifa_event_from_json(%s)", ...)

# To:
cursor.execute("SELECT insert_kaifa_event_from_json_with_meter_sync(%s)", ...)
```

### Call Center Consumer
```python
# In services/call_center/consumer/call_center_consumer.py
# Change from:
cursor.execute("SELECT insert_callcenter_ticket_from_json(%s)", ...)

# To:
cursor.execute("SELECT insert_callcenter_ticket_from_json_with_meter_link(%s)", ...)
```

## 📈 Performance Characteristics

### Indexes Created
- 15+ indexes on `oms_meters`
- Composite indexes on (lat, lng) for geographic queries
- Foreign key indexes on all mapping tables
- Timestamp indexes (DESC) for recent event queries

### Expected Performance
- **Meter lookup by substation**: < 50ms for 1000 meters
- **SCADA event processing**: < 500ms for 150 meters
- **Status history query**: < 100ms for last 100 events
- **Geographic proximity**: < 200ms within 5km radius

### Optimization Tips
1. Archive `oms_meter_status_events` older than 6 months
2. Use materialized views for dashboard aggregations
3. Partition `oms_meter_status_events` by month if > 1M rows/month
4. Consider PostGIS for advanced spatial queries

## 🧪 Testing

### Test SCADA Event Processing
```sql
-- 1. Insert test SCADA event
SELECT insert_scada_event_with_meter_check('{
  "eventType": "breaker_trip",
  "substationId": "SS001",
  "feederId": "FD001",
  "timestamp": "2025-09-30T10:00:00Z",
  "voltage": 0.0,
  "alarmType": "fault",
  "severity": "critical",
  "reason": "Test event"
}'::jsonb);

-- 2. Verify outage created
SELECT * FROM oms_outage_events WHERE root_cause LIKE '%SS001%';

-- 3. Check affected meters
SELECT COUNT(*) FROM scada_event_affected_meters;

-- 4. Verify meter statuses updated
SELECT power_status, COUNT(*) 
FROM oms_meters 
WHERE substation_id = (SELECT id FROM network_substations WHERE substation_id = 'SS001')
GROUP BY power_status;
```

## 📚 Documentation

- **Complete Guide**: `OMS_METER_CORRELATION_GUIDE.md`
- **Architecture**: `ARCHITECTURE.md`
- **API Integration**: `OMS_API_INTEGRATION_GUIDE.md`

## ✅ Validation Checklist

After installation, verify:

- [ ] `oms_meters` table created and populated
- [ ] `network_substation_meters` mapping populated
- [ ] `network_feeder_meters` mapping populated
- [ ] Existing meters migrated from ONU, KAIFA, CALL CENTER
- [ ] SCADA events can trigger meter checks
- [ ] Outage events created for offline meters
- [ ] All four services link to `oms_meters`
- [ ] Views return expected data
- [ ] Indexes exist on all foreign keys

**Run Validation Query**:
```sql
-- Should show summary of meters by source
SELECT 
    COUNT(*) as total_meters,
    COUNT(CASE WHEN onu_id IS NOT NULL THEN 1 END) as from_onu,
    COUNT(CASE WHEN asset_mrid IS NOT NULL THEN 1 END) as from_kaifa,
    COUNT(CASE WHEN substation_id IS NOT NULL THEN 1 END) as linked_to_substation,
    COUNT(CASE WHEN customer_id IS NOT NULL THEN 1 END) as linked_to_customer
FROM oms_meters
WHERE status = 'active';
```

## 🐛 Troubleshooting

### Issue: Meters not linked to substation
**Solution**: Run geographic proximity update in migration script

### Issue: SCADA events not checking meters
**Solution**: Verify alarm_type is in critical list (fault, breaker_trip, power_failure, outage)

### Issue: Duplicate meters
**Solution**: Use merge logic in migration script to consolidate duplicates

## 🎓 Key Concepts

1. **Single Source of Truth**: `oms_meters` is the authoritative meter registry
2. **Many-to-Many Relationships**: Substations can control multiple meters, meters can be on multiple feeders
3. **Automatic Cascade**: SCADA infrastructure events trigger meter-level checks
4. **Multi-Source Correlation**: Events from all sources contribute to outage confidence
5. **Audit Trail**: Complete history of all status changes from all sources

## 📞 Support

For questions or issues:
1. Check `OMS_METER_CORRELATION_GUIDE.md` for detailed documentation
2. Review SQL comments in schema files
3. Examine sample queries in this README

---

**Version**: 1.0  
**Date**: 2025-09-30  
**Status**: ✅ Ready for Production

