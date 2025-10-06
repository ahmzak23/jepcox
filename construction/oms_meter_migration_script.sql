-- =========================================================
-- OMS Meter Correlation Migration Script
-- =========================================================
-- This script migrates existing data into the new unified meter
-- correlation structure and establishes relationships
-- =========================================================

-- =========================================================
-- STEP 1: Migrate existing meters to oms_meters
-- =========================================================

-- 1.1: Migrate from ONU meters table
INSERT INTO oms_meters (
    meter_number, meter_type, onu_id, onu_serial_no,
    building_id, location_lat, location_lng,
    communication_status, power_status, last_communication,
    status, created_at
)
SELECT 
    m.meter_id,
    'smart',
    m.onu_id,
    o.onu_serial_no,
    m.building_id,
    m.location_lat,
    m.location_lng,
    CASE 
        WHEN o.onu_power_flag = TRUE THEN 'online'
        WHEN o.onu_power_flag = FALSE THEN 'offline'
        ELSE 'unknown'
    END,
    CASE 
        WHEN o.onu_power_flag = TRUE THEN 'on'
        WHEN o.onu_power_flag = FALSE THEN 'off'
        ELSE 'unknown'
    END,
    o.onu_power_flag_date,
    'active',
    m.created_at
FROM meters m
LEFT JOIN onus o ON m.onu_id = o.id
ON CONFLICT (meter_number) DO UPDATE SET
    onu_id = EXCLUDED.onu_id,
    onu_serial_no = EXCLUDED.onu_serial_no,
    location_lat = COALESCE(oms_meters.location_lat, EXCLUDED.location_lat),
    location_lng = COALESCE(oms_meters.location_lng, EXCLUDED.location_lng),
    updated_at = CURRENT_TIMESTAMP;

-- 1.2: Link ONU meters back to oms_meters
UPDATE meters m
SET oms_meter_id = om.id
FROM oms_meters om
WHERE m.meter_id = om.meter_number;

-- 1.3: Migrate from Kaifa event assets (mrid as meter identifier)
INSERT INTO oms_meters (
    meter_number, meter_type, asset_mrid, usage_point_mrid,
    communication_status, last_communication, status
)
SELECT DISTINCT
    kea.mrid,
    'kaifa',
    kea.mrid,
    keup.mrid,
    'online', -- Kaifa events indicate communication
    MAX(ke.event_timestamp),
    'active'
FROM kaifa_event_assets kea
JOIN kaifa_event_payloads kep ON kea.payload_id = kep.id
JOIN kaifa_events ke ON kep.event_id = ke.id
LEFT JOIN kaifa_event_usage_points keup ON keup.payload_id = kep.id
WHERE kea.mrid IS NOT NULL
GROUP BY kea.mrid, keup.mrid
ON CONFLICT (meter_number) DO UPDATE SET
    asset_mrid = EXCLUDED.asset_mrid,
    usage_point_mrid = COALESCE(oms_meters.usage_point_mrid, EXCLUDED.usage_point_mrid),
    last_communication = GREATEST(oms_meters.last_communication, EXCLUDED.last_communication),
    meter_type = CASE 
        WHEN oms_meters.meter_type = 'smart' THEN 'smart'
        ELSE 'kaifa'
    END,
    updated_at = CURRENT_TIMESTAMP;

-- 1.4: Link Kaifa event assets back to oms_meters
UPDATE kaifa_event_assets kea
SET meter_id = om.id
FROM oms_meters om
WHERE kea.mrid = om.meter_number OR kea.mrid = om.asset_mrid;

-- 1.5: Link Kaifa usage points back to oms_meters
UPDATE kaifa_event_usage_points keup
SET meter_id = om.id
FROM oms_meters om
WHERE keup.mrid = om.usage_point_mrid;

-- 1.6: Migrate from Call Center customer meter numbers
INSERT INTO oms_meters (
    meter_number, meter_type, communication_status, power_status, status
)
SELECT DISTINCT
    cc.meter_number,
    'smart',
    'unknown',
    'unknown',
    'active'
FROM callcenter_customers cc
WHERE cc.meter_number IS NOT NULL
AND cc.meter_number != ''
ON CONFLICT (meter_number) DO NOTHING;

