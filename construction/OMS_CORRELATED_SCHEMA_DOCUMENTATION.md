# OMS Correlated Schema Documentation

## Overview

This document describes the correlated database schema for the Outage Management System (OMS) that integrates data from four service sources:
- **Call Center**: Customer tickets and reports
- **Kaifa (Smart Meters)**: Last-gasp signals and meter data
- **SCADA**: System alarms and breaker trips
- **ONU**: Fiber network device events

## Architecture Principles

### 1. **Topology-Aware Design**
- **Network Hierarchy**: Substation → Feeder → Distribution Point → Customer
- **Geographic Correlation**: Spatial proximity using PostGIS for location-based correlation
- **Asset Mapping**: Unified customer and asset registry across all systems

### 2. **Event Correlation Engine**
- **Temporal Correlation**: Time-window based event grouping
- **Spatial Correlation**: Geographic proximity for event association
- **Confidence Scoring**: Weighted scoring based on source reliability (SCADA > Kaifa > ONU > Call Center)
- **Storm Mode**: Adaptive correlation parameters for high-volume events

### 3. **Process Flow Alignment**
The schema directly supports the OMS process flow shown in the attached diagrams:

```
Input Signals → Pre-Filter & Enrichment → Seed Event Creation → 
Neighbor Validation → Scoring & Classification → Clustering & Correlation → 
Storm Mode Adjustment → Restoration & Clearance → Output Actions
```

## Core Schema Components

### 1. Network Topology (`network_*` tables)
```sql
network_substations → network_feeders → network_distribution_points
```
- **Purpose**: Defines electrical network hierarchy
- **Key Features**: Geographic coordinates, capacity, status tracking
- **Correlation**: Enables topology-aware grouping of events

### 2. Customer & Asset Registry (`oms_*` tables)
```sql
oms_customers → oms_smart_meters, oms_onu_devices
```
- **Purpose**: Unified view of customers and their assets
- **Key Features**: Location mapping, device relationships, communication channels
- **Correlation**: Links events to specific customers and assets

### 3. Outage Event Management (`oms_outage_events`)
```sql
oms_outage_events ← oms_event_sources ← oms_event_timeline
```
- **Purpose**: Master outage event tracking with full lifecycle management
- **Key Features**: Confidence scoring, affected customer count, restoration tracking
- **Correlation**: Central hub for all correlated events

### 4. Event Correlation (`oms_event_sources`)
- **Purpose**: Links outage events to their source events from different systems
- **Key Features**: Source type tracking, correlation weights, temporal mapping
- **Correlation**: Enables multi-source event correlation

### 5. Operational Management
- **Crew Management**: Assignment and dispatch tracking
- **Customer Communication**: Notification and status updates
- **Configuration**: Correlation rules and storm mode settings

## Key Features Supporting OMS Process Flow

### 1. **Pre-Filter & Enrichment**
- **Spatial Indexing**: PostGIS indexes for fast geographic queries
- **Temporal Indexing**: Time-based event filtering and sorting
- **Asset Enrichment**: Automatic linking to customer and network topology

### 2. **Seed Event Creation**
- **Multi-Source Detection**: Automatic event creation from any source
- **Confidence Scoring**: Initial scoring based on source type and reliability
- **Geographic Scope**: Automatic area determination based on network topology

### 3. **Neighbor Validation**
- **Spatial Correlation**: `oms_correlate_events()` function for proximity-based correlation
- **Temporal Correlation**: Configurable time windows for event grouping
- **Network Topology**: Feeder hierarchy for smart meter and ONU grouping

### 4. **Scoring & Classification**
- **Weighted Scoring**: SCADA (1.0) > Kaifa (0.8) > ONU (0.6) > Call Center (0.4)
- **Confidence Calculation**: Dynamic scoring based on number and type of sources
- **Severity Classification**: Automatic severity assignment based on confidence and scope

### 5. **Clustering & Correlation**
- **Event Grouping**: Automatic grouping of related events into single outage
- **Source Aggregation**: Multiple sources contributing to single outage event
- **Timeline Tracking**: Complete audit trail of event progression

### 6. **Storm Mode Adjustment**
- **Adaptive Parameters**: Configurable correlation windows and spatial radius
- **Volume Handling**: Optimized for high-volume event processing
- **Auto-Activation**: Automatic storm mode based on event volume thresholds

### 7. **Restoration & Clearance**
- **Status Tracking**: Complete lifecycle from detection to restoration
- **Crew Management**: Assignment and dispatch tracking
- **Customer Communication**: Automated notification system

## Performance Optimizations

### 1. **Spatial Indexing**
```sql
-- PostGIS spatial indexes for geographic queries
CREATE INDEX idx_network_substations_location ON network_substations 
USING GIST(ST_Point(location_lng, location_lat));
```

### 2. **Temporal Indexing**
```sql
-- Time-based indexes for event correlation
CREATE INDEX idx_oms_outage_events_detected ON oms_outage_events(first_detected_at DESC);
```

