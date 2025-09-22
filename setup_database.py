#!/usr/bin/env python3
"""
Database Setup Script for HES-Kaifa Events
This script helps you set up the database configuration and test the connection.
"""

import os
import sys
import subprocess
from pathlib import Path

def create_database_config():
    """Create database_config.py from template if it doesn't exist."""
    config_file = Path("database_config.py")
    template_file = Path("database_config_template.py")
    
    if not config_file.exists():
        if template_file.exists():
            print("Creating database_config.py from template...")
            with open(template_file, 'r') as f:
                content = f.read()
            with open(config_file, 'w') as f:
                f.write(content)
            print("✅ database_config.py created from template")
        else:
            print("❌ Template file not found. Please create database_config.py manually.")
            return False
    else:
        print("✅ database_config.py already exists")
    
    return True

def test_database_connection():
    """Test database connection."""
    try:
        from database_config import test_connection
        return test_connection()
    except ImportError as e:
        print(f"❌ Cannot import database_config: {e}")
        return False
    except Exception as e:
        print(f"❌ Database connection test failed: {e}")
        return False

def install_dependencies():
    """Install required Python dependencies."""
    try:
        print("Installing Python dependencies...")
        subprocess.run([sys.executable, "-m", "pip", "install", "psycopg2-binary"], check=True)
        print("✅ Dependencies installed successfully")
        return True
    except subprocess.CalledProcessError as e:
        print(f"❌ Failed to install dependencies: {e}")
        return False

def setup_database_schema():
    """Set up database schema."""
    schema_file = Path("database_schema.sql")
    if not schema_file.exists():
        print("❌ database_schema.sql not found")
        return False
    
    try:
        from database_config import get_database_config
        import psycopg2
        
        db_config = get_database_config()
        conn = psycopg2.connect(**db_config.get_connection_config())
        cursor = conn.cursor()
        
        print("Setting up database schema...")
        with open(schema_file, 'r') as f:
            schema_sql = f.read()
        
        cursor.execute(schema_sql)
        conn.commit()
        cursor.close()
        conn.close()
        
        print("✅ Database schema set up successfully")
        return True
        
    except Exception as e:
        print(f"❌ Failed to set up database schema: {e}")
        return False

def main():
    """Main setup function."""
    print("=== HES-Kaifa Events Database Setup ===")
    print()
    
    # Step 1: Install dependencies
    print("1. Installing dependencies...")
    if not install_dependencies():
        print("❌ Setup failed at dependency installation")
        return False
    
    # Step 2: Create database configuration
    print("\n2. Setting up database configuration...")
    if not create_database_config():
        print("❌ Setup failed at database configuration")
        return False
    
    # Step 3: Test database connection
    print("\n3. Testing database connection...")
    print("Please ensure your PostgreSQL database is running and accessible.")
    print("Update database_config.py with your database settings if needed.")
    
    if test_database_connection():
        print("✅ Database connection successful!")
        
        # Step 4: Set up database schema
        print("\n4. Setting up database schema...")
        if setup_database_schema():
            print("✅ Database setup completed successfully!")
            print("\nYou can now run the consumer with database support:")
            print("  python Kaifa-HES-Events/run_consumer.py --enable-database")
        else:
            print("❌ Database schema setup failed")
            return False
    else:
        print("❌ Database connection failed")
        print("\nPlease check your database configuration in database_config.py")
        print("Make sure PostgreSQL is running and accessible")
        return False
    
    return True

if __name__ == "__main__":
    success = main()
    if not success:
        sys.exit(1)
    else:
        print("\n🎉 Setup completed successfully!")
