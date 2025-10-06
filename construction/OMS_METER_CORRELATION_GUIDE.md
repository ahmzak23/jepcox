# OMS Meter Correlation Enhancement Guide

## Executive Summary

This guide documents the comprehensive enhancement to the OMS (Outage Management System) database schema that establishes proper relationships between **substations, feeders, and meters** across all four data providers: **SCADA, ONU, KAIFA, and CALL CENTER**.

## Problem Analysis

### Original Architecture Limitations

The four OMS data providers had **inconsistent meter identification**:

1. **SCADA**: Uses `substation_id` and `feeder_id` (infrastructure-level)
2. **ONU**: Has `meters` table with `meter_id` linked to ONUs
3. **KAIFA**: Uses `mrid` in assets/usage points as meter identifiers
4. **CALL CENTER**: Uses `meter_number` as a text field in customer data

**Key Issues:**
- No unified meter registry
- No mapping between substations and the meters they control
- SCADA events couldn't automatically check related meter statuses
- No way to determine which meters should be considered "off" when substation fails

### Business Requirement

When a SCADA event is received (e.g., breaker trip, substation fault):
1. System should identify **all meters controlled by that substation/feeder**
2. **Ping/check status** of each meter
3. Meters that are **offline/not responding** should be considered **outage events**
4. Create correlated outage events with affected customer counts

## Solution Architecture

### Core Design Principles

1. **Single Source of Truth**: `oms_meters` table as the central meter registry
2. **Explicit Topology Mapping**: Direct many-to-many relationships between substations/feeders and meters
3. **Multi-Source Integration**: All four data providers reference the same meter records
4. **Automatic Processing**: SCADA events trigger automatic meter status checks
5. **Audit Trail**: Complete history of all meter status changes

### Database Schema Enhancements

```
Network Hierarchy:
  network_substations ──┬──> network_substation_meters ──> oms_meters
                        │
                        └──> network_feeders ──┬──> network_feeder_meters ──> oms_meters
                                               │
                                               └──> network_distribution_points ──> oms_meters

Data Provider Integration:
  oms_meters <──┬── ONU (onu_id, onu_serial_no)
                ├── KAIFA (asset_mrid, usage_point_mrid)
                ├── CALL CENTER (meter_number reference)
                └── SCADA (via substation/feeder mapping)
```

## Implementation Details

### 1. Central Meter Registry (`oms_meters`)

**Purpose**: Unified table containing all meters from all sources

**Key Fields**:
```sql
- meter_number (VARCHAR(64), UNIQUE) -- Primary identifier
- meter_type -- 'smart', 'kaifa', 'analog'
- substation_id, feeder_id, dp_id -- Network topology links
- customer_id -- Customer link
- communication_status -- 'online', 'offline', 'unknown'
- power_status -- 'on', 'off', 'unknown'
- last_communication, last_power_change -- Temporal tracking
- onu_id, onu_serial_no -- ONU integration
- asset_mrid, usage_point_mrid -- Kaifa integration
```

**Integration Points**:
- **ONU**: Links via `onu_id` and `onu_serial_no`
- **KAIFA**: Links via `asset_mrid` and `usage_point_mrid`
- **CALL CENTER**: Links via `meter_number` string matching
- **SCADA**: Links via `substation_id`/`feeder_id` topology mapping

### 2. Substation-Meter Mapping (`network_substation_meters`)

**Purpose**: Defines which meters are controlled by each substation

```sql
CREATE TABLE network_substation_meters (
    substation_id UUID REFERENCES network_substations(id),
    meter_id UUID REFERENCES oms_meters(id),
    feeder_id UUID REFERENCES network_feeders(id),
    priority INTEGER DEFAULT 1, -- 1=critical, 2=high, 3=medium, 4=low
    UNIQUE(substation_id, meter_id)
);
```

