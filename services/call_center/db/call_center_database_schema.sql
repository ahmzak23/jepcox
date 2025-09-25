-- Call Center ticketing schema (enterprise-ready, normalized, indexed)
-- Database: oms_db (ensure base bootstrap applied)

-- Schema
-- CREATE SCHEMA IF NOT EXISTS callcenter;
-- SET search_path TO callcenter, public;

-- Core tickets
CREATE TABLE IF NOT EXISTS callcenter_tickets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    external_ticket_id VARCHAR(64) NOT NULL,             -- e.g., TC_1703123456789
    intake_id VARCHAR(64) UNIQUE,                        -- generated intake id
    oms_event_id VARCHAR(64) UNIQUE,                     -- tracking id in OMS
    status VARCHAR(32) NOT NULL DEFAULT 'Registered',    -- Registered, Crew Assigned, In Progress, Partially Restored, Restored
    intake_timestamp TIMESTAMPTZ NOT NULL,               -- from client payload
    source VARCHAR(64) DEFAULT 'call-center',            -- source tag/header
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Customer details (1:1 with ticket at intake time)
CREATE TABLE IF NOT EXISTS callcenter_customers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES callcenter_tickets(id) ON DELETE CASCADE,
    phone VARCHAR(32),
    meter_number VARCHAR(64),
    address TEXT,
    notes TEXT
);

-- Status history (audit trail)
CREATE TABLE IF NOT EXISTS callcenter_ticket_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NOT NULL REFERENCES callcenter_tickets(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    note TEXT
);

-- Raw messages for observability/debug
CREATE TABLE IF NOT EXISTS callcenter_raw_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_id UUID NULL REFERENCES callcenter_tickets(id) ON DELETE SET NULL,
    raw_payload JSONB NOT NULL,
    received_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_cc_tickets_external ON callcenter_tickets(external_ticket_id);
CREATE INDEX IF NOT EXISTS idx_cc_tickets_status ON callcenter_tickets(status);
CREATE INDEX IF NOT EXISTS idx_cc_tickets_intake_ts ON callcenter_tickets(intake_timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_cc_customers_ticket ON callcenter_customers(ticket_id);
CREATE INDEX IF NOT EXISTS idx_cc_customers_phone ON callcenter_customers(phone);
CREATE INDEX IF NOT EXISTS idx_cc_status_ticket ON callcenter_ticket_status_history(ticket_id);
CREATE INDEX IF NOT EXISTS idx_cc_status_changed ON callcenter_ticket_status_history(changed_at DESC);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION cc_update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS cc_tickets_updated_at ON callcenter_tickets;
CREATE TRIGGER cc_tickets_updated_at
    BEFORE UPDATE ON callcenter_tickets
    FOR EACH ROW EXECUTE FUNCTION cc_update_updated_at();

-- Insertion function from intake JSON
-- Expected JSON payload:
-- {
--   "ticketId": "TC_1703123456789",
--   "timestamp": "2024-01-15T10:30:45.123Z",
--   "customer": {"phone":"...","meterNumber":"...","address":"...","notes":"..."},
--   "intake": {"intakeId":"...","omsEventId":"..."},    -- optional
--   "source": "call-center-intake"                            -- optional
-- }

CREATE OR REPLACE FUNCTION insert_callcenter_ticket_from_json(json_data JSONB)
RETURNS UUID AS $$
DECLARE
    v_ticket_uuid UUID;
    v_status TEXT;
    v_intake_id TEXT;
    v_oms_event_id TEXT;
    v_source TEXT;
BEGIN
    IF json_data ? 'ticketId' IS FALSE OR json_data ? 'timestamp' IS FALSE OR json_data ? 'customer' IS FALSE THEN
        RAISE EXCEPTION 'Missing required fields: ticketId, timestamp, customer';
    END IF;

    v_status := COALESCE(json_data->>'status', 'Registered');
    v_intake_id := COALESCE(json_data->'intake'->>'intakeId', NULL);
    v_oms_event_id := COALESCE(json_data->'intake'->>'omsEventId', NULL);
    v_source := COALESCE(json_data->>'source', 'call-center');

    INSERT INTO callcenter_tickets (
        external_ticket_id, intake_id, oms_event_id, status, intake_timestamp, source
    ) VALUES (
        json_data->>'ticketId',
        v_intake_id,
        v_oms_event_id,
        v_status,
        (json_data->>'timestamp')::TIMESTAMPTZ,
        v_source
    ) RETURNING id INTO v_ticket_uuid;

    INSERT INTO callcenter_customers (
        ticket_id, phone, meter_number, address, notes
    ) VALUES (
        v_ticket_uuid,
        json_data->'customer'->>'phone',
        json_data->'customer'->>'meterNumber',
        json_data->'customer'->>'address',
        json_data->'customer'->>'notes'
    );

    INSERT INTO callcenter_ticket_status_history (
        ticket_id, status, changed_at, note
    ) VALUES (
        v_ticket_uuid,
        v_status,
        NOW(),
        'Intake created'
    );

    -- Store raw message for traceability
    INSERT INTO callcenter_raw_messages (ticket_id, raw_payload)
    VALUES (v_ticket_uuid, json_data);

    RETURN v_ticket_uuid;
END;
$$ LANGUAGE plpgsql;


