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

    # Test the exact logic from map data endpoint
    print("Testing crew count query...")
    cursor.execute("SELECT COUNT(*) as count FROM oms_crew_teams WHERE status = 'active'")
    result = cursor.fetchone()
    print('Crew count result:', result)
    crew_count = result['count']
    print('Crew count:', crew_count)
    
    if crew_count > 0:
        print("Crew count > 0, executing main query...")
        # Return real data from database using new crew management schema
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
        print('Query results:', len(results), 'rows')
        
        crews = []
        for row in results:
            crews.append({
                "id": f"crew_{row['team_id']}",
                "team_id": row['team_id'],
                "name": row['team_name'] or "Unknown Crew",
                "type": row['team_type'] or "line_crew",
                "latitude": float(row['location_lat']) if row['location_lat'] else 31.9539,
                "longitude": float(row['location_lng']) if row['location_lng'] else 35.9106,
                "status": row['current_status'] or "available",
                "team_leader": row['team_leader_name'] or "Unknown",
                "team_leader_phone": row['team_leader_phone'],
                "member_count": row['member_count'] or 0,
                "assigned_outage": row['assigned_outage_id'],
                "assigned_at": row['assigned_at'].isoformat() if row['assigned_at'] else None,
                "estimated_completion": row['estimated_completion'].isoformat() if row['estimated_completion'] else None,
                "equipment": ["bucket_truck", "test_equipment", "safety_gear"]
            })
        
        print('Processed crews:', len(crews))
        if crews:
            print('First crew:', crews[0])
    else:
        print("Crew count is 0, returning empty array")

except Exception as e:
    print('Error:', e)
    import traceback
    traceback.print_exc()

finally:
    if 'conn' in locals():
        conn.close()
