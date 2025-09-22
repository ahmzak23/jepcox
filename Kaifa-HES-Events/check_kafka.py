#!/usr/bin/env python3
"""
Check if Kafka is running and accessible
"""

import subprocess
import sys
import time

def check_docker():
    """Check if Docker is running."""
    try:
        result = subprocess.run(['docker', '--version'], capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Docker is available")
            return True
        else:
            print("✗ Docker is not available")
            return False
    except FileNotFoundError:
        print("✗ Docker is not installed or not in PATH")
        return False

def check_kafka_containers():
    """Check if Kafka containers are running."""
    try:
        result = subprocess.run(['docker', 'ps', '--filter', 'name=oms-kafka', '--format', 'table {{.Names}}\t{{.Status}}'], 
                              capture_output=True, text=True)
        
        if 'oms-kafka' in result.stdout:
            print("✓ Kafka container is running")
            print(result.stdout)
            return True
        else:
            print("✗ Kafka container is not running")
            return False
    except Exception as e:
        print(f"✗ Error checking containers: {e}")
        return False

def check_kafka_connection():
    """Check if Kafka is accessible."""
    try:
        from kafka import KafkaProducer
        producer = KafkaProducer(bootstrap_servers='localhost:9092')
        producer.close()
        print("✓ Kafka connection successful")
        return True
    except Exception as e:
        print(f"✗ Cannot connect to Kafka: {e}")
        return False

def start_kafka():
    """Start Kafka using docker-compose."""
    print("Starting Kafka infrastructure...")
    try:
        result = subprocess.run(['docker-compose', 'up', '-d', 'zookeeper', 'kafka'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Kafka infrastructure started")
            print("Waiting for services to be ready...")
            time.sleep(30)  # Wait for services to start
            return True
        else:
            print(f"✗ Failed to start Kafka: {result.stderr}")
            return False
    except Exception as e:
        print(f"✗ Error starting Kafka: {e}")
        return False

def create_topic():
    """Create the required topic."""
    try:
        result = subprocess.run([
            'docker', 'exec', 'oms-kafka', 
            'kafka-topics', '--create', 
            '--topic', 'hes-kaifa-outage-topic',
            '--bootstrap-server', 'localhost:9092',
            '--partitions', '3',
            '--replication-factor', '1'
        ], capture_output=True, text=True)
        
        if result.returncode == 0:
            print("✓ Topic created successfully")
            return True
        else:
            if "already exists" in result.stderr:
                print("✓ Topic already exists")
                return True
            else:
                print(f"✗ Failed to create topic: {result.stderr}")
                return False
    except Exception as e:
        print(f"✗ Error creating topic: {e}")
        return False

def main():
    """Main function."""
    print("Kafka Status Checker")
    print("=" * 20)
    
    # Check Docker
    if not check_docker():
        print("Please install Docker and try again")
        return
    
    # Check containers
    if not check_kafka_containers():
        print("\nStarting Kafka infrastructure...")
        if not start_kafka():
            print("Failed to start Kafka. Please check Docker and try again.")
            return
    
    # Check connection
    if not check_kafka_connection():
        print("Kafka is not accessible. Please check the configuration.")
        return
    
    # Create topic
    print("\nCreating topic...")
    create_topic()
    
    print("\n✓ Kafka is ready!")
    print("You can now run the consumer:")
    print("  python run_consumer.py --bootstrap-servers localhost:9092 --topic hes-kaifa-outage-topic")

if __name__ == "__main__":
    main()