**Usage**: When SCADA event occurs at substation SS001, system queries:
```sql
SELECT * FROM get_meters_by_substation('SS001');
```

### 3. Feeder-Meter Mapping (`network_feeder_meters`)

**Purpose**: Defines which meters are supplied by each feeder

```sql
CREATE TABLE network_feeder_meters (
    feeder_id UUID REFERENCES network_feeders(id),
    meter_id UUID REFERENCES oms_meters(id),
    circuit_path VARCHAR(200),
    priority INTEGER DEFAULT 2,
    UNIQUE(feeder_id, meter_id)
);
```

**Usage**: For feeder-specific events:
```sql
SELECT * FROM get_meters_by_feeder('FD001');
```

### 4. Meter Status Events (`oms_meter_status_events`)

**Purpose**: Audit trail of all meter status changes from all sources

```sql
CREATE TABLE oms_meter_status_events (
    meter_id UUID REFERENCES oms_meters(id),
    event_type VARCHAR(50), -- 'power_on', 'power_off', 'communication_lost'
    source_type VARCHAR(32), -- 'scada', 'kaifa', 'onu', 'call_center', 'system'
    source_event_id VARCHAR(100),
    previous_status VARCHAR(20),
    new_status VARCHAR(20),
    event_timestamp TIMESTAMPTZ,
    confidence_score DECIMAL(5,2),
    metadata JSONB
);
```

### 5. SCADA Event Enhancements

**Schema Changes**:
```sql
ALTER TABLE scada_events 
    ADD COLUMN affected_meter_count INTEGER,
    ADD COLUMN meters_checked_at TIMESTAMPTZ,
    ADD COLUMN outage_event_id UUID REFERENCES oms_outage_events(id);

CREATE TABLE scada_event_affected_meters (
    scada_event_id UUID REFERENCES scada_events(id),
    meter_id UUID REFERENCES oms_meters(id),
    meter_status_before VARCHAR(20),
    meter_status_after VARCHAR(20),
    checked_at TIMESTAMPTZ
);
```

## Key Functions and Workflows

### Function: `process_scada_event_meters()`

**Purpose**: Process SCADA event and check all related meter statuses

**Workflow**:
1. Receives SCADA event (substation_id, feeder_id, timestamp)
2. Queries all meters linked to that substation/feeder
3. Checks each meter's status:
   - **Offline**: `power_status = 'off'` OR `communication_status = 'offline'`
   - **Timeout**: No communication in last 15 minutes
   - **Online**: Recent communication + power_status = 'on'
4. For each offline meter:
   - Records in `scada_event_affected_meters`
   - Updates `oms_meters.power_status` to 'off'
   - Creates entry in `oms_meter_status_events`
5. If offline meters detected:
   - Creates `oms_outage_events` record
   - Links SCADA event to outage via `oms_event_sources`
   - Adds timeline entry
6. Returns summary:
   - total_meters, offline_meters, online_meters, unknown_meters
   - outage_event_id (if created)

**Example**:
```sql
SELECT * FROM process_scada_event_meters(
    p_scada_event_id := 'uuid-here',
    p_substation_id := 'SS001',
    p_feeder_id := 'FD002',
    p_event_timestamp := '2025-09-30 10:30:00+03'
);

-- Returns:
-- total_meters | offline_meters | online_meters | unknown_meters | outage_event_id
-- 150          | 45             | 95            | 10             | uuid-of-outage
```

### Function: `insert_scada_event_with_meter_check()`

**Purpose**: Enhanced SCADA event insertion with automatic meter checking

**Workflow**:
1. Inserts SCADA event using existing `insert_scada_event_from_json()`
2. Checks if event is critical (fault, breaker_trip, power_failure, outage)
3. If critical, automatically calls `process_scada_event_meters()`
4. Returns comprehensive result with meter check summary

