-- =========================================================
-- OMS Data Migration Script
-- =========================================================
-- This script migrates and correlates data from existing services
-- into the OMS correlated schema for intelligent outage management.
-- =========================================================

-- =========================================================
-- 1. NETWORK TOPOLOGY SETUP
-- =========================================================

-- Create sample network topology based on existing data
INSERT INTO network_substations (substation_id, name, location_lat, location_lng, region_code, voltage_level)
SELECT DISTINCT 
    se.substation_id,
    'Substation ' || se.substation_id,
    se.latitude,
    se.longitude,
    'REGION_' || substr(se.substation_id, 1, 2),
    '33kV'
FROM scada_events se
WHERE se.substation_id IS NOT NULL
ON CONFLICT (substation_id) DO NOTHING;

INSERT INTO network_feeders (feeder_id, substation_id, name, location_lat, location_lng, capacity_kva)
SELECT DISTINCT 
    se.feeder_id,
    ns.id,
    'Feeder ' || se.feeder_id,
    se.latitude,
    se.longitude,
    1000.0
FROM scada_events se
JOIN network_substations ns ON se.substation_id = ns.substation_id
WHERE se.feeder_id IS NOT NULL
ON CONFLICT (feeder_id) DO NOTHING;

INSERT INTO network_distribution_points (dp_id, feeder_id, name, location_lat, location_lng, building_id)
SELECT DISTINCT 
    COALESCE(o.building_id, 'DP_' || substr(o.onu_serial_no, 1, 8)),
    nf.id,
    'DP ' || COALESCE(o.building_id, substr(o.onu_serial_no, 1, 8)),
    o.location_lat,
    o.location_lng,
    o.building_id
FROM onus o
JOIN network_feeders nf ON nf.feeder_id = 'FEEDER_001' -- Default feeder assignment
WHERE o.building_id IS NOT NULL
ON CONFLICT (dp_id) DO NOTHING;

-- =========================================================
-- 2. CUSTOMER & ASSET MIGRATION
-- =========================================================

-- Migrate customers from call center data
INSERT INTO oms_customers (customer_id, phone, address, building_id, location_lat, location_lng)
SELECT DISTINCT 
    ('CUST_' || substr(cc.phone, -8))::varchar(64),
    cc.phone,
    cc.address::text,
    NULL::varchar(50), -- Will be updated from ONU data
    NULL::decimal,     -- Will be updated from ONU data
    NULL::decimal
FROM callcenter_customers cc
JOIN callcenter_tickets ct ON cc.ticket_id = ct.id
WHERE cc.phone IS NOT NULL
ON CONFLICT (customer_id) DO NOTHING;

-- Update customer locations from ONU data
UPDATE oms_customers 
SET 
    building_id = o.building_id,
    location_lat = o.location_lat,
    location_lng = o.location_lng
FROM onus o
WHERE oms_customers.building_id IS NULL 
AND o.building_id IS NOT NULL;

-- Migrate smart meters from Kaifa data
INSERT INTO oms_smart_meters (meter_number, customer_id, asset_mrid, usage_point_mrid, location_lat, location_lng, last_communication)
SELECT DISTINCT 
    kea.mrid,
    oc.id,
    kea.mrid,
    keup.mrid,
    NULL::decimal, -- Will be updated from customer location
    NULL::decimal,
    ke.event_timestamp
FROM kaifa_event_assets kea
JOIN kaifa_event_payloads kep ON kea.payload_id = kep.id
JOIN kaifa_events ke ON kep.event_id = ke.id
JOIN kaifa_event_usage_points keup ON keup.payload_id = kep.id
LEFT JOIN oms_customers oc ON oc.customer_id = 'CUST_' || substr(kea.mrid, -8)
WHERE kea.mrid IS NOT NULL
ON CONFLICT (meter_number) DO NOTHING;

-- Update smart meter locations from customer data
UPDATE oms_smart_meters 
SET 
    location_lat = oc.location_lat,
    location_lng = oc.location_lng
