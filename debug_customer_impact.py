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

    # Test the exact query from the customer impact endpoint
    print("Testing customer impact query...")
    
    days = 30
    granularity = "day"
    
    time_grouping = {
        'hour': "DATE_TRUNC('hour', first_detected_at)",
        'day': "DATE_TRUNC('day', first_detected_at)",
        'week': "DATE_TRUNC('week', first_detected_at)"
    }
    
    # Get customer impact trends
    query = f"""
        SELECT 
            {time_grouping[granularity]} as period,
            COUNT(*) as outage_count,
            SUM(affected_customers_count) as total_customers_affected,
            AVG(affected_customers_count) as avg_customers_per_outage,
            MAX(affected_customers_count) as max_customers_single_outage,
            COUNT(CASE WHEN affected_customers_count > 100 THEN 1 END) as major_outages,
            COUNT(CASE WHEN affected_customers_count > 1000 THEN 1 END) as critical_outages,
            AVG(EXTRACT(EPOCH FROM (actual_restoration_time - first_detected_at))/3600) as avg_restoration_time_hours
        FROM oms_outage_events
        WHERE first_detected_at >= NOW() - INTERVAL '{days} days'
          AND affected_customers_count > 0
        GROUP BY {time_grouping[granularity]}
        ORDER BY period ASC
    """
    
    print("Executing query...")
    cursor.execute(query)
    results = cursor.fetchall()
    
    print(f"Query executed successfully! Found {len(results)} rows")
    if results:
        print("First result:", dict(results[0]))
    else:
        print("No results found")
    
    # Test the summary query
    print("\nTesting summary query...")
    summary_query = f"""
        SELECT 
            SUM(affected_customers_count) as total_customers_affected,
            AVG(affected_customers_count) as avg_customers_per_outage,
            MAX(affected_customers_count) as max_customers_single_outage,
            COUNT(CASE WHEN affected_customers_count > 100 THEN 1 END) as major_outages,
            COUNT(CASE WHEN affected_customers_count > 1000 THEN 1 END) as critical_outages,
            AVG(EXTRACT(EPOCH FROM (actual_restoration_time - first_detected_at))/3600) as avg_restoration_time_hours,
            COUNT(DISTINCT CASE WHEN affected_customers_count > 0 THEN id END) as outages_with_customers
        FROM oms_outage_events
        WHERE first_detected_at >= NOW() - INTERVAL '{days} days'
    """
    
    cursor.execute(summary_query)
    summary = cursor.fetchone()
    print("Summary result:", dict(summary))

except Exception as e:
    print('Error:', e)
    import traceback
    traceback.print_exc()

finally:
    if 'conn' in locals():
        conn.close()