**Example**:
```sql
SELECT insert_scada_event_with_meter_check('{
  "eventType": "breaker_trip",
  "substationId": "SS001",
  "feederId": "FD002",
  "timestamp": "2025-09-30T10:30:00Z",
  "voltage": 33.5,
  "alarmType": "fault",
  "severity": "critical",
  "reason": "Overcurrent detected",
  "coordinates": {"lat": 31.9500, "lng": 35.9300}
}'::jsonb);

-- Returns:
{
  "scada_event_id": "uuid",
  "meters_checked": true,
  "total_meters": 150,
  "offline_meters": 45,
  "online_meters": 95,
  "unknown_meters": 10,
  "outage_event_id": "uuid"
}
```

### Function: `update_meter_status()`

**Purpose**: Update individual meter status with full audit trail

**Usage**:
```sql
SELECT update_meter_status(
    p_meter_number := 'M12345678',
    p_new_status := 'off',
    p_event_type := 'power_off',
    p_source_type := 'onu',
    p_source_event_id := 'ONU_EVENT_123',
    p_event_timestamp := NOW(),
    p_metadata := '{"reason": "Last gasp signal"}'::jsonb
);
```

## Integration with Data Providers

### SCADA Integration

**Schema Files**: `apisix-workshop/services/scada/db/scada_database_schema.sql`

**Changes Made**:
1. Added `affected_meter_count`, `meters_checked_at`, `outage_event_id` to `scada_events`
2. Created `scada_event_affected_meters` link table
3. Enhanced `insert_scada_event_from_json()` → use `insert_scada_event_with_meter_check()`

**Consumer Update Required**:
```python
# In scada_consumer.py
# Change from:
cursor.execute("SELECT insert_scada_event_from_json(%s)", (json.dumps(event_data),))

# To:
result = cursor.execute(
    "SELECT insert_scada_event_with_meter_check(%s)", 
    (json.dumps(event_data),)
).fetchone()
logger.info(f"SCADA event processed: {result}")
```

### ONU Integration

**Schema Files**: `apisix-workshop/services/onu/db/onu_database_schema.sql`

**Changes Made**:
1. Added `meter_id` to `onu_events` table (links to `oms_meters`)
2. Added `oms_meter_id` to `meters` table (links to `oms_meters`)

**Consumer Update Required**:
```python
# In onu_consumer.py or insert function
# After inserting ONU event, update meter status:
UPDATE oms_meters 
SET 
    power_status = CASE WHEN event_type = 'ONU_PowerRestored' THEN 'on' ELSE 'off' END,
    last_power_change = event_timestamp
WHERE onu_id = event_onu_id;
```

### KAIFA Integration

**Schema Files**: `apisix-workshop/services/kaifa/db/kaifa_database_schema.sql`

**Changes Made**:
1. Added `meter_id` to `kaifa_event_assets` (links to `oms_meters` via `mrid`)
2. Added `meter_id` to `kaifa_event_usage_points` (links via `usage_point_mrid`)

**Consumer Update Required**:
```python
# In hes_kaifa_consumer.py
# After inserting Kaifa event, update meter communication status:
UPDATE oms_meters 
SET 
    last_communication = event_timestamp,
    communication_status = 'online'
WHERE asset_mrid = event_asset_mrid OR usage_point_mrid = event_usage_point_mrid;
```

### CALL CENTER Integration

**Schema Files**: `apisix-workshop/services/call_center/db/call_center_database_schema.sql`

**Changes Made**:
1. Added `meter_id` to `callcenter_customers` (links to `oms_meters` via `meter_number`)

**Consumer Update Required**:
```python
# In call_center_consumer.py
# After inserting customer, link to meter:
UPDATE callcenter_customers cc
SET meter_id = (SELECT id FROM oms_meters WHERE meter_number = cc.meter_number)
WHERE cc.meter_id IS NULL AND cc.meter_number IS NOT NULL;
```

## Migration Strategy

### Step-by-Step Migration