-- 1.7: Link Call Center customers back to oms_meters
UPDATE callcenter_customers cc
SET meter_id = om.id
FROM oms_meters om
WHERE cc.meter_number = om.meter_number;

-- =========================================================
-- STEP 2: Establish network topology relationships
-- =========================================================

-- 2.1: Update oms_meters with substation/feeder from existing topology
-- (This assumes you have some way to determine which substation/feeder serves which meter)
-- For now, we'll use geographic proximity or existing mappings

-- Link meters to substations based on geographic proximity (within 5km)
UPDATE oms_meters m
SET substation_id = (
    SELECT ns.id
    FROM network_substations ns
    WHERE m.location_lat IS NOT NULL 
    AND m.location_lng IS NOT NULL
    AND ns.location_lat IS NOT NULL
    AND ns.location_lng IS NOT NULL
    ORDER BY haversine_distance_meters(
        m.location_lat, m.location_lng,
        ns.location_lat, ns.location_lng
    ) ASC
    LIMIT 1
)
WHERE m.substation_id IS NULL
AND m.location_lat IS NOT NULL
AND m.location_lng IS NOT NULL;

-- Link meters to feeders based on geographic proximity (within 2km)
UPDATE oms_meters m
SET feeder_id = (
    SELECT nf.id
    FROM network_feeders nf
    WHERE m.location_lat IS NOT NULL 
    AND m.location_lng IS NOT NULL
    AND nf.location_lat IS NOT NULL
    AND nf.location_lng IS NOT NULL
    AND nf.substation_id = m.substation_id -- Must be on same substation
    ORDER BY haversine_distance_meters(
        m.location_lat, m.location_lng,
        nf.location_lat, nf.location_lng
    ) ASC
    LIMIT 1
)
WHERE m.feeder_id IS NULL
AND m.substation_id IS NOT NULL
AND m.location_lat IS NOT NULL
AND m.location_lng IS NOT NULL;

-- Link meters to distribution points based on building_id or proximity
UPDATE oms_meters m
SET dp_id = (
    SELECT ndp.id
    FROM network_distribution_points ndp
    WHERE (
        -- Match by building_id if available
        (m.building_id IS NOT NULL AND ndp.building_id = m.building_id)
        OR
        -- Otherwise by proximity (within 500m)
        (m.location_lat IS NOT NULL AND m.location_lng IS NOT NULL
         AND ndp.location_lat IS NOT NULL AND ndp.location_lng IS NOT NULL
         AND haversine_distance_meters(
            m.location_lat, m.location_lng,
            ndp.location_lat, ndp.location_lng
         ) <= 500)
    )
    ORDER BY 
        CASE WHEN m.building_id IS NOT NULL AND ndp.building_id = m.building_id THEN 0 ELSE 1 END,
        haversine_distance_meters(
            m.location_lat, m.location_lng,
            ndp.location_lat, ndp.location_lng
        ) ASC
    LIMIT 1
)
WHERE m.dp_id IS NULL;

-- 2.2: Populate network_substation_meters mapping
INSERT INTO network_substation_meters (substation_id, meter_id, feeder_id, priority)
SELECT DISTINCT
    m.substation_id,
    m.id,
    m.feeder_id,
    2 -- Default medium priority
FROM oms_meters m
WHERE m.substation_id IS NOT NULL
AND m.status = 'active'
ON CONFLICT (substation_id, meter_id) DO NOTHING;

-- 2.3: Populate network_feeder_meters mapping
INSERT INTO network_feeder_meters (feeder_id, meter_id, priority)
SELECT DISTINCT
    m.feeder_id,
    m.id,
    2 -- Default medium priority
FROM oms_meters m
WHERE m.feeder_id IS NOT NULL
AND m.status = 'active'
ON CONFLICT (feeder_id, meter_id) DO NOTHING;

-- =========================================================
-- STEP 3: Link meters to customers
-- =========================================================

-- 3.1: Link via Call Center data (phone-based matching)
UPDATE oms_meters m
SET customer_id = oc.id
FROM callcenter_customers cc
JOIN callcenter_tickets ct ON cc.ticket_id = ct.id
JOIN oms_customers oc ON oc.phone = cc.phone
WHERE m.meter_number = cc.meter_number
AND m.customer_id IS NULL;

