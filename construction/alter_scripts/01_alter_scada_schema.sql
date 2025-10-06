-- =========================================================
-- SCADA Schema Alterations for Meter Correlation
-- =========================================================
-- Run this on existing SCADA database to add meter correlation support
-- =========================================================

SET search_path TO public;

-- Add meter correlation columns to scada_events
DO $$ 
BEGIN
    -- Add affected_meter_count column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'scada_events' AND column_name = 'affected_meter_count'
    ) THEN
        ALTER TABLE scada_events ADD COLUMN affected_meter_count INTEGER DEFAULT 0;
    END IF;

    -- Add meters_checked_at column
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'scada_events' AND column_name = 'meters_checked_at'
    ) THEN
        ALTER TABLE scada_events ADD COLUMN meters_checked_at TIMESTAMPTZ;
    END IF;

    -- Add outage_event_id column (links to oms_outage_events)
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'scada_events' AND column_name = 'outage_event_id'
    ) THEN
        ALTER TABLE scada_events ADD COLUMN outage_event_id UUID;
        -- Note: Foreign key will be added after oms_outage_events table exists
        -- ALTER TABLE scada_events ADD CONSTRAINT fk_scada_outage 
        --     FOREIGN KEY (outage_event_id) REFERENCES oms_outage_events(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on outage_event_id
CREATE INDEX IF NOT EXISTS idx_scada_events_outage ON scada_events(outage_event_id);

-- Create link table for SCADA events to affected meters
CREATE TABLE IF NOT EXISTS scada_event_affected_meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    scada_event_id UUID NOT NULL,
    meter_id UUID NOT NULL,
    meter_status_before VARCHAR(20),
    meter_status_after VARCHAR(20),
    checked_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(scada_event_id, meter_id)
);

-- Add foreign key constraints
DO $$
BEGIN
    -- FK to scada_events
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'fk_scada_affected_event'
    ) THEN
        ALTER TABLE scada_event_affected_meters 
            ADD CONSTRAINT fk_scada_affected_event
            FOREIGN KEY (scada_event_id) REFERENCES scada_events(id) ON DELETE CASCADE;
    END IF;

    -- FK to oms_meters (will be created when oms schema is applied)
    -- ALTER TABLE scada_event_affected_meters 
    --     ADD CONSTRAINT fk_scada_affected_meter
    --     FOREIGN KEY (meter_id) REFERENCES oms_meters(id) ON DELETE CASCADE;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_scada_affected_meters_event ON scada_event_affected_meters(scada_event_id);
CREATE INDEX IF NOT EXISTS idx_scada_affected_meters_meter ON scada_event_affected_meters(meter_id);

-- =========================================================
-- Comments
-- =========================================================
COMMENT ON COLUMN scada_events.affected_meter_count IS 'Number of meters affected by this SCADA event';
COMMENT ON COLUMN scada_events.meters_checked_at IS 'Timestamp when meters were checked for this event';
COMMENT ON COLUMN scada_events.outage_event_id IS 'Link to OMS outage event if created';
COMMENT ON TABLE scada_event_affected_meters IS 'Links SCADA events to specific meters that were checked/affected';

-- =========================================================
-- Validation
-- =========================================================
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'SCADA Schema Alterations Complete';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Added columns to scada_events:';
    RAISE NOTICE '  - affected_meter_count';
    RAISE NOTICE '  - meters_checked_at';
    RAISE NOTICE '  - outage_event_id';
    RAISE NOTICE 'Created table: scada_event_affected_meters';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'NOTE: Apply oms_meter_correlation_enhancement.sql';
    RAISE NOTICE '      to enable automatic meter checking';
    RAISE NOTICE '============================================';
END $$;

