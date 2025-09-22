#!/usr/bin/env python3
"""
Example usage of HES-Kaifa Kafka Consumer
Demonstrates how to use the consumer programmatically.
"""

import json
import time
from hes_kaifa_consumer import HESKaifaConsumer
from config import ConsumerConfig


def example_basic_usage():
    """Example of basic consumer usage."""
    print("=== Basic Consumer Usage ===")
    
    # Create consumer with default settings
    consumer = HESKaifaConsumer()
    
    print(f"Consumer created:")
    print(f"  Topic: {consumer.topic}")
    print(f"  Bootstrap servers: {consumer.bootstrap_servers}")
    print(f"  Output directory: {consumer.output_dir}")
    print(f"  Group ID: {consumer.group_id}")
    
    # Note: In a real scenario, you would call consumer.start_consuming()
    # For this example, we'll just show the configuration
    print("\nTo start consuming, call: consumer.start_consuming()")


def example_custom_configuration():
    """Example of custom consumer configuration."""
    print("\n=== Custom Configuration ===")
    
    # Create consumer with custom settings
    consumer = HESKaifaConsumer(
        bootstrap_servers='localhost:9092',
        topic='hes-kaifa-outage-topic',
        output_dir='./custom_output',
        group_id='custom-consumer-group'
    )
    
    print(f"Custom consumer created:")
    print(f"  Topic: {consumer.topic}")
    print(f"  Bootstrap servers: {consumer.bootstrap_servers}")
    print(f"  Output directory: {consumer.output_dir}")
    print(f"  Group ID: {consumer.group_id}")


def example_soap_transformation():
    """Example of SOAP to JSON transformation."""
    print("\n=== SOAP Transformation Example ===")
    
    # Sample SOAP XML (simplified)
    sample_soap = '''<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/" 
               xmlns:ns1="http://iec.ch/TC57/2011/schema/message">
    <soap:Body>
        <ns1:EventMessage>
            <ns1:Header>
                <ns1:Verb>Create</ns1:Verb>
                <ns1:Noun>EndDeviceEvents</ns1:Noun>
                <ns1:Source>Test-Source</ns1:Source>
            </ns1:Header>
            <ns1:Payload>
                <ns2:EndDeviceEvents xmlns:ns2="http://iec.ch/TC57/2011/EndDeviceEvents#">
                    <ns2:EndDeviceEvent>
                        <ns2:mRID>test_event_123</ns2:mRID>
                        <ns2:reason>Test Event</ns2:reason>
                        <ns2:severity>Low</ns2:severity>
                    </ns2:EndDeviceEvent>
                </ns2:EndDeviceEvents>
            </ns1:Payload>
        </ns1:EventMessage>
    </soap:Body>
</soap:Envelope>'''
    
    # Create consumer for transformation
    consumer = HESKaifaConsumer()
    
    # Extract SOAP body
    soap_body = consumer._extract_soap_body(sample_soap)
    print("SOAP Body extracted:")
    print(json.dumps(soap_body, indent=2))
    
    # Transform to JSON
    transformed = consumer._transform_soap_to_json(soap_body)
    print("\nTransformed JSON:")
    print(json.dumps(transformed, indent=2))


def example_message_processing():
    """Example of message processing."""
    print("\n=== Message Processing Example ===")
    
    # Sample Kafka message
    sample_message = {
        "timestamp": "2025-09-22T07:23:59.072883",
        "source": "test-generator",
        "request": {
            "method": "POST",
            "uri": "http://localhost:9080/test",
            "body": '''<?xml version="1.0" encoding="UTF-8"?>
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
    <soap:Body>
        <ns1:EventMessage xmlns:ns1="http://iec.ch/TC57/2011/schema/message">
            <ns1:Header>
                <ns1:Verb>Create</ns1:Verb>
                <ns1:Noun>EndDeviceEvents</ns1:Noun>
            </ns1:Header>
            <ns1:Payload>
                <ns2:EndDeviceEvents xmlns:ns2="http://iec.ch/TC57/2011/EndDeviceEvents#">
                    <ns2:EndDeviceEvent>
                        <ns2:mRID>example_event_456</ns2:mRID>
                        <ns2:reason>Example Event</ns2:reason>
                    </ns2:EndDeviceEvent>
                </ns2:EndDeviceEvents>
            </ns1:Payload>
        </ns1:EventMessage>
    </soap:Body>
</soap:Envelope>''',
            "headers": {
                "Content-Type": "text/xml; charset=utf-8"
            }
        },
        "topic": "hes-kaifa-outage-topic"
    }
    
    # Create mock message object
    class MockMessage:
        def __init__(self, value):
            self.value = value
            self.partition = 0
            self.offset = 123
    
    mock_message = MockMessage(sample_message)
    
    # Create consumer
    consumer = HESKaifaConsumer()
    
    # Process message (this would normally save to file)
    print("Processing sample message...")
    result = consumer._process_message(mock_message)
    print(f"Message processing result: {result}")


def example_configuration_options():
    """Example of different configuration options."""
    print("\n=== Configuration Options ===")
    
    # Show different ways to configure the consumer
    configs = [
        {
            'name': 'Default Configuration',
            'config': {}
        },
        {
            'name': 'Custom Kafka Settings',
            'config': {
                'bootstrap_servers': 'kafka1:9092,kafka2:9092',
                'topic': 'custom-topic',
                'group_id': 'custom-group'
            }
        },
        {
            'name': 'Custom Output Directory',
            'config': {
                'output_dir': '/var/log/hes-events',
                'group_id': 'production-consumer'
            }
        }
    ]
    
    for config_info in configs:
        print(f"\n{config_info['name']}:")
        consumer = HESKaifaConsumer(**config_info['config'])
        print(f"  Bootstrap servers: {consumer.bootstrap_servers}")
        print(f"  Topic: {consumer.topic}")
        print(f"  Output directory: {consumer.output_dir}")
        print(f"  Group ID: {consumer.group_id}")


def main():
    """Run all examples."""
    print("HES-Kaifa Kafka Consumer - Usage Examples")
    print("=" * 50)
    
    try:
        example_basic_usage()
        example_custom_configuration()
        example_soap_transformation()
        example_message_processing()
        example_configuration_options()
        
        print("\n" + "=" * 50)
        print("Examples completed successfully!")
        print("\nTo run the actual consumer:")
        print("  python run_consumer.py")
        print("\nTo run tests:")
        print("  python test_hes_kaifa_consumer.py")
        
    except Exception as e:
        print(f"Error running examples: {e}")
        print("Make sure all dependencies are installed:")
        print("  pip install -r ../requirements.txt")


if __name__ == "__main__":
    main()
