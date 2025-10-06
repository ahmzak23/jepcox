#!/usr/bin/env python3
"""
Apply topology connections by running the link_meters_to_substations.sql script
"""

import psycopg2
import os
from psycopg2.extras import RealDictCursor

# Database configuration
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'oms_db',
    'user': 'oms_user',
    'password': 'oms_password'
}

def apply_topology_connections():
    """Apply the topology connections SQL script"""
    try:
        # Connect to database
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cursor = conn.cursor(cursor_factory=RealDictCursor)
        
        print("Connected to database successfully")
        
        # Read and execute the SQL script
        script_path = 'construction/link_meters_to_substations.sql'
        if os.path.exists(script_path):
            with open(script_path, 'r', encoding='utf-8') as f:
                sql_content = f.read()
            
            print("Executing topology connections script...")
            cursor.execute(sql_content)
            
            # Check results
            cursor.execute("""
                SELECT 
                    'Substations' as type, COUNT(*) as count
                FROM network_substations
                UNION ALL
                SELECT 
                    'Meters' as type, COUNT(*) as count
                FROM oms_meters
                UNION ALL
                SELECT 
                    'Substation-Meter Links' as type, COUNT(*) as count
                FROM network_substation_meters
            """)
            
            results = cursor.fetchall()
            print("\nTopology setup results:")
            for row in results:
                print(f"  {row['type']}: {row['count']}")
                
        else:
            print(f"Script file not found: {script_path}")
            
        cursor.close()
        conn.close()
        print("Topology connections applied successfully!")
        
    except Exception as e:
        print(f"Error applying topology connections: {e}")
        return False
    
    return True

if __name__ == "__main__":
    apply_topology_connections()
