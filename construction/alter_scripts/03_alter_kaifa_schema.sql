-- =========================================================
-- KAIFA (HES) Schema Alterations for Meter Correlation
-- =========================================================
-- Run this on existing KAIFA database to add meter correlation support
-- =========================================================

SET search_path TO public;

-- Add meter_id to kaifa_event_assets (links to oms_meters via mrid)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'kaifa_event_assets' AND column_name = 'meter_id'
    ) THEN
        ALTER TABLE kaifa_event_assets ADD COLUMN meter_id UUID;
        -- Foreign key will be added after oms_meters table exists
        -- ALTER TABLE kaifa_event_assets ADD CONSTRAINT fk_kaifa_assets_meter
        --     FOREIGN KEY (meter_id) REFERENCES oms_meters(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on meter_id
CREATE INDEX IF NOT EXISTS idx_kaifa_assets_meter ON kaifa_event_assets(meter_id);

-- Add meter_id to kaifa_event_usage_points (links to oms_meters via mrid)
DO $$ 
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'kaifa_event_usage_points' AND column_name = 'meter_id'
    ) THEN
        ALTER TABLE kaifa_event_usage_points ADD COLUMN meter_id UUID;
        -- Foreign key will be added after oms_meters table exists
        -- ALTER TABLE kaifa_event_usage_points ADD CONSTRAINT fk_kaifa_usage_points_meter
        --     FOREIGN KEY (meter_id) REFERENCES oms_meters(id) ON DELETE SET NULL;
    END IF;
END $$;

-- Create index on meter_id
CREATE INDEX IF NOT EXISTS idx_kaifa_usage_points_meter ON kaifa_event_usage_points(meter_id);

-- =========================================================
-- Enhanced KAIFA event insert function
-- =========================================================

-- Update the existing insert function to also update oms_meters
CREATE OR REPLACE FUNCTION insert_kaifa_event_from_json_with_meter_sync(json_data JSONB)
RETURNS UUID AS $$
DECLARE
    event_uuid UUID;
    v_asset_mrid VARCHAR(100);
    v_usage_point_mrid VARCHAR(100);
    v_meter_id UUID;
    v_event_timestamp TIMESTAMPTZ;
    v_severity VARCHAR(20);
BEGIN
    -- Use existing insert function
    event_uuid := insert_kaifa_event_from_json(json_data);
    
    -- Extract meter identifiers
    v_asset_mrid := json_data->'payload'->'assets'->>'ns2:mRID';
    v_usage_point_mrid := json_data->'payload'->'usage_point'->>'ns2:mRID';
    v_event_timestamp := (json_data->>'timestamp')::TIMESTAMPTZ;
    v_severity := json_data->'payload'->>'severity';
    
    -- Update meter status if oms_meters table exists
    BEGIN
        -- Find meter by asset_mrid or usage_point_mrid
        SELECT id INTO v_meter_id
        FROM oms_meters
        WHERE asset_mrid = v_asset_mrid 
           OR usage_point_mrid = v_usage_point_mrid
           OR meter_number = v_asset_mrid
        LIMIT 1;
        
        IF v_meter_id IS NOT NULL THEN
            -- Update meter communication status
            UPDATE oms_meters
            SET 
                last_communication = v_event_timestamp,
                communication_status = 'online',
                -- Update power status if critical event (last gasp scenario)
                power_status = CASE 
                    WHEN v_severity IN ('critical', 'high') THEN 'off'
                    ELSE power_status
                END,
                last_power_change = CASE 
                    WHEN v_severity IN ('critical', 'high') THEN v_event_timestamp
                    ELSE last_power_change
                END,
                last_status_change = v_event_timestamp,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_meter_id;
            
            -- Update kaifa_event_assets.meter_id
            UPDATE kaifa_event_assets
            SET meter_id = v_meter_id
            WHERE payload_id IN (
                SELECT id FROM kaifa_event_payloads WHERE event_id = event_uuid
            );
            
            -- Update kaifa_event_usage_points.meter_id
            UPDATE kaifa_event_usage_points
            SET meter_id = v_meter_id
            WHERE payload_id IN (
                SELECT id FROM kaifa_event_payloads WHERE event_id = event_uuid
            );
            
            -- Record in meter status events for critical events
            IF v_severity IN ('critical', 'high') THEN
                BEGIN
                    INSERT INTO oms_meter_status_events (
                        meter_id, event_type, source_type, source_event_id,
                        previous_status, 
                        new_status, 
                        event_timestamp, 
                        confidence_score,
                        metadata
                    ) VALUES (
                        v_meter_id,
                        'power_off',
                        'kaifa',
                        event_uuid::TEXT,
                        'on',
                        'off',
                        v_event_timestamp,
                        0.90,
                        jsonb_build_object(
                            'severity', v_severity,
                            'reason', json_data->'payload'->>'reason'
                        )
                    );
                EXCEPTION WHEN undefined_table THEN
                    -- oms_meter_status_events doesn't exist yet, skip
                    NULL;
                END;
            END IF;
        END IF;
    EXCEPTION WHEN undefined_table THEN
        -- oms_meters doesn't exist yet, skip meter update
        NULL;
    END;
    
    RETURN event_uuid;
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- Comments
-- =========================================================
COMMENT ON COLUMN kaifa_event_assets.meter_id IS 'Link to unified oms_meters table via asset mRID';
COMMENT ON COLUMN kaifa_event_usage_points.meter_id IS 'Link to unified oms_meters table via usage point mRID';
COMMENT ON FUNCTION insert_kaifa_event_from_json_with_meter_sync IS 'Enhanced Kaifa event insertion with automatic meter status sync to oms_meters';

-- =========================================================
-- Validation
-- =========================================================
DO $$
BEGIN
    RAISE NOTICE '============================================';
    RAISE NOTICE 'KAIFA Schema Alterations Complete';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'Added columns:';
    RAISE NOTICE '  - kaifa_event_assets.meter_id';
    RAISE NOTICE '  - kaifa_event_usage_points.meter_id';
    RAISE NOTICE 'Created function: insert_kaifa_event_from_json_with_meter_sync';
    RAISE NOTICE '============================================';
    RAISE NOTICE 'NOTE: Update consumer to use new function:';
    RAISE NOTICE '  insert_kaifa_event_from_json_with_meter_sync()';
    RAISE NOTICE '============================================';
END $$;