**1. Apply Core Schema (Prerequisite)**
```bash
psql -U postgres -d oms_db -f construction/oms_correlated_schema.sql
```

**2. Apply Meter Correlation Enhancement**
```bash
psql -U postgres -d oms_db -f construction/oms_meter_correlation_enhancement.sql
```

**3. Run Migration Script**
```bash
psql -U postgres -d oms_db -f construction/oms_meter_migration_script.sql
```

**4. Update Individual Service Schemas** (Optional - for new installations)
```bash
psql -U postgres -d oms_db -f services/scada/db/scada_database_schema.sql
psql -U postgres -d oms_db -f services/onu/db/onu_database_schema.sql
psql -U postgres -d oms_db -f services/kaifa/db/kaifa_database_schema.sql
psql -U postgres -d oms_db -f services/call_center/db/call_center_database_schema.sql
```

### Migration Script Features

The `oms_meter_migration_script.sql` performs:

1. **Data Migration**:
   - Migrates meters from ONU `meters` table → `oms_meters`
   - Migrates meter identifiers from Kaifa assets/usage points → `oms_meters`
   - Migrates meter numbers from Call Center customers → `oms_meters`

2. **Topology Establishment**:
   - Links meters to substations via geographic proximity (5km radius)
   - Links meters to feeders via proximity (2km radius)
   - Links meters to distribution points via building_id or proximity (500m)
   - Populates `network_substation_meters` mapping
   - Populates `network_feeder_meters` mapping

3. **Customer Linking**:
   - Links meters to customers via phone (Call Center data)
   - Links via building_id
   - Links via geographic proximity (50m)

4. **Historical Data**:
   - Creates historical meter status events from ONU events
   - Creates events from Kaifa severity data

5. **Validation**:
   - Reports migration statistics
   - Shows substation coverage

## Useful Views

### 1. Substations with Meter Counts
```sql
SELECT * FROM network_substations_with_meters;
-- Shows: substation, total/online/offline/unknown meter counts
```

### 2. Feeders with Meter Counts
```sql
SELECT * FROM network_feeders_with_meters;
-- Shows: feeder, substation, meter counts by status
```

### 3. Meters with Full Topology
```sql
SELECT * FROM oms_meters_with_topology
WHERE communication_status = 'offline';
-- Shows: meter details + customer + substation + feeder + DP info
```

### 4. Active Outages
```sql
SELECT * FROM oms_active_outages;
-- Shows: outage events with source counts, affected infrastructure
```

## Operational Queries

### Check Meters Under Substation
```sql
-- Get all meters controlled by substation SS001
SELECT * FROM get_meters_by_substation('SS001');
```

### Check Offline Meters by Substation
```sql
SELECT 
    ns.substation_id,
    ns.name as substation_name,
    m.meter_number,
    m.power_status,
    m.communication_status,
    m.last_communication,
    c.customer_id,
    c.phone as customer_phone
FROM network_substations ns
JOIN network_substation_meters nsm ON ns.id = nsm.substation_id
JOIN oms_meters m ON nsm.meter_id = m.id
LEFT JOIN oms_customers c ON m.customer_id = c.id
WHERE ns.substation_id = 'SS001'
AND (m.power_status = 'off' OR m.communication_status = 'offline')
ORDER BY nsm.priority ASC, m.meter_number;
```

### Meter Status History
```sql
SELECT 
    mse.event_timestamp,
    mse.event_type,
    mse.source_type,
    mse.previous_status,
    mse.new_status,
    mse.confidence_score,
    m.meter_number
FROM oms_meter_status_events mse
JOIN oms_meters m ON mse.meter_id = m.id
WHERE m.meter_number = 'M12345678'
ORDER BY mse.event_timestamp DESC
LIMIT 20;
```

