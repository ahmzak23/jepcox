-- Clear ALL database data
-- This script will delete all data from ALL tables while preserving the schema structure

-- Disable foreign key checks temporarily to avoid constraint issues
SET session_replication_role = replica;

-- Clear OMS tables (in reverse dependency order)
TRUNCATE TABLE oms_customer_notifications CASCADE;
TRUNCATE TABLE oms_crew_assignments CASCADE;
TRUNCATE TABLE oms_event_timeline CASCADE;
TRUNCATE TABLE oms_event_sources CASCADE;
TRUNCATE TABLE oms_outage_events CASCADE;
TRUNCATE TABLE oms_correlation_rules CASCADE;
TRUNCATE TABLE oms_storm_mode_config CASCADE;
TRUNCATE TABLE oms_customers CASCADE;
TRUNCATE TABLE oms_smart_meters CASCADE;
TRUNCATE TABLE oms_onu_devices CASCADE;

-- Clear network topology tables
TRUNCATE TABLE network_distribution_points CASCADE;
TRUNCATE TABLE network_feeders CASCADE;
TRUNCATE TABLE network_substations CASCADE;

-- Clear Call Center tables
TRUNCATE TABLE callcenter_customers CASCADE;
TRUNCATE TABLE callcenter_raw_messages CASCADE;
TRUNCATE TABLE callcenter_ticket_status_history CASCADE;
TRUNCATE TABLE callcenter_tickets CASCADE;

-- Clear Kaifa tables
TRUNCATE TABLE kaifa_event_assets CASCADE;
TRUNCATE TABLE kaifa_event_details CASCADE;
TRUNCATE TABLE kaifa_event_headers CASCADE;
TRUNCATE TABLE kaifa_event_metadata CASCADE;
TRUNCATE TABLE kaifa_event_names CASCADE;
TRUNCATE TABLE kaifa_event_original_messages CASCADE;
TRUNCATE TABLE kaifa_event_payloads CASCADE;
TRUNCATE TABLE kaifa_event_status CASCADE;
TRUNCATE TABLE kaifa_event_usage_points CASCADE;
TRUNCATE TABLE kaifa_event_users CASCADE;
TRUNCATE TABLE kaifa_events CASCADE;

-- Clear SCADA tables
TRUNCATE TABLE scada_events CASCADE;
TRUNCATE TABLE scada_raw_messages CASCADE;

-- Clear ONU tables
TRUNCATE TABLE onu_events CASCADE;
TRUNCATE TABLE onus CASCADE;

-- Clear Meters table
TRUNCATE TABLE meters CASCADE;

-- Re-enable foreign key checks
SET session_replication_role = DEFAULT;

-- Reset ALL sequences to start from 1
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

-- Show confirmation
SELECT 'ALL database data has been cleared successfully!' as status;
