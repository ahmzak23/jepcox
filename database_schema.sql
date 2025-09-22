-- PostgreSQL Database Schema for HES-Kaifa Events
-- Based on JSON structure from hes_kaifa_event_*.json files
-- Created: 2025-09-22

-- Create database (uncomment if needed)
-- CREATE DATABASE hes_kaifa_events;
-- \c hes_kaifa_events;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================
-- MAIN EVENTS TABLE
-- =============================================
CREATE TABLE hes_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_type VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- HEADER INFORMATION
-- =============================================
CREATE TABLE event_headers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES hes_events(id) ON DELETE CASCADE,
    verb VARCHAR(20) NOT NULL,
    noun VARCHAR(50) NOT NULL,
    revision VARCHAR(10),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    source VARCHAR(100),
    async_reply_flag BOOLEAN DEFAULT FALSE,
    ack_required BOOLEAN DEFAULT FALSE,
    message_id VARCHAR(100) UNIQUE,
    correlation_id VARCHAR(100),
    comment TEXT
);

-- =============================================
-- USER INFORMATION
-- =============================================
CREATE TABLE event_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    header_id UUID NOT NULL REFERENCES event_headers(id) ON DELETE CASCADE,
    user_id VARCHAR(100),
    organization VARCHAR(100)
);

-- =============================================
-- PAYLOAD INFORMATION
-- =============================================
CREATE TABLE event_payloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES hes_events(id) ON DELETE CASCADE,
    event_id_value VARCHAR(100) UNIQUE,
    created_date_time TIMESTAMP WITH TIME ZONE,
    issuer_id VARCHAR(100),
    issuer_tracking_id VARCHAR(100),
    reason VARCHAR(200),
    severity VARCHAR(20),
    user_id VARCHAR(100),
    event_type_ref VARCHAR(50)
);

-- =============================================
-- ASSETS INFORMATION
-- =============================================
CREATE TABLE event_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES event_payloads(id) ON DELETE CASCADE,
    mrid VARCHAR(100),
    name VARCHAR(200),
    name_type VARCHAR(100),
    name_description TEXT
);

-- =============================================
-- EVENT DETAILS (Key-Value pairs)
-- =============================================
CREATE TABLE event_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES event_payloads(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    value VARCHAR(200) NOT NULL,
    detail_order INTEGER DEFAULT 0
);

-- =============================================
-- EVENT NAMES
-- =============================================
CREATE TABLE event_names (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES event_payloads(id) ON DELETE CASCADE,
    name VARCHAR(200),
    name_type VARCHAR(100),
    name_description TEXT
);

-- =============================================
-- EVENT STATUS
-- =============================================
CREATE TABLE event_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES event_payloads(id) ON DELETE CASCADE,
    date_time TIMESTAMP WITH TIME ZONE,
    reason VARCHAR(200),
    remark TEXT,
    value VARCHAR(50)
);

-- =============================================
-- USAGE POINTS
-- =============================================
CREATE TABLE event_usage_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES event_payloads(id) ON DELETE CASCADE,
    mrid VARCHAR(100),
    name VARCHAR(200),
    name_type VARCHAR(100),
    name_description TEXT
);

-- =============================================
-- METADATA
-- =============================================
CREATE TABLE event_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES hes_events(id) ON DELETE CASCADE,
    source VARCHAR(100),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- =============================================
-- ORIGINAL MESSAGE
-- =============================================
CREATE TABLE event_original_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES hes_events(id) ON DELETE CASCADE,
    timestamp TIMESTAMP WITH TIME ZONE,
    source VARCHAR(100),
    topic VARCHAR(100),
    processed_at TIMESTAMP WITH TIME ZONE
);

-- =============================================
-- INDEXES FOR PERFORMANCE
-- =============================================

-- Main events indexes
CREATE INDEX idx_hes_events_timestamp ON hes_events(timestamp);
CREATE INDEX idx_hes_events_message_type ON hes_events(message_type);
CREATE INDEX idx_hes_events_created_at ON hes_events(created_at);

-- Header indexes
CREATE INDEX idx_event_headers_event_id ON event_headers(event_id);
CREATE INDEX idx_event_headers_message_id ON event_headers(message_id);
CREATE INDEX idx_event_headers_correlation_id ON event_headers(correlation_id);
CREATE INDEX idx_event_headers_timestamp ON event_headers(timestamp);

-- Payload indexes
CREATE INDEX idx_event_payloads_event_id ON event_payloads(event_id);
CREATE INDEX idx_event_payloads_event_id_value ON event_payloads(event_id_value);
CREATE INDEX idx_event_payloads_created_date_time ON event_payloads(created_date_time);
CREATE INDEX idx_event_payloads_severity ON event_payloads(severity);
CREATE INDEX idx_event_payloads_reason ON event_payloads(reason);

