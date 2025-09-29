-- Working database clear script - clears all tables one by one
-- This script uses the same approach that worked in the simple test

-- Clear Kaifa tables first (largest tables)
SELECT 'Clearing Kaifa tables...' as status;
DELETE FROM kaifa_event_payloads WHERE 1=1;
DELETE FROM kaifa_events WHERE 1=1;
DELETE FROM kaifa_event_assets WHERE 1=1;
DELETE FROM kaifa_event_details WHERE 1=1;
DELETE FROM kaifa_event_headers WHERE 1=1;
DELETE FROM kaifa_event_metadata WHERE 1=1;
DELETE FROM kaifa_event_names WHERE 1=1;
DELETE FROM kaifa_event_original_messages WHERE 1=1;
DELETE FROM kaifa_event_status WHERE 1=1;
DELETE FROM kaifa_event_usage_points WHERE 1=1;
DELETE FROM kaifa_event_users WHERE 1=1;

-- Clear Call Center tables
SELECT 'Clearing Call Center tables...' as status;
DELETE FROM callcenter_tickets WHERE 1=1;
DELETE FROM callcenter_customers WHERE 1=1;
DELETE FROM callcenter_raw_messages WHERE 1=1;
DELETE FROM callcenter_ticket_status_history WHERE 1=1;

-- Clear OMS tables
SELECT 'Clearing OMS tables...' as status;
DELETE FROM oms_outage_events WHERE 1=1;
DELETE FROM oms_customers WHERE 1=1;
DELETE FROM oms_smart_meters WHERE 1=1;
DELETE FROM oms_onu_devices WHERE 1=1;
DELETE FROM oms_event_sources WHERE 1=1;
DELETE FROM oms_event_timeline WHERE 1=1;
DELETE FROM oms_crew_assignments WHERE 1=1;
DELETE FROM oms_customer_notifications WHERE 1=1;
DELETE FROM oms_correlation_rules WHERE 1=1;
DELETE FROM oms_storm_mode_config WHERE 1=1;

-- Clear SCADA tables
SELECT 'Clearing SCADA tables...' as status;
DELETE FROM scada_events WHERE 1=1;
DELETE FROM scada_raw_messages WHERE 1=1;

-- Clear ONU tables
SELECT 'Clearing ONU tables...' as status;
DELETE FROM onu_events WHERE 1=1;
DELETE FROM onus WHERE 1=1;

-- Clear Meters table
SELECT 'Clearing Meters table...' as status;
DELETE FROM meters WHERE 1=1;

-- Clear Network tables
SELECT 'Clearing Network tables...' as status;
DELETE FROM network_distribution_points WHERE 1=1;
DELETE FROM network_feeders WHERE 1=1;
DELETE FROM network_substations WHERE 1=1;

-- Reset sequences
SELECT 'Resetting sequences...' as status;
ALTER SEQUENCE IF EXISTS oms_outage_events_event_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS oms_customers_customer_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS oms_smart_meters_meter_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS oms_onu_devices_device_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS network_substations_substation_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS network_feeders_feeder_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS network_distribution_points_dp_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS callcenter_tickets_ticket_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS kaifa_events_event_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS scada_events_event_id_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS onu_events_event_id_seq RESTART WITH 1;

-- Verify clearing
SELECT 'Verification - checking remaining data...' as status;
SELECT 'kaifa_events' as table_name, COUNT(*) as remaining_rows FROM kaifa_events;
SELECT 'kaifa_event_payloads' as table_name, COUNT(*) as remaining_rows FROM kaifa_event_payloads;
SELECT 'callcenter_tickets' as table_name, COUNT(*) as remaining_rows FROM callcenter_tickets;
SELECT 'oms_outage_events' as table_name, COUNT(*) as remaining_rows FROM oms_outage_events;

SELECT 'Database clearing completed successfully!' as final_status;
