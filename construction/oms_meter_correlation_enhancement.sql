-- =========================================================
-- OMS Meter Correlation Enhancement
-- =========================================================
-- This enhancement establishes proper relationships between:
-- 1. Substations/Feeders and Meters (SCADA integration)
-- 2. All four data providers (SCADA, ONU, KAIFA, CALL CENTER)
-- 3. Automatic meter status checking when SCADA events occur
-- =========================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 1. UNIFIED METERS REGISTRY (Central Source of Truth)
-- =========================================================

-- Central meters table that all services reference
CREATE TABLE IF NOT EXISTS oms_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_number VARCHAR(64) UNIQUE NOT NULL,
    meter_type VARCHAR(50) DEFAULT 'smart', -- 'smart', 'analog', 'kaifa', 'other'
    
    -- Customer linkage
    customer_id UUID REFERENCES oms_customers(id) ON DELETE SET NULL,
    
    -- Network topology linkage
    substation_id UUID REFERENCES network_substations(id) ON DELETE SET NULL,
    feeder_id UUID REFERENCES network_feeders(id) ON DELETE SET NULL,
    dp_id UUID REFERENCES network_distribution_points(id) ON DELETE SET NULL,
    
    -- Geographic location
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    building_id VARCHAR(50),
    
    -- Communication status
    communication_status VARCHAR(20) DEFAULT 'unknown', -- 'online', 'offline', 'unknown'
    last_communication TIMESTAMPTZ,
    last_status_change TIMESTAMPTZ,
    
    -- Power status
    power_status VARCHAR(20) DEFAULT 'unknown', -- 'on', 'off', 'unknown'
    last_power_change TIMESTAMPTZ,
    
    -- Kaifa-specific fields
    asset_mrid VARCHAR(100),
    usage_point_mrid VARCHAR(100),
    
    -- ONU-specific fields
    onu_id INT,
    onu_serial_no VARCHAR(100),
    
    -- Metadata
    status VARCHAR(20) DEFAULT 'active', -- 'active', 'inactive', 'decomissioned'
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Performance indexes for oms_meters
CREATE INDEX IF NOT EXISTS idx_oms_meters_number ON oms_meters(meter_number);
CREATE INDEX IF NOT EXISTS idx_oms_meters_customer ON oms_meters(customer_id);
CREATE INDEX IF NOT EXISTS idx_oms_meters_substation ON oms_meters(substation_id);
CREATE INDEX IF NOT EXISTS idx_oms_meters_feeder ON oms_meters(feeder_id);
CREATE INDEX IF NOT EXISTS idx_oms_meters_dp ON oms_meters(dp_id);
CREATE INDEX IF NOT EXISTS idx_oms_meters_comm_status ON oms_meters(communication_status);
CREATE INDEX IF NOT EXISTS idx_oms_meters_power_status ON oms_meters(power_status);
CREATE INDEX IF NOT EXISTS idx_oms_meters_type ON oms_meters(meter_type);
CREATE INDEX IF NOT EXISTS idx_oms_meters_onu_id ON oms_meters(onu_id);
CREATE INDEX IF NOT EXISTS idx_oms_meters_asset_mrid ON oms_meters(asset_mrid);
CREATE INDEX IF NOT EXISTS idx_oms_meters_lat_lng ON oms_meters(location_lat, location_lng);

-- =========================================================
-- 2. SUBSTATION-METER MAPPING (Many-to-Many)
-- =========================================================

-- Direct mapping between substations and meters they control
CREATE TABLE IF NOT EXISTS network_substation_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    substation_id UUID NOT NULL REFERENCES network_substations(id) ON DELETE CASCADE,
    meter_id UUID NOT NULL REFERENCES oms_meters(id) ON DELETE CASCADE,
    feeder_id UUID REFERENCES network_feeders(id) ON DELETE SET NULL,
    priority INTEGER DEFAULT 1, -- 1=critical, 2=high, 3=medium, 4=low
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(substation_id, meter_id)
);

CREATE INDEX IF NOT EXISTS idx_substation_meters_substation ON network_substation_meters(substation_id);
CREATE INDEX IF NOT EXISTS idx_substation_meters_meter ON network_substation_meters(meter_id);
CREATE INDEX IF NOT EXISTS idx_substation_meters_feeder ON network_substation_meters(feeder_id);
CREATE INDEX IF NOT EXISTS idx_substation_meters_priority ON network_substation_meters(priority);

