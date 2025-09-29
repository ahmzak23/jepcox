-- =========================================================
-- CREW MANAGEMENT SAMPLE DATA
-- =========================================================
-- This script adds sample data for testing the crew management system
-- =========================================================

-- =========================================================
-- 1. CREW MEMBERS
-- =========================================================

-- Insert sample crew members
INSERT INTO oms_crew_members (
    employee_id, first_name, last_name, email, phone, 
    emergency_contact_name, emergency_contact_phone, hire_date, 
    crew_type, experience_years, location_lat, location_lng, home_base
) VALUES
('EMP001', 'John', 'Smith', 'john.smith@utility.com', '555-0101', 'Jane Smith', '555-0102', '2020-03-15', 'lineman', 8, 40.7128, -74.0060, 'Manhattan Depot'),
('EMP002', 'Maria', 'Garcia', 'maria.garcia@utility.com', '555-0103', 'Carlos Garcia', '555-0104', '2019-07-22', 'lineman', 6, 40.7589, -73.9851, 'Brooklyn Depot'),
('EMP003', 'Robert', 'Johnson', 'robert.johnson@utility.com', '555-0105', 'Linda Johnson', '555-0106', '2018-11-08', 'supervisor', 12, 40.7505, -73.9934, 'Queens Depot'),
('EMP004', 'Sarah', 'Williams', 'sarah.williams@utility.com', '555-0107', 'Michael Williams', '555-0108', '2021-01-12', 'technician', 4, 40.6892, -74.0445, 'Staten Island Depot'),
('EMP005', 'David', 'Brown', 'david.brown@utility.com', '555-0109', 'Lisa Brown', '555-0110', '2017-05-30', 'engineer', 10, 40.7282, -73.7949, 'Bronx Depot'),
('EMP006', 'Jennifer', 'Davis', 'jennifer.davis@utility.com', '555-0111', 'Tom Davis', '555-0112', '2020-09-14', 'dispatcher', 5, 40.7128, -74.0060, 'Manhattan Control Center'),
('EMP007', 'Michael', 'Wilson', 'michael.wilson@utility.com', '555-0113', 'Susan Wilson', '555-0114', '2019-12-03', 'lineman', 7, 40.7589, -73.9851, 'Brooklyn Depot'),
('EMP008', 'Lisa', 'Anderson', 'lisa.anderson@utility.com', '555-0115', 'Mark Anderson', '555-0116', '2021-06-18', 'technician', 3, 40.7505, -73.9934, 'Queens Depot');

-- =========================================================
-- 2. CREW TEAMS
-- =========================================================

-- Insert sample teams
INSERT INTO oms_crew_teams (
    team_id, team_name, team_leader_id, team_type, max_members, 
    location_lat, location_lng
) VALUES
('TEAM001', 'Manhattan Line Crew Alpha', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), 'line_crew', 4, 40.7128, -74.0060),
('TEAM002', 'Brooklyn Emergency Response', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), 'emergency', 3, 40.7589, -73.9851),
('TEAM003', 'Queens Maintenance Team', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), 'maintenance', 5, 40.7505, -73.9934),
('TEAM004', 'Specialized Equipment Crew', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), 'specialized', 3, 40.7282, -73.7949);

-- =========================================================
-- 3. TEAM MEMBERSHIPS
-- =========================================================

-- Assign crew members to teams
INSERT INTO oms_crew_team_members (team_id, crew_member_id, role, is_primary_team) VALUES
-- Manhattan Line Crew Alpha
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM001'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), 'leader', true),
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM001'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), 'member', true),
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM001'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP007'), 'member', true),

-- Brooklyn Emergency Response
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM002'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), 'leader', true),
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM002'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP008'), 'member', true),

-- Queens Maintenance Team
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM003'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), 'leader', true),
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM003'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), 'member', false),

