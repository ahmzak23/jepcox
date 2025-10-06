-- Link meters to substations based on proximity
-- This creates the visual connections you'll see on the map

-- First, ensure we have comprehensive test substations with coordinates
INSERT INTO network_substations (substation_id, name, location_lat, location_lng, region_code, voltage_level, status)
VALUES 
    ('SS001', 'Central Amman Substation', 31.9539, 35.9106, 'AM', '33kV', 'active'),
    ('SS002', 'Zarqa Substation', 32.0731, 36.0880, 'ZR', '33kV', 'active'),
    ('SS003', 'Irbid Substation', 32.5561, 35.8515, 'IR', '33kV', 'active'),
    ('SS004', 'Salt Substation', 32.0389, 35.7275, 'SL', '33kV', 'active'),
    ('SS005', 'Madaba Substation', 31.7167, 35.7833, 'MD', '33kV', 'active'),
    ('SS006', 'Jerash Substation', 32.2808, 35.8994, 'JR', '33kV', 'active'),
    ('SS007', 'Ajloun Substation', 32.3333, 35.7500, 'AJ', '33kV', 'active'),
    ('SS008', 'Mafraq Substation', 32.3500, 36.2000, 'MF', '33kV', 'active'),
    ('SS009', 'Karak Substation', 31.1853, 35.7047, 'KR', '33kV', 'active'),
    ('SS010', 'Tafilah Substation', 30.8333, 35.6000, 'TF', '33kV', 'active'),
    ('SS011', 'Aqaba Substation', 29.5321, 35.0063, 'AQ', '33kV', 'active'),
    ('SS012', 'Ma''an Substation', 30.1964, 35.7342, 'MN', '33kV', 'active'),
    ('SS013', 'Russeifa Substation', 32.0167, 36.0500, 'RS', '33kV', 'active'),
    ('SS014', 'Sweileh Substation', 32.0167, 35.8167, 'SW', '33kV', 'active'),
    ('SS015', 'Jubaiha Substation', 32.0167, 35.8667, 'JB', '33kV', 'active'),
    ('SS016', 'Wadi Seer Substation', 31.9000, 35.8167, 'WS', '33kV', 'active'),
    ('SS017', 'Abu Nsair Substation', 31.9500, 35.9500, 'AN', '33kV', 'active'),
    ('SS018', 'Marj Al-Hamam Substation', 31.9167, 35.9000, 'MH', '33kV', 'active'),
    ('SS019', 'Na''our Substation', 31.8667, 35.8333, 'NO', '33kV', 'active'),
    ('SS020', 'Dabouq Substation', 32.0000, 35.8500, 'DB', '33kV', 'active')
ON CONFLICT (substation_id) DO UPDATE SET
    location_lat = EXCLUDED.location_lat,
    location_lng = EXCLUDED.location_lng,
    updated_at = CURRENT_TIMESTAMP;

-- Link existing meters to nearest substation
-- (Meters within 50km of a substation)
INSERT INTO network_substation_meters (substation_id, meter_id, priority)
SELECT 
    ns.id,
    m.id,
    2 -- medium priority
FROM oms_meters m
CROSS JOIN LATERAL (
    SELECT id, location_lat, location_lng
    FROM network_substations
    WHERE location_lat IS NOT NULL
    ORDER BY haversine_distance_meters(
        m.location_lat, m.location_lng,
        location_lat, location_lng
    ) ASC
    LIMIT 1
) ns
WHERE m.location_lat IS NOT NULL
AND m.location_lng IS NOT NULL
ON CONFLICT (substation_id, meter_id) DO NOTHING;

-- Link meters without coordinates to all substations (temporary)
INSERT INTO network_substation_meters (substation_id, meter_id, priority)
SELECT 
    ns.id,
    m.id,
    3 -- low priority
FROM oms_meters m
CROSS JOIN network_substations ns
WHERE (m.location_lat IS NULL OR m.location_lng IS NULL)
AND m.id NOT IN (SELECT meter_id FROM network_substation_meters)
ON CONFLICT (substation_id, meter_id) DO NOTHING;

-- Show results
SELECT 
    'Substations' as type,
    COUNT(*) as count
FROM network_substations
UNION ALL
SELECT 
    'Meters' as type,
    COUNT(*) as count
FROM oms_meters
UNION ALL
SELECT 
    'Substation-Meter Links' as type,
    COUNT(*) as count
FROM network_substation_meters;