-- =========================================================
-- 3. FEEDER-METER MAPPING (Many-to-Many)
-- =========================================================

-- Direct mapping between feeders and meters they supply
CREATE TABLE IF NOT EXISTS network_feeder_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    feeder_id UUID NOT NULL REFERENCES network_feeders(id) ON DELETE CASCADE,
    meter_id UUID NOT NULL REFERENCES oms_meters(id) ON DELETE CASCADE,
    circuit_path VARCHAR(200), -- Optional circuit path info
    priority INTEGER DEFAULT 2,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(feeder_id, meter_id)
);

CREATE INDEX IF NOT EXISTS idx_feeder_meters_feeder ON network_feeder_meters(feeder_id);
CREATE INDEX IF NOT EXISTS idx_feeder_meters_meter ON network_feeder_meters(meter_id);

-- =========================================================
-- 4. METER STATUS EVENTS TABLE
-- =========================================================

-- Track all meter status changes from all sources
CREATE TABLE IF NOT EXISTS oms_meter_status_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_id UUID NOT NULL REFERENCES oms_meters(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL, -- 'power_on', 'power_off', 'communication_lost', 'communication_restored'
    source_type VARCHAR(32) NOT NULL, -- 'scada', 'kaifa', 'onu', 'call_center', 'system'
    source_event_id VARCHAR(100),
    previous_status VARCHAR(20),
    new_status VARCHAR(20) NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    confidence_score DECIMAL(5,2) DEFAULT 1.0,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_meter_status_events_meter ON oms_meter_status_events(meter_id);
CREATE INDEX IF NOT EXISTS idx_meter_status_events_type ON oms_meter_status_events(event_type);
CREATE INDEX IF NOT EXISTS idx_meter_status_events_source ON oms_meter_status_events(source_type);
CREATE INDEX IF NOT EXISTS idx_meter_status_events_timestamp ON oms_meter_status_events(event_timestamp DESC);

-- =========================================================
-- 5. SCADA EVENT ENHANCEMENTS
-- =========================================================

-- Add columns to link SCADA events to affected meters
ALTER TABLE scada_events 
    ADD COLUMN IF NOT EXISTS affected_meter_count INTEGER DEFAULT 0,
    ADD COLUMN IF NOT EXISTS meters_checked_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS outage_event_id UUID REFERENCES oms_outage_events(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_scada_events_outage ON scada_events(outage_event_id);

-- Link table for SCADA event to affected meters
CREATE TABLE IF NOT EXISTS scada_event_affected_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scada_event_id UUID NOT NULL REFERENCES scada_events(id) ON DELETE CASCADE,
    meter_id UUID NOT NULL REFERENCES oms_meters(id) ON DELETE CASCADE,
    meter_status_before VARCHAR(20),
    meter_status_after VARCHAR(20),
    checked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(scada_event_id, meter_id)
);

CREATE INDEX IF NOT EXISTS idx_scada_affected_meters_event ON scada_event_affected_meters(scada_event_id);
CREATE INDEX IF NOT EXISTS idx_scada_affected_meters_meter ON scada_event_affected_meters(meter_id);

-- =========================================================
-- 6. ONU INTEGRATION ENHANCEMENTS
-- =========================================================

-- Link ONU events to meters
ALTER TABLE onu_events
    ADD COLUMN IF NOT EXISTS meter_id UUID REFERENCES oms_meters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_onu_events_meter ON onu_events(meter_id);

-- Link meters table to oms_meters
ALTER TABLE meters
    ADD COLUMN IF NOT EXISTS oms_meter_id UUID REFERENCES oms_meters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_meters_oms_meter ON meters(oms_meter_id);

-- =========================================================
-- 7. KAIFA INTEGRATION ENHANCEMENTS
-- =========================================================

-- Link Kaifa events to meters via assets
ALTER TABLE kaifa_event_assets
    ADD COLUMN IF NOT EXISTS meter_id UUID REFERENCES oms_meters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_kaifa_assets_meter ON kaifa_event_assets(meter_id);

-- Link Kaifa usage points to meters
ALTER TABLE kaifa_event_usage_points
    ADD COLUMN IF NOT EXISTS meter_id UUID REFERENCES oms_meters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_kaifa_usage_points_meter ON kaifa_event_usage_points(meter_id);

-- =========================================================
-- 8. CALL CENTER INTEGRATION ENHANCEMENTS
-- =========================================================

-- Link call center customers to meters
ALTER TABLE callcenter_customers
    ADD COLUMN IF NOT EXISTS meter_id UUID REFERENCES oms_meters(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_callcenter_customers_meter ON callcenter_customers(meter_id);

-- =========================================================
-- 9. TRIGGERS FOR AUTOMATIC UPDATES
-- =========================================================

-- Trigger to update oms_meters.updated_at
DROP TRIGGER IF EXISTS oms_meters_updated_at ON oms_meters;
CREATE TRIGGER oms_meters_updated_at
    BEFORE UPDATE ON oms_meters
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

-- =========================================================
-- 10. CORE FUNCTIONS FOR METER-SUBSTATION CORRELATION
-- =========================================================

-- Function: Get all meters controlled by a substation
CREATE OR REPLACE FUNCTION get_meters_by_substation(p_substation_id VARCHAR(64))
RETURNS TABLE(
    meter_id UUID,
    meter_number VARCHAR(64),
    communication_status VARCHAR(20),
    power_status VARCHAR(20),
    last_communication TIMESTAMPTZ,
    customer_id UUID,
    location_lat DECIMAL(10,8),
    location_lng DECIMAL(11,8)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.meter_number,
        m.communication_status,
        m.power_status,
        m.last_communication,
        m.customer_id,
        m.location_lat,
        m.location_lng
    FROM oms_meters m
    JOIN network_substation_meters nsm ON m.id = nsm.meter_id
    JOIN network_substations ns ON nsm.substation_id = ns.id
    WHERE ns.substation_id = p_substation_id
    AND m.status = 'active';
END;
$$ LANGUAGE plpgsql;

-- Function: Get all meters on a specific feeder
CREATE OR REPLACE FUNCTION get_meters_by_feeder(p_feeder_id VARCHAR(64))
RETURNS TABLE(
    meter_id UUID,
    meter_number VARCHAR(64),
    communication_status VARCHAR(20),
    power_status VARCHAR(20),
    last_communication TIMESTAMPTZ,
    customer_id UUID,
    location_lat DECIMAL(10,8),
    location_lng DECIMAL(11,8)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        m.id,
        m.meter_number,
        m.communication_status,
        m.power_status,
        m.last_communication,
        m.customer_id,
        m.location_lat,
        m.location_lng
    FROM oms_meters m
    JOIN network_feeder_meters nfm ON m.id = nfm.meter_id
    JOIN network_feeders nf ON nfm.feeder_id = nf.id
    WHERE nf.feeder_id = p_feeder_id
    AND m.status = 'active';
END;
$$ LANGUAGE plpgsql;

-- Function: Update meter status
CREATE OR REPLACE FUNCTION update_meter_status(
    p_meter_number VARCHAR(64),
    p_new_status VARCHAR(20),
    p_event_type VARCHAR(50),
    p_source_type VARCHAR(32),
    p_source_event_id VARCHAR(100) DEFAULT NULL,
    p_event_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    p_metadata JSONB DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_meter_id UUID;
    v_previous_status VARCHAR(20);
    v_status_event_id UUID;
BEGIN
    -- Get meter and current status
    SELECT id, power_status INTO v_meter_id, v_previous_status
    FROM oms_meters
    WHERE meter_number = p_meter_number;

    IF v_meter_id IS NULL THEN
        RAISE EXCEPTION 'Meter not found: %', p_meter_number;
    END IF;

    -- Update meter status
    UPDATE oms_meters
    SET 
        power_status = p_new_status,
        last_power_change = p_event_timestamp,
        last_status_change = p_event_timestamp,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = v_meter_id;

    -- Record status event
    INSERT INTO oms_meter_status_events (
        meter_id, event_type, source_type, source_event_id,
        previous_status, new_status, event_timestamp, metadata
    ) VALUES (
        v_meter_id, p_event_type, p_source_type, p_source_event_id,
        v_previous_status, p_new_status, p_event_timestamp, p_metadata
    ) RETURNING id INTO v_status_event_id;

    RETURN v_status_event_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 11. SCADA EVENT PROCESSING FUNCTION
-- =========================================================

-- Function: Process SCADA event and check affected meters
CREATE OR REPLACE FUNCTION process_scada_event_meters(
    p_scada_event_id UUID,
    p_substation_id VARCHAR(64),
    p_feeder_id VARCHAR(64) DEFAULT NULL,
    p_event_timestamp TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
RETURNS TABLE(
    total_meters INTEGER,
    offline_meters INTEGER,
    online_meters INTEGER,
    unknown_meters INTEGER,
    outage_event_id UUID
) AS $$
DECLARE
    v_total_meters INTEGER := 0;
    v_offline_meters INTEGER := 0;
    v_online_meters INTEGER := 0;
    v_unknown_meters INTEGER := 0;
    v_outage_event_id UUID;
    v_meter_record RECORD;
    v_substation_uuid UUID;
    v_feeder_uuid UUID;
    v_scada_event_location RECORD;
BEGIN
    -- Get substation UUID
    SELECT id INTO v_substation_uuid
    FROM network_substations
    WHERE substation_id = p_substation_id;

    -- Get feeder UUID if provided
    IF p_feeder_id IS NOT NULL THEN
        SELECT id INTO v_feeder_uuid
        FROM network_feeders
        WHERE feeder_id = p_feeder_id;
    END IF;

    -- Get SCADA event location
    SELECT latitude, longitude, severity, reason
    INTO v_scada_event_location
    FROM scada_events
    WHERE id = p_scada_event_id;

    -- Get all meters for this substation/feeder
    FOR v_meter_record IN (
        SELECT DISTINCT
            m.id as meter_id,
            m.meter_number,
            m.communication_status,
            m.power_status,
            m.last_communication,
            m.location_lat,
            m.location_lng
        FROM oms_meters m
        LEFT JOIN network_substation_meters nsm ON m.id = nsm.meter_id
        LEFT JOIN network_feeder_meters nfm ON m.id = nfm.meter_id
        WHERE m.status = 'active'
        AND (
            (nsm.substation_id = v_substation_uuid)
            OR 
            (v_feeder_uuid IS NOT NULL AND nfm.feeder_id = v_feeder_uuid)
        )
    ) LOOP
        v_total_meters := v_total_meters + 1;

        -- Check meter status
        -- Consider meter offline if:
        -- 1. power_status = 'off'
        -- 2. communication_status = 'offline'
        -- 3. No communication in last 15 minutes
        IF v_meter_record.power_status = 'off' 
           OR v_meter_record.communication_status = 'offline'
           OR v_meter_record.last_communication IS NULL
           OR v_meter_record.last_communication < (p_event_timestamp - INTERVAL '15 minutes') THEN
            
            v_offline_meters := v_offline_meters + 1;

            -- Record affected meter
            INSERT INTO scada_event_affected_meters (
                scada_event_id, meter_id, meter_status_before, meter_status_after, checked_at
            ) VALUES (
                p_scada_event_id, v_meter_record.meter_id, 
                v_meter_record.power_status, 'off', CURRENT_TIMESTAMP
            ) ON CONFLICT (scada_event_id, meter_id) DO NOTHING;

            -- Update meter status
            UPDATE oms_meters
            SET 
                power_status = 'off',
                communication_status = 'offline',
                last_status_change = p_event_timestamp,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_meter_record.meter_id;

            -- Record meter status event
            INSERT INTO oms_meter_status_events (
                meter_id, event_type, source_type, source_event_id,
                previous_status, new_status, event_timestamp, confidence_score
            ) VALUES (
                v_meter_record.meter_id, 'power_off', 'scada', p_scada_event_id::TEXT,
                v_meter_record.power_status, 'off', p_event_timestamp, 0.9
            );

        ELSIF v_meter_record.power_status = 'on' 
              AND v_meter_record.communication_status = 'online' THEN
            v_online_meters := v_online_meters + 1;
        ELSE
            v_unknown_meters := v_unknown_meters + 1;
        END IF;
    END LOOP;

    -- Create or update OMS outage event if offline meters detected
    IF v_offline_meters > 0 THEN
        -- Create outage event
        INSERT INTO oms_outage_events (
            event_id, event_type, status, severity, confidence_score,
            affected_customers_count, first_detected_at,
            substation_id, feeder_id,
            event_latitude, event_longitude,
            root_cause, description
        ) VALUES (
            'OMS_SCADA_' || extract(epoch from p_event_timestamp)::bigint || '_' || substr(md5(random()::text), 1, 8),
            'outage', 'detected', 
            COALESCE(v_scada_event_location.severity, 'high')::VARCHAR(16),
            0.9, -- High confidence from SCADA
            v_offline_meters,
            p_event_timestamp,
            v_substation_uuid, v_feeder_uuid,
            v_scada_event_location.latitude, v_scada_event_location.longitude,
            'SCADA Event: ' || p_substation_id || ' / ' || COALESCE(p_feeder_id, 'N/A'),
            'Substation/Feeder issue detected. ' || v_offline_meters || ' meters offline. ' || 
            COALESCE(v_scada_event_location.reason, 'No reason provided.')
        ) RETURNING id INTO v_outage_event_id;

        -- Link SCADA event to outage event
        INSERT INTO oms_event_sources (
            outage_event_id, source_type, source_event_id, source_table,
            correlation_weight, detected_at
        ) VALUES (
            v_outage_event_id, 'scada', p_scada_event_id::TEXT, 'scada_events',
            1.0, p_event_timestamp
        );

        -- Add timeline entry
        INSERT INTO oms_event_timeline (
            outage_event_id, event_type, status, description, source, timestamp
        ) VALUES (
            v_outage_event_id, 'detected', 'detected',
            'SCADA event at ' || p_substation_id || ' affecting ' || v_offline_meters || ' meters',
            'scada', p_event_timestamp
        );

        -- Update SCADA event with outage info
        UPDATE scada_events
        SET 
            affected_meter_count = v_offline_meters,
            meters_checked_at = CURRENT_TIMESTAMP,
            outage_event_id = v_outage_event_id
        WHERE id = p_scada_event_id;
    END IF;

    -- Return summary
    RETURN QUERY SELECT 
        v_total_meters, 
        v_offline_meters, 
        v_online_meters, 
        v_unknown_meters, 
        v_outage_event_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 12. ENHANCED SCADA INSERT FUNCTION
-- =========================================================

-- Enhanced function to insert SCADA event and automatically check meters
CREATE OR REPLACE FUNCTION insert_scada_event_with_meter_check(json_data JSONB)
RETURNS JSONB AS $$
DECLARE
    v_scada_event_id UUID;
    v_substation_id VARCHAR(64);
    v_feeder_id VARCHAR(64);
    v_event_timestamp TIMESTAMPTZ;
    v_meter_check_result RECORD;
    v_result JSONB;
BEGIN
    -- Extract data
    v_substation_id := json_data->>'substationId';
    v_feeder_id := json_data->>'feederId';
    v_event_timestamp := (json_data->>'timestamp')::TIMESTAMPTZ;

    -- Insert SCADA event (reuse existing function)
    v_scada_event_id := insert_scada_event_from_json(json_data);

    -- Process meters for critical events
    IF json_data->>'alarmType' IN ('fault', 'breaker_trip', 'power_failure', 'outage') THEN
        -- Check all affected meters
        SELECT * INTO v_meter_check_result
        FROM process_scada_event_meters(
            v_scada_event_id,
            v_substation_id,
            v_feeder_id,
            v_event_timestamp
        );

        -- Build result
        v_result := jsonb_build_object(
            'scada_event_id', v_scada_event_id,
            'meters_checked', true,
            'total_meters', v_meter_check_result.total_meters,
            'offline_meters', v_meter_check_result.offline_meters,
            'online_meters', v_meter_check_result.online_meters,
            'unknown_meters', v_meter_check_result.unknown_meters,
            'outage_event_id', v_meter_check_result.outage_event_id
        );
    ELSE
        v_result := jsonb_build_object(
            'scada_event_id', v_scada_event_id,
            'meters_checked', false,
            'reason', 'Non-critical alarm type'
        );
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 13. VIEWS FOR METER-SUBSTATION RELATIONSHIPS
-- =========================================================

-- View: Substations with meter counts
CREATE OR REPLACE VIEW network_substations_with_meters AS
SELECT 
    ns.id,
    ns.substation_id,
    ns.name,
    ns.location_lat,
    ns.location_lng,
    ns.status,
    COUNT(DISTINCT nsm.meter_id) as total_meters,
    COUNT(DISTINCT CASE WHEN m.power_status = 'on' THEN m.id END) as online_meters,
    COUNT(DISTINCT CASE WHEN m.power_status = 'off' THEN m.id END) as offline_meters,
    COUNT(DISTINCT CASE WHEN m.power_status = 'unknown' THEN m.id END) as unknown_meters,
    COUNT(DISTINCT CASE WHEN m.communication_status = 'offline' THEN m.id END) as comm_offline_meters
FROM network_substations ns
LEFT JOIN network_substation_meters nsm ON ns.id = nsm.substation_id
LEFT JOIN oms_meters m ON nsm.meter_id = m.id AND m.status = 'active'
GROUP BY ns.id, ns.substation_id, ns.name, ns.location_lat, ns.location_lng, ns.status;

-- View: Feeders with meter counts
CREATE OR REPLACE VIEW network_feeders_with_meters AS
SELECT 
    nf.id,
    nf.feeder_id,
    nf.name,
    nf.substation_id,
    ns.substation_id as substation_code,
    ns.name as substation_name,
    nf.location_lat,
    nf.location_lng,
    nf.status,
    COUNT(DISTINCT nfm.meter_id) as total_meters,
    COUNT(DISTINCT CASE WHEN m.power_status = 'on' THEN m.id END) as online_meters,
    COUNT(DISTINCT CASE WHEN m.power_status = 'off' THEN m.id END) as offline_meters,
    COUNT(DISTINCT CASE WHEN m.power_status = 'unknown' THEN m.id END) as unknown_meters
FROM network_feeders nf
LEFT JOIN network_substations ns ON nf.substation_id = ns.id
LEFT JOIN network_feeder_meters nfm ON nf.id = nfm.feeder_id
LEFT JOIN oms_meters m ON nfm.meter_id = m.id AND m.status = 'active'
GROUP BY nf.id, nf.feeder_id, nf.name, nf.substation_id, ns.substation_id, 
         ns.name, nf.location_lat, nf.location_lng, nf.status;

-- View: Meters with full topology
CREATE OR REPLACE VIEW oms_meters_with_topology AS
SELECT 
    m.id as meter_id,
    m.meter_number,
    m.meter_type,
    m.communication_status,
    m.power_status,
    m.last_communication,
    m.last_power_change,
    m.location_lat,
    m.location_lng,
    -- Customer info
    c.customer_id,
    c.phone as customer_phone,
    c.address as customer_address,
    -- Substation info
    ns.substation_id,
    ns.name as substation_name,
    -- Feeder info
    nf.feeder_id,
    nf.name as feeder_name,
    -- Distribution point info
    ndp.dp_id,
    ndp.name as dp_name
FROM oms_meters m
LEFT JOIN oms_customers c ON m.customer_id = c.id
LEFT JOIN network_substations ns ON m.substation_id = ns.id
LEFT JOIN network_feeders nf ON m.feeder_id = nf.id
LEFT JOIN network_distribution_points ndp ON m.dp_id = ndp.id
WHERE m.status = 'active';

-- =========================================================
-- 14. COMMENTS AND DOCUMENTATION
-- =========================================================

COMMENT ON TABLE oms_meters IS 'Central registry for all meters across all data providers (SCADA, ONU, KAIFA, CALL CENTER)';
COMMENT ON TABLE network_substation_meters IS 'Maps substations to the meters they control for SCADA event processing';
COMMENT ON TABLE network_feeder_meters IS 'Maps feeders to the meters they supply';
COMMENT ON TABLE oms_meter_status_events IS 'Audit trail of all meter status changes from all sources';
COMMENT ON TABLE scada_event_affected_meters IS 'Links SCADA events to meters that were checked/affected';

COMMENT ON FUNCTION process_scada_event_meters IS 'Processes a SCADA event by checking status of all related meters and creating outage events for offline meters';
COMMENT ON FUNCTION get_meters_by_substation IS 'Returns all active meters controlled by a given substation';
COMMENT ON FUNCTION get_meters_by_feeder IS 'Returns all active meters supplied by a given feeder';

-- =========================================================
-- END OF METER CORRELATION ENHANCEMENT
-- =========================================================

