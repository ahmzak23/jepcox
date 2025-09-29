# OMS API Integration Guide

## Overview

This guide demonstrates how the OMS correlated schema integrates with the existing service APIs to enable intelligent outage management following the OMS process flow.

## API Integration Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Call Center   │    │     Kaifa       │    │     SCADA       │    │      ONU       │
│     Service     │    │    Service      │    │    Service      │    │    Service     │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │                      │
          │                      │                      │                      │
          ▼                      ▼                      ▼                      ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        OMS Correlation Engine                                    │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Pre-Filter &    │  │ Seed Event      │  │ Neighbor        │  │ Scoring &   │ │
│  │ Enrichment      │  │ Creation        │  │ Validation      │  │ Classification│ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Clustering &    │  │ Storm Mode     │  │ Restoration &   │  │ Output      │ │
│  │ Correlation     │  │ Adjustment      │  │ Clearance       │  │ Actions     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        OMS Correlated Database                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ │
│  │ Network         │  │ Customer &      │  │ Outage Events   │  │ Crew &      │ │
│  │ Topology        │  │ Asset Registry  │  │ & Correlation   │  │ Communication│ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  └─────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## 1. Pre-Filter & Enrichment API

### Endpoint: `POST /api/oms/events/correlate`

```python
# Example integration for Call Center service
def correlate_call_center_event(ticket_data):
    """
    Correlate Call Center ticket with existing outage events
    """
    correlation_request = {
        "event_type": "outage",
        "source_type": "call_center",
        "source_event_id": ticket_data["ticketId"],
        "timestamp": ticket_data["timestamp"],
        "latitude": ticket_data.get("customer", {}).get("location", {}).get("lat"),
        "longitude": ticket_data.get("customer", {}).get("location", {}).get("lng"),
        "correlation_window_minutes": 30,
        "spatial_radius_meters": 1000,
        "metadata": {
            "phone": ticket_data["customer"]["phone"],
            "address": ticket_data["customer"]["address"],
            "meter_number": ticket_data["customer"]["meterNumber"]
        }
    }
    
    # Call OMS correlation API
    response = requests.post("/api/oms/events/correlate", json=correlation_request)
    return response.json()

# Example integration for Kaifa service
def correlate_kaifa_event(kaifa_data):
    """
    Correlate Kaifa Last-Gasp event with existing outage events
    """
    correlation_request = {
        "event_type": "outage",
        "source_type": "kaifa",
        "source_event_id": kaifa_data["event_id"],
        "timestamp": kaifa_data["timestamp"],
        "latitude": kaifa_data.get("location", {}).get("lat"),
        "longitude": kaifa_data.get("location", {}).get("lng"),
        "correlation_window_minutes": 30,
        "spatial_radius_meters": 1000,
        "metadata": {
            "meter_number": kaifa_data.get("assets", {}).get("mrid"),
            "usage_point": kaifa_data.get("usage_point", {}).get("mrid"),
            "event_type": kaifa_data.get("message_type")
        }
    }
    
    response = requests.post("/api/oms/events/correlate", json=correlation_request)
    return response.json()
```

### Database Integration

```sql
-- The correlation function automatically:
-- 1. Checks for existing events within spatial/temporal window
-- 2. Creates new outage event if no correlation found
-- 3. Links source event to outage event
-- 4. Updates confidence score based on source weights
-- 5. Creates timeline entry for audit trail

SELECT oms_correlate_events(
    'outage',                    -- event_type
    'call_center',              -- source_type
    'TC_1703123456789',         -- source_event_id
    '2024-01-15T10:30:45.123Z'::TIMESTAMPTZ, -- timestamp
    31.9454,                    -- latitude
    35.9284,                    -- longitude
    30,                         -- correlation_window_minutes
    1000                        -- spatial_radius_meters
);
```

## 2. Seed Event Creation API

### Endpoint: `POST /api/oms/events/create`