FROM oms_customers oc
WHERE oms_smart_meters.customer_id = oc.id
AND oms_smart_meters.location_lat IS NULL;

-- Migrate ONU devices
INSERT INTO oms_onu_devices (onu_id, onu_serial_no, customer_id, fibertech_id, olt_name, location_lat, location_lng, power_status, last_power_change)
SELECT 
    o.id,
    o.onu_serial_no,
    oc.id,
    o.fibertech_id,
    o.olt_name,
    o.location_lat,
    o.location_lng,
    o.onu_power_flag,
    o.onu_power_flag_date
FROM onus o
LEFT JOIN oms_customers oc ON oc.building_id = o.building_id
ON CONFLICT (onu_id) DO NOTHING;

-- =========================================================
-- 3. EVENT CORRELATION MIGRATION
-- =========================================================

-- Function to correlate and migrate events
CREATE OR REPLACE FUNCTION migrate_and_correlate_events()
RETURNS TABLE (
    migrated_events INTEGER,
    correlated_outages INTEGER,
    scada_events INTEGER,
    kaifa_events INTEGER,
    onu_events INTEGER,
    call_center_events INTEGER
) AS $$
DECLARE
    v_migrated_events INTEGER := 0;
    v_correlated_outages INTEGER := 0;
    v_scada_events INTEGER := 0;
    v_kaifa_events INTEGER := 0;
    v_onu_events INTEGER := 0;
    v_call_center_events INTEGER := 0;
    v_outage_event_id UUID;
    v_event_record RECORD;
BEGIN
    -- Migrate SCADA events
    FOR v_event_record IN 
        SELECT 
            se.id::text as source_event_id,
            se.event_timestamp,
            se.latitude,
            se.longitude,
            se.event_type,
            se.severity,
            se.reason
        FROM scada_events se
        WHERE se.event_type IN ('BreakerTrip', 'FuseTrip', 'Alarm')
        ORDER BY se.event_timestamp
    LOOP
        -- Correlate SCADA event
        SELECT oms_correlate_events(
            'outage',
            'scada',
            v_event_record.source_event_id,
            v_event_record.event_timestamp,
            v_event_record.latitude,
            v_event_record.longitude,
            30, -- correlation window
            1000 -- spatial radius
        ) INTO v_outage_event_id;
        
        v_scada_events := v_scada_events + 1;
        v_migrated_events := v_migrated_events + 1;
    END LOOP;

    -- Migrate Kaifa Last-Gasp events
    FOR v_event_record IN 
        SELECT 
            ke.id::text as source_event_id,
            ke.event_timestamp,
            kea.name as location_name,
            NULL::DECIMAL as latitude,
            NULL::DECIMAL as longitude,
            'LastGasp' as event_type,
            kes.value as severity,
            kes.reason
        FROM kaifa_events ke
        JOIN kaifa_event_payloads kep ON kep.event_id = ke.id
        JOIN kaifa_event_assets kea ON kea.payload_id = kep.id
        JOIN kaifa_event_status kes ON kes.payload_id = kep.id
        WHERE ke.message_type = 'LastGasp'
        AND kes.value = 'offline'
        ORDER BY ke.event_timestamp
    LOOP
        -- Correlate Kaifa event
        SELECT oms_correlate_events(
            'outage',
            'kaifa',
            v_event_record.source_event_id,
            v_event_record.event_timestamp,
            v_event_record.latitude,
            v_event_record.longitude,
            30, -- correlation window
            1000 -- spatial radius
        ) INTO v_outage_event_id;
        
        v_kaifa_events := v_kaifa_events + 1;
        v_migrated_events := v_migrated_events + 1;
    END LOOP;

    -- Migrate ONU power events
    FOR v_event_record IN 
        SELECT 
            oe.id::text as source_event_id,
            oe.timestamp as event_timestamp,
            o.location_lat as latitude,
            o.location_lng as longitude,
            oe.event_type,
            oe.alarm_category as severity,
            oe.alarm_type as reason
        FROM onu_events oe
        JOIN onus o ON oe.onu_id = o.id
        WHERE oe.event_type IN ('ONU_LastGaspAlert', 'ONU_PowerRestored')
        ORDER BY oe.timestamp
    LOOP
        -- Correlate ONU event
        SELECT oms_correlate_events(
            'outage',
            'onu',
            v_event_record.source_event_id,
            v_event_record.event_timestamp,
            v_event_record.latitude,
            v_event_record.longitude,
            30, -- correlation window
            1000 -- spatial radius
        ) INTO v_outage_event_id;
        
        v_onu_events := v_onu_events + 1;
        v_migrated_events := v_migrated_events + 1;
    END LOOP;

    -- Migrate Call Center tickets
    FOR v_event_record IN 
        SELECT 
            ct.id::text as source_event_id,
            ct.intake_timestamp as event_timestamp,
            cc.address as location_name,
            NULL::DECIMAL as latitude,
            NULL::DECIMAL as longitude,
            'CustomerReport' as event_type,
            'medium' as severity,
            'Customer reported outage' as reason
        FROM callcenter_tickets ct
        JOIN callcenter_customers cc ON cc.ticket_id = ct.id
        WHERE ct.status = 'Registered'
        ORDER BY ct.intake_timestamp
    LOOP
        -- Correlate Call Center event
        SELECT oms_correlate_events(
            'outage',
            'call_center',
            v_event_record.source_event_id,
            v_event_record.event_timestamp,
            v_event_record.latitude,
            v_event_record.longitude,
            30, -- correlation window
            1000 -- spatial radius
        ) INTO v_outage_event_id;
        
        v_call_center_events := v_call_center_events + 1;
        v_migrated_events := v_migrated_events + 1;
    END LOOP;

    -- Count correlated outages
    SELECT COUNT(*) INTO v_correlated_outages FROM oms_outage_events;

    RETURN QUERY SELECT 
        v_migrated_events,
        v_correlated_outages,
        v_scada_events,
        v_kaifa_events,
        v_onu_events,
        v_call_center_events;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 4. DATA QUALITY AND VALIDATION