-- Specialized Equipment Crew
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM004'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), 'leader', true),
((SELECT id FROM oms_crew_teams WHERE team_id = 'TEAM004'), (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP008'), 'member', false);

-- =========================================================
-- 4. CREW MEMBER SKILLS
-- =========================================================

-- Assign skills to crew members
INSERT INTO oms_crew_member_skills (crew_member_id, skill_id, skill_level, proficiency_score, years_experience, verified_by, verified_date) VALUES
-- John Smith (EMP001) - Senior Lineman
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED'), 'expert', 0.95, 8, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-15'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'SAFETY_OSHA'), 'expert', 0.90, 8, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-15'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'COMM_RADIO'), 'advanced', 0.85, 6, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-15'),

-- Maria Garcia (EMP002) - Senior Lineman
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED'), 'expert', 0.92, 6, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-02-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'SAFETY_CONFINED'), 'advanced', 0.88, 4, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-02-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'COMM_CUSTOMER'), 'advanced', 0.90, 5, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-02-10'),

-- Robert Johnson (EMP003) - Supervisor
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED'), 'expert', 0.98, 12, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), '2023-01-05'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'SAFETY_OSHA'), 'expert', 0.95, 12, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), '2023-01-05'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'COMM_CUSTOMER'), 'expert', 0.92, 10, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), '2023-01-05'),

-- Sarah Williams (EMP004) - Technician
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_BASIC'), 'intermediate', 0.75, 4, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-03-20'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'MECH_BASIC'), 'intermediate', 0.80, 3, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-03-20'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'TOOL_POWER'), 'advanced', 0.85, 4, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-03-20'),

-- David Brown (EMP005) - Engineer
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED'), 'expert', 0.96, 10, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'TOOL_SPECIALIZED'), 'expert', 0.94, 8, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'COMM_CUSTOMER'), 'advanced', 0.88, 7, (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-10');

-- =========================================================
-- 5. CREW MEMBER CERTIFICATIONS
-- =========================================================

-- Assign certifications to crew members
INSERT INTO oms_crew_member_certifications (crew_member_id, certification_id, cert_number, issued_date, expiry_date, status, issuing_authority, verified_by, verified_date) VALUES
-- John Smith certifications
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'OSHA_30'), 'OSH-001-2023', '2023-01-15', '2025-01-15', 'valid', 'OSHA', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-15'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'CPR'), 'CPR-001-2023', '2023-01-20', '2025-01-20', 'valid', 'American Red Cross', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-20'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'ELECTRICAL_LICENSE'), 'EL-001-2020', '2020-03-15', '2024-03-15', 'valid', 'NY State Licensing Board', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-15'),

-- Maria Garcia certifications
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'OSHA_30'), 'OSH-002-2023', '2023-02-10', '2025-02-10', 'valid', 'OSHA', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-02-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'CONFINED_SPACE'), 'CS-002-2023', '2023-02-15', '2026-02-15', 'valid', 'OSHA', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-02-15'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'HIGH_VOLTAGE'), 'HV-002-2021', '2021-07-22', '2024-07-22', 'valid', 'Utility Training Center', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-02-10'),

-- Robert Johnson certifications (Supervisor)
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'OSHA_30'), 'OSH-003-2023', '2023-01-05', '2025-01-05', 'valid', 'OSHA', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), '2023-01-05'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'ELECTRICAL_LICENSE'), 'EL-003-2018', '2018-11-08', '2024-11-08', 'valid', 'NY State Licensing Board', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), '2023-01-05'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'CDL'), 'CDL-003-2019', '2019-03-15', '2025-03-15', 'valid', 'NY DMV', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), '2023-01-05'),

-- Sarah Williams certifications
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'OSHA_10'), 'OSH-004-2023', '2023-03-20', '2025-03-20', 'valid', 'OSHA', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-03-20'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'CPR'), 'CPR-004-2023', '2023-03-25', '2025-03-25', 'valid', 'American Red Cross', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-03-25'),

