-- =========================================================
-- CREW MANAGEMENT SCHEMA - Outage Management System
-- =========================================================
-- This schema provides comprehensive crew management capabilities
-- for the OMS system, including crew members, skills, availability,
-- assignments, and performance tracking.
-- =========================================================

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================
-- 1. CREW MEMBERS & ORGANIZATION
-- =========================================================

-- Crew members master table
CREATE TABLE IF NOT EXISTS oms_crew_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id VARCHAR(64) UNIQUE NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255),
    phone VARCHAR(32),
    emergency_contact_name VARCHAR(200),
    emergency_contact_phone VARCHAR(32),
    hire_date DATE NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'active', -- active, inactive, on_leave, terminated
    crew_type VARCHAR(32) NOT NULL, -- lineman, supervisor, technician, engineer, dispatcher
    experience_years INTEGER DEFAULT 0,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    home_base VARCHAR(200), -- primary work location
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Crew teams/groups
CREATE TABLE IF NOT EXISTS oms_crew_teams (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id VARCHAR(64) UNIQUE NOT NULL,
    team_name VARCHAR(200) NOT NULL,
    team_leader_id UUID REFERENCES oms_crew_members(id),
    team_type VARCHAR(32) NOT NULL, -- line_crew, maintenance, emergency, specialized
    max_members INTEGER DEFAULT 6,
    status VARCHAR(32) DEFAULT 'active', -- active, inactive
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Team membership
CREATE TABLE IF NOT EXISTS oms_crew_team_members (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    team_id UUID NOT NULL REFERENCES oms_crew_teams(id) ON DELETE CASCADE,
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL, -- leader, member, trainee
    joined_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_primary_team BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(team_id, crew_member_id)
);

-- =========================================================
-- 2. SKILLS & CERTIFICATIONS
-- =========================================================

-- Skills catalog
CREATE TABLE IF NOT EXISTS oms_crew_skills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    skill_code VARCHAR(64) UNIQUE NOT NULL,
    skill_name VARCHAR(200) NOT NULL,
    skill_category VARCHAR(64) NOT NULL, -- electrical, mechanical, safety, communication
    skill_levels VARCHAR(100)[] DEFAULT ARRAY['basic', 'intermediate', 'advanced', 'expert'],
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Certifications catalog
CREATE TABLE IF NOT EXISTS oms_crew_certifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    cert_code VARCHAR(64) UNIQUE NOT NULL,
    cert_name VARCHAR(200) NOT NULL,
    cert_type VARCHAR(64) NOT NULL, -- safety, technical, regulatory, specialized
    issuing_authority VARCHAR(200),
    validity_months INTEGER, -- NULL for permanent certifications
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Crew member skills
CREATE TABLE IF NOT EXISTS oms_crew_member_skills (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    skill_id UUID NOT NULL REFERENCES oms_crew_skills(id) ON DELETE CASCADE,
    skill_level VARCHAR(32) NOT NULL, -- basic, intermediate, advanced, expert
    proficiency_score DECIMAL(3,2) DEFAULT 0.0, -- 0.0 to 1.0
    years_experience INTEGER DEFAULT 0,
    last_used_date DATE,
    verified_by UUID REFERENCES oms_crew_members(id),
    verified_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crew_member_id, skill_id)
);

-- Crew member certifications
CREATE TABLE IF NOT EXISTS oms_crew_member_certifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    certification_id UUID NOT NULL REFERENCES oms_crew_certifications(id) ON DELETE CASCADE,
    cert_number VARCHAR(100),
    issued_date DATE NOT NULL,
    expiry_date DATE,
    status VARCHAR(32) NOT NULL DEFAULT 'valid', -- valid, expired, suspended, revoked
    issuing_authority VARCHAR(200),
    verified_by UUID REFERENCES oms_crew_members(id),
    verified_date DATE,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crew_member_id, certification_id, cert_number)
);

-- =========================================================
-- 3. AVAILABILITY & SCHEDULING
-- =========================================================

-- Crew availability calendar
CREATE TABLE IF NOT EXISTS oms_crew_availability (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    availability_date DATE NOT NULL,
    shift_start TIME,
    shift_end TIME,
    status VARCHAR(32) NOT NULL, -- available, unavailable, on_call, sick, vacation, training
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crew_member_id, availability_date)
);

