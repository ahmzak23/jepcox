#!/usr/bin/env python3
"""
Example usage of HES-Kaifa Consumer with database enabled
This script shows how to run the consumer on a server with database storage
"""

from Kaifa_HES_Events.hes_kaifa_consumer import HESKaifaConsumer

def main():
    """Example of running the consumer with database enabled."""
    
    # Create consumer with database enabled
    consumer = HESKaifaConsumer(
        bootstrap_servers='localhost:9092',
        topic='hes-kaifa-outage-topic',
        output_dir='hes_kaifa_events_log',
        group_id='hes-kaifa-consumer-group',
        enable_database=True  # Enable database storage
    )
    
    # Update database configuration for your server
    consumer.db_config = {
        'host': 'your-db-host',
        'database': 'hes_kaifa_events',
        'user': 'hes_app_user',
        'password': 'your-secure-password',
        'port': 5432
    }
    
    try:
        print("Starting HES-Kaifa consumer with database storage enabled...")
        consumer.start_consuming()
    except KeyboardInterrupt:
        print("\nShutting down consumer...")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    main()
