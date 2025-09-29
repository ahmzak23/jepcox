#!/usr/bin/env python3

import psycopg2
import os
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.getenv('DATABASE_URL', 'postgresql://web:123456@host.docker.internal:5432/oms_db')
print('DATABASE_URL:', DATABASE_URL)

try:
    # Connect to database using DATABASE_URL
    conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
    conn.autocommit = True
    cursor = conn.cursor()

    # Test the exact query from the API
    query = """
        SELECT 
            t.id as team_id,
            t.team_id as team_code,
            t.team_name,
            t.team_type,
            t.location_lat,
            t.location_lng,
            t.team_leader_id,
            cm.first_name || ' ' || cm.last_name as team_leader_name,
            cm.phone as team_leader_phone,
            COUNT(tm.crew_member_id) as member_count,
            COALESCE(ca.status, 'available') as current_status,
            ca.id as assignment_id,
            o.event_id as assigned_outage_id,
            ca.assigned_at,
            ca.estimated_arrival as estimated_completion
        FROM oms_crew_teams t
        LEFT JOIN oms_crew_members cm ON t.team_leader_id = cm.id
        LEFT JOIN oms_crew_team_members tm ON t.id = tm.team_id AND tm.is_primary_team = true
        LEFT JOIN oms_crew_assignments ca ON t.team_id = ca.crew_id AND ca.status IN ('assigned', 'in_progress')
        LEFT JOIN oms_outage_events o ON ca.outage_event_id = o.id
        WHERE t.status = 'active'
        GROUP BY t.id, t.team_id, t.team_name, t.team_type, t.location_lat, t.location_lng,
                 t.team_leader_id, cm.first_name, cm.last_name, cm.phone,
                 ca.status, ca.id, o.event_id, ca.assigned_at, 
                 ca.estimated_arrival
        ORDER BY t.team_name
    """
    
    print('Executing query...')
    cursor.execute(query)
    crews = cursor.fetchall()
    
    print('Query executed successfully!')
    print('Crews count:', len(crews))
    
    # Test the team members query
    for crew in crews:
        print(f'Testing team members query for crew {crew["team_id"]}...')
        cursor.execute("""
            SELECT 
                cm.id,
                cm.employee_id,
                cm.first_name,
                cm.last_name,
                cm.phone,
                cm.crew_type,
                cm.experience_years,
                tm.role
            FROM oms_crew_team_members tm
            JOIN oms_crew_members cm ON tm.crew_member_id = cm.id
            WHERE tm.team_id = %s AND tm.is_primary_team = true
            ORDER BY tm.role, cm.first_name
        """, [crew['team_id']])  # crew['team_id'] contains the UUID id from t.id as team_id
        members = cursor.fetchall()
        print(f'  Members count: {len(members)}')

except Exception as e:
    print('Error:', e)
    import traceback
    traceback.print_exc()

finally:
    if 'conn' in locals():
        conn.close()
