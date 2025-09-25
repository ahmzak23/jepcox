#!/usr/bin/env python3
"""
Configuration settings for HES-Kaifa Kafka Consumer
"""

import os
from typing import Dict, Any


class ConsumerConfig:
    """Configuration class for HES-Kaifa consumer."""
    
    # Kafka Configuration
    KAFKA_BOOTSTRAP_SERVERS: str = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
    KAFKA_TOPIC: str = os.getenv('KAFKA_TOPIC', 'hes-kaifa-outage-topic')
    KAFKA_GROUP_ID: str = os.getenv('KAFKA_GROUP_ID', 'hes-kaifa-consumer-group')
    
    # Output Configuration
    OUTPUT_DIR: str = os.getenv('OUTPUT_DIR', 'apisix-workshop/Kaifa-HES-Events')
    
    # Consumer Settings
    AUTO_OFFSET_RESET: str = os.getenv('AUTO_OFFSET_RESET', 'latest')
    ENABLE_AUTO_COMMIT: bool = os.getenv('ENABLE_AUTO_COMMIT', 'true').lower() == 'true'
    CONSUMER_TIMEOUT_MS: int = int(os.getenv('CONSUMER_TIMEOUT_MS', '1000'))
    
    # Logging Configuration
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    LOG_FORMAT: str = '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    
    # File Storage Configuration
    MAX_FILE_SIZE_MB: int = int(os.getenv('MAX_FILE_SIZE_MB', '10'))
    FILE_PREFIX: str = os.getenv('FILE_PREFIX', 'hes_kaifa_event')
    
    @classmethod
    def get_kafka_config(cls) -> Dict[str, Any]:
        """Get Kafka consumer configuration."""
        return {
            'bootstrap_servers': cls.KAFKA_BOOTSTRAP_SERVERS,
            'group_id': cls.KAFKA_GROUP_ID,
            'auto_offset_reset': cls.AUTO_OFFSET_RESET,
            'enable_auto_commit': cls.ENABLE_AUTO_COMMIT,
            'consumer_timeout_ms': cls.CONSUMER_TIMEOUT_MS
        }
    
    @classmethod
    def get_consumer_config(cls) -> Dict[str, Any]:
        """Get consumer configuration."""
        return {
            'bootstrap_servers': cls.KAFKA_BOOTSTRAP_SERVERS,
            'topic': cls.KAFKA_TOPIC,
            'output_dir': cls.OUTPUT_DIR,
            'group_id': cls.KAFKA_GROUP_ID
        }
    
    @classmethod
    def get_logging_config(cls) -> Dict[str, Any]:
        """Get logging configuration."""
        return {
            'level': cls.LOG_LEVEL,
            'format': cls.LOG_FORMAT
        }