```python
def create_seed_event(event_data):
    """
    Create a new seed outage event from any source
    """
    seed_event_request = {
        "event_type": "outage",
        "source_type": event_data["source_type"],
        "source_event_id": event_data["source_event_id"],
        "timestamp": event_data["timestamp"],
        "location": {
            "latitude": event_data["latitude"],
            "longitude": event_data["longitude"]
        },
        "metadata": event_data.get("metadata", {}),
        "correlation_parameters": {
            "window_minutes": 30,
            "spatial_radius_meters": 1000
        }
    }
    
    response = requests.post("/api/oms/events/create", json=seed_event_request)
    return response.json()
```

### Database Integration

```sql
-- Create seed event with automatic correlation
INSERT INTO oms_outage_events (
    event_id, event_type, status, severity, confidence_score,
    first_detected_at, dp_id
) VALUES (
    'OMS_' || extract(epoch from NOW())::bigint || '_' || substr(md5(random()::text), 1, 8),
    'outage', 'detected', 'medium', 0.5,
    NOW(), NULL
) RETURNING id;
```

## 3. Neighbor Validation API

### Endpoint: `POST /api/oms/events/validate`

```python
def validate_neighbor_events(outage_event_id):
    """
    Validate outage event by checking for neighbor events
    """
    validation_request = {
        "outage_event_id": outage_event_id,
        "validation_type": "neighbor_check",
        "parameters": {
            "spatial_radius_meters": 1000,
            "temporal_window_minutes": 30,
            "source_types": ["scada", "kaifa", "onu", "call_center"]
        }
    }
    
    response = requests.post("/api/oms/events/validate", json=validation_request)
    return response.json()

# Example neighbor validation logic
def check_neighbor_events(outage_event):
    """
    Check for supporting events in the same area
    """
    neighbor_events = db.query("""
        SELECT 
            es.source_type,
            es.source_event_id,
            es.detected_at,
            es.correlation_weight
        FROM oms_event_sources es
        WHERE es.outage_event_id = %s
        AND es.detected_at BETWEEN %s AND %s
        ORDER BY es.detected_at DESC
    """, [
        outage_event["id"],
        outage_event["first_detected_at"] - timedelta(minutes=30),
        outage_event["first_detected_at"] + timedelta(minutes=30)
    ])
    
    return neighbor_events
```

### Database Integration

```sql
-- Check for neighbor events within spatial and temporal proximity
SELECT 
    es.source_type,
    es.source_event_id,
    es.detected_at,
    es.correlation_weight,
    oe.confidence_score
FROM oms_event_sources es
JOIN oms_outage_events oe ON es.outage_event_id = oe.id
WHERE es.outage_event_id = $1
AND es.detected_at BETWEEN $2 AND $3
ORDER BY es.detected_at DESC;
```

## 4. Scoring & Classification API

### Endpoint: `POST /api/oms/events/score`

```python
def score_and_classify_event(outage_event_id):
    """
    Score and classify outage event based on correlated sources
    """
    scoring_request = {
        "outage_event_id": outage_event_id,
        "scoring_parameters": {
            "weight_scada": 1.0,
            "weight_kaifa": 0.8,
            "weight_onu": 0.6,
            "weight_call_center": 0.4
        }
    }
    
    response = requests.post("/api/oms/events/score", json=scoring_request)
    return response.json()

# Example scoring logic
def calculate_confidence_score(outage_event_id):
    """
    Calculate confidence score based on source weights and counts
    """
    source_weights = {
        'scada': 1.0,
        'kaifa': 0.8,
        'onu': 0.6,
        'call_center': 0.4
    }
    
    source_counts = db.query("""
        SELECT 
            source_type,
            COUNT(*) as count,
            AVG(correlation_weight) as avg_weight
        FROM oms_event_sources
        WHERE outage_event_id = %s
        GROUP BY source_type
    """, [outage_event_id])
    
    total_score = 0.0
    total_weight = 0.0
    
    for source in source_counts:
        weight = source_weights.get(source["source_type"], 0.0)
        total_score += weight * source["count"] * source["avg_weight"]
        total_weight += weight * source["count"]
    
    confidence_score = min(1.0, total_score / max(total_weight, 1.0))
    
    # Update confidence score
    db.execute("""
        UPDATE oms_outage_events 
        SET confidence_score = %s, last_updated_at = NOW()
        WHERE id = %s
    """, [confidence_score, outage_event_id])
    
    return confidence_score
```