-- Event details indexes
CREATE INDEX idx_event_details_payload_id ON event_details(payload_id);
CREATE INDEX idx_event_details_name ON event_details(name);
CREATE INDEX idx_event_details_name_value ON event_details(name, value);

-- Asset indexes
CREATE INDEX idx_event_assets_payload_id ON event_assets(payload_id);
CREATE INDEX idx_event_assets_mrid ON event_assets(mrid);

-- Status indexes
CREATE INDEX idx_event_status_payload_id ON event_status(payload_id);
CREATE INDEX idx_event_status_value ON event_status(value);
CREATE INDEX idx_event_status_date_time ON event_status(date_time);

-- Usage point indexes
CREATE INDEX idx_event_usage_points_payload_id ON event_usage_points(payload_id);
CREATE INDEX idx_event_usage_points_mrid ON event_usage_points(mrid);
CREATE INDEX idx_event_usage_points_name ON event_usage_points(name);

-- =============================================
-- TRIGGERS FOR UPDATED_AT
-- =============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for hes_events table
CREATE TRIGGER update_hes_events_updated_at 
    BEFORE UPDATE ON hes_events 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================
-- VIEWS FOR COMMON QUERIES
-- =============================================

-- Complete event view with all related data
CREATE VIEW v_complete_events AS
SELECT 
    e.id as event_id,
    e.message_type,
    e.timestamp as event_timestamp,
    e.created_at,
    h.verb,
    h.noun,
    h.revision,
    h.timestamp as header_timestamp,
    h.source as header_source,
    h.message_id,
    h.correlation_id,
    h.comment,
    u.user_id,
    u.organization,
    p.event_id_value,
    p.created_date_time,
    p.issuer_id,
    p.issuer_tracking_id,
    p.reason,
    p.severity,
    p.user_id as payload_user_id,
    p.event_type_ref,
    s.value as status_value,
    s.reason as status_reason,
    s.remark as status_remark,
    s.date_time as status_date_time,
    up.name as usage_point_name,
    up.mrid as usage_point_mrid,
    m.source as metadata_source,
    m.processed_at as metadata_processed_at,
    om.timestamp as original_timestamp,
    om.source as original_source,
    om.topic as original_topic
FROM hes_events e
LEFT JOIN event_headers h ON e.id = h.event_id
LEFT JOIN event_users u ON h.id = u.header_id
LEFT JOIN event_payloads p ON e.id = p.event_id
LEFT JOIN event_status s ON p.id = s.payload_id
LEFT JOIN event_usage_points up ON p.id = up.payload_id
LEFT JOIN event_metadata m ON e.id = m.event_id
LEFT JOIN event_original_messages om ON e.id = om.event_id;

-- Event details view with key-value pairs
CREATE VIEW v_event_details AS
SELECT 
    e.id as event_id,
    e.message_type,
    e.timestamp as event_timestamp,
    p.reason,
    p.severity,
    ed.name as detail_name,
    ed.value as detail_value,
    ed.detail_order
FROM hes_events e
JOIN event_payloads p ON e.id = p.event_id
JOIN event_details ed ON p.id = ed.payload_id
ORDER BY e.timestamp DESC, ed.detail_order;

-- =============================================
-- SAMPLE DATA INSERTION FUNCTION
-- =============================================

CREATE OR REPLACE FUNCTION insert_hes_event_from_json(json_data JSONB)
RETURNS UUID AS $$
DECLARE
    event_uuid UUID;
    header_uuid UUID;
    payload_uuid UUID;
    detail_record JSONB;
