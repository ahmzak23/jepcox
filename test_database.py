#!/usr/bin/env python3
"""
Test script to verify database connection and schema
"""

import psycopg2
import json
from datetime import datetime

def test_database_connection():
    """Test database connection and basic operations."""
    
    try:
        from database_config import get_database_config
        db_config = get_database_config().get_connection_config()
    except ImportError:
        print("❌ database_config.py not found. Please run setup_database.py first.")
        return False
    
    try:
        # Test connection
        print("Testing database connection...")
        conn = psycopg2.connect(**db_config)
        cursor = conn.cursor()
        
        # Test basic query
        cursor.execute("SELECT version();")
        version = cursor.fetchone()[0]
        print(f"✅ Connected to PostgreSQL: {version}")
        
        # Test if tables exist
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        """)
        tables = cursor.fetchall()
        print(f"✅ Found {len(tables)} tables:")
        for table in tables:
            print(f"  - {table[0]}")
        
        # Test insert function
        test_data = {
            "message_type": "TestEvent",
            "timestamp": datetime.now().isoformat(),
            "header": {
                "verb": "Create",
                "noun": "TestEvents",
                "revision": "1.0",
                "timestamp": datetime.now().isoformat() + "Z",
                "source": "Test-Source",
                "async_reply_flag": "false",
                "ack_required": "false",
                "message_id": "test_msg_001",
                "correlation_id": "test_corr_001",
                "comment": "Test event for database validation"
            },
            "payload": {
                "event_id": "test_event_001",
                "created_date_time": datetime.now().isoformat() + "Z",
                "issuer_id": "Test-Issuer",
                "reason": "Test Event",
                "severity": "Low"
            }
        }
        
        print("Testing JSON insertion function...")
        cursor.execute("SELECT insert_hes_event_from_json(%s::jsonb)", (json.dumps(test_data),))
        event_id = cursor.fetchone()[0]
        print(f"✅ Successfully inserted test event: {event_id}")
        
        # Clean up test data
        cursor.execute("DELETE FROM hes_events WHERE id = %s", (event_id,))
        conn.commit()
        print("✅ Cleaned up test data")
        
        cursor.close()
        conn.close()
        print("✅ Database test completed successfully!")
        
    except Exception as e:
        print(f"❌ Database test failed: {e}")
        return False
    
    return True

if __name__ == "__main__":
    test_database_connection()