-- David Brown certifications (Engineer)
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'OSHA_30'), 'OSH-005-2023', '2023-01-10', '2025-01-10', 'valid', 'OSHA', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'ELECTRICAL_LICENSE'), 'EL-005-2017', '2017-05-30', '2025-05-30', 'valid', 'NY State Licensing Board', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-10'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), (SELECT id FROM oms_crew_certifications WHERE cert_code = 'HIGH_VOLTAGE'), 'HV-005-2019', '2019-08-15', '2025-08-15', 'valid', 'Utility Training Center', (SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), '2023-01-10');

-- =========================================================
-- 6. CREW AVAILABILITY
-- =========================================================

-- Set availability for the next 7 days
INSERT INTO oms_crew_availability (crew_member_id, availability_date, shift_start, shift_end, status) VALUES
-- John Smith - Available for next 7 days
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE, '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE + INTERVAL '1 day', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE + INTERVAL '2 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE + INTERVAL '3 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE + INTERVAL '4 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE + INTERVAL '5 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE + INTERVAL '6 days', '08:00', '16:00', 'available'),

-- Maria Garcia - Available for next 7 days
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE, '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE + INTERVAL '1 day', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE + INTERVAL '2 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE + INTERVAL '3 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE + INTERVAL '4 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE + INTERVAL '5 days', '08:00', '16:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE + INTERVAL '6 days', '08:00', '16:00', 'available'),

-- Robert Johnson - Available for next 7 days
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE, '07:00', '15:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE + INTERVAL '1 day', '07:00', '15:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE + INTERVAL '2 days', '07:00', '15:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE + INTERVAL '3 days', '07:00', '15:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE + INTERVAL '4 days', '07:00', '15:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE + INTERVAL '5 days', '07:00', '15:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE + INTERVAL '6 days', '07:00', '15:00', 'available'),

-- Sarah Williams - Available for next 7 days
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE, '09:00', '17:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE + INTERVAL '1 day', '09:00', '17:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE + INTERVAL '2 days', '09:00', '17:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE + INTERVAL '3 days', '09:00', '17:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE + INTERVAL '4 days', '09:00', '17:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE + INTERVAL '5 days', '09:00', '17:00', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'), CURRENT_DATE + INTERVAL '6 days', '09:00', '17:00', 'available'),

-- David Brown - Available for next 7 days
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE, '08:30', '16:30', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE + INTERVAL '1 day', '08:30', '16:30', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE + INTERVAL '2 days', '08:30', '16:30', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE + INTERVAL '3 days', '08:30', '16:30', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE + INTERVAL '4 days', '08:30', '16:30', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE + INTERVAL '5 days', '08:30', '16:30', 'available'),
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'), CURRENT_DATE + INTERVAL '6 days', '08:30', '16:30', 'available');

-- =========================================================
-- 7. EQUIPMENT
-- =========================================================

-- Insert sample equipment
INSERT INTO oms_crew_equipment (equipment_id, equipment_name, equipment_type, category, status, location, last_maintenance_date, next_maintenance_date) VALUES
('VEH001', 'Bucket Truck Alpha', 'vehicle', 'electrical', 'available', 'Manhattan Depot', '2023-10-15', '2024-04-15'),
('VEH002', 'Service Van Beta', 'vehicle', 'electrical', 'available', 'Brooklyn Depot', '2023-11-01', '2024-05-01'),
('VEH003', 'Crane Truck Gamma', 'vehicle', 'mechanical', 'available', 'Queens Depot', '2023-09-20', '2024-03-20'),
('TOOL001', 'Insulated Gloves Set', 'tool', 'safety', 'available', 'Manhattan Depot', '2023-12-01', '2024-06-01'),
('TOOL002', 'Voltage Tester Pro', 'tool', 'electrical', 'available', 'Brooklyn Depot', '2023-11-15', '2024-05-15'),
('TOOL003', 'Hydraulic Crimper', 'tool', 'mechanical', 'available', 'Queens Depot', '2023-10-30', '2024-04-30'),
('SAFE001', 'Hard Hat Set', 'safety_gear', 'safety', 'available', 'Manhattan Depot', '2023-12-10', '2024-06-10'),
('SAFE002', 'Safety Harness', 'safety_gear', 'safety', 'available', 'Brooklyn Depot', '2023-11-25', '2024-05-25'),
('COMM001', 'Two-Way Radio Set', 'communication', 'communication', 'available', 'Manhattan Control Center', '2023-12-05', '2024-06-05'),
('COMM002', 'Satellite Phone', 'communication', 'communication', 'available', 'Manhattan Control Center', '2023-11-30', '2024-05-30');