-- Crew schedules
CREATE TABLE IF NOT EXISTS oms_crew_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    schedule_date DATE NOT NULL,
    shift_type VARCHAR(32) NOT NULL, -- day, night, on_call, standby
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    location VARCHAR(200),
    status VARCHAR(32) DEFAULT 'scheduled', -- scheduled, confirmed, in_progress, completed, cancelled
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 4. ENHANCED CREW ASSIGNMENTS
-- =========================================================

-- Enhanced crew assignments (replaces basic oms_crew_assignments)
CREATE TABLE IF NOT EXISTS oms_crew_assignments_enhanced (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    outage_event_id UUID NOT NULL REFERENCES oms_outage_events(id) ON DELETE CASCADE,
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id),
    team_id UUID REFERENCES oms_crew_teams(id),
    assignment_type VARCHAR(32) NOT NULL, -- investigation, repair, restoration, assessment, support
    priority VARCHAR(16) NOT NULL DEFAULT 'medium', -- low, medium, high, critical
    status VARCHAR(32) NOT NULL DEFAULT 'assigned', -- assigned, accepted, en_route, on_site, in_progress, completed, cancelled
    assigned_by UUID REFERENCES oms_crew_members(id),
    assigned_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    accepted_at TIMESTAMPTZ,
    estimated_arrival TIMESTAMPTZ,
    actual_arrival TIMESTAMPTZ,
    work_started_at TIMESTAMPTZ,
    work_completed_at TIMESTAMPTZ,
    estimated_duration_hours DECIMAL(4,2),
    actual_duration_hours DECIMAL(4,2),
    required_skills UUID[], -- array of skill IDs required
    required_certifications UUID[], -- array of certification IDs required
    work_location_lat DECIMAL(10, 8),
    work_location_lng DECIMAL(11, 8),
    work_location_address TEXT,
    equipment_required TEXT[],
    safety_requirements TEXT[],
    special_instructions TEXT,
    completion_notes TEXT,
    performance_rating INTEGER CHECK (performance_rating >= 1 AND performance_rating <= 5),
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Assignment status history
CREATE TABLE IF NOT EXISTS oms_crew_assignment_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    assignment_id UUID NOT NULL REFERENCES oms_crew_assignments_enhanced(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL,
    changed_by UUID REFERENCES oms_crew_members(id),
    changed_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    notes TEXT,
    location_lat DECIMAL(10, 8),
    location_lng DECIMAL(11, 8)
);

-- =========================================================
-- 5. CREW PERFORMANCE & TRACKING
-- =========================================================

-- Crew performance metrics
CREATE TABLE IF NOT EXISTS oms_crew_performance (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    performance_period_start DATE NOT NULL,
    performance_period_end DATE NOT NULL,
    total_assignments INTEGER DEFAULT 0,
    completed_assignments INTEGER DEFAULT 0,
    on_time_completions INTEGER DEFAULT 0,
    average_completion_time_hours DECIMAL(4,2),
    safety_incidents INTEGER DEFAULT 0,
    customer_satisfaction_score DECIMAL(3,2),
    supervisor_rating DECIMAL(3,2),
    training_hours_completed DECIMAL(4,2) DEFAULT 0,
    certifications_earned INTEGER DEFAULT 0,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(crew_member_id, performance_period_start, performance_period_end)
);

