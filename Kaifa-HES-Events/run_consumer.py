#!/usr/bin/env python3
"""
Runner script for HES-Kaifa Kafka Consumer
Provides command-line interface and configuration management.
"""

import argparse
import sys
import os
import signal
from typing import Optional

from hes_kaifa_consumer import HESKaifaConsumer
from config import ConsumerConfig


def parse_arguments():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description='HES-Kaifa Kafka Consumer - Consumes SOAP messages and converts to JSON'
    )
    
    parser.add_argument(
        '--bootstrap-servers',
        default=ConsumerConfig.KAFKA_BOOTSTRAP_SERVERS,
        help=f'Kafka bootstrap servers (default: {ConsumerConfig.KAFKA_BOOTSTRAP_SERVERS})'
    )
    
    parser.add_argument(
        '--topic',
        default=ConsumerConfig.KAFKA_TOPIC,
        help=f'Kafka topic to consume from (default: {ConsumerConfig.KAFKA_TOPIC})'
    )
    
    parser.add_argument(
        '--output-dir',
        default=ConsumerConfig.OUTPUT_DIR,
        help=f'Output directory for JSON files (default: {ConsumerConfig.OUTPUT_DIR})'
    )
    
    parser.add_argument(
        '--group-id',
        default=ConsumerConfig.KAFKA_GROUP_ID,
        help=f'Kafka consumer group ID (default: {ConsumerConfig.KAFKA_GROUP_ID})'
    )
    
    parser.add_argument(
        '--log-level',
        default=ConsumerConfig.LOG_LEVEL,
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
        help=f'Logging level (default: {ConsumerConfig.LOG_LEVEL})'
    )
    
    parser.add_argument(
        '--test-mode',
        action='store_true',
        help='Run in test mode (process one message and exit)'
    )
    
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Dry run mode (don\'t save files, just process messages)'
    )
    
    parser.add_argument(
        '--enable-database',
        action='store_true',
        default=False,
        help='Enable database storage (default: False)'
    )
    
    return parser.parse_args()


def setup_environment(args):
    """Setup environment variables from command line arguments."""
    os.environ['KAFKA_BOOTSTRAP_SERVERS'] = args.bootstrap_servers
    os.environ['KAFKA_TOPIC'] = args.topic
    os.environ['OUTPUT_DIR'] = args.output_dir
    os.environ['KAFKA_GROUP_ID'] = args.group_id
    os.environ['LOG_LEVEL'] = args.log_level


def create_consumer(args) -> HESKaifaConsumer:
    """Create and configure the consumer."""
    return HESKaifaConsumer(
        bootstrap_servers=args.bootstrap_servers,
        topic=args.topic,
        output_dir=args.output_dir,
        group_id=args.group_id,
        enable_database=args.enable_database
    )


def run_consumer(consumer: HESKaifaConsumer, test_mode: bool = False):
    """Run the consumer."""
    try:
        if test_mode:
            print("Running in test mode - processing one message...")
            # In test mode, we would process one message and exit
            # This is a placeholder for test mode implementation
            print("Test mode not fully implemented yet")
        else:
            print(f"Starting HES-Kaifa consumer...")
            print(f"Topic: {consumer.topic}")
            print(f"Bootstrap servers: {consumer.bootstrap_servers}")
            print(f"Output directory: {consumer.output_dir}")
            print(f"Group ID: {consumer.group_id}")
            print("Press Ctrl+C to stop the consumer")
            
            consumer.start_consuming()
    except KeyboardInterrupt:
        print("\nReceived interrupt signal, shutting down...")
    except Exception as e:
        print(f"Error running consumer: {e}")
        sys.exit(1)


def main():
    """Main function."""
    args = parse_arguments()
    
    # Setup environment
    setup_environment(args)
    
    # Create consumer
    try:
        consumer = create_consumer(args)
        print("Consumer created successfully")
    except Exception as e:
        print(f"Failed to create consumer: {e}")
        sys.exit(1)
    
    # Run consumer
    run_consumer(consumer, args.test_mode)


if __name__ == "__main__":
    main()
