-- Verify database clearing and show table counts
-- This script will show the row count for each table to verify they are empty

SELECT 'Checking table row counts...' as status;

-- OMS Tables
SELECT 'OMS Tables:' as section;
SELECT 'oms_customer_notifications' as table_name, COUNT(*) as row_count FROM oms_customer_notifications;
SELECT 'oms_crew_assignments' as table_name, COUNT(*) as row_count FROM oms_crew_assignments;
SELECT 'oms_event_timeline' as table_name, COUNT(*) as row_count FROM oms_event_timeline;
SELECT 'oms_event_sources' as table_name, COUNT(*) as row_count FROM oms_event_sources;
SELECT 'oms_outage_events' as table_name, COUNT(*) as row_count FROM oms_outage_events;
SELECT 'oms_correlation_rules' as table_name, COUNT(*) as row_count FROM oms_correlation_rules;
SELECT 'oms_storm_mode_config' as table_name, COUNT(*) as row_count FROM oms_storm_mode_config;
SELECT 'oms_customers' as table_name, COUNT(*) as row_count FROM oms_customers;
SELECT 'oms_smart_meters' as table_name, COUNT(*) as row_count FROM oms_smart_meters;
SELECT 'oms_onu_devices' as table_name, COUNT(*) as row_count FROM oms_onu_devices;

-- Network Tables
SELECT 'Network Tables:' as section;
SELECT 'network_distribution_points' as table_name, COUNT(*) as row_count FROM network_distribution_points;
SELECT 'network_feeders' as table_name, COUNT(*) as row_count FROM network_feeders;
SELECT 'network_substations' as table_name, COUNT(*) as row_count FROM network_substations;

-- Call Center Tables
SELECT 'Call Center Tables:' as section;
SELECT 'callcenter_customers' as table_name, COUNT(*) as row_count FROM callcenter_customers;
SELECT 'callcenter_raw_messages' as table_name, COUNT(*) as row_count FROM callcenter_raw_messages;
SELECT 'callcenter_ticket_status_history' as table_name, COUNT(*) as row_count FROM callcenter_ticket_status_history;
SELECT 'callcenter_tickets' as table_name, COUNT(*) as row_count FROM callcenter_tickets;

-- Kaifa Tables
SELECT 'Kaifa Tables:' as section;
SELECT 'kaifa_event_assets' as table_name, COUNT(*) as row_count FROM kaifa_event_assets;
SELECT 'kaifa_event_details' as table_name, COUNT(*) as row_count FROM kaifa_event_details;
SELECT 'kaifa_event_headers' as table_name, COUNT(*) as row_count FROM kaifa_event_headers;
SELECT 'kaifa_event_metadata' as table_name, COUNT(*) as row_count FROM kaifa_event_metadata;
SELECT 'kaifa_event_names' as table_name, COUNT(*) as row_count FROM kaifa_event_names;
SELECT 'kaifa_event_original_messages' as table_name, COUNT(*) as row_count FROM kaifa_event_original_messages;
SELECT 'kaifa_event_payloads' as table_name, COUNT(*) as row_count FROM kaifa_event_payloads;
SELECT 'kaifa_event_status' as table_name, COUNT(*) as row_count FROM kaifa_event_status;
SELECT 'kaifa_event_usage_points' as table_name, COUNT(*) as row_count FROM kaifa_event_usage_points;
SELECT 'kaifa_event_users' as table_name, COUNT(*) as row_count FROM kaifa_event_users;
SELECT 'kaifa_events' as table_name, COUNT(*) as row_count FROM kaifa_events;

-- SCADA Tables
SELECT 'SCADA Tables:' as section;
SELECT 'scada_events' as table_name, COUNT(*) as row_count FROM scada_events;
SELECT 'scada_raw_messages' as table_name, COUNT(*) as row_count FROM scada_raw_messages;

-- ONU Tables
SELECT 'ONU Tables:' as section;
SELECT 'onu_events' as table_name, COUNT(*) as row_count FROM onu_events;
SELECT 'onus' as table_name, COUNT(*) as row_count FROM onus;

-- Meters Table
SELECT 'Meters Table:' as section;
SELECT 'meters' as table_name, COUNT(*) as row_count FROM meters;
