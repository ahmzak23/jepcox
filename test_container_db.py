#!/usr/bin/env python3

import psycopg2
import os
from psycopg2.extras import RealDictCursor

DATABASE_URL = os.getenv('DATABASE_URL')
print('DATABASE_URL:', DATABASE_URL)

try:
    # Connect to database using DATABASE_URL
    conn = psycopg2.connect(DATABASE_URL, cursor_factory=RealDictCursor)
    conn.autocommit = True
    cursor = conn.cursor()

    # Test the crew count query
    cursor.execute("SELECT COUNT(*) as count FROM oms_crew_teams WHERE status = 'active'")
    result = cursor.fetchone()
    print('Crew count result:', result)

    # Test the full crew query
    cursor.execute("""
        SELECT 
            t.team_id,
            t.team_name,
            t.team_type,
            t.location_lat,
            t.location_lng,
            cm.first_name || ' ' || cm.last_name as team_leader_name,
            cm.phone as team_leader_phone,
            COUNT(tm.crew_member_id) as member_count,
            COALESCE(ca.status, 'available') as current_status,
            o.event_id as assigned_outage_id,
            ca.assigned_at,
            ca.estimated_arrival as estimated_completion
        FROM oms_crew_teams t
        LEFT JOIN oms_crew_members cm ON t.team_leader_id = cm.id
        LEFT JOIN oms_crew_team_members tm ON t.id = tm.team_id AND tm.is_primary_team = true
        LEFT JOIN oms_crew_assignments ca ON t.team_id = ca.crew_id AND ca.status IN ('assigned', 'in_progress')
        LEFT JOIN oms_outage_events o ON ca.outage_event_id = o.id
        WHERE t.status = 'active' AND t.location_lat IS NOT NULL AND t.location_lng IS NOT NULL
        GROUP BY t.id, t.team_id, t.team_name, t.team_type, t.location_lat, t.location_lng,
                 t.team_leader_id, cm.first_name, cm.last_name, cm.phone,
                 ca.status, o.event_id, ca.assigned_at, 
                 ca.estimated_arrival
        ORDER BY t.team_name
    """)

    results = cursor.fetchall()
    print('Crew query results:', len(results), 'rows')
    for row in results:
        print('  ', dict(row))

except Exception as e:
    print('Error:', e)

finally:
    if 'conn' in locals():
        conn.close()
