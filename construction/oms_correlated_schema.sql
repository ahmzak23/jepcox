-- =========================================================
-- OMS Correlated Schema - Outage Management System
-- =========================================================
-- This schema correlates data from Call Center, Kaifa (Smart Meters), 
-- SCADA, and ONU services to enable intelligent outage detection,
-- correlation, and management following the OMS process flow.
-- =========================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
-- NOTE: PostGIS is optional. If installed, you can add spatial indexes/views separately.

-- =========================================================
-- 1. NETWORK TOPOLOGY & ASSETS
-- =========================================================

-- Network hierarchy: Substation → Feeder → Distribution Point → Customer
CREATE TABLE IF NOT EXISTS network_substations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    substation_id VARCHAR(64) UNIQUE NOT NULL,
    name VARCHAR(200) NOT NULL,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    region_code VARCHAR(10),
    voltage_level VARCHAR(20),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS network_feeders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feeder_id VARCHAR(64) UNIQUE NOT NULL,
    substation_id UUID NOT NULL REFERENCES network_substations(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    capacity_kva DECIMAL(12,2),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS network_distribution_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    dp_id VARCHAR(64) UNIQUE NOT NULL,
    feeder_id UUID NOT NULL REFERENCES network_feeders(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    building_id VARCHAR(50),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 2. CUSTOMER & ASSET MAPPING
-- =========================================================

-- Unified customer and asset registry
CREATE TABLE IF NOT EXISTS oms_customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    customer_id VARCHAR(64) UNIQUE NOT NULL,
    phone VARCHAR(32),
    address TEXT,
    building_id VARCHAR(50),
    dp_id UUID REFERENCES network_distribution_points(id),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Smart meters (Kaifa) mapping
CREATE TABLE IF NOT EXISTS oms_smart_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_number VARCHAR(64) UNIQUE NOT NULL,
    customer_id UUID REFERENCES oms_customers(id),
    asset_mrid VARCHAR(100),
    usage_point_mrid VARCHAR(100),
    dp_id UUID REFERENCES network_distribution_points(id),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    meter_type VARCHAR(50) DEFAULT 'kaifa',
    status VARCHAR(20) DEFAULT 'active',
    last_communication TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- ONU devices mapping
CREATE TABLE IF NOT EXISTS oms_onu_devices (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    onu_id INT UNIQUE NOT NULL,
    onu_serial_no VARCHAR(100) UNIQUE,
    customer_id UUID REFERENCES oms_customers(id),
    dp_id UUID REFERENCES network_distribution_points(id),
    fibertech_id VARCHAR(50),
    olt_name VARCHAR(200),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    power_status BOOLEAN DEFAULT TRUE,
    last_power_change TIMESTAMPTZ,
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 3. OMS EVENTS & CORRELATION
-- =========================================================

-- Master outage events table
CREATE TABLE IF NOT EXISTS oms_outage_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id VARCHAR(64) UNIQUE NOT NULL,
    event_type VARCHAR(50) NOT NULL, -- 'outage', 'restoration', 'planned_outage'
    status VARCHAR(32) NOT NULL DEFAULT 'detected', -- detected, confirmed, in_progress, restored, cleared
    severity VARCHAR(16) NOT NULL DEFAULT 'medium', -- low, medium, high, critical
    confidence_score DECIMAL(5,2) DEFAULT 0.0, -- 0.0 to 1.0
    affected_customers_count INTEGER DEFAULT 0,
    estimated_restoration_time TIMESTAMPTZ,
    actual_restoration_time TIMESTAMPTZ,
    root_cause VARCHAR(200),
    description TEXT,
    -- Geographic scope
    affected_area_geojson JSONB,
    -- Event location (used when PostGIS is unavailable)
    event_latitude DECIMAL(10, 8),
    event_longitude DECIMAL(11, 8),
    -- Network scope
    substation_id UUID REFERENCES network_substations(id),
    feeder_id UUID REFERENCES network_feeders(id),
    dp_id UUID REFERENCES network_distribution_points(id),
    -- Temporal
    first_detected_at TIMESTAMPTZ NOT NULL,
    last_updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Event correlation sources (links to source events)
CREATE TABLE IF NOT EXISTS oms_event_sources (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outage_event_id UUID NOT NULL REFERENCES oms_outage_events(id) ON DELETE CASCADE,
    source_type VARCHAR(32) NOT NULL, -- 'scada', 'kaifa', 'onu', 'call_center'
    source_event_id VARCHAR(100) NOT NULL,
    source_table VARCHAR(100) NOT NULL,
    correlation_weight DECIMAL(5,2) DEFAULT 1.0,
    detected_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(outage_event_id, source_type, source_event_id)
);

-- Event timeline and status changes
CREATE TABLE IF NOT EXISTS oms_event_timeline (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outage_event_id UUID NOT NULL REFERENCES oms_outage_events(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- 'detected', 'confirmed', 'crew_dispatched', 'restored', etc.
    status VARCHAR(32) NOT NULL,
    description TEXT,
    source VARCHAR(64),
    timestamp TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- =========================================================
-- 4. CORRELATION RULES & CONFIGURATION
-- =========================================================

-- Correlation rules for different event types
CREATE TABLE IF NOT EXISTS oms_correlation_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    rule_name VARCHAR(100) NOT NULL,
    source_types VARCHAR(100)[] NOT NULL, -- ['scada', 'kaifa', 'onu']
    correlation_window_minutes INTEGER DEFAULT 30,
    spatial_radius_meters INTEGER DEFAULT 1000,
    confidence_threshold DECIMAL(5,2) DEFAULT 0.7,
    weight_scada DECIMAL(5,2) DEFAULT 1.0,
    weight_kaifa DECIMAL(5,2) DEFAULT 0.8,
    weight_onu DECIMAL(5,2) DEFAULT 0.6,
    weight_call_center DECIMAL(5,2) DEFAULT 0.4,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Storm mode configuration
CREATE TABLE IF NOT EXISTS oms_storm_mode_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    is_active BOOLEAN DEFAULT FALSE,
    correlation_window_minutes INTEGER DEFAULT 60,
    spatial_radius_meters INTEGER DEFAULT 2000,
    confidence_threshold DECIMAL(5,2) DEFAULT 0.5,
    auto_activation_threshold INTEGER DEFAULT 100, -- events per hour
    activated_at TIMESTAMPTZ,
    deactivated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 5. CREW MANAGEMENT & DISPATCH
-- =========================================================

-- Crew assignments
CREATE TABLE IF NOT EXISTS oms_crew_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outage_event_id UUID NOT NULL REFERENCES oms_outage_events(id) ON DELETE CASCADE,
    crew_id VARCHAR(64) NOT NULL,
    crew_name VARCHAR(200),
    assignment_type VARCHAR(32) NOT NULL, -- 'investigation', 'repair', 'restoration'
    status VARCHAR(32) NOT NULL DEFAULT 'assigned', -- assigned, en_route, on_site, completed
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    estimated_arrival TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    notes TEXT,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8)
);

-- =========================================================
-- 6. CUSTOMER COMMUNICATION
-- =========================================================

-- Customer notifications
CREATE TABLE IF NOT EXISTS oms_customer_notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outage_event_id UUID NOT NULL REFERENCES oms_outage_events(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES oms_customers(id),
    notification_type VARCHAR(32) NOT NULL, -- 'outage_detected', 'crew_dispatched', 'restored'
    channel VARCHAR(32) NOT NULL, -- 'sms', 'email', 'phone', 'app'
    status VARCHAR(32) NOT NULL DEFAULT 'pending', -- pending, sent, delivered, failed
    sent_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    message_content TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 7. PERFORMANCE INDEXES
-- =========================================================

-- Network topology indexes
-- If PostGIS is available, you can create GIST indexes. Here we use simple BTREE indexes.
CREATE INDEX IF NOT EXISTS idx_network_substations_lat ON network_substations(location_lat);
CREATE INDEX IF NOT EXISTS idx_network_substations_lng ON network_substations(location_lng);
CREATE INDEX IF NOT EXISTS idx_network_feeders_substation ON network_feeders(substation_id);
CREATE INDEX IF NOT EXISTS idx_network_feeders_lat ON network_feeders(location_lat);
CREATE INDEX IF NOT EXISTS idx_network_feeders_lng ON network_feeders(location_lng);
CREATE INDEX IF NOT EXISTS idx_network_dp_feeder ON network_distribution_points(feeder_id);
CREATE INDEX IF NOT EXISTS idx_network_dp_lat ON network_distribution_points(location_lat);
CREATE INDEX IF NOT EXISTS idx_network_dp_lng ON network_distribution_points(location_lng);

-- Customer and asset indexes
CREATE INDEX IF NOT EXISTS idx_oms_customers_phone ON oms_customers(phone);
CREATE INDEX IF NOT EXISTS idx_oms_customers_building ON oms_customers(building_id);
CREATE INDEX IF NOT EXISTS idx_oms_customers_lat ON oms_customers(location_lat);
CREATE INDEX IF NOT EXISTS idx_oms_customers_lng ON oms_customers(location_lng);
CREATE INDEX IF NOT EXISTS idx_oms_smart_meters_customer ON oms_smart_meters(customer_id);
CREATE INDEX IF NOT EXISTS idx_oms_smart_meters_dp ON oms_smart_meters(dp_id);
CREATE INDEX IF NOT EXISTS idx_oms_smart_meters_lat ON oms_smart_meters(location_lat);
CREATE INDEX IF NOT EXISTS idx_oms_smart_meters_lng ON oms_smart_meters(location_lng);
CREATE INDEX IF NOT EXISTS idx_oms_onu_devices_customer ON oms_onu_devices(customer_id);
CREATE INDEX IF NOT EXISTS idx_oms_onu_devices_dp ON oms_onu_devices(dp_id);
CREATE INDEX IF NOT EXISTS idx_oms_onu_devices_lat ON oms_onu_devices(location_lat);
CREATE INDEX IF NOT EXISTS idx_oms_onu_devices_lng ON oms_onu_devices(location_lng);

-- Outage events indexes
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_status ON oms_outage_events(status);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_severity ON oms_outage_events(severity);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_confidence ON oms_outage_events(confidence_score);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_detected ON oms_outage_events(first_detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_substation ON oms_outage_events(substation_id);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_feeder ON oms_outage_events(feeder_id);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_dp ON oms_outage_events(dp_id);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_lat ON oms_outage_events(event_latitude);
CREATE INDEX IF NOT EXISTS idx_oms_outage_events_lng ON oms_outage_events(event_longitude);

-- Event sources indexes
CREATE INDEX IF NOT EXISTS idx_oms_event_sources_outage ON oms_event_sources(outage_event_id);
CREATE INDEX IF NOT EXISTS idx_oms_event_sources_type ON oms_event_sources(source_type);
CREATE INDEX IF NOT EXISTS idx_oms_event_sources_detected ON oms_event_sources(detected_at DESC);

-- Timeline indexes
CREATE INDEX IF NOT EXISTS idx_oms_event_timeline_outage ON oms_event_timeline(outage_event_id);
CREATE INDEX IF NOT EXISTS idx_oms_event_timeline_timestamp ON oms_event_timeline(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_oms_event_timeline_type ON oms_event_timeline(event_type);

-- Crew assignments indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_outage ON oms_crew_assignments(outage_event_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_crew ON oms_crew_assignments(crew_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_status ON oms_crew_assignments(status);

-- Customer notifications indexes
CREATE INDEX IF NOT EXISTS idx_oms_customer_notifications_outage ON oms_customer_notifications(outage_event_id);
CREATE INDEX IF NOT EXISTS idx_oms_customer_notifications_customer ON oms_customer_notifications(customer_id);
CREATE INDEX IF NOT EXISTS idx_oms_customer_notifications_status ON oms_customer_notifications(status);

-- =========================================================
-- 8. TRIGGERS FOR AUTOMATIC UPDATES
-- =========================================================

-- Updated_at trigger function
CREATE OR REPLACE FUNCTION oms_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply triggers
DROP TRIGGER IF EXISTS oms_network_substations_updated_at ON network_substations;
CREATE TRIGGER oms_network_substations_updated_at
    BEFORE UPDATE ON network_substations
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_network_feeders_updated_at ON network_feeders;
CREATE TRIGGER oms_network_feeders_updated_at
    BEFORE UPDATE ON network_feeders
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_network_dp_updated_at ON network_distribution_points;
CREATE TRIGGER oms_network_dp_updated_at
    BEFORE UPDATE ON network_distribution_points
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_customers_updated_at ON oms_customers;
CREATE TRIGGER oms_customers_updated_at
    BEFORE UPDATE ON oms_customers
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_smart_meters_updated_at ON oms_smart_meters;
CREATE TRIGGER oms_smart_meters_updated_at
    BEFORE UPDATE ON oms_smart_meters
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_onu_devices_updated_at ON oms_onu_devices;
CREATE TRIGGER oms_onu_devices_updated_at
    BEFORE UPDATE ON oms_onu_devices
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

-- =========================================================
-- 9. CORRELATION FUNCTIONS
-- =========================================================

-- Helper: Haversine distance (in meters) between two lat/lng points
CREATE OR REPLACE FUNCTION haversine_distance_meters(
    lat1 DECIMAL(10,8), lon1 DECIMAL(11,8),
    lat2 DECIMAL(10,8), lon2 DECIMAL(11,8)
) RETURNS DOUBLE PRECISION AS $$
DECLARE
    r CONSTANT DOUBLE PRECISION := 6371000; -- Earth radius in meters
    dlat DOUBLE PRECISION;
    dlon DOUBLE PRECISION;
    a DOUBLE PRECISION;
BEGIN
    IF lat1 IS NULL OR lon1 IS NULL OR lat2 IS NULL OR lon2 IS NULL THEN
        RETURN NULL;
    END IF;
    dlat := radians(lat2 - lat1);
    dlon := radians(lon2 - lon1);
    a := sin(dlat/2)^2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon/2)^2;
    RETURN 2 * r * atan2(sqrt(a), sqrt(1 - a));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Function to correlate events based on spatial and temporal proximity
CREATE OR REPLACE FUNCTION oms_correlate_events(
    p_event_type VARCHAR(50),
    p_source_type VARCHAR(32),
    p_source_event_id VARCHAR(100),
    p_timestamp TIMESTAMPTZ,
    p_latitude DECIMAL(10,8),
    p_longitude DECIMAL(11,8),
    p_correlation_window_minutes INTEGER DEFAULT 30,
    p_spatial_radius_meters INTEGER DEFAULT 1000
)
RETURNS UUID AS $$
DECLARE
    v_outage_event_id UUID;
    v_existing_event_id UUID;
    v_correlation_weight DECIMAL(5,2);
    v_confidence_score DECIMAL(5,2);
BEGIN
    -- Check for existing events within correlation window and spatial radius
    SELECT oe.id INTO v_existing_event_id
    FROM oms_outage_events oe
    WHERE oe.event_type = p_event_type
    AND oe.status IN ('detected', 'confirmed', 'in_progress')
    AND oe.first_detected_at >= p_timestamp - INTERVAL '1 minute' * p_correlation_window_minutes
    AND oe.first_detected_at <= p_timestamp + INTERVAL '1 minute' * p_correlation_window_minutes
    AND haversine_distance_meters(p_latitude, p_longitude, oe.event_latitude, oe.event_longitude) <= p_spatial_radius_meters
    ORDER BY oe.first_detected_at DESC
    LIMIT 1;

    IF v_existing_event_id IS NOT NULL THEN
        -- Add source to existing event
        INSERT INTO oms_event_sources (
            outage_event_id, source_type, source_event_id, source_table,
            correlation_weight, detected_at
        ) VALUES (
            v_existing_event_id, p_source_type, p_source_event_id, 'source_events',
            1.0, p_timestamp
        ) ON CONFLICT (outage_event_id, source_type, source_event_id) DO NOTHING;

        -- Update confidence score
        UPDATE oms_outage_events 
        SET confidence_score = LEAST(1.0, confidence_score + 0.1),
            last_updated_at = CURRENT_TIMESTAMP
        WHERE id = v_existing_event_id;

        RETURN v_existing_event_id;
    ELSE
        -- Create new outage event
        INSERT INTO oms_outage_events (
            event_id, event_type, status, severity, confidence_score,
            first_detected_at, dp_id, event_latitude, event_longitude
        ) VALUES (
            'OMS_' || extract(epoch from p_timestamp)::bigint || '_' || substr(md5(random()::text), 1, 8),
            p_event_type, 'detected', 'medium', 0.5,
            p_timestamp, NULL, p_latitude, p_longitude -- dp lookup can populate later
        ) RETURNING id INTO v_outage_event_id;

        -- Add source to new event
        INSERT INTO oms_event_sources (
            outage_event_id, source_type, source_event_id, source_table,
            correlation_weight, detected_at
        ) VALUES (
            v_outage_event_id, p_source_type, p_source_event_id, 'source_events',
            1.0, p_timestamp
        );

        -- Add timeline entry
        INSERT INTO oms_event_timeline (
            outage_event_id, event_type, status, description, source
        ) VALUES (
            v_outage_event_id, 'detected', 'detected', 
            'Outage event detected from ' || p_source_type, p_source_type
        );

        RETURN v_outage_event_id;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 10. VIEWS FOR OMS DASHBOARD
-- =========================================================

-- Active outages view
CREATE OR REPLACE VIEW oms_active_outages AS
SELECT 
    oe.id,
    oe.event_id,
    oe.event_type,
    oe.status,
    oe.severity,
    oe.confidence_score,
    oe.affected_customers_count,
    oe.first_detected_at,
    oe.estimated_restoration_time,
    ns.name as substation_name,
    nf.name as feeder_name,
    ndp.name as dp_name,
    COUNT(es.id) as source_count,
    STRING_AGG(DISTINCT es.source_type, ', ') as source_types
FROM oms_outage_events oe
LEFT JOIN network_substations ns ON oe.substation_id = ns.id
LEFT JOIN network_feeders nf ON oe.feeder_id = nf.id
LEFT JOIN network_distribution_points ndp ON oe.dp_id = ndp.id
LEFT JOIN oms_event_sources es ON oe.id = es.outage_event_id
WHERE oe.status IN ('detected', 'confirmed', 'in_progress')
GROUP BY oe.id, oe.event_id, oe.event_type, oe.status, oe.severity, 
         oe.confidence_score, oe.affected_customers_count, oe.first_detected_at,
         oe.estimated_restoration_time, ns.name, nf.name, ndp.name;

-- Event correlation summary
CREATE OR REPLACE VIEW oms_correlation_summary AS
SELECT 
    oe.id as outage_event_id,
    oe.event_id,
    oe.status,
    oe.confidence_score,
    COUNT(es.id) as total_sources,
    COUNT(CASE WHEN es.source_type = 'scada' THEN 1 END) as scada_sources,
    COUNT(CASE WHEN es.source_type = 'kaifa' THEN 1 END) as kaifa_sources,
    COUNT(CASE WHEN es.source_type = 'onu' THEN 1 END) as onu_sources,
    COUNT(CASE WHEN es.source_type = 'call_center' THEN 1 END) as call_center_sources,
    MIN(es.detected_at) as first_source_detected,
    MAX(es.detected_at) as last_source_detected
FROM oms_outage_events oe
LEFT JOIN oms_event_sources es ON oe.id = es.outage_event_id
GROUP BY oe.id, oe.event_id, oe.status, oe.confidence_score;

-- =========================================================
-- 11. INITIAL DATA SETUP
-- =========================================================

-- Insert default correlation rules
INSERT INTO oms_correlation_rules (
    rule_name, source_types, correlation_window_minutes, spatial_radius_meters,
    confidence_threshold, weight_scada, weight_kaifa, weight_onu, weight_call_center
) VALUES 
('Standard Outage Detection', ARRAY['scada', 'kaifa', 'onu', 'call_center'], 30, 1000, 0.7, 1.0, 0.8, 0.6, 0.4),
('Storm Mode Detection', ARRAY['scada', 'kaifa', 'onu', 'call_center'], 60, 2000, 0.5, 1.0, 0.8, 0.6, 0.4),
('SCADA Priority', ARRAY['scada'], 15, 500, 0.9, 1.0, 0.0, 0.0, 0.0)
ON CONFLICT DO NOTHING;

-- Insert default storm mode configuration
INSERT INTO oms_storm_mode_config (
    is_active, correlation_window_minutes, spatial_radius_meters,
    confidence_threshold, auto_activation_threshold
) VALUES (
    FALSE, 60, 2000, 0.5, 100
) ON CONFLICT DO NOTHING;

-- =========================================================
-- 12. COMMENTS AND DOCUMENTATION
-- =========================================================

COMMENT ON TABLE oms_outage_events IS 'Master table for all outage events with correlation and management';
COMMENT ON TABLE oms_event_sources IS 'Links outage events to their source events from different systems';
COMMENT ON TABLE oms_event_timeline IS 'Audit trail of all events and status changes for an outage';
COMMENT ON TABLE oms_correlation_rules IS 'Configurable rules for event correlation based on spatial and temporal proximity';
COMMENT ON TABLE oms_storm_mode_config IS 'Configuration for storm mode operation with relaxed correlation parameters';

COMMENT ON COLUMN oms_outage_events.confidence_score IS 'Confidence score from 0.0 to 1.0 based on number and type of correlated sources';
COMMENT ON COLUMN oms_outage_events.affected_area_geojson IS 'GeoJSON polygon representing the affected area';
COMMENT ON COLUMN oms_event_sources.correlation_weight IS 'Weight of this source in the overall correlation (SCADA=1.0, Kaifa=0.8, etc.)';

-- =========================================================
-- END OF OMS CORRELATED SCHEMA
-- =========================================================