-- =========================================================
-- 8. PERFORMANCE DATA
-- =========================================================

-- Insert sample performance data for the last quarter
INSERT INTO oms_crew_performance (
    crew_member_id, performance_period_start, performance_period_end,
    total_assignments, completed_assignments, on_time_completions,
    average_completion_time_hours, safety_incidents, customer_satisfaction_score,
    supervisor_rating, training_hours_completed, certifications_earned
) VALUES
-- John Smith performance
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), 
 CURRENT_DATE - INTERVAL '3 months', CURRENT_DATE - INTERVAL '1 day',
 25, 24, 22, 2.5, 0, 4.8, 4.7, 16.0, 1),

-- Maria Garcia performance  
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'),
 CURRENT_DATE - INTERVAL '3 months', CURRENT_DATE - INTERVAL '1 day',
 28, 27, 25, 2.2, 0, 4.9, 4.8, 20.0, 2),

-- Robert Johnson performance
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'),
 CURRENT_DATE - INTERVAL '3 months', CURRENT_DATE - INTERVAL '1 day',
 15, 15, 14, 3.0, 0, 4.9, 4.9, 24.0, 1),

-- Sarah Williams performance
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP004'),
 CURRENT_DATE - INTERVAL '3 months', CURRENT_DATE - INTERVAL '1 day',
 18, 17, 15, 2.8, 0, 4.6, 4.5, 32.0, 2),

-- David Brown performance
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP005'),
 CURRENT_DATE - INTERVAL '3 months', CURRENT_DATE - INTERVAL '1 day',
 12, 12, 11, 4.2, 0, 4.9, 4.8, 18.0, 1);

-- =========================================================
-- 9. WORK HISTORY
-- =========================================================

-- Insert sample work history for the last month
INSERT INTO oms_crew_work_history (crew_member_id, work_date, work_type, hours_worked, location, description, skills_used, equipment_used, safety_notes) VALUES
-- John Smith work history
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE - INTERVAL '5 days', 'outage_repair', 8.0, 'Manhattan - 5th Ave', 'Repaired downed power line after storm', 
 ARRAY[(SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'SAFETY_OSHA')],
 ARRAY['Bucket Truck Alpha', 'Insulated Gloves Set', 'Voltage Tester Pro'], 'All safety protocols followed'),

((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP001'), CURRENT_DATE - INTERVAL '3 days', 'maintenance', 6.0, 'Manhattan - Central Park', 'Routine transformer maintenance',
 ARRAY[(SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED')],
 ARRAY['Service Van Beta', 'Voltage Tester Pro'], 'Standard maintenance procedures'),

-- Maria Garcia work history
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP002'), CURRENT_DATE - INTERVAL '4 days', 'emergency', 10.0, 'Brooklyn - Prospect Park', 'Emergency pole replacement',
 ARRAY[(SELECT id FROM oms_crew_skills WHERE skill_code = 'ELEC_ADVANCED'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'SAFETY_CONFINED')],
 ARRAY['Crane Truck Gamma', 'Safety Harness', 'Hard Hat Set'], 'Emergency response protocols followed'),

-- Robert Johnson work history
((SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), CURRENT_DATE - INTERVAL '2 days', 'outage_repair', 7.5, 'Queens - Flushing', 'Supervised major outage restoration',
 ARRAY[(SELECT id FROM oms_crew_members WHERE employee_id = 'EMP003'), (SELECT id FROM oms_crew_skills WHERE skill_code = 'COMM_CUSTOMER')],
 ARRAY['Two-Way Radio Set', 'Satellite Phone'], 'Coordinated with multiple crews');

-- =========================================================
-- END OF SAMPLE DATA
-- =========================================================