BEGIN
    -- Insert main event
    INSERT INTO hes_events (message_type, timestamp)
    VALUES (
        json_data->>'message_type',
        (json_data->>'timestamp')::TIMESTAMP WITH TIME ZONE
    )
    RETURNING id INTO event_uuid;
    
    -- Insert header
    INSERT INTO event_headers (
        event_id, verb, noun, revision, timestamp, source,
        async_reply_flag, ack_required, message_id, correlation_id, comment
    )
    VALUES (
        event_uuid,
        json_data->'header'->>'verb',
        json_data->'header'->>'noun',
        json_data->'header'->>'revision',
        (json_data->'header'->>'timestamp')::TIMESTAMP WITH TIME ZONE,
        json_data->'header'->>'source',
        (json_data->'header'->>'async_reply_flag')::BOOLEAN,
        (json_data->'header'->>'ack_required')::BOOLEAN,
        json_data->'header'->>'message_id',
        json_data->'header'->>'correlation_id',
        json_data->'header'->>'comment'
    )
    RETURNING id INTO header_uuid;
    
    -- Insert user information
    INSERT INTO event_users (header_id, user_id, organization)
    VALUES (
        header_uuid,
        json_data->'header'->'user'->>'ns1:UserID',
        json_data->'header'->'user'->>'ns1:Organization'
    );
    
    -- Insert payload
    INSERT INTO event_payloads (
        event_id, event_id_value, created_date_time, issuer_id,
        issuer_tracking_id, reason, severity, user_id, event_type_ref
    )
    VALUES (
        event_uuid,
        json_data->'payload'->>'event_id',
        (json_data->'payload'->>'created_date_time')::TIMESTAMP WITH TIME ZONE,
        json_data->'payload'->>'issuer_id',
        json_data->'payload'->>'issuer_tracking_id',
        json_data->'payload'->>'reason',
        json_data->'payload'->>'severity',
        json_data->'payload'->>'user_id',
        json_data->'payload'->'event_type'->>'@ref'
    )
    RETURNING id INTO payload_uuid;
    
    -- Insert assets
    INSERT INTO event_assets (payload_id, mrid, name, name_type, name_description)
    VALUES (
        payload_uuid,
        json_data->'payload'->'assets'->>'ns2:mRID',
        json_data->'payload'->'assets'->'ns2:Names'->>'ns2:name',
        json_data->'payload'->'assets'->'ns2:Names'->'ns2:NameType'->>'ns2:name',
        json_data->'payload'->'assets'->'ns2:Names'->'ns2:NameType'->>'ns2:description'
    );
    
    -- Insert event details (array)
    FOR detail_record IN SELECT * FROM jsonb_array_elements(json_data->'payload'->'event_details')
    LOOP
        INSERT INTO event_details (payload_id, name, value)
        VALUES (
            payload_uuid,
            detail_record->>'ns2:name',
            detail_record->>'ns2:value'
        );
    END LOOP;
    
    -- Insert event names
    INSERT INTO event_names (payload_id, name, name_type, name_description)
    VALUES (
        payload_uuid,
        json_data->'payload'->'names'->>'ns2:name',
        json_data->'payload'->'names'->'ns2:NameType'->>'ns2:name',
        json_data->'payload'->'names'->'ns2:NameType'->>'ns2:description'
    );
    
    -- Insert status
    INSERT INTO event_status (payload_id, date_time, reason, remark, value)
    VALUES (
        payload_uuid,
        (json_data->'payload'->'status'->>'ns2:dateTime')::TIMESTAMP WITH TIME ZONE,
        json_data->'payload'->'status'->>'ns2:reason',
        json_data->'payload'->'status'->>'ns2:remark',
        json_data->'payload'->'status'->>'ns2:value'
    );
    
    -- Insert usage point
    INSERT INTO event_usage_points (payload_id, mrid, name, name_type, name_description)
    VALUES (
        payload_uuid,
        json_data->'payload'->'usage_point'->>'ns2:mRID',
        json_data->'payload'->'usage_point'->'ns2:Names'->>'ns2:name',
        json_data->'payload'->'usage_point'->'ns2:Names'->'ns2:NameType'->>'ns2:name',
        json_data->'payload'->'usage_point'->'ns2:Names'->'ns2:NameType'->>'ns2:description'
    );
    
    -- Insert metadata
    INSERT INTO event_metadata (event_id, source, processed_at)
    VALUES (
        event_uuid,
        json_data->'metadata'->>'source',
        (json_data->'metadata'->>'processed_at')::TIMESTAMP WITH TIME ZONE
    );
    
    -- Insert original message
    INSERT INTO event_original_messages (event_id, timestamp, source, topic, processed_at)
    VALUES (
        event_uuid,
        (json_data->'original_message'->>'timestamp')::TIMESTAMP WITH TIME ZONE,
        json_data->'original_message'->>'source',
        json_data->'original_message'->>'topic',
        (json_data->'original_message'->>'processed_at')::TIMESTAMP WITH TIME ZONE
    );
    
    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;

-- =============================================
-- COMMENTS AND DOCUMENTATION
-- =============================================

COMMENT ON DATABASE hes_kaifa_events IS 'Database for storing HES-Kaifa power system events from Kafka consumer';
COMMENT ON TABLE hes_events IS 'Main events table storing basic event information';
COMMENT ON TABLE event_headers IS 'Event header information including message metadata';
COMMENT ON TABLE event_payloads IS 'Event payload containing detailed event data';
COMMENT ON TABLE event_details IS 'Key-value pairs for event measurements (frequency, power, etc.)';
COMMENT ON TABLE event_assets IS 'Asset information associated with events';
COMMENT ON TABLE event_status IS 'Event status information';
COMMENT ON TABLE event_usage_points IS 'Usage point information for power consumption points';

-- =============================================
-- GRANT PERMISSIONS (Adjust as needed)
-- =============================================

-- Example permissions for application user
-- CREATE USER hes_app_user WITH PASSWORD 'secure_password';
-- GRANT CONNECT ON DATABASE hes_kaifa_events TO hes_app_user;
-- GRANT USAGE ON SCHEMA public TO hes_app_user;
-- GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO hes_app_user;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO hes_app_user;
