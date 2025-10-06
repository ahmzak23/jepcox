import psycopg2
import psycopg2.extras

try:
    DATABASE_URL = "postgresql://web:123456@host.docker.internal:5432/oms_db"
    conn = psycopg2.connect(DATABASE_URL)
    cursor = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    
    print("Testing asset count...")
    cursor.execute("SELECT COUNT(*) FROM network_substations")
    asset_count = cursor.fetchone()[0]
    print(f"Asset count: {asset_count}")
    
    if asset_count > 0:
        print("\nFetching substations...")
        cursor.execute("""
            SELECT substation_id, name, voltage_level, status, location_lat, location_lng
            FROM network_substations 
            WHERE location_lat IS NOT NULL AND location_lng IS NOT NULL
            LIMIT 50
        """)
        
        substations = []
        for row in cursor.fetchall():
            sub = {
                "id": f"sub_{row['substation_id']}",
                "substation_id": row['substation_id'],
                "name": row['name'] or "Unknown Substation",
                "type": "substation",
                "latitude": float(row['location_lat']) if row['location_lat'] else 31.9539,
                "longitude": float(row['location_lng']) if row['location_lng'] else 35.9106,
                "voltage_level": row['voltage_level'] or "33kV",
                "status": row['status'] or "active",
                "load_percentage": 75
            }
            substations.append(sub)
            print(f"  - {sub['name']} at ({sub['latitude']}, {sub['longitude']})")
        
        print(f"\nTotal substations: {len(substations)}")
    else:
        print("No substations found!")
    
    cursor.close()
    conn.close()
    print("\nSUCCESS!")
    
except Exception as e:
    print(f"ERROR: {e}")
    import traceback
    traceback.print_exc()