-- =========================================================

-- Function to validate migrated data
CREATE OR REPLACE FUNCTION validate_migrated_data()
RETURNS TABLE (
    validation_check VARCHAR(100),
    status VARCHAR(20),
    count_value BIGINT,
    message TEXT
) AS $$
BEGIN
    -- Check network topology completeness
    RETURN QUERY SELECT 
        'Network Topology'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Substations created'::text as message
    FROM network_substations;

    RETURN QUERY SELECT 
        'Network Topology'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Feeders created'::text as message
    FROM network_feeders;

    -- Check customer migration
    RETURN QUERY SELECT 
        'Customer Migration'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Customers migrated'::text as message
    FROM oms_customers;

    -- Check asset migration
    RETURN QUERY SELECT 
        'Asset Migration'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Smart meters migrated'::text as message
    FROM oms_smart_meters;

    RETURN QUERY SELECT 
        'Asset Migration'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'ONU devices migrated'::text as message
    FROM oms_onu_devices;

    -- Check event correlation
    RETURN QUERY SELECT 
        'Event Correlation'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Outage events created'::text as message
    FROM oms_outage_events;

    RETURN QUERY SELECT 
        'Event Correlation'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Event sources linked'::text as message
    FROM oms_event_sources;

    -- Check data quality
    RETURN QUERY SELECT 
        'Data Quality'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Events without location data'::text as message
    FROM oms_outage_events 
    WHERE dp_id IS NULL AND substation_id IS NULL;

    RETURN QUERY SELECT 
        'Data Quality'::varchar(100) as validation_check,
        (CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END)::varchar(20) as status,
        COUNT(*) as count_value,
        'Events with zero confidence score'::text as message
    FROM oms_outage_events 
    WHERE confidence_score = 0.0;

END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 5. MIGRATION EXECUTION
-- =========================================================

-- Execute the migration
DO $$
DECLARE
    migration_result RECORD;
    validation_result RECORD;
