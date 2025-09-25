-- SCADA service database objects under schema "scada"
SET search_path TO public;

-- Minimal SCADA event table tailored to SCADA JSON
CREATE TABLE IF NOT EXISTS scada_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_type VARCHAR(64) NOT NULL,
    substation_id VARCHAR(64) NOT NULL,
    feeder_id VARCHAR(64) NOT NULL,
    main_station_id VARCHAR(64) NOT NULL,
    alarm_type VARCHAR(32) NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    voltage NUMERIC(12,3) NOT NULL,
    severity VARCHAR(16),
    reason TEXT,
    latitude NUMERIC(10,6),
    longitude NUMERIC(10,6),
    source VARCHAR(128),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_scada_events_ts ON scada_events(event_timestamp);
CREATE INDEX IF NOT EXISTS idx_scada_events_type ON scada_events(event_type);

-- Optional staging for raw messages
CREATE TABLE IF NOT EXISTS scada_raw_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    raw_payload JSONB NOT NULL,
    received_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Upsert helper from JSON
CREATE OR REPLACE FUNCTION insert_scada_event_from_json(json_data JSONB)
RETURNS UUID AS $$
DECLARE
    ev_uuid UUID;
BEGIN
    INSERT INTO scada_events (
        event_type, substation_id, feeder_id, main_station_id, alarm_type,
        event_timestamp, voltage, severity, reason, latitude, longitude, source
    ) VALUES (
        json_data->>'eventType',
        json_data->>'substationId',
        json_data->>'feederId',
        json_data->>'mainStationId',
        json_data->>'alarmType',
        (json_data->>'timestamp')::TIMESTAMPTZ,
        (json_data->>'voltage')::NUMERIC,
        json_data->>'severity',
        json_data->>'reason',
        (json_data->'coordinates'->>'lat')::NUMERIC,
        (json_data->'coordinates'->>'lng')::NUMERIC,
        json_data->>'source'
    ) RETURNING id INTO ev_uuid;

    RETURN ev_uuid;
END;
$$ LANGUAGE plpgsql;


