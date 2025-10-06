-- =========================================================
-- ONU Schema Alterations for Meter Correlation
-- =========================================================
-- Run this on existing ONU database to add meter correlation support
-- =========================================================

SET search_path TO public;

-- Add meter_id to onu_events (links to oms_meters)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'onu_events' AND column_name = 'meter_id'
    ) THEN
        ALTER TABLE onu_events ADD COLUMN meter_id UUID;
        -- Foreign key will be added after oms_meters table exists
        -- ALTER TABLE onu_events ADD CONSTRAINT fk_onu_events_meter
        --     FOREIGN KEY (meter_id) REFERENCES oms_meters(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on meter_id
CREATE INDEX IF NOT EXISTS idx_onu_events_meter ON onu_events(meter_id);

-- Add oms_meter_id to meters table (links to oms_meters)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'meters' AND column_name = 'oms_meter_id'
    ) THEN
        ALTER TABLE meters ADD COLUMN oms_meter_id UUID;
        -- Foreign key will be added after oms_meters table exists
        -- ALTER TABLE meters ADD CONSTRAINT fk_meters_oms_meter
        --     FOREIGN KEY (oms_meter_id) REFERENCES oms_meters(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on oms_meter_id
CREATE INDEX IF NOT EXISTS idx_meters_oms_meter ON meters(oms_meter_id);

-- =========================================================
-- Enhanced ONU event insert function
-- =========================================================

-- Update the existing insert function to also update oms_meters
CREATE OR REPLACE FUNCTION insert_onu_event_from_json_with_meter_sync(json_data JSONB)
RETURNS INTEGER AS $$
DECLARE
    v_event_id INTEGER;
    v_onu_id INT;
    v_event_type VARCHAR(50);
    v_timestamp TIMESTAMPTZ;
    v_meter_id UUID;
BEGIN
    -- Use existing insert function
    v_event_id := insert_onu_event_from_json(json_data);
    
    -- Extract fields for meter update
    v_event_type := json_data->>'type';
    v_timestamp := (json_data->>'timestamp')::TIMESTAMPTZ;
    v_onu_id := (json_data->>'onuId')::INT;
    
    -- Update meter status if power-related event and oms_meters table exists
    IF v_event_type IN ('ONU_LastGaspAlert', 'ONU_PowerRestored') THEN
        BEGIN
            -- Get meter_id from oms_meters
            SELECT id INTO v_meter_id
            FROM oms_meters
            WHERE onu_id = v_onu_id;
            
            IF v_meter_id IS NOT NULL THEN
                -- Update meter status in oms_meters
                UPDATE oms_meters
                SET 
                    power_status = CASE 
                        WHEN v_event_type = 'ONU_PowerRestored' THEN 'on'
                        ELSE 'off'
                    END,
                    communication_status = CASE 
                        WHEN v_event_type = 'ONU_PowerRestored' THEN 'online'
                        ELSE 'offline'
                    END,
                    last_power_change = v_timestamp,
                    last_status_change = v_timestamp,
                    last_communication = v_timestamp,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_meter_id;
                
                -- Update onu_events.meter_id
                UPDATE onu_events
                SET meter_id = v_meter_id
                WHERE id = v_event_id;
                
                -- Record in meter status events (if table exists)
                BEGIN
                    INSERT INTO oms_meter_status_events (
                        meter_id, event_type, source_type, source_event_id,
                        previous_status, 
                        new_status, 
                        event_timestamp, 
                        confidence_score
                    ) VALUES (
                        v_meter_id,
                        CASE WHEN v_event_type = 'ONU_PowerRestored' THEN 'power_on' ELSE 'power_off' END,
                        'onu',
                        (json_data->>'eventId')::TEXT,
                        CASE WHEN v_event_type = 'ONU_PowerRestored' THEN 'off' ELSE 'on' END,
                        CASE WHEN v_event_type = 'ONU_PowerRestored' THEN 'on' ELSE 'off' END,
                        v_timestamp,
                        0.85
                    );
                EXCEPTION WHEN undefined_table THEN
                    -- oms_meter_status_events doesn't exist yet, skip
                    NULL;
                END;
            END IF;
        EXCEPTION WHEN undefined_table THEN
            -- oms_meters doesn't exist yet, skip meter update
            NULL;
        END;
    END IF;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Comments
-- =========================================================
COMMENT ON COLUMN onu_events.meter_id IS 'Link to unified oms_meters table';
COMMENT ON COLUMN meters.oms_meter_id IS 'Link to unified oms_meters table';
COMMENT ON FUNCTION insert_onu_event_from_json_with_meter_sync IS 'Enhanced ONU event insertion with automatic meter status sync to oms_meters';

-- =========================================================
-- Validation
-- =========================================================
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'ONU Schema Alterations Complete';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Added columns:';
    RAISE NOTICE '  - onu_events.meter_id';
    RAISE NOTICE '  - meters.oms_meter_id';
    RAISE NOTICE 'Created function: insert_onu_event_from_json_with_meter_sync';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'NOTE: Update consumer to use new function:';
    RAISE NOTICE '  insert_onu_event_from_json_with_meter_sync()';
    RAISE NOTICE '============================================';
END $$;

