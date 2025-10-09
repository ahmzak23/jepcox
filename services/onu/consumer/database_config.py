#!/usr/bin/env python3
"""
Database configuration for ONU consumer
"""

import os


class DatabaseConfig:
    def __init__(self):
        self.host = os.getenv('DB_HOST', 'oms-database')  # Use OMS database service
        self.port = int(os.getenv('DB_PORT', '5432'))
        self.database = os.getenv('DB_NAME', 'oms_db')
        self.user = os.getenv('DB_USER', 'web')
        self.password = os.getenv('DB_PASSWORD', '123456')
        self.ssl_mode = os.getenv('DB_SSL_MODE', 'prefer')
    
    def get_connection_config(self):
        return {
            'host': self.host,
            'port': self.port,
            'database': self.database,
            'user': self.user,
            'password': self.password,
            'sslmode': self.ssl_mode
        }


def get_database_config():
    return DatabaseConfig()