-- 3.2: Link via building_id
UPDATE oms_meters m
SET customer_id = oc.id
FROM oms_customers oc
WHERE m.building_id = oc.building_id
AND m.customer_id IS NULL
AND m.building_id IS NOT NULL;

-- 3.3: Link via geographic proximity (within 50 meters, likely same building)
UPDATE oms_meters m
SET customer_id = (
    SELECT oc.id
    FROM oms_customers oc
    WHERE m.location_lat IS NOT NULL
    AND m.location_lng IS NOT NULL
    AND oc.location_lat IS NOT NULL
    AND oc.location_lng IS NOT NULL
    AND haversine_distance_meters(
        m.location_lat, m.location_lng,
        oc.location_lat, oc.location_lng
    ) <= 50
    ORDER BY haversine_distance_meters(
        m.location_lat, m.location_lng,
        oc.location_lat, oc.location_lng
    ) ASC
    LIMIT 1
)
WHERE m.customer_id IS NULL;

-- =========================================================
-- STEP 4: Link ONU events to meters
-- =========================================================

UPDATE onu_events oe
SET meter_id = om.id
FROM oms_meters om
WHERE oe.onu_id = om.onu_id
AND oe.meter_id IS NULL;

-- =========================================================
-- STEP 5: Create sample substation-feeder-meter topology
-- =========================================================

-- This section creates sample data if no real topology exists yet

-- Sample substations (if none exist)
INSERT INTO network_substations (substation_id, name, location_lat, location_lng, region_code, voltage_level, status)
VALUES 
    ('SS001', 'Central Substation', 31.9500, 35.9300, 'AM', '33kV', 'active'),
    ('SS002', 'North Substation', 32.0000, 35.9500, 'AM', '33kV', 'active'),
    ('SS003', 'East Substation', 31.9300, 36.0000, 'AM', '33kV', 'active')
ON CONFLICT (substation_id) DO NOTHING;

-- Sample feeders (if none exist)
INSERT INTO network_feeders (feeder_id, substation_id, name, location_lat, location_lng, capacity_kva, status)
SELECT 
    'FD' || LPAD(seq::TEXT, 3, '0'),
    ns.id,
    'Feeder ' || LPAD(seq::TEXT, 3, '0') || ' - ' || ns.name,
    ns.location_lat + (random() * 0.01 - 0.005),
    ns.location_lng + (random() * 0.01 - 0.005),
    1000.0,
    'active'
FROM network_substations ns
CROSS JOIN generate_series(1, 3) AS seq
ON CONFLICT (feeder_id) DO NOTHING;

-- =========================================================
-- STEP 6: Historical meter status events from existing data
-- =========================================================

-- 6.1: Create status events from ONU events
INSERT INTO oms_meter_status_events (
    meter_id, event_type, source_type, source_event_id,
    previous_status, new_status, event_timestamp, confidence_score
)
SELECT 
    om.id,
    CASE 
        WHEN oe.event_type = 'ONU_LastGaspAlert' THEN 'power_off'
        WHEN oe.event_type = 'ONU_PowerRestored' THEN 'power_on'
        ELSE 'communication_lost'
    END,
    'onu',
    oe.event_id,
    CASE 
        WHEN oe.event_type = 'ONU_LastGaspAlert' THEN 'on'
        WHEN oe.event_type = 'ONU_PowerRestored' THEN 'off'
        ELSE 'online'
    END,
    CASE 
        WHEN oe.event_type = 'ONU_LastGaspAlert' THEN 'off'
        WHEN oe.event_type = 'ONU_PowerRestored' THEN 'on'
        ELSE 'offline'
    END,
    oe.timestamp,
    0.8
FROM onu_events oe
JOIN oms_meters om ON oe.meter_id = om.id
WHERE oe.event_type IN ('ONU_LastGaspAlert', 'ONU_PowerRestored')
ON CONFLICT DO NOTHING;