### Database Integration

```sql
-- Calculate confidence score based on source weights
UPDATE oms_outage_events 
SET confidence_score = (
    SELECT LEAST(1.0, 
        (COUNT(CASE WHEN es.source_type = 'scada' THEN 1 END) * 1.0 +
         COUNT(CASE WHEN es.source_type = 'kaifa' THEN 1 END) * 0.8 +
         COUNT(CASE WHEN es.source_type = 'onu' THEN 1 END) * 0.6 +
         COUNT(CASE WHEN es.source_type = 'call_center' THEN 1 END) * 0.4) /
        GREATEST(COUNT(*), 1)
    )
    FROM oms_event_sources es
    WHERE es.outage_event_id = oms_outage_events.id
),
severity = CASE 
    WHEN confidence_score >= 0.9 THEN 'critical'
    WHEN confidence_score >= 0.7 THEN 'high'
    WHEN confidence_score >= 0.5 THEN 'medium'
    ELSE 'low'
END
WHERE id = $1;
```

## 5. Clustering & Correlation API

### Endpoint: `POST /api/oms/events/cluster`

```python
def cluster_related_events():
    """
    Cluster related events into single outage events
    """
    clustering_request = {
        "clustering_parameters": {
            "spatial_radius_meters": 1000,
            "temporal_window_minutes": 30,
            "confidence_threshold": 0.7
        }
    }
    
    response = requests.post("/api/oms/events/cluster", json=clustering_request)
    return response.json()

# Example clustering logic
def cluster_events():
    """
    Find and cluster related events
    """
    # Find events that should be clustered
    related_events = db.query("""
        SELECT 
            oe1.id as event1_id,
            oe2.id as event2_id,
            ST_Distance(
                ST_Point(oe1.dp_id::text, oe1.dp_id::text),
                ST_Point(oe2.dp_id::text, oe2.dp_id::text)
            ) as distance,
            ABS(EXTRACT(EPOCH FROM (oe1.first_detected_at - oe2.first_detected_at))) as time_diff
        FROM oms_outage_events oe1
        JOIN oms_outage_events oe2 ON oe1.id < oe2.id
        WHERE oe1.status IN ('detected', 'confirmed')
        AND oe2.status IN ('detected', 'confirmed')
        AND ST_DWithin(
            ST_Point(oe1.dp_id::text, oe1.dp_id::text),
            ST_Point(oe2.dp_id::text, oe2.dp_id::text),
            1000
        )
        AND ABS(EXTRACT(EPOCH FROM (oe1.first_detected_at - oe2.first_detected_at))) <= 1800
    """)
    
    # Cluster related events
    for event_pair in related_events:
        if event_pair["distance"] <= 1000 and event_pair["time_diff"] <= 1800:
            # Merge events
            merge_events(event_pair["event1_id"], event_pair["event2_id"])
    
    return len(related_events)
```

### Database Integration

```sql
-- Find events that should be clustered
SELECT 
    oe1.id as event1_id,
    oe2.id as event2_id,
    ST_Distance(
        ST_Point(oe1.dp_id::text, oe1.dp_id::text),
        ST_Point(oe2.dp_id::text, oe2.dp_id::text)
    ) as distance,
    ABS(EXTRACT(EPOCH FROM (oe1.first_detected_at - oe2.first_detected_at))) as time_diff
FROM oms_outage_events oe1
JOIN oms_outage_events oe2 ON oe1.id < oe2.id
WHERE oe1.status IN ('detected', 'confirmed')
AND oe2.status IN ('detected', 'confirmed')
AND ST_DWithin(
    ST_Point(oe1.dp_id::text, oe1.dp_id::text),
    ST_Point(oe2.dp_id::text, oe2.dp_id::text),
    1000
)
AND ABS(EXTRACT(EPOCH FROM (oe1.first_detected_at - oe2.first_detected_at))) <= 1800;
```

