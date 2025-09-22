#!/usr/bin/env python3
"""
Kafka Consumer for HES-Kaifa Outage Topic
Consumes SOAP messages from hes-kaifa-outage-topic and converts them to JSON format.
Stores the transformed messages in dedicated JSON files.
"""

import json
import os
import logging
import xmltodict
from datetime import datetime
from typing import Dict, Any, Optional
from kafka import KafkaConsumer
from kafka.errors import KafkaError
import signal
import sys


class HESKaifaConsumer:
    """Kafka consumer for HES-Kaifa outage events with SOAP to JSON transformation."""
    
    def __init__(self, 
                 bootstrap_servers: str = 'localhost:9092',
                 topic: str = 'hes-kaifa-outage-topic',
                 output_dir: str = 'apisix-workshop/Kaifa-HES-Events/hes_kaifa_events',
                 group_id: str = 'hes-kaifa-consumer-group'):
        """
        Initialize the HES-Kaifa consumer.
        
        Args:
            bootstrap_servers: Kafka bootstrap servers
            topic: Kafka topic to consume from
            output_dir: Directory to store JSON files
            group_id: Kafka consumer group ID
        """
        self.bootstrap_servers = bootstrap_servers
        self.topic = topic
        self.output_dir = output_dir
        self.group_id = group_id
        self.consumer = None
        self.running = True
        
        # Setup logging
        self._setup_logging()
        
        # Ensure output directory exists
        os.makedirs(self.output_dir, exist_ok=True)
        
        # Setup signal handlers for graceful shutdown
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
    
    def _setup_logging(self):
        """Setup logging configuration."""
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(self.output_dir, 'consumer.log')),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger(__name__)
    
    def _signal_handler(self, signum, frame):
        """Handle shutdown signals gracefully."""
        self.logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
        if self.consumer:
            self.consumer.close()
    
    def _create_consumer(self) -> KafkaConsumer:
        """Create and configure Kafka consumer."""
        try:
            consumer = KafkaConsumer(
                self.topic,
                bootstrap_servers=self.bootstrap_servers,
                group_id=self.group_id,
                auto_offset_reset='latest',
                enable_auto_commit=True,
                value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                consumer_timeout_ms=1000
            )
            self.logger.info(f"Connected to Kafka topic: {self.topic}")
            return consumer
        except KafkaError as e:
            self.logger.error(f"Failed to create Kafka consumer: {e}")
            raise
    
    def _extract_soap_body(self, soap_xml: str) -> str:
        """
        Extract SOAP body content from SOAP envelope.
        
        Args:
            soap_xml: Raw SOAP XML string
            
        Returns:
            SOAP body content as string
        """
        try:
            # Parse SOAP XML to extract body content
            soap_dict = xmltodict.parse(soap_xml)
            
            # Navigate to SOAP body content
            if 'soap:Envelope' in soap_dict and 'soap:Body' in soap_dict['soap:Envelope']:
                body_content = soap_dict['soap:Envelope']['soap:Body']
                return body_content
            else:
                self.logger.warning("Could not find SOAP body in message")
                return soap_xml
        except Exception as e:
            self.logger.error(f"Error parsing SOAP XML: {e}")
            return soap_xml
    
    def _transform_soap_to_json(self, soap_body: Dict[str, Any]) -> Dict[str, Any]:
        """
        Transform SOAP body content to structured JSON.
        
        Args:
            soap_body: SOAP body content as dictionary
            
        Returns:
            Transformed JSON structure
        """
        try:
            # Extract EventMessage from SOAP body
            if 'ns1:EventMessage' in soap_body:
                event_message = soap_body['ns1:EventMessage']
                
                # Transform the structure to a more readable JSON format
                transformed = {
                    'message_type': 'EndDeviceEvent',
                    'timestamp': datetime.now().isoformat(),
                    'header': self._extract_header(event_message.get('ns1:Header', {})),
                    'payload': self._extract_payload(event_message.get('ns1:Payload', {})),
                    'metadata': {
                        'source': 'hes-kaifa-outage-topic',
                        'processed_at': datetime.now().isoformat()
                    }
                }
                return transformed
            else:
                self.logger.warning("No EventMessage found in SOAP body")
                return {'raw_soap': soap_body}
        except Exception as e:
            self.logger.error(f"Error transforming SOAP to JSON: {e}")
            return {'error': str(e), 'raw_soap': soap_body}
    
    def _extract_header(self, header: Dict[str, Any]) -> Dict[str, Any]:
        """Extract and clean header information."""
        return {
            'verb': header.get('ns1:Verb', ''),
            'noun': header.get('ns1:Noun', ''),
            'revision': header.get('ns1:Revision', ''),
            'timestamp': header.get('ns1:Timestamp', ''),
            'source': header.get('ns1:Source', ''),
            'async_reply_flag': header.get('ns1:AsyncReplyFlag', ''),
            'ack_required': header.get('ns1:AckRequired', ''),
            'user': header.get('ns1:User', {}),
            'message_id': header.get('ns1:MessageID', ''),
            'correlation_id': header.get('ns1:CorrelationID', ''),
            'comment': header.get('ns1:Comment', '')
        }
    
    def _extract_payload(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Extract and clean payload information."""
        if 'ns2:EndDeviceEvents' in payload:
            events = payload['ns2:EndDeviceEvents']
            if 'ns2:EndDeviceEvent' in events:
                event = events['ns2:EndDeviceEvent']
                return {
                    'event_id': event.get('ns2:mRID', ''),
                    'created_date_time': event.get('ns2:createdDateTime', ''),
                    'issuer_id': event.get('ns2:issuerID', ''),
                    'issuer_tracking_id': event.get('ns2:issuerTrackingID', ''),
                    'reason': event.get('ns2:reason', ''),
                    'severity': event.get('ns2:severity', ''),
                    'user_id': event.get('ns2:userID', ''),
                    'assets': event.get('ns2:Assets', {}),
                    'event_details': event.get('ns2:EndDeviceEventDetails', []),
                    'event_type': event.get('ns2:EndDeviceEventType', {}),
                    'names': event.get('ns2:Names', {}),
                    'status': event.get('ns2:status', {}),
                    'usage_point': event.get('ns2:UsagePoint', {})
                }
        return {}
    
    def _save_to_json_file(self, data: Dict[str, Any], message_id: str) -> str:
        """
        Save transformed data to JSON file.
        
        Args:
            data: Transformed JSON data
            message_id: Unique message identifier for filename
            
        Returns:
            Path to saved file
        """
        try:
            # Create filename with timestamp and message ID
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"hes_kaifa_event_{timestamp}_{message_id}.json"
            filepath = os.path.join(self.output_dir, filename)
            
            # Save to file with pretty formatting
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
            
            self.logger.info(f"Saved event to file: {filepath}")
            return filepath
        except Exception as e:
            self.logger.error(f"Error saving JSON file: {e}")
            raise
    
    def _process_message(self, message) -> bool:
        """
        Process a single Kafka message.
        
        Args:
            message: Kafka message object
            
        Returns:
            True if processing successful, False otherwise
        """
        try:
            self.logger.info(f"Processing message from partition {message.partition}, offset {message.offset}")
            
            # Extract message data
            message_data = message.value
            
            # Extract SOAP body from request
            if 'request' in message_data and 'body' in message_data['request']:
                soap_xml = message_data['request']['body']
                
                # Extract SOAP body content
                soap_body = self._extract_soap_body(soap_xml)
                
                # Transform SOAP to JSON
                transformed_data = self._transform_soap_to_json(soap_body)
                
                # Add original message metadata
                transformed_data['original_message'] = {
                    'timestamp': message_data.get('timestamp', ''),
                    'source': message_data.get('source', ''),
                    'topic': message_data.get('topic', ''),
                    'processed_at': message_data.get('processed_at', '')
                }
                
                # Generate unique message ID
                message_id = message_data.get('request', {}).get('headers', {}).get('X-Message-ID', 
                             message_data.get('request', {}).get('headers', {}).get('Message-ID', 
                             f"msg_{int(datetime.now().timestamp() * 1000)}"))
                
                # Save to JSON file
                filepath = self._save_to_json_file(transformed_data, message_id)
                
                self.logger.info(f"Successfully processed and saved message to {filepath}")
                return True
            else:
                self.logger.warning("No SOAP body found in message")
                return False
                
        except Exception as e:
            self.logger.error(f"Error processing message: {e}")
            return False
    
    def start_consuming(self):
        """Start consuming messages from Kafka topic."""
        try:
            self.logger.info("Starting HES-Kaifa consumer...")
            self.consumer = self._create_consumer()
            
            self.logger.info(f"Consumer started. Listening to topic: {self.topic}")
            
            while self.running:
                try:
                    # Poll for messages
                    message_batch = self.consumer.poll(timeout_ms=1000)
                    
                    if message_batch:
                        for topic_partition, messages in message_batch.items():
                            for message in messages:
                                if not self.running:
                                    break
                                
                                self._process_message(message)
                                
                                # Commit offset after processing
                                self.consumer.commit()
                    
                except KafkaError as e:
                    self.logger.error(f"Kafka error: {e}")
                    break
                except Exception as e:
                    self.logger.error(f"Unexpected error: {e}")
                    break
            
        except KeyboardInterrupt:
            self.logger.info("Received keyboard interrupt, shutting down...")
        except Exception as e:
            self.logger.error(f"Fatal error: {e}")
        finally:
            self._cleanup()
    
    def _cleanup(self):
        """Cleanup resources."""
        if self.consumer:
            self.consumer.close()
            self.logger.info("Consumer closed")
        self.logger.info("HES-Kaifa consumer stopped")


def main():
    """Main function to run the consumer."""
    consumer = HESKaifaConsumer()
    consumer.start_consuming()


if __name__ == "__main__":
    main()
