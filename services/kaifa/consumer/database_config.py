#!/usr/bin/env python3
"""
Database Configuration for HES-Kaifa Events
External PostgreSQL database configuration
"""

import os
from typing import Dict, Any

class DatabaseConfig:
    """Database configuration class for external PostgreSQL connection."""
    
    def __init__(self):
        """Initialize database configuration from environment variables or defaults."""
        self.host = os.getenv('DB_HOST', 'host.docker.internal')
        self.port = int(os.getenv('DB_PORT', '5432'))
        self.database = os.getenv('DB_NAME', 'oms_db')
        self.user = os.getenv('DB_USER', 'web')
        self.password = os.getenv('DB_PASSWORD', '123456')
        self.ssl_mode = os.getenv('DB_SSL_MODE', 'prefer')
        
    def get_connection_config(self) -> Dict[str, Any]:
        """Get database connection configuration dictionary."""
        return {
            'host': self.host,
            'port': self.port,
            'database': self.database,
            'user': self.user,
            'password': self.password,
            'sslmode': self.ssl_mode
        }
    
    def get_connection_string(self) -> str:
        """Get PostgreSQL connection string."""
        return f"postgresql://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}?sslmode={self.ssl_mode}"
    
    def __str__(self) -> str:
        """String representation of database configuration."""
        return f"DatabaseConfig(host={self.host}, port={self.port}, database={self.database}, user={self.user})"

# Global database configuration instance
db_config = DatabaseConfig()

# Example environment variables for different environments
ENVIRONMENT_EXAMPLES = {
    'development': {
        'DB_HOST': 'localhost',
        'DB_PORT': '5432',
        'DB_NAME': 'hes_kaifa_events_dev',
        'DB_USER': 'hes_app_user',
        'DB_PASSWORD': 'dev_password',
        'DB_SSL_MODE': 'disable'
    },
    'production': {
        'DB_HOST': 'your-production-db-host',
        'DB_PORT': '5432',
        'DB_NAME': 'hes_kaifa_events',
        'DB_USER': 'hes_app_user',
        'DB_PASSWORD': 'your-secure-production-password',
        'DB_SSL_MODE': 'require'
    },
    'docker': {
        'DB_HOST': 'host.docker.internal',  # For Docker Desktop
        'DB_PORT': '5432',
        'DB_NAME': 'hes_kaifa_events',
        'DB_USER': 'hes_app_user',
        'DB_PASSWORD': 'secure_password',
        'DB_SSL_MODE': 'prefer'
    }
}

def get_database_config() -> DatabaseConfig:
    """Get the global database configuration."""
    return db_config

def test_connection() -> bool:
    """Test database connection."""
    try:
        import psycopg2
        conn = psycopg2.connect(**db_config.get_connection_config())
        conn.close()
        return True
    except Exception as e:
        print(f"Database connection test failed: {e}")
        return False

if __name__ == "__main__":
    # Print current configuration
    print("Current Database Configuration:")
    print(f"  Host: {db_config.host}")
    print(f"  Port: {db_config.port}")
    print(f"  Database: {db_config.database}")
    print(f"  User: {db_config.user}")
    print(f"  SSL Mode: {db_config.ssl_mode}")
    
    # Test connection
    print("\nTesting database connection...")
    if test_connection():
        print("✅ Database connection successful!")
    else:
        print("❌ Database connection failed!")
        print("\nPlease check your database configuration and ensure PostgreSQL is running.")