## 6. Storm Mode Adjustment API

### Endpoint: `POST /api/oms/storm-mode/activate`

```python
def activate_storm_mode():
    """
    Activate storm mode with relaxed correlation parameters
    """
    storm_mode_request = {
        "activation_reason": "high_event_volume",
        "parameters": {
            "correlation_window_minutes": 60,
            "spatial_radius_meters": 2000,
            "confidence_threshold": 0.5,
            "auto_activation_threshold": 100
        }
    }
    
    response = requests.post("/api/oms/storm-mode/activate", json=storm_mode_request)
    return response.json()

# Example storm mode logic
def check_storm_mode_activation():
    """
    Check if storm mode should be activated based on event volume
    """
    # Count events in the last hour
    event_count = db.query("""
        SELECT COUNT(*) as event_count
        FROM oms_outage_events
        WHERE first_detected_at >= NOW() - INTERVAL '1 hour'
    """)[0]["event_count"]
    
    if event_count >= 100:  # Threshold for storm mode
        # Activate storm mode
        db.execute("""
            UPDATE oms_storm_mode_config 
            SET is_active = TRUE, activated_at = NOW()
            WHERE id = (SELECT id FROM oms_storm_mode_config ORDER BY created_at DESC LIMIT 1)
        """)
        
        # Update correlation rules for storm mode
        db.execute("""
            UPDATE oms_correlation_rules 
            SET correlation_window_minutes = 60,
                spatial_radius_meters = 2000,
                confidence_threshold = 0.5
            WHERE rule_name = 'Storm Mode Detection'
        """)
        
        return True
    
    return False
```

### Database Integration

```sql
-- Activate storm mode
UPDATE oms_storm_mode_config 
SET is_active = TRUE, activated_at = NOW()
WHERE id = (SELECT id FROM oms_storm_mode_config ORDER BY created_at DESC LIMIT 1);

-- Update correlation rules for storm mode
UPDATE oms_correlation_rules 
SET correlation_window_minutes = 60,
    spatial_radius_meters = 2000,
    confidence_threshold = 0.5
WHERE rule_name = 'Storm Mode Detection';
```

## 7. Restoration & Clearance API

### Endpoint: `POST /api/oms/events/restore`

```python
def restore_outage_event(outage_event_id, restoration_data):
    """
    Mark outage event as restored
    """
    restoration_request = {
        "outage_event_id": outage_event_id,
        "restoration_data": {
            "restoration_time": restoration_data["restoration_time"],
            "restoration_reason": restoration_data["restoration_reason"],
            "crew_id": restoration_data.get("crew_id"),
            "notes": restoration_data.get("notes")
        }
    }
    
    response = requests.post("/api/oms/events/restore", json=restoration_request)
    return response.json()

# Example restoration logic
def restore_outage_event(outage_event_id, restoration_data):
    """
    Restore outage event and update related data
    """
    # Update outage event status
    db.execute("""
        UPDATE oms_outage_events 
        SET status = 'restored',
            actual_restoration_time = %s,
            last_updated_at = NOW()
        WHERE id = %s
    """, [restoration_data["restoration_time"], outage_event_id])
    
    # Add timeline entry
    db.execute("""
        INSERT INTO oms_event_timeline (
            outage_event_id, event_type, status, description, source
        ) VALUES (
            %s, 'restored', 'restored', %s, 'crew'
        )
    """, [
        outage_event_id,
        f"Outage restored at {restoration_data['restoration_time']}. Reason: {restoration_data['restoration_reason']}"
    ])
    
    # Update crew assignment if provided
    if restoration_data.get("crew_id"):
        db.execute("""
            UPDATE oms_crew_assignments 
            SET status = 'completed',
                completed_at = %s,
                notes = %s
            WHERE outage_event_id = %s AND crew_id = %s
        """, [
            restoration_data["restoration_time"],
            restoration_data.get("notes"),
            outage_event_id,
            restoration_data["crew_id"]
        ])
    
    return True
```

