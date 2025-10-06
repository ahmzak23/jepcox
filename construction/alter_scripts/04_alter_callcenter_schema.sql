-- =========================================================
-- CALL CENTER Schema Alterations for Meter Correlation
-- =========================================================
-- Run this on existing CALL CENTER database to add meter correlation support
-- =========================================================

SET search_path TO public;

-- Add meter_id to callcenter_customers (links to oms_meters via meter_number)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'callcenter_customers' AND column_name = 'meter_id'
    ) THEN
        ALTER TABLE callcenter_customers ADD COLUMN meter_id UUID;
        -- Foreign key will be added after oms_meters table exists
        -- ALTER TABLE callcenter_customers ADD CONSTRAINT fk_callcenter_customers_meter
        --     FOREIGN KEY (meter_id) REFERENCES oms_meters(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on meter_id
CREATE INDEX IF NOT EXISTS idx_callcenter_customers_meter ON callcenter_customers(meter_id);

-- =========================================================
-- Enhanced Call Center ticket insert function
-- =========================================================

-- Update the existing insert function to also link to oms_meters
CREATE OR REPLACE FUNCTION insert_callcenter_ticket_from_json_with_meter_link(json_data JSONB)
RETURNS UUID AS $$
DECLARE
    v_ticket_uuid UUID;
    v_meter_number VARCHAR(64);
    v_meter_id UUID;
BEGIN
    -- Use existing insert function
    v_ticket_uuid := insert_callcenter_ticket_from_json(json_data);
    
    -- Extract meter number
    v_meter_number := json_data->'customer'->>'meterNumber';
    
    -- Link to oms_meters if exists
    IF v_meter_number IS NOT NULL AND v_meter_number != '' THEN
        BEGIN
            -- Find meter in oms_meters
            SELECT id INTO v_meter_id
            FROM oms_meters
            WHERE meter_number = v_meter_number;
            
            IF v_meter_id IS NOT NULL THEN
                -- Update callcenter_customers with meter_id
                UPDATE callcenter_customers
                SET meter_id = v_meter_id
                WHERE ticket_id = v_ticket_uuid
                AND meter_number = v_meter_number;
                
                -- Optionally record customer report as meter status event
                BEGIN
                    INSERT INTO oms_meter_status_events (
                        meter_id, 
                        event_type, 
                        source_type, 
                        source_event_id,
                        previous_status, 
                        new_status, 
                        event_timestamp, 
                        confidence_score,
                        metadata
                    ) VALUES (
                        v_meter_id,
                        'power_off',
                        'call_center',
                        v_ticket_uuid::TEXT,
                        'unknown',
                        'off',
                        (json_data->>'timestamp')::TIMESTAMPTZ,
                        0.60, -- Lower confidence for call center reports
                        jsonb_build_object(
                            'ticket_id', json_data->>'ticketId',
                            'customer_phone', json_data->'customer'->>'phone'
                        )
                    );
                EXCEPTION WHEN undefined_table THEN
                    -- oms_meter_status_events doesn't exist yet, skip
                    NULL;
                END;
            END IF;
        EXCEPTION WHEN undefined_table THEN
            -- oms_meters doesn't exist yet, skip linking
            NULL;
        END;
    END IF;
    
    RETURN v_ticket_uuid;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Helper function to sync existing tickets to meters
-- =========================================================

CREATE OR REPLACE FUNCTION sync_callcenter_tickets_to_meters()
RETURNS TABLE(
    tickets_processed INTEGER,
    meters_linked INTEGER,
    meters_not_found INTEGER
) AS $$
DECLARE
    v_tickets_processed INTEGER := 0;
    v_meters_linked INTEGER := 0;
    v_meters_not_found INTEGER := 0;
    v_customer_record RECORD;
BEGIN
    FOR v_customer_record IN (
        SELECT cc.id, cc.meter_number
        FROM callcenter_customers cc
        WHERE cc.meter_id IS NULL
        AND cc.meter_number IS NOT NULL
        AND cc.meter_number != ''
    ) LOOP
        v_tickets_processed := v_tickets_processed + 1;
        
        -- Try to find meter
        UPDATE callcenter_customers cc
        SET meter_id = om.id
        FROM oms_meters om
        WHERE cc.id = v_customer_record.id
        AND om.meter_number = v_customer_record.meter_number;
        
        IF FOUND THEN
            v_meters_linked := v_meters_linked + 1;
        ELSE
            v_meters_not_found := v_meters_not_found + 1;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_tickets_processed, v_meters_linked, v_meters_not_found;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Comments
-- =========================================================
COMMENT ON COLUMN callcenter_customers.meter_id IS 'Link to unified oms_meters table via meter_number';
COMMENT ON FUNCTION insert_callcenter_ticket_from_json_with_meter_link IS 'Enhanced Call Center ticket insertion with automatic meter linking';
COMMENT ON FUNCTION sync_callcenter_tickets_to_meters IS 'Utility function to link existing call center tickets to oms_meters';

-- =========================================================
-- Validation
-- =========================================================
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'CALL CENTER Schema Alterations Complete';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Added column: callcenter_customers.meter_id';
    RAISE NOTICE 'Created function: insert_callcenter_ticket_from_json_with_meter_link';
    RAISE NOTICE 'Created function: sync_callcenter_tickets_to_meters';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'NOTE: Update consumer to use new function:';
    RAISE NOTICE '  insert_callcenter_ticket_from_json_with_meter_link()';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'To link existing tickets to meters, run:';
    RAISE NOTICE '  SELECT * FROM sync_callcenter_tickets_to_meters();';
    RAISE NOTICE '============================================';
END $$;

