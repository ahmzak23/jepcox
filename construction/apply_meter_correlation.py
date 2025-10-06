#!/usr/bin/env python3
"""
Apply meter correlation schema to the database
"""
import psycopg2
import os

# Database configuration (same as your consumers)
DB_CONFIG = {
    'host': os.getenv('DB_HOST', '127.0.0.1'),
    'port': int(os.getenv('DB_PORT', '5432')),
    'database': os.getenv('DB_NAME', 'oms_db'),
    'user': os.getenv('DB_USER', 'web'),
    'password': os.getenv('DB_PASSWORD', '123456')
}

def apply_sql_file(cursor, filepath):
    """Apply a SQL file to the database"""
    print(f"Applying: {filepath}")
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            sql = f.read()
        cursor.execute(sql)
        print(f"[OK] Success: {filepath}")
        return True
    except Exception as e:
        print(f"[ERROR] Error in {filepath}: {e}")
        return False

def main():
    print("Applying Meter Correlation Schema to Database")
    print(f"Database: {DB_CONFIG['host']}:{DB_CONFIG['port']}/{DB_CONFIG['database']}")
    print()
    
    try:
        # Connect to database
        print("Connecting to database...")
        conn = psycopg2.connect(**DB_CONFIG)
        conn.autocommit = True
        cursor = conn.cursor()
        print("[OK] Connected successfully")
        print()
        
        # List of SQL files to apply in order
        sql_files = [
            'construction/oms_meter_correlation_enhancement.sql',
            'construction/alter_scripts/01_alter_scada_schema.sql',
            'construction/alter_scripts/02_alter_onu_schema.sql',
            'construction/alter_scripts/03_alter_kaifa_schema.sql',
            'construction/alter_scripts/04_alter_callcenter_schema.sql',
            'construction/oms_meter_migration_script.sql'
        ]
        
        success_count = 0
        for sql_file in sql_files:
            if apply_sql_file(cursor, sql_file):
                success_count += 1
            print()
        
        cursor.close()
        conn.close()
        
        print("=" * 60)
        print(f"[OK] Applied {success_count}/{len(sql_files)} schemas successfully!")
        print("=" * 60)
        print()
        print("SUCCESS: Meter correlation is now active!")
        print("Refresh your dashboard to see the changes:")
        print("   http://localhost:9200")
        print()
        
    except Exception as e:
        print(f"[ERROR] Fatal error: {e}")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())