### SCADA Events with Meter Impact
```sql
SELECT 
    se.event_type,
    se.substation_id,
    se.feeder_id,
    se.event_timestamp,
    se.affected_meter_count,
    se.severity,
    oe.event_id as outage_event_id,
    oe.status as outage_status,
    COUNT(seam.meter_id) as meters_checked
FROM scada_events se
LEFT JOIN oms_outage_events oe ON se.outage_event_id = oe.id
LEFT JOIN scada_event_affected_meters seam ON se.id = seam.scada_event_id
WHERE se.event_timestamp >= NOW() - INTERVAL '24 hours'
GROUP BY se.id, se.event_type, se.substation_id, se.feeder_id, 
         se.event_timestamp, se.affected_meter_count, se.severity,
         oe.event_id, oe.status
ORDER BY se.event_timestamp DESC;
```

## Performance Considerations

### Indexes Created

**oms_meters**:
- `idx_oms_meters_number` (meter_number)
- `idx_oms_meters_substation` (substation_id)
- `idx_oms_meters_feeder` (feeder_id)
- `idx_oms_meters_comm_status` (communication_status)
- `idx_oms_meters_power_status` (power_status)
- Composite: `idx_oms_meters_lat_lng` (location_lat, location_lng)

**Mapping Tables**:
- All foreign keys indexed
- Unique constraints on (substation_id, meter_id) and (feeder_id, meter_id)

**Status Events**:
- `idx_meter_status_events_timestamp` (DESC for recent queries)
- `idx_meter_status_events_meter` (for meter history)

### Query Optimization Tips

1. **Use Views**: Pre-aggregated views for dashboards
2. **Partition `oms_meter_status_events`**: By month if volume is high
3. **Archive Old Events**: Move events older than 6 months to archive table
4. **Cache Meter Counts**: Materialized view for substation/feeder meter counts

## Testing Scenarios

### Scenario 1: SCADA Breaker Trip

**Setup**:
```sql
-- Create substation with 100 meters
INSERT INTO network_substations (substation_id, name, location_lat, location_lng)
VALUES ('SS_TEST', 'Test Substation', 32.0, 36.0);

-- Link meters (assume meters already exist in oms_meters)
INSERT INTO network_substation_meters (substation_id, meter_id)
SELECT (SELECT id FROM network_substations WHERE substation_id = 'SS_TEST'), id
FROM oms_meters LIMIT 100;
```

**Test**:
```sql
SELECT insert_scada_event_with_meter_check('{
  "eventType": "breaker_trip",
  "substationId": "SS_TEST",
  "feederId": "FD_TEST",
  "timestamp": "2025-09-30T10:00:00Z",
  "voltage": 0.0,
  "alarmType": "fault",
  "severity": "critical",
  "reason": "Test breaker trip"
}'::jsonb);
```

**Validate**:
```sql
-- Check outage event created
SELECT * FROM oms_outage_events WHERE root_cause LIKE '%SS_TEST%';

-- Check affected meters recorded
SELECT COUNT(*) FROM scada_event_affected_meters 
WHERE scada_event_id IN (
    SELECT id FROM scada_events WHERE substation_id = 'SS_TEST'
);

-- Check meter statuses updated
SELECT power_status, COUNT(*) 
FROM oms_meters 
WHERE substation_id = (SELECT id FROM network_substations WHERE substation_id = 'SS_TEST')
GROUP BY power_status;
```

### Scenario 2: ONU Last Gasp + SCADA Correlation

**Test Workflow**:
1. Insert ONU last gasp event for meter M001
2. Insert SCADA breaker trip event 2 minutes later
3. Verify both events correlate to same outage