### Database Integration

```sql
-- Restore outage event
UPDATE oms_outage_events 
SET status = 'restored',
    actual_restoration_time = $2,
    last_updated_at = NOW()
WHERE id = $1;

-- Add timeline entry
INSERT INTO oms_event_timeline (
    outage_event_id, event_type, status, description, source
) VALUES (
    $1, 'restored', 'restored', $3, 'crew'
);
```

## 8. Output Actions API

### Crew Dispatch: `POST /api/oms/crew/dispatch`

```python
def dispatch_crew(outage_event_id, crew_data):
    """
    Dispatch crew to outage event
    """
    dispatch_request = {
        "outage_event_id": outage_event_id,
        "crew_data": {
            "crew_id": crew_data["crew_id"],
            "crew_name": crew_data["crew_name"],
            "assignment_type": crew_data["assignment_type"],
            "estimated_arrival": crew_data["estimated_arrival"],
            "location": crew_data.get("location")
        }
    }
    
    response = requests.post("/api/oms/crew/dispatch", json=dispatch_request)
    return response.json()
```

### Customer Communication: `POST /api/oms/notifications/send`

```python
def send_customer_notification(outage_event_id, notification_data):
    """
    Send notification to affected customers
    """
    notification_request = {
        "outage_event_id": outage_event_id,
        "notification_data": {
            "notification_type": notification_data["notification_type"],
            "channel": notification_data["channel"],
            "message_content": notification_data["message_content"],
            "customer_ids": notification_data.get("customer_ids", [])
        }
    }
    
    response = requests.post("/api/oms/notifications/send", json=notification_request)
    return response.json()
```

## 9. Real-time Dashboard API

### Endpoint: `GET /api/oms/dashboard/active-outages`

```python
def get_active_outages():
    """
    Get active outages for dashboard
    """
    response = requests.get("/api/oms/dashboard/active-outages")
    return response.json()

# Example dashboard data
def get_dashboard_data():
    """
    Get comprehensive dashboard data
    """
    dashboard_data = {
        "active_outages": db.query("""
            SELECT 
                oe.id, oe.event_id, oe.status, oe.severity, oe.confidence_score,
                oe.affected_customers_count, oe.first_detected_at,
                ns.name as substation_name, nf.name as feeder_name,
                COUNT(es.id) as source_count,
                STRING_AGG(DISTINCT es.source_type, ', ') as source_types
            FROM oms_outage_events oe
            LEFT JOIN network_substations ns ON oe.substation_id = ns.id
            LEFT JOIN network_feeders nf ON oe.feeder_id = nf.id
            LEFT JOIN oms_event_sources es ON oe.id = es.outage_event_id
            WHERE oe.status IN ('detected', 'confirmed', 'in_progress')
            GROUP BY oe.id, oe.event_id, oe.status, oe.severity, 
                     oe.confidence_score, oe.affected_customers_count, 
                     oe.first_detected_at, ns.name, nf.name
            ORDER BY oe.first_detected_at DESC
        """),
        
        "correlation_summary": db.query("""
            SELECT 
                oe.id as outage_event_id, oe.event_id, oe.status, oe.confidence_score,
                COUNT(es.id) as total_sources,
                COUNT(CASE WHEN es.source_type = 'scada' THEN 1 END) as scada_sources,
                COUNT(CASE WHEN es.source_type = 'kaifa' THEN 1 END) as kaifa_sources,
                COUNT(CASE WHEN es.source_type = 'onu' THEN 1 END) as onu_sources,
                COUNT(CASE WHEN es.source_type = 'call_center' THEN 1 END) as call_center_sources
            FROM oms_outage_events oe
            LEFT JOIN oms_event_sources es ON oe.id = es.outage_event_id
            GROUP BY oe.id, oe.event_id, oe.status, oe.confidence_score
        """),
        
        "storm_mode_status": db.query("""
            SELECT is_active, activated_at, deactivated_at
            FROM oms_storm_mode_config
            ORDER BY created_at DESC LIMIT 1
        """)
    }
    
    return dashboard_data
```

