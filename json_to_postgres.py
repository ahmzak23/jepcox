#!/usr/bin/env python3
"""
JSON to PostgreSQL Data Insertion Script
Reads JSON files from hes_kaifa_events_log directory and inserts them into PostgreSQL database
"""

import json
import os
import psycopg2
from psycopg2.extras import RealDictCursor
import glob
from datetime import datetime
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class JSONToPostgresLoader:
    def __init__(self, db_config):
        """
        Initialize the JSON to PostgreSQL loader
        
        Args:
            db_config: Dictionary with database connection parameters
        """
        self.db_config = db_config
        self.connection = None
        
    def connect(self):
        """Establish database connection"""
        try:
            self.connection = psycopg2.connect(**self.db_config)
            logger.info("Connected to PostgreSQL database")
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise
    
    def disconnect(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            logger.info("Disconnected from database")
    
    def load_json_file(self, json_file_path):
        """
        Load a single JSON file and insert into database
        
        Args:
            json_file_path: Path to the JSON file
        """
        try:
            with open(json_file_path, 'r', encoding='utf-8') as file:
                json_data = json.load(file)
            
            # Insert using the PostgreSQL function
            cursor = self.connection.cursor()
            
            # Convert Python dict to JSON string for PostgreSQL
            json_string = json.dumps(json_data)
            
            # Call the PostgreSQL function
            cursor.execute("SELECT insert_hes_event_from_json(%s::jsonb)", (json_string,))
            
            event_id = cursor.fetchone()[0]
            self.connection.commit()
            
            logger.info(f"Successfully inserted event {event_id} from {json_file_path}")
            return event_id
            
        except Exception as e:
            logger.error(f"Failed to load {json_file_path}: {e}")
            self.connection.rollback()
            return None
        finally:
            if 'cursor' in locals():
                cursor.close()
    
    def load_all_json_files(self, directory_path):
        """
        Load all JSON files from a directory
        
        Args:
            directory_path: Path to directory containing JSON files
        """
        json_files = glob.glob(os.path.join(directory_path, "*.json"))
        
        if not json_files:
            logger.warning(f"No JSON files found in {directory_path}")
            return
        
        logger.info(f"Found {len(json_files)} JSON files to process")
        
        successful_inserts = 0
        failed_inserts = 0
        
        for json_file in json_files:
            logger.info(f"Processing {json_file}")
            event_id = self.load_json_file(json_file)
            
            if event_id:
                successful_inserts += 1
            else:
                failed_inserts += 1
        
        logger.info(f"Processing complete: {successful_inserts} successful, {failed_inserts} failed")
    
    def get_event_statistics(self):
        """Get statistics about loaded events"""
        try:
            cursor = self.connection.cursor(cursor_factory=RealDictCursor)
            
            # Get total events count
            cursor.execute("SELECT COUNT(*) as total_events FROM hes_events")
            total_events = cursor.fetchone()['total_events']
            
            # Get events by message type
            cursor.execute("""
                SELECT message_type, COUNT(*) as count 
                FROM hes_events 
                GROUP BY message_type 
                ORDER BY count DESC
            """)
            events_by_type = cursor.fetchall()
            
            # Get events by severity
            cursor.execute("""
                SELECT p.severity, COUNT(*) as count 
                FROM hes_events e
                JOIN event_payloads p ON e.id = p.event_id
                GROUP BY p.severity 
                ORDER BY count DESC
            """)
            events_by_severity = cursor.fetchall()
            
            # Get recent events
            cursor.execute("""
                SELECT e.timestamp, h.message_id, p.reason, p.severity
                FROM hes_events e
                LEFT JOIN event_headers h ON e.id = h.event_id
                LEFT JOIN event_payloads p ON e.id = p.event_id
                ORDER BY e.timestamp DESC
                LIMIT 10
            """)
            recent_events = cursor.fetchall()
            
            stats = {
                'total_events': total_events,
                'events_by_type': events_by_type,
                'events_by_severity': events_by_severity,
                'recent_events': recent_events
            }
            
            return stats
            
        except Exception as e:
            logger.error(f"Failed to get statistics: {e}")
            return None
        finally:
            if 'cursor' in locals():
                cursor.close()

def main():
    """Main function to run the JSON to PostgreSQL loader"""
    
    # Database configuration
    db_config = {
        'host': 'localhost',
        'database': 'hes_kaifa_events',
        'user': 'hes_app_user',
        'password': 'secure_password',
        'port': 5432
    }
    
    # JSON files directory
    json_directory = 'Kaifa-HES-Events/hes_kaifa_events_log'
    
    # Initialize loader
    loader = JSONToPostgresLoader(db_config)
    
    try:
        # Connect to database
        loader.connect()
        
        # Load all JSON files
        loader.load_all_json_files(json_directory)
        
        # Get and display statistics
        stats = loader.get_event_statistics()
        if stats:
            print("\n=== Database Statistics ===")
            print(f"Total Events: {stats['total_events']}")
            
            print("\nEvents by Type:")
            for event_type in stats['events_by_type']:
                print(f"  {event_type['message_type']}: {event_type['count']}")
            
            print("\nEvents by Severity:")
            for severity in stats['events_by_severity']:
                print(f"  {severity['severity']}: {severity['count']}")
            
            print("\nRecent Events:")
            for event in stats['recent_events']:
                print(f"  {event['timestamp']} - {event['message_id']} - {event['reason']} ({event['severity']})")
        
    except Exception as e:
        logger.error(f"Error in main execution: {e}")
    finally:
        loader.disconnect()

if __name__ == "__main__":
    main()
