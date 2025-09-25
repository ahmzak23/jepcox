-- ONU service database objects
-- Database: oms_db (ensure base bootstrap applied)

-- =========================================================
-- ONU Master Table
-- =========================================================
CREATE TABLE IF NOT EXISTS onus (
    id INT PRIMARY KEY,
    fibertech_id VARCHAR(50),
    building_id VARCHAR(50),
    region_code VARCHAR(10),
    onu_serial_no VARCHAR(100) UNIQUE,
    olt_name VARCHAR(200),
    area_fibertech VARCHAR(200),
    onu_power_flag BOOLEAN DEFAULT FALSE,
    onu_power_flag_date TIMESTAMPTZ,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- Meters Table
-- =========================================================
CREATE TABLE IF NOT EXISTS meters (
    id SERIAL PRIMARY KEY,
    meter_id VARCHAR(50) UNIQUE NOT NULL,
    onu_id INT,
    building_id VARCHAR(50),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (onu_id) REFERENCES onus(id) ON DELETE SET NULL
);

-- =========================================================
-- ONU Events Table
-- =========================================================
CREATE TABLE IF NOT EXISTS onu_events (
    id SERIAL PRIMARY KEY,
    event_id VARCHAR(100) UNIQUE NOT NULL,
    onu_id INT,
    event_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMPTZ NOT NULL,
    alarm_category VARCHAR(20),
    alarm_type VARCHAR(20),
    parcel_code VARCHAR(50),
    serial_number VARCHAR(100),
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    nms_type VARCHAR(50),
    raw_payload JSONB NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (onu_id) REFERENCES onus(id) ON DELETE SET NULL
);

-- =========================================================
-- Indexes for Performance
-- =========================================================
CREATE INDEX IF NOT EXISTS idx_onus_serial ON onus(onu_serial_no);
CREATE INDEX IF NOT EXISTS idx_onus_power_flag ON onus(onu_power_flag);
CREATE INDEX IF NOT EXISTS idx_onus_power_date ON onus(onu_power_flag_date);
CREATE INDEX IF NOT EXISTS idx_onus_building ON onus(building_id);

CREATE INDEX IF NOT EXISTS idx_meters_meter_id ON meters(meter_id);
CREATE INDEX IF NOT EXISTS idx_meters_onu_id ON meters(onu_id);
CREATE INDEX IF NOT EXISTS idx_meters_building ON meters(building_id);

CREATE INDEX IF NOT EXISTS idx_onu_events_event_id ON onu_events(event_id);
CREATE INDEX IF NOT EXISTS idx_onu_events_onu_id ON onu_events(onu_id);
CREATE INDEX IF NOT EXISTS idx_onu_events_timestamp ON onu_events(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_onu_events_type ON onu_events(event_type);
CREATE INDEX IF NOT EXISTS idx_onu_events_alarm_category ON onu_events(alarm_category);

-- =========================================================
-- Updated_at Trigger Function
-- =========================================================
CREATE OR REPLACE FUNCTION onu_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to onus table
DROP TRIGGER IF EXISTS onu_onus_updated_at ON onus;
CREATE TRIGGER onu_onus_updated_at
    BEFORE UPDATE ON onus
    FOR EACH ROW EXECUTE FUNCTION onu_update_updated_at();

-- =========================================================
-- Insert Function for ONU Events
-- =========================================================
CREATE OR REPLACE FUNCTION insert_onu_event_from_json(json_data JSONB)
RETURNS INTEGER AS $$
DECLARE
    v_event_id INTEGER;
    v_onu_id INT;
    v_event_type VARCHAR(50);
    v_timestamp TIMESTAMPTZ;
    v_alarm_data JSONB;
    v_location JSONB;
BEGIN
    -- Extract required fields
    v_event_type := json_data->>'type';
    v_timestamp := (json_data->>'timestamp')::TIMESTAMPTZ;
    v_onu_id := (json_data->>'onuId')::INT;
    v_alarm_data := COALESCE(json_data->'alarmData', '{}'::jsonb);
    v_location := COALESCE(json_data->'location', '{}'::jsonb);

    -- Ensure referenced ONU exists to satisfy FK
    INSERT INTO onus (id, onu_serial_no)
    VALUES (v_onu_id, json_data->>'onuSerial')
    ON CONFLICT (id) DO NOTHING;

    -- Insert ONU event
    INSERT INTO onu_events (
        event_id,
        onu_id,
        event_type,
        timestamp,
        alarm_category,
        alarm_type,
        parcel_code,
        serial_number,
        location_lat,
        location_lng,
        nms_type,
        raw_payload
    ) VALUES (
        json_data->>'eventId',
        v_onu_id,
        v_event_type,
        v_timestamp,
        v_alarm_data->>'category',
        v_alarm_data->>'alarmType',
        v_alarm_data->>'parcel',
        v_alarm_data->>'serial',
        NULLIF(v_location->>'lat','')::DECIMAL,
        NULLIF(v_location->>'lng','')::DECIMAL,
        json_data->>'nmsType',
        json_data
    ) RETURNING id INTO v_event_id;

    -- Update ONU power status if it's a power-related event
    IF v_event_type IN ('ONU_LastGaspAlert', 'ONU_PowerRestored') THEN
        UPDATE onus 
        SET 
            onu_power_flag = (v_event_type = 'ONU_PowerRestored'),
            onu_power_flag_date = v_timestamp,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_onu_id;
    END IF;

    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Sample Data Insertion (Optional)
-- =========================================================
-- Insert sample ONU data
INSERT INTO onus (
    id, fibertech_id, building_id, region_code, onu_serial_no, 
    olt_name, area_fibertech, onu_power_flag, onu_power_flag_date,
    location_lat, location_lng
) VALUES (
    3230316, '250221', '05040835035', 'AM', '48575443ED8345B0',
    '1046-Abdullah_Ghosheh-MA5800_X17_02', 'Al-Rawabi', 
    TRUE, '2025-08-08 03:00:08', 31.9454, 35.9284
) ON CONFLICT (id) DO NOTHING;

-- Insert sample meter data
INSERT INTO meters (meter_id, onu_id, building_id, location_lat, location_lng)
VALUES 
    ('M12345678', 3230316, '05040835035', 31.9454, 35.9284),
    ('M23456789', 3230316, '05040835035', 31.9454, 35.9284)
ON CONFLICT (meter_id) DO NOTHING;