BEGIN
    RAISE NOTICE 'Starting OMS data migration...';
    
    -- Execute migration
    SELECT * INTO migration_result FROM migrate_and_correlate_events();
    
    RAISE NOTICE 'Migration completed:';
    RAISE NOTICE '  Migrated events: %', migration_result.migrated_events;
    RAISE NOTICE '  Correlated outages: %', migration_result.correlated_outages;
    RAISE NOTICE '  SCADA events: %', migration_result.scada_events;
    RAISE NOTICE '  Kaifa events: %', migration_result.kaifa_events;
    RAISE NOTICE '  ONU events: %', migration_result.onu_events;
    RAISE NOTICE '  Call Center events: %', migration_result.call_center_events;
    
    -- Validate migration
    RAISE NOTICE 'Validating migrated data...';
    
    FOR validation_result IN 
        SELECT * FROM validate_migrated_data()
    LOOP
        RAISE NOTICE '  %: % - % (%)', 
            validation_result.validation_check,
            validation_result.status,
            validation_result.message,
            validation_result.count_value;
    END LOOP;
    
    RAISE NOTICE 'Migration and validation completed successfully!';
END;
$$;

-- =========================================================
-- 6. POST-MIGRATION OPTIMIZATION
-- =========================================================

-- Update statistics for better query performance
ANALYZE network_substations;
ANALYZE network_feeders;
ANALYZE network_distribution_points;
ANALYZE oms_customers;
ANALYZE oms_smart_meters;
ANALYZE oms_onu_devices;
ANALYZE oms_outage_events;
ANALYZE oms_event_sources;
ANALYZE oms_event_timeline;

-- Update affected customer counts
UPDATE oms_outage_events 
SET affected_customers_count = (
    SELECT COUNT(DISTINCT oc.id)
    FROM oms_customers oc
    JOIN oms_smart_meters osm ON osm.customer_id = oc.id
    JOIN oms_onu_devices ood ON ood.customer_id = oc.id
    WHERE oc.dp_id = oms_outage_events.dp_id
    OR oc.building_id IN (
        SELECT ndp.building_id 
        FROM network_distribution_points ndp 
        WHERE ndp.id = oms_outage_events.dp_id
    )
)
WHERE affected_customers_count = 0;

-- =========================================================
-- 7. MIGRATION SUMMARY REPORT
-- =========================================================

-- Create migration summary view
CREATE OR REPLACE VIEW oms_migration_summary AS
SELECT 
    'Network Topology' as component,
    COUNT(*) as count,
    'Substations' as detail
FROM network_substations
UNION ALL
SELECT 
    'Network Topology' as component,
    COUNT(*) as count,
    'Feeders' as detail
FROM network_feeders
UNION ALL
SELECT 
    'Network Topology' as component,
    COUNT(*) as count,
    'Distribution Points' as detail
FROM network_distribution_points
UNION ALL
SELECT 
    'Customer Assets' as component,
    COUNT(*) as count,
    'Customers' as detail
FROM oms_customers
UNION ALL
SELECT 
    'Customer Assets' as component,
    COUNT(*) as count,
    'Smart Meters' as detail
FROM oms_smart_meters
UNION ALL
SELECT 
    'Customer Assets' as component,
    COUNT(*) as count,
    'ONU Devices' as detail
FROM oms_onu_devices
UNION ALL
SELECT 
    'Outage Management' as component,
    COUNT(*) as count,
    'Outage Events' as detail
FROM oms_outage_events
UNION ALL
SELECT 
    'Outage Management' as component,
    COUNT(*) as count,
    'Event Sources' as detail
FROM oms_event_sources
UNION ALL
SELECT 
    'Outage Management' as component,
    COUNT(*) as count,
    'Timeline Events' as detail
FROM oms_event_timeline;

-- Display migration summary
SELECT 
    component,
    SUM(count) as total_count,
    STRING_AGG(detail || ': ' || count, ', ') as details
FROM oms_migration_summary
GROUP BY component
ORDER BY component;

-- =========================================================
-- END OF MIGRATION SCRIPT
-- =========================================================
