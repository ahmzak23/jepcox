#!/usr/bin/env python3
"""
Create Database and Schema for HES-Kaifa Events
This script creates the database and sets up the schema.
"""

import psycopg2
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
import os
from pathlib import Path

def create_database():
    """Create the database if it doesn't exist."""
    try:
        # Connect to PostgreSQL server (not to a specific database)
        conn = psycopg2.connect(
            host='127.0.0.1',
            port=5432,
            user='web',
            password='123456',
            database='postgres'  # Connect to default postgres database
        )
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        # Check if database exists
        cursor.execute("SELECT 1 FROM pg_database WHERE datname = 'hes_kaifa_events'")
        exists = cursor.fetchone()
        
        if not exists:
            print("Creating database 'hes_kaifa_events'...")
            cursor.execute("CREATE DATABASE hes_kaifa_events")
            print("✅ Database 'hes_kaifa_events' created successfully!")
        else:
            print("✅ Database 'hes_kaifa_events' already exists!")
        
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Failed to create database: {e}")
        return False

def setup_schema():
    """Set up the database schema."""
    try:
        # Connect to the specific database
        conn = psycopg2.connect(
            host='127.0.0.1',
            port=5432,
            user='web',
            password='123456',
            database='hes_kaifa_events'
        )
        cursor = conn.cursor()
        
        # Read and execute schema file
        schema_file = Path("database_schema.sql")
        if not schema_file.exists():
            print("❌ database_schema.sql not found!")
            return False
        
        print("Setting up database schema...")
        with open(schema_file, 'r', encoding='utf-8') as f:
            schema_sql = f.read()
        
        # Execute schema SQL
        cursor.execute(schema_sql)
        conn.commit()
        
        print("✅ Database schema set up successfully!")
        
        # Verify tables were created
        cursor.execute("""
            SELECT table_name 
            FROM information_schema.tables 
            WHERE table_schema = 'public' 
            ORDER BY table_name;
        """)
        tables = cursor.fetchall()
        print(f"✅ Created {len(tables)} tables:")
        for table in tables:
            print(f"  - {table[0]}")
        
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Failed to set up schema: {e}")
        return False

def test_connection():
    """Test the database connection."""
    try:
        conn = psycopg2.connect(
            host='127.0.0.1',
            port=5432,
            user='web',
            password='123456',
            database='hes_kaifa_events'
        )
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
        
        cursor.close()
        conn.close()
        return True
        
    except Exception as e:
        print(f"❌ Database connection test failed: {e}")
        return False

def main():
    """Main setup function."""
    print("=== HES-Kaifa Events Database Setup ===")
    print()
    
    # Step 1: Create database
    print("1. Creating database...")
    if not create_database():
        print("❌ Setup failed at database creation")
        return False
    
    # Step 2: Set up schema
    print("\n2. Setting up database schema...")
    if not setup_schema():
        print("❌ Setup failed at schema setup")
        return False
    
    # Step 3: Test connection
    print("\n3. Testing database connection...")
    if not test_connection():
        print("❌ Setup failed at connection test")
        return False
    
    print("\n🎉 Database setup completed successfully!")
    print("\nYou can now run the consumer with database support:")
    print("  python Kaifa-HES-Events/run_consumer.py --enable-database")
    
    return True

if __name__ == "__main__":
    success = main()
    if not success:
        exit(1)
