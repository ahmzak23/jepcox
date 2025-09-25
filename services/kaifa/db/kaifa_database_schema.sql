-- HES (Kaifa) service database objects with performance-oriented design
SET search_path TO public;

-- =========================================================
-- Core events (partitioned by month on event_timestamp)
-- =========================================================
CREATE TABLE IF NOT EXISTS kaifa_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    message_type VARCHAR(50) NOT NULL,
    event_timestamp TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
)
PARTITION BY HASH (id);

-- Default catch-all partition to prevent insertion failures
-- Hash partitions by id (adjust modulus as needed)
CREATE TABLE IF NOT EXISTS kaifa_events_p0 PARTITION OF kaifa_events FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE IF NOT EXISTS kaifa_events_p1 PARTITION OF kaifa_events FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE IF NOT EXISTS kaifa_events_p2 PARTITION OF kaifa_events FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE IF NOT EXISTS kaifa_events_p3 PARTITION OF kaifa_events FOR VALUES WITH (MODULUS 4, REMAINDER 3);

-- Example current-month partition (adjust as needed)
-- Time-based partitions are not used here to keep PK(id) valid for FKs.

-- Indexes on parent propagate to partitions in modern PostgreSQL
CREATE INDEX IF NOT EXISTS idx_kaifa_events_ts ON kaifa_events (event_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_kaifa_events_type ON kaifa_events (message_type);

-- =========================================================
-- Header table (FK -> partitioned parent)
-- =========================================================
CREATE TABLE IF NOT EXISTS kaifa_event_headers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES kaifa_events(id) ON DELETE CASCADE,
    verb VARCHAR(20) NOT NULL,
    noun VARCHAR(50) NOT NULL,
    revision VARCHAR(10),
    header_timestamp TIMESTAMPTZ NOT NULL,
    source VARCHAR(100),
    async_reply_flag BOOLEAN DEFAULT FALSE,
    ack_required BOOLEAN DEFAULT FALSE,
    message_id VARCHAR(100) UNIQUE,
    correlation_id VARCHAR(100),
    comment TEXT
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_headers_event_id ON kaifa_event_headers(event_id);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_headers_msg_id ON kaifa_event_headers(message_id);

-- =========================================================
-- Users (1:1 with header)
-- =========================================================
CREATE TABLE IF NOT EXISTS kaifa_event_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    header_id UUID NOT NULL REFERENCES kaifa_event_headers(id) ON DELETE CASCADE,
    user_id VARCHAR(100),
    organization VARCHAR(100)
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_users_header_id ON kaifa_event_users(header_id);

-- =========================================================
-- Payloads (large; HASH partition across 4 shards by event_id)
-- =========================================================
CREATE TABLE IF NOT EXISTS kaifa_event_payloads (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES kaifa_events(id) ON DELETE CASCADE,
    event_id_value VARCHAR(100),
    created_date_time TIMESTAMPTZ,
    issuer_id VARCHAR(100),
    issuer_tracking_id VARCHAR(100),
    reason VARCHAR(200),
    severity VARCHAR(20),
    user_id VARCHAR(100),
    event_type_ref VARCHAR(50)
)
PARTITION BY HASH (id);

CREATE TABLE IF NOT EXISTS kaifa_event_payloads_p0 PARTITION OF kaifa_event_payloads FOR VALUES WITH (MODULUS 4, REMAINDER 0);
CREATE TABLE IF NOT EXISTS kaifa_event_payloads_p1 PARTITION OF kaifa_event_payloads FOR VALUES WITH (MODULUS 4, REMAINDER 1);
CREATE TABLE IF NOT EXISTS kaifa_event_payloads_p2 PARTITION OF kaifa_event_payloads FOR VALUES WITH (MODULUS 4, REMAINDER 2);
CREATE TABLE IF NOT EXISTS kaifa_event_payloads_p3 PARTITION OF kaifa_event_payloads FOR VALUES WITH (MODULUS 4, REMAINDER 3);

CREATE INDEX IF NOT EXISTS idx_kaifa_event_payloads_event_id ON kaifa_event_payloads(event_id);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_payloads_event_id_value ON kaifa_event_payloads(event_id_value);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_payloads_created_dt ON kaifa_event_payloads(created_date_time DESC);

-- =========================================================
-- Assets, Details, Names, Status, Usage Points
-- =========================================================
CREATE TABLE IF NOT EXISTS kaifa_event_assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES kaifa_event_payloads(id) ON DELETE CASCADE,
    mrid VARCHAR(100),
    name VARCHAR(200),
    name_type VARCHAR(100),
    name_description TEXT
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_assets_payload_id ON kaifa_event_assets(payload_id);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_assets_mrid ON kaifa_event_assets(mrid);

CREATE TABLE IF NOT EXISTS kaifa_event_details (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES kaifa_event_payloads(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    value VARCHAR(200) NOT NULL,
    detail_order INTEGER DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_details_payload_id ON kaifa_event_details(payload_id);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_details_name ON kaifa_event_details(name);

CREATE TABLE IF NOT EXISTS kaifa_event_names (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES kaifa_event_payloads(id) ON DELETE CASCADE,
    name VARCHAR(200),
    name_type VARCHAR(100),
    name_description TEXT
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_names_payload_id ON kaifa_event_names(payload_id);

CREATE TABLE IF NOT EXISTS kaifa_event_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES kaifa_event_payloads(id) ON DELETE CASCADE,
    date_time TIMESTAMPTZ,
    reason VARCHAR(200),
    remark TEXT,
    value VARCHAR(50)
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_status_payload_id ON kaifa_event_status(payload_id);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_status_dt ON kaifa_event_status(date_time DESC);

CREATE TABLE IF NOT EXISTS kaifa_event_usage_points (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payload_id UUID NOT NULL REFERENCES kaifa_event_payloads(id) ON DELETE CASCADE,
    mrid VARCHAR(100),
    name VARCHAR(200),
    name_type VARCHAR(100),
    name_description TEXT
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_usage_points_payload_id ON kaifa_event_usage_points(payload_id);

-- =========================================================
-- Metadata and Original Messages
-- =========================================================
CREATE TABLE IF NOT EXISTS kaifa_event_metadata (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES kaifa_events(id) ON DELETE CASCADE,
    source VARCHAR(100),
    processed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_metadata_event_id ON kaifa_event_metadata(event_id);

CREATE TABLE IF NOT EXISTS kaifa_event_original_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES kaifa_events(id) ON DELETE CASCADE,
    original_timestamp TIMESTAMPTZ,
    source VARCHAR(100),
    topic VARCHAR(100),
    processed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_kaifa_event_original_messages_event_id ON kaifa_event_original_messages(event_id);

-- =========================================================
-- Updated_at trigger (shared)
-- =========================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_kaifa_events_updated_at ON kaifa_events;
CREATE TRIGGER update_kaifa_events_updated_at
    BEFORE UPDATE ON kaifa_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =========================================================
-- Insert function (keeps the original function name for compatibility)
-- =========================================================
CREATE OR REPLACE FUNCTION insert_kaifa_event_from_json(json_data JSONB)
RETURNS UUID AS $$
DECLARE
    event_uuid UUID;
    header_uuid UUID;
    payload_uuid UUID;
    detail_record JSONB;
BEGIN
    INSERT INTO kaifa_events (message_type, event_timestamp)
    VALUES (
        json_data->>'message_type',
        (json_data->>'timestamp')::TIMESTAMPTZ
    ) RETURNING id INTO event_uuid;

    INSERT INTO kaifa_event_headers (
        event_id, verb, noun, revision, header_timestamp, source,
        async_reply_flag, ack_required, message_id, correlation_id, comment
    ) VALUES (
        event_uuid,
        json_data->'header'->>'verb',
        json_data->'header'->>'noun',
        json_data->'header'->>'revision',
        (json_data->'header'->>'timestamp')::TIMESTAMPTZ,
        json_data->'header'->>'source',
        (json_data->'header'->>'async_reply_flag')::BOOLEAN,
        (json_data->'header'->>'ack_required')::BOOLEAN,
        json_data->'header'->>'message_id',
        json_data->'header'->>'correlation_id',
        json_data->'header'->>'comment'
    ) RETURNING id INTO header_uuid;

    INSERT INTO kaifa_event_users (header_id, user_id, organization)
    VALUES (
        header_uuid,
        json_data->'header'->'user'->>'ns1:UserID',
        json_data->'header'->'user'->>'ns1:Organization'
    );

    INSERT INTO kaifa_event_payloads (
        event_id, event_id_value, created_date_time, issuer_id,
        issuer_tracking_id, reason, severity, user_id, event_type_ref
    ) VALUES (
        event_uuid,
        json_data->'payload'->>'event_id',
        (json_data->'payload'->>'created_date_time')::TIMESTAMPTZ,
        json_data->'payload'->>'issuer_id',
        json_data->'payload'->>'issuer_tracking_id',
        json_data->'payload'->>'reason',
        json_data->'payload'->>'severity',
        json_data->'payload'->>'user_id',
        json_data->'payload'->'event_type'->>'@ref'
    ) RETURNING id INTO payload_uuid;

    INSERT INTO kaifa_event_assets (payload_id, mrid, name, name_type, name_description)
    VALUES (
        payload_uuid,
        json_data->'payload'->'assets'->>'ns2:mRID',
        json_data->'payload'->'assets'->'ns2:Names'->>'ns2:name',
        json_data->'payload'->'assets'->'ns2:Names'->'ns2:NameType'->>'ns2:name',
        json_data->'payload'->'assets'->'ns2:Names'->'ns2:NameType'->>'ns2:description'
    );

    FOR detail_record IN SELECT * FROM jsonb_array_elements(json_data->'payload'->'event_details') LOOP
        INSERT INTO kaifa_event_details (payload_id, name, value)
        VALUES (
            payload_uuid,
            detail_record->>'ns2:name',
            detail_record->>'ns2:value'
        );
    END LOOP;

    INSERT INTO kaifa_event_names (payload_id, name, name_type, name_description)
    VALUES (
        payload_uuid,
        json_data->'payload'->'names'->>'ns2:name',
        json_data->'payload'->'names'->'ns2:NameType'->>'ns2:name',
        json_data->'payload'->'names'->'ns2:NameType'->>'ns2:description'
    );

    INSERT INTO kaifa_event_status (payload_id, date_time, reason, remark, value)
    VALUES (
        payload_uuid,
        (json_data->'payload'->'status'->>'ns2:dateTime')::TIMESTAMPTZ,
        json_data->'payload'->'status'->>'ns2:reason',
        json_data->'payload'->'status'->>'ns2:remark',
        json_data->'payload'->'status'->>'ns2:value'
    );

    INSERT INTO kaifa_event_usage_points (payload_id, mrid, name, name_type, name_description)
    VALUES (
        payload_uuid,
        json_data->'payload'->'usage_point'->>'ns2:mRID',
        json_data->'payload'->'usage_point'->'ns2:Names'->>'ns2:name',
        json_data->'payload'->'usage_point'->'ns2:Names'->'ns2:NameType'->>'ns2:name',
        json_data->'payload'->'usage_point'->'ns2:Names'->'ns2:NameType'->>'ns2:description'
    );

    INSERT INTO kaifa_event_metadata (event_id, source, processed_at)
    VALUES (
        event_uuid,
        json_data->'metadata'->>'source',
        (json_data->'metadata'->>'processed_at')::TIMESTAMPTZ
    );

    INSERT INTO kaifa_event_original_messages (event_id, original_timestamp, source, topic, processed_at)
    VALUES (
        event_uuid,
        (json_data->'original_message'->>'timestamp')::TIMESTAMPTZ,
        json_data->'original_message'->>'source',
        json_data->'original_message'->>'topic',
        (json_data->'original_message'->>'processed_at')::TIMESTAMPTZ
    );

    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;