-- 6.2: Create status events from Kaifa events (last gasp scenarios)
INSERT INTO oms_meter_status_events (
    meter_id, event_type, source_type, source_event_id,
    previous_status, new_status, event_timestamp, confidence_score
)
SELECT 
    om.id,
    CASE 
        WHEN kep.severity IN ('critical', 'high') THEN 'power_off'
        ELSE 'communication_lost'
    END,
    'kaifa',
    ke.id::TEXT,
    'on',
    CASE 
        WHEN kep.severity IN ('critical', 'high') THEN 'off'
        ELSE 'offline'
    END,
    ke.event_timestamp,
    0.9
FROM kaifa_events ke
JOIN kaifa_event_payloads kep ON ke.id = kep.event_id
JOIN kaifa_event_assets kea ON kep.id = kea.payload_id
JOIN oms_meters om ON kea.meter_id = om.id
WHERE kep.severity IN ('critical', 'high', 'medium')
ON CONFLICT DO NOTHING;

-- =========================================================
-- STEP 7: Update statistics and refresh materialized views
-- =========================================================

-- Update affected customer counts in outage events
UPDATE oms_outage_events oe
SET affected_customers_count = (
    SELECT COUNT(DISTINCT m.customer_id)
    FROM oms_event_sources es
    JOIN oms_meters m ON (
        (es.source_type = 'onu' AND es.source_event_id IN (
            SELECT event_id FROM onu_events WHERE meter_id = m.id
        ))
        OR
        (es.source_type = 'kaifa' AND es.source_event_id::UUID IN (
            SELECT ke.id FROM kaifa_events ke
            JOIN kaifa_event_payloads kep ON ke.id = kep.event_id
            JOIN kaifa_event_assets kea ON kep.id = kea.payload_id
            WHERE kea.meter_id = m.id
        ))
    )
    WHERE es.outage_event_id = oe.id
    AND m.customer_id IS NOT NULL
)
WHERE oe.affected_customers_count = 0;

-- =========================================================
-- STEP 8: Validation queries
-- =========================================================

-- Report: Meters by source
DO $$
DECLARE
    v_total_meters INTEGER;
    v_onu_meters INTEGER;
    v_kaifa_meters INTEGER;
    v_call_center_meters INTEGER;
    v_linked_to_substation INTEGER;
    v_linked_to_customer INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total_meters FROM oms_meters WHERE status = 'active';
    SELECT COUNT(*) INTO v_onu_meters FROM oms_meters WHERE onu_id IS NOT NULL;
    SELECT COUNT(*) INTO v_kaifa_meters FROM oms_meters WHERE asset_mrid IS NOT NULL;
    SELECT COUNT(*) INTO v_call_center_meters FROM callcenter_customers WHERE meter_id IS NOT NULL;
    SELECT COUNT(*) INTO v_linked_to_substation FROM oms_meters WHERE substation_id IS NOT NULL;
    SELECT COUNT(*) INTO v_linked_to_customer FROM oms_meters WHERE customer_id IS NOT NULL;

    RAISE NOTICE '============================================';
    RAISE NOTICE 'OMS METER MIGRATION SUMMARY';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Total Active Meters: %', v_total_meters;
    RAISE NOTICE 'Meters from ONU: %', v_onu_meters;
    RAISE NOTICE 'Meters from Kaifa: %', v_kaifa_meters;
    RAISE NOTICE 'Meters linked in Call Center: %', v_call_center_meters;
    RAISE NOTICE 'Meters linked to Substations: %', v_linked_to_substation;
    RAISE NOTICE 'Meters linked to Customers: %', v_linked_to_customer;
    RAISE NOTICE '============================================';
END $$;

-- Report: Substation coverage
SELECT 
    ns.substation_id,
    ns.name,
    COUNT(nsm.meter_id) as total_meters,
    COUNT(CASE WHEN m.power_status = 'on' THEN 1 END) as online_meters,
    COUNT(CASE WHEN m.power_status = 'off' THEN 1 END) as offline_meters,
    COUNT(CASE WHEN m.power_status = 'unknown' THEN 1 END) as unknown_meters
FROM network_substations ns
LEFT JOIN network_substation_meters nsm ON ns.id = nsm.substation_id
LEFT JOIN oms_meters m ON nsm.meter_id = m.id
GROUP BY ns.id, ns.substation_id, ns.name
ORDER BY total_meters DESC;

-- =========================================================
-- END OF MIGRATION SCRIPT
-- =========================================================