-- Crew work history
CREATE TABLE IF NOT EXISTS oms_crew_work_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    crew_member_id UUID NOT NULL REFERENCES oms_crew_members(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES oms_crew_assignments_enhanced(id),
    work_date DATE NOT NULL,
    work_type VARCHAR(64) NOT NULL, -- outage_repair, maintenance, emergency, training
    hours_worked DECIMAL(4,2) NOT NULL,
    location VARCHAR(200),
    description TEXT,
    skills_used UUID[], -- array of skill IDs used
    equipment_used TEXT[],
    safety_notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 6. EQUIPMENT & RESOURCES
-- =========================================================

-- Equipment catalog
CREATE TABLE IF NOT EXISTS oms_crew_equipment (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    equipment_id VARCHAR(64) UNIQUE NOT NULL,
    equipment_name VARCHAR(200) NOT NULL,
    equipment_type VARCHAR(64) NOT NULL, -- vehicle, tool, safety_gear, communication
    category VARCHAR(64) NOT NULL, -- electrical, mechanical, safety, communication
    status VARCHAR(32) DEFAULT 'available', -- available, in_use, maintenance, retired
    location VARCHAR(200),
    assigned_to UUID REFERENCES oms_crew_members(id),
    last_maintenance_date DATE,
    next_maintenance_date DATE,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- Equipment assignments
CREATE TABLE IF NOT EXISTS oms_crew_equipment_assignments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    equipment_id UUID NOT NULL REFERENCES oms_crew_equipment(id) ON DELETE CASCADE,
    crew_member_id UUID REFERENCES oms_crew_members(id),
    assignment_id UUID REFERENCES oms_crew_assignments_enhanced(id),
    assigned_date DATE NOT NULL,
    return_date DATE,
    status VARCHAR(32) DEFAULT 'assigned', -- assigned, in_use, returned, lost, damaged
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);

-- =========================================================
-- 7. PERFORMANCE INDEXES
-- =========================================================

-- Crew members indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_members_employee_id ON oms_crew_members(employee_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_members_status ON oms_crew_members(status);
CREATE INDEX IF NOT EXISTS idx_oms_crew_members_crew_type ON oms_crew_members(crew_type);
CREATE INDEX IF NOT EXISTS idx_oms_crew_members_location ON oms_crew_members(location_lat, location_lng);

-- Crew teams indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_teams_team_id ON oms_crew_teams(team_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_teams_leader ON oms_crew_teams(team_leader_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_teams_type ON oms_crew_teams(team_type);
CREATE INDEX IF NOT EXISTS idx_oms_crew_teams_status ON oms_crew_teams(status);

-- Team membership indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_team_members_team ON oms_crew_team_members(team_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_team_members_member ON oms_crew_team_members(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_team_members_primary ON oms_crew_team_members(is_primary_team);

-- Skills indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_skills_code ON oms_crew_skills(skill_code);
CREATE INDEX IF NOT EXISTS idx_oms_crew_skills_category ON oms_crew_skills(skill_category);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_skills_member ON oms_crew_member_skills(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_skills_skill ON oms_crew_member_skills(skill_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_skills_level ON oms_crew_member_skills(skill_level);

-- Certifications indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_certifications_code ON oms_crew_certifications(cert_code);
CREATE INDEX IF NOT EXISTS idx_oms_crew_certifications_type ON oms_crew_certifications(cert_type);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_certifications_member ON oms_crew_member_certifications(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_certifications_cert ON oms_crew_member_certifications(certification_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_certifications_status ON oms_crew_member_certifications(status);
CREATE INDEX IF NOT EXISTS idx_oms_crew_member_certifications_expiry ON oms_crew_member_certifications(expiry_date);

-- Availability indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_availability_member ON oms_crew_availability(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_availability_date ON oms_crew_availability(availability_date);
CREATE INDEX IF NOT EXISTS idx_oms_crew_availability_status ON oms_crew_availability(status);
CREATE INDEX IF NOT EXISTS idx_oms_crew_schedules_member ON oms_crew_schedules(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_schedules_date ON oms_crew_schedules(schedule_date);
CREATE INDEX IF NOT EXISTS idx_oms_crew_schedules_status ON oms_crew_schedules(status);

-- Enhanced assignments indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_enhanced_outage ON oms_crew_assignments_enhanced(outage_event_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_enhanced_member ON oms_crew_assignments_enhanced(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_enhanced_team ON oms_crew_assignments_enhanced(team_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_enhanced_status ON oms_crew_assignments_enhanced(status);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_enhanced_assigned ON oms_crew_assignments_enhanced(assigned_at);
CREATE INDEX IF NOT EXISTS idx_oms_crew_assignments_enhanced_priority ON oms_crew_assignments_enhanced(priority);

-- Performance indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_performance_member ON oms_crew_performance(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_performance_period ON oms_crew_performance(performance_period_start, performance_period_end);
CREATE INDEX IF NOT EXISTS idx_oms_crew_work_history_member ON oms_crew_work_history(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_work_history_date ON oms_crew_work_history(work_date);
CREATE INDEX IF NOT EXISTS idx_oms_crew_work_history_type ON oms_crew_work_history(work_type);

-- Equipment indexes
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_equipment_id ON oms_crew_equipment(equipment_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_type ON oms_crew_equipment(equipment_type);
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_status ON oms_crew_equipment(status);
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_assigned ON oms_crew_equipment(assigned_to);
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_assignments_equipment ON oms_crew_equipment_assignments(equipment_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_assignments_member ON oms_crew_equipment_assignments(crew_member_id);
CREATE INDEX IF NOT EXISTS idx_oms_crew_equipment_assignments_date ON oms_crew_equipment_assignments(assigned_date);

-- =========================================================
-- 8. TRIGGERS FOR AUTOMATIC UPDATES
-- =========================================================

-- Updated_at trigger function (reuse existing)
-- Apply triggers to new tables
DROP TRIGGER IF EXISTS oms_crew_members_updated_at ON oms_crew_members;
CREATE TRIGGER oms_crew_members_updated_at
    BEFORE UPDATE ON oms_crew_members
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_teams_updated_at ON oms_crew_teams;
CREATE TRIGGER oms_crew_teams_updated_at
    BEFORE UPDATE ON oms_crew_teams
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_skills_updated_at ON oms_crew_skills;
CREATE TRIGGER oms_crew_skills_updated_at
    BEFORE UPDATE ON oms_crew_skills
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_certifications_updated_at ON oms_crew_certifications;
CREATE TRIGGER oms_crew_certifications_updated_at
    BEFORE UPDATE ON oms_crew_certifications
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_member_skills_updated_at ON oms_crew_member_skills;
CREATE TRIGGER oms_crew_member_skills_updated_at
    BEFORE UPDATE ON oms_crew_member_skills
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_member_certifications_updated_at ON oms_crew_member_certifications;
CREATE TRIGGER oms_crew_member_certifications_updated_at
    BEFORE UPDATE ON oms_crew_member_certifications
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_availability_updated_at ON oms_crew_availability;
CREATE TRIGGER oms_crew_availability_updated_at
    BEFORE UPDATE ON oms_crew_availability
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_schedules_updated_at ON oms_crew_schedules;
CREATE TRIGGER oms_crew_schedules_updated_at
    BEFORE UPDATE ON oms_crew_schedules
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_assignments_enhanced_updated_at ON oms_crew_assignments_enhanced;
CREATE TRIGGER oms_crew_assignments_enhanced_updated_at
    BEFORE UPDATE ON oms_crew_assignments_enhanced
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_performance_updated_at ON oms_crew_performance;
CREATE TRIGGER oms_crew_performance_updated_at
    BEFORE UPDATE ON oms_crew_performance
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

DROP TRIGGER IF EXISTS oms_crew_equipment_updated_at ON oms_crew_equipment;
CREATE TRIGGER oms_crew_equipment_updated_at
    BEFORE UPDATE ON oms_crew_equipment
    FOR EACH ROW EXECUTE FUNCTION oms_update_updated_at();

-- =========================================================
-- 9. CREW MANAGEMENT FUNCTIONS
-- =========================================================

-- Function to find available crew members for assignment
CREATE OR REPLACE FUNCTION oms_find_available_crew(
    p_required_skills UUID[],
    p_required_certifications UUID[],
    p_location_lat DECIMAL(10,8),
    p_location_lng DECIMAL(11,8),
    p_max_distance_km INTEGER DEFAULT 50,
    p_assignment_date DATE DEFAULT CURRENT_DATE,
    p_crew_type VARCHAR(32) DEFAULT NULL
)
RETURNS TABLE (
    crew_member_id UUID,
    employee_id VARCHAR(64),
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    crew_type VARCHAR(32),
    distance_km DECIMAL(8,2),
    skills_match_count INTEGER,
    certifications_match_count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        cm.id,
        cm.employee_id,
        cm.first_name,
        cm.last_name,
        cm.crew_type,
        ROUND(haversine_distance_meters(p_location_lat, p_location_lng, cm.location_lat, cm.location_lng) / 1000, 2) as distance_km,
        COUNT(CASE WHEN cms.skill_id = ANY(p_required_skills) THEN 1 END) as skills_match_count,
        COUNT(CASE WHEN cmc.certification_id = ANY(p_required_certifications) THEN 1 END) as certifications_match_count
    FROM oms_crew_members cm
    LEFT JOIN oms_crew_member_skills cms ON cm.id = cms.crew_member_id
    LEFT JOIN oms_crew_member_certifications cmc ON cm.id = cmc.crew_member_id 
        AND cmc.status = 'valid' 
        AND (cmc.expiry_date IS NULL OR cmc.expiry_date > CURRENT_DATE)
    LEFT JOIN oms_crew_availability ca ON cm.id = ca.crew_member_id 
        AND ca.availability_date = p_assignment_date
    WHERE cm.status = 'active'
    AND (p_crew_type IS NULL OR cm.crew_type = p_crew_type)
    AND (ca.status = 'available' OR ca.status IS NULL)
    AND (cm.location_lat IS NOT NULL AND cm.location_lng IS NOT NULL)
    AND haversine_distance_meters(p_location_lat, p_location_lng, cm.location_lat, cm.location_lng) <= (p_max_distance_km * 1000)
    GROUP BY cm.id, cm.employee_id, cm.first_name, cm.last_name, cm.crew_type, cm.location_lat, cm.location_lng
    HAVING 
        (p_required_skills IS NULL OR array_length(p_required_skills, 1) IS NULL OR 
         COUNT(CASE WHEN cms.skill_id = ANY(p_required_skills) THEN 1 END) = array_length(p_required_skills, 1))
    AND (p_required_certifications IS NULL OR array_length(p_required_certifications, 1) IS NULL OR
         COUNT(CASE WHEN cmc.certification_id = ANY(p_required_certifications) THEN 1 END) = array_length(p_required_certifications, 1))
    ORDER BY distance_km ASC, skills_match_count DESC, certifications_match_count DESC;
END;
$$ LANGUAGE plpgsql;

-- Function to calculate crew performance score
CREATE OR REPLACE FUNCTION oms_calculate_crew_performance_score(
    p_crew_member_id UUID,
    p_period_start DATE,
    p_period_end DATE
)
RETURNS DECIMAL(5,2) AS $$
DECLARE
    v_score DECIMAL(5,2) := 0.0;
    v_total_assignments INTEGER;
    v_completed_assignments INTEGER;
    v_on_time_completions INTEGER;
    v_safety_incidents INTEGER;
    v_customer_satisfaction DECIMAL(3,2);
    v_supervisor_rating DECIMAL(3,2);
BEGIN
    -- Check if parameters are valid
    IF p_crew_member_id IS NULL OR p_period_start IS NULL OR p_period_end IS NULL THEN
        RETURN NULL;
    END IF;
    
    -- Get performance metrics
    SELECT 
        COALESCE(total_assignments, 0),
        COALESCE(completed_assignments, 0),
        COALESCE(on_time_completions, 0),
        COALESCE(safety_incidents, 0),
        COALESCE(customer_satisfaction_score, 0.0),
        COALESCE(supervisor_rating, 0.0)
    INTO v_total_assignments, v_completed_assignments, v_on_time_completions, 
         v_safety_incidents, v_customer_satisfaction, v_supervisor_rating
    FROM oms_crew_performance
    WHERE crew_member_id = p_crew_member_id
    AND performance_period_start = p_period_start
    AND performance_period_end = p_period_end;
    
    -- If no performance record found, return NULL
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;
    
    -- Calculate score (0-100)
    IF v_total_assignments > 0 THEN
        -- Completion rate (40% weight)
        v_score := v_score + (v_completed_assignments::DECIMAL / v_total_assignments) * 40;
        
        -- On-time completion rate (30% weight)
        v_score := v_score + (v_on_time_completions::DECIMAL / GREATEST(v_completed_assignments, 1)) * 30;
        
        -- Safety score (20% weight) - inverse of incidents
        v_score := v_score + GREATEST(0, 20 - (v_safety_incidents * 5));
        
        -- Customer satisfaction (5% weight)
        v_score := v_score + (v_customer_satisfaction * 5);
        
        -- Supervisor rating (5% weight)
        v_score := v_score + (v_supervisor_rating * 5);
    END IF;
    
    RETURN LEAST(100.0, GREATEST(0.0, v_score));
END;
$$ LANGUAGE plpgsql;

-- =========================================================
-- 10. VIEWS FOR CREW MANAGEMENT DASHBOARD
-- =========================================================

-- Available crew view
CREATE OR REPLACE VIEW oms_available_crew AS
SELECT 
    cm.id,
    cm.employee_id,
    cm.first_name,
    cm.last_name,
    cm.crew_type,
    cm.experience_years,
    cm.location_lat,
    cm.location_lng,
    ca.status as availability_status,
    ca.shift_start,
    ca.shift_end,
    COUNT(DISTINCT cms.skill_id) as skills_count,
    COUNT(DISTINCT cmc.certification_id) as certifications_count
FROM oms_crew_members cm
LEFT JOIN oms_crew_availability ca ON cm.id = ca.crew_member_id 
    AND ca.availability_date = CURRENT_DATE
LEFT JOIN oms_crew_member_skills cms ON cm.id = cms.crew_member_id
LEFT JOIN oms_crew_member_certifications cmc ON cm.id = cmc.crew_member_id 
    AND cmc.status = 'valid'
WHERE cm.status = 'active'
GROUP BY cm.id, cm.employee_id, cm.first_name, cm.last_name, cm.crew_type, 
         cm.experience_years, cm.location_lat, cm.location_lng, 
         ca.status, ca.shift_start, ca.shift_end;

-- Active assignments view
CREATE OR REPLACE VIEW oms_active_crew_assignments AS
SELECT 
    cae.id,
    cae.outage_event_id,
    oe.event_id,
    oe.status as outage_status,
    cae.crew_member_id,
    cm.employee_id,
    cm.first_name,
    cm.last_name,
    cae.team_id,
    ct.team_name,
    cae.assignment_type,
    cae.priority,
    cae.status as assignment_status,
    cae.assigned_at,
    cae.estimated_arrival,
    cae.actual_arrival,
    cae.work_location_lat,
    cae.work_location_lng,
    cae.work_location_address
FROM oms_crew_assignments_enhanced cae
JOIN oms_outage_events oe ON cae.outage_event_id = oe.id
JOIN oms_crew_members cm ON cae.crew_member_id = cm.id
LEFT JOIN oms_crew_teams ct ON cae.team_id = ct.id
WHERE cae.status IN ('assigned', 'accepted', 'en_route', 'on_site', 'in_progress');

-- Crew performance summary view
CREATE OR REPLACE VIEW oms_crew_performance_summary AS
SELECT 
    cm.id,
    cm.employee_id,
    cm.first_name,
    cm.last_name,
    cm.crew_type,
    cp.performance_period_start,
    cp.performance_period_end,
    cp.total_assignments,
    cp.completed_assignments,
    cp.on_time_completions,
    cp.average_completion_time_hours,
    cp.safety_incidents,
    cp.customer_satisfaction_score,
    cp.supervisor_rating,
    CASE 
        WHEN cp.performance_period_start IS NOT NULL AND cp.performance_period_end IS NOT NULL 
        THEN oms_calculate_crew_performance_score(cm.id, cp.performance_period_start, cp.performance_period_end)
        ELSE NULL 
    END as performance_score
FROM oms_crew_members cm
LEFT JOIN oms_crew_performance cp ON cm.id = cp.crew_member_id
WHERE cm.status = 'active'
AND (cp.performance_period_end IS NULL OR cp.performance_period_end >= CURRENT_DATE - INTERVAL '1 year');

-- =========================================================
-- 11. INITIAL DATA SETUP
-- =========================================================

-- Insert default skills
INSERT INTO oms_crew_skills (skill_code, skill_name, skill_category, description) VALUES
('ELEC_BASIC', 'Basic Electrical Work', 'electrical', 'Basic electrical installation and repair'),
('ELEC_ADVANCED', 'Advanced Electrical Work', 'electrical', 'High voltage electrical work and complex repairs'),
('MECH_BASIC', 'Basic Mechanical Work', 'mechanical', 'Basic mechanical equipment maintenance'),
('MECH_ADVANCED', 'Advanced Mechanical Work', 'mechanical', 'Complex mechanical system repairs'),
('SAFETY_OSHA', 'OSHA Safety Standards', 'safety', 'OSHA safety compliance and procedures'),
('SAFETY_CONFINED', 'Confined Space Safety', 'safety', 'Confined space entry and safety procedures'),
('COMM_RADIO', 'Radio Communication', 'communication', 'Two-way radio operation and protocols'),
('COMM_CUSTOMER', 'Customer Communication', 'communication', 'Customer service and communication skills'),
('TOOL_POWER', 'Power Tool Operation', 'mechanical', 'Safe operation of power tools'),
('TOOL_SPECIALIZED', 'Specialized Equipment', 'mechanical', 'Operation of specialized electrical equipment')
ON CONFLICT (skill_code) DO NOTHING;

-- Insert default certifications
INSERT INTO oms_crew_certifications (cert_code, cert_name, cert_type, issuing_authority, validity_months, description) VALUES
('OSHA_10', 'OSHA 10-Hour Construction Safety', 'safety', 'OSHA', 60, 'Basic construction safety certification'),
('OSHA_30', 'OSHA 30-Hour Construction Safety', 'safety', 'OSHA', 60, 'Advanced construction safety certification'),
('CPR', 'CPR/First Aid Certification', 'safety', 'American Red Cross', 24, 'Cardiopulmonary resuscitation and first aid'),
('CONFINED_SPACE', 'Confined Space Entry', 'safety', 'OSHA', 36, 'Confined space entry and rescue certification'),
('ELECTRICAL_LICENSE', 'Electrical License', 'technical', 'State Licensing Board', 24, 'State electrical contractor license'),
('CDL', 'Commercial Driver License', 'regulatory', 'DMV', 60, 'Commercial driver license for utility vehicles'),
('RADIO_OPERATOR', 'Radio Operator License', 'regulatory', 'FCC', 60, 'FCC radio operator license'),
('HIGH_VOLTAGE', 'High Voltage Certification', 'technical', 'Utility Training Center', 36, 'High voltage electrical work certification')
ON CONFLICT (cert_code) DO NOTHING;

-- =========================================================
-- 12. COMMENTS AND DOCUMENTATION
-- =========================================================

COMMENT ON TABLE oms_crew_members IS 'Master table for all crew members with personal and professional information';
COMMENT ON TABLE oms_crew_teams IS 'Crew teams and groups for organizing work assignments';
COMMENT ON TABLE oms_crew_skills IS 'Catalog of skills available for crew members';
COMMENT ON TABLE oms_crew_certifications IS 'Catalog of certifications and licenses';
COMMENT ON TABLE oms_crew_member_skills IS 'Skills possessed by individual crew members';
COMMENT ON TABLE oms_crew_member_certifications IS 'Certifications held by individual crew members';
COMMENT ON TABLE oms_crew_availability IS 'Daily availability calendar for crew members';
COMMENT ON TABLE oms_crew_schedules IS 'Scheduled work shifts for crew members';
COMMENT ON TABLE oms_crew_assignments_enhanced IS 'Enhanced crew assignments with detailed tracking and requirements';
COMMENT ON TABLE oms_crew_performance IS 'Performance metrics and ratings for crew members';
COMMENT ON TABLE oms_crew_work_history IS 'Historical record of work performed by crew members';
COMMENT ON TABLE oms_crew_equipment IS 'Equipment and tools available for crew assignments';
COMMENT ON TABLE oms_crew_equipment_assignments IS 'Equipment assignments to crew members and jobs';

COMMENT ON COLUMN oms_crew_members.crew_type IS 'Type of crew member: lineman, supervisor, technician, engineer, dispatcher';
COMMENT ON COLUMN oms_crew_member_skills.proficiency_score IS 'Proficiency score from 0.0 to 1.0 for this skill';
COMMENT ON COLUMN oms_crew_member_certifications.status IS 'Certification status: valid, expired, suspended, revoked';
COMMENT ON COLUMN oms_crew_assignments_enhanced.required_skills IS 'Array of skill IDs required for this assignment';
COMMENT ON COLUMN oms_crew_assignments_enhanced.required_certifications IS 'Array of certification IDs required for this assignment';
-- Performance score is calculated dynamically using the oms_calculate_crew_performance_score() function

-- =========================================================
-- END OF CREW MANAGEMENT SCHEMA
-- =========================================================