## 10. Integration Examples

### Complete OMS Process Flow Integration

```python
class OMSIntegration:
    def __init__(self, db_connection):
        self.db = db_connection
    
    def process_outage_event(self, event_data):
        """
        Complete OMS process flow integration
        """
        try:
            # 1. Pre-Filter & Enrichment
            enriched_event = self.enrich_event_data(event_data)
            
            # 2. Seed Event Creation
            outage_event_id = self.create_seed_event(enriched_event)
            
            # 3. Neighbor Validation
            validation_result = self.validate_neighbor_events(outage_event_id)
            
            # 4. Scoring & Classification
            confidence_score = self.score_and_classify_event(outage_event_id)
            
            # 5. Clustering & Correlation
            if confidence_score >= 0.7:
                self.cluster_related_events(outage_event_id)
            
            # 6. Storm Mode Adjustment
            if self.check_storm_mode_activation():
                self.activate_storm_mode()
            
            # 7. Restoration & Clearance
            if enriched_event.get("restoration_signal"):
                self.restore_outage_event(outage_event_id, enriched_event)
            
            # 8. Output Actions
            self.dispatch_crew(outage_event_id, enriched_event)
            self.send_customer_notifications(outage_event_id, enriched_event)
            
            return {
                "outage_event_id": outage_event_id,
                "confidence_score": confidence_score,
                "status": "processed"
            }
            
        except Exception as e:
            return {
                "error": str(e),
                "status": "failed"
            }
    
    def enrich_event_data(self, event_data):
        """
        Enrich event data with network topology and customer information
        """
        # Add network topology information
        if event_data.get("latitude") and event_data.get("longitude"):
            topology_info = self.db.query("""
                SELECT 
                    ns.id as substation_id, ns.name as substation_name,
                    nf.id as feeder_id, nf.name as feeder_name,
                    ndp.id as dp_id, ndp.name as dp_name
                FROM network_substations ns
                JOIN network_feeders nf ON nf.substation_id = ns.id
                JOIN network_distribution_points ndp ON ndp.feeder_id = nf.id
                WHERE ST_DWithin(
                    ST_Point(%s, %s),
                    ST_Point(ndp.location_lng, ndp.location_lat),
                    1000
                )
                ORDER BY ST_Distance(
                    ST_Point(%s, %s),
                    ST_Point(ndp.location_lng, ndp.location_lat)
                )
                LIMIT 1
            """, [
                event_data["longitude"], event_data["latitude"],
                event_data["longitude"], event_data["latitude"]
            ])
            
            if topology_info:
                event_data.update(topology_info[0])
        
        # Add customer information
        if event_data.get("meter_number"):
            customer_info = self.db.query("""
                SELECT 
                    oc.id as customer_id, oc.phone, oc.address,
                    osm.id as smart_meter_id, ood.id as onu_device_id
                FROM oms_customers oc
                LEFT JOIN oms_smart_meters osm ON osm.customer_id = oc.id
                LEFT JOIN oms_onu_devices ood ON ood.customer_id = oc.id
                WHERE osm.meter_number = %s OR ood.onu_serial_no = %s
            """, [event_data["meter_number"], event_data["meter_number"]])
            
            if customer_info:
                event_data["customer_info"] = customer_info[0]
        
        return event_data
```

## Conclusion

The OMS API integration provides a comprehensive framework for intelligent outage management that:

1. **Correlates** multiple input sources through spatial and temporal proximity
2. **Validates** events through neighbor checking and confidence scoring
3. **Clusters** related events into single outage events
4. **Adapts** to storm conditions with relaxed correlation parameters
5. **Manages** the complete outage lifecycle from detection to restoration
6. **Communicates** with customers and crews throughout the process

The integration follows the OMS process flow exactly as shown in the attached diagrams, providing a robust foundation for intelligent outage management.