### 3. **Composite Indexes**
```sql
-- Multi-column indexes for complex queries
CREATE INDEX idx_oms_event_sources_correlation ON oms_event_sources(outage_event_id, source_type, detected_at);
```

### 4. **Partitioning Strategy**
- **Hash Partitioning**: For high-volume event tables
- **Time-based Partitioning**: For historical data management
- **Geographic Partitioning**: For spatial data optimization

## Correlation Algorithm

### 1. **Spatial Correlation**
```sql
-- Events within spatial radius are considered for correlation
ST_DWithin(
    ST_Point(longitude, latitude)::geography,
    ST_Point(target_lng, target_lat)::geography,
    spatial_radius_meters
)
```

### 2. **Temporal Correlation**
```sql
-- Events within time window are considered for correlation
event_timestamp BETWEEN 
    (target_timestamp - INTERVAL '30 minutes') AND 
    (target_timestamp + INTERVAL '30 minutes')
```

### 3. **Confidence Scoring**
```sql
-- Weighted confidence calculation
confidence_score = 
    (scada_weight * scada_count + 
     kaifa_weight * kaifa_count + 
     onu_weight * onu_count + 
     call_center_weight * call_center_count) / 
    total_sources
```

## Views and Reporting

### 1. **Active Outages View**
```sql
CREATE VIEW oms_active_outages AS
SELECT 
    oe.id, oe.event_id, oe.status, oe.severity, oe.confidence_score,
    oe.affected_customers_count, oe.first_detected_at,
    ns.name as substation_name, nf.name as feeder_name,
    COUNT(es.id) as source_count,
    STRING_AGG(DISTINCT es.source_type, ', ') as source_types
FROM oms_outage_events oe
-- ... joins and filters
```

### 2. **Correlation Summary View**
```sql
CREATE VIEW oms_correlation_summary AS
SELECT 
    oe.id, oe.event_id, oe.status, oe.confidence_score,
    COUNT(es.id) as total_sources,
    COUNT(CASE WHEN es.source_type = 'scada' THEN 1 END) as scada_sources,
    -- ... other source counts
FROM oms_outage_events oe
-- ... joins and grouping
```

## Configuration and Rules

### 1. **Correlation Rules**
- **Standard Mode**: 30-minute window, 1000m radius, 0.7 confidence threshold
- **Storm Mode**: 60-minute window, 2000m radius, 0.5 confidence threshold
- **SCADA Priority**: 15-minute window, 500m radius, 0.9 confidence threshold

### 2. **Source Weights**
- **SCADA**: 1.0 (highest reliability)
- **Kaifa**: 0.8 (smart meter data)
- **ONU**: 0.6 (fiber network devices)
- **Call Center**: 0.4 (customer reports)

### 3. **Storm Mode Configuration**
- **Auto-activation**: 100 events per hour threshold
- **Adaptive parameters**: Relaxed correlation criteria
- **Volume handling**: Optimized for high-volume processing

## Integration Points

### 1. **Service Integration**
- **Call Center**: `callcenter_tickets` → `oms_event_sources`
- **Kaifa**: `kaifa_events` → `oms_event_sources`
- **SCADA**: `scada_events` → `oms_event_sources`
- **ONU**: `onu_events` → `oms_event_sources`

### 2. **Data Flow**
```
Service Events → oms_correlate_events() → oms_outage_events → 
oms_event_sources → oms_event_timeline → oms_crew_assignments → 
oms_customer_notifications
```

### 3. **API Endpoints**
- **Event Correlation**: `/api/oms/correlate`
- **Outage Management**: `/api/oms/outages`
- **Crew Dispatch**: `/api/oms/crew`
- **Customer Communication**: `/api/oms/notifications`

## Best Practices

### 1. **Data Consistency**
- **Referential Integrity**: Foreign key constraints ensure data consistency
- **Audit Trails**: Complete timeline tracking for all events
- **Source Attribution**: Every event linked to its source system

### 2. **Performance**
- **Indexing Strategy**: Comprehensive indexing for all query patterns
- **Spatial Optimization**: PostGIS for geographic operations
- **Partitioning**: Hash and time-based partitioning for scalability

### 3. **Maintainability**
- **Modular Design**: Clear separation of concerns
- **Configuration Management**: Rule-based correlation parameters
- **Documentation**: Comprehensive comments and documentation

## Conclusion

The OMS correlated schema provides a robust, scalable foundation for intelligent outage management that:

1. **Correlates** multiple input sources (SCADA, Kaifa, ONU, Call Center)
2. **Confirms** outage events through confidence scoring and validation
3. **Predicts** outage extent using topological tracing
4. **Manages** the complete outage lifecycle from detection to restoration
5. **Communicates** with customers and crews throughout the process

The schema follows enterprise best practices with proper normalization, indexing, and performance optimization while maintaining the flexibility needed for complex outage management scenarios.