```sql
-- 1. ONU Event
INSERT INTO onu_events (event_id, onu_id, event_type, timestamp, meter_id)
VALUES ('ONU_TEST_001', 3230316, 'ONU_LastGaspAlert', NOW(), 
        (SELECT id FROM oms_meters WHERE meter_number = 'M001'));

-- 2. SCADA Event
SELECT insert_scada_event_with_meter_check('{
  "eventType": "breaker_trip",
  "substationId": "SS001",
  "timestamp": "' || (NOW() + INTERVAL '2 minutes')::text || '",
  ...
}'::jsonb);

-- 3. Verify Correlation
SELECT 
    oe.event_id,
    oe.confidence_score,
    STRING_AGG(es.source_type, ', ') as sources
FROM oms_outage_events oe
JOIN oms_event_sources es ON oe.id = es.outage_event_id
WHERE oe.first_detected_at >= NOW() - INTERVAL '10 minutes'
GROUP BY oe.event_id, oe.confidence_score;
```

## Troubleshooting

### Issue: Meters Not Linked to Substation

**Cause**: Missing topology data or incorrect geographic coordinates

**Fix**:
```sql
-- Check meters without substation
SELECT COUNT(*) FROM oms_meters WHERE substation_id IS NULL;

-- Manually link via proximity
UPDATE oms_meters m
SET substation_id = (
    SELECT ns.id FROM network_substations ns
    ORDER BY haversine_distance_meters(
        m.location_lat, m.location_lng, ns.location_lat, ns.location_lng
    ) ASC LIMIT 1
)
WHERE m.substation_id IS NULL AND m.location_lat IS NOT NULL;
```

### Issue: SCADA Event Not Checking Meters

**Cause**: Event alarm_type not in critical list

**Fix**:
```sql
-- Check alarm types
SELECT DISTINCT alarm_type FROM scada_events;

-- Update function to include more alarm types (in enhancement SQL)
-- Or manually trigger check:
SELECT * FROM process_scada_event_meters(
    'scada-event-uuid',
    'SS001',
    'FD002',
    NOW()
);
```

### Issue: Duplicate Meters

**Cause**: Same meter imported from multiple sources with different identifiers

**Fix**:
```sql
-- Find duplicates by location
SELECT location_lat, location_lng, COUNT(*), STRING_AGG(meter_number, ', ')
FROM oms_meters
GROUP BY location_lat, location_lng
HAVING COUNT(*) > 1;

-- Merge duplicates (keep one, update references, delete others)
-- Use application-specific logic
```

## Next Steps

1. **Consumer Updates**: Update all four consumers to use new functions
2. **API Updates**: Update OMS ingestion service to query new views
3. **Dashboard Updates**: Use new views for real-time meter status
4. **Alerting**: Configure alerts for high offline meter counts
5. **Reporting**: Create reports on substation health and meter coverage

## File References

### Core Schema Files
- `construction/oms_correlated_schema.sql` - Base OMS schema
- `construction/oms_meter_correlation_enhancement.sql` - Meter enhancements (this implementation)
- `construction/oms_meter_migration_script.sql` - Data migration
- `construction/OMS_METER_CORRELATION_GUIDE.md` - This document

### Service Schema Files
- `services/scada/db/scada_database_schema.sql`
- `services/onu/db/onu_database_schema.sql`
- `services/kaifa/db/kaifa_database_schema.sql`
- `services/call_center/db/call_center_database_schema.sql`

### Consumer Files (Require Updates)
- `services/scada/consumer/scada_consumer.py`
- `services/onu/consumer/onu_consumer.py`
- `services/kaifa/consumer/hes_kaifa_consumer.py`
- `services/call_center/consumer/call_center_consumer.py`

## Summary

This enhancement establishes a **complete, unified meter correlation system** that:

✅ **Centralizes** all meter data from SCADA, ONU, KAIFA, and CALL CENTER  
✅ **Maps** substations and feeders to the meters they control  
✅ **Automatically checks** meter statuses when SCADA events occur  
✅ **Detects outages** by identifying offline meters  
✅ **Correlates events** from multiple sources to the same outage  
✅ **Provides audit trail** of all meter status changes  
✅ **Enables topology-aware** outage management

The system is now capable of intelligent outage detection, correlation, and management aligned with industry best practices.

