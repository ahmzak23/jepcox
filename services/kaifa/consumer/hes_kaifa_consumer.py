#!/usr/bin/env python3
"""
Kafka Consumer for HES-Kaifa Outage Topic
Consumes SOAP messages from hes-kaifa-outage-topic and converts them to JSON format.
Stores the transformed messages in dedicated JSON files.

Database Storage:
- Database storage functionality is included and controlled by enable_database parameter
- Set enable_database=False for local development (default)
- Set enable_database=True for server deployment with PostgreSQL
- Requires psycopg2 package and PostgreSQL database with the provided schema
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

# Database imports
import psycopg2
from psycopg2.extras import RealDictCursor
import psycopg2.pool
import requests


class HESKaifaConsumer:
    """Kafka consumer for HES-Kaifa outage events with SOAP to JSON transformation."""
    
    def __init__(self, 
                 bootstrap_servers: str = 'localhost:9092',
                 topic: str = 'hes-kaifa-outage-topic',
                 output_dir: str = 'apisix-workshop/Kaifa-HES-Events/hes_kaifa_events_log',
                 group_id: str = 'hes-kaifa-consumer-group',
                 enable_database: bool = False):
        """
        Initialize the HES-Kaifa consumer.
        
        Args:
            bootstrap_servers: Kafka bootstrap servers
            topic: Kafka topic to consume from
            output_dir: Directory to store JSON files
            group_id: Kafka consumer group ID
            enable_database: Enable database storage (uncomment database code on server)
        """
        self.bootstrap_servers = bootstrap_servers
        self.topic = topic
        self.output_dir = output_dir
        self.group_id = group_id
        self.enable_database = enable_database
        self.consumer = None
        self.running = True
        
        # Database configuration - will be loaded from database_config.py
        self.db_config = None
        self.db_pool = None
        
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
        # Close database connections if enabled
        if self.enable_database and self.db_pool:
            self.db_pool.closeall()
    
    # =============================================
    # DATABASE METHODS
    # =============================================
    
    def _init_database_connection(self):
        """Initialize database connection pool."""
        try:
            # Import database configuration
            import sys
            import os
            sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
            from database_config import get_database_config
            
            # Load database configuration
            db_config = get_database_config()
            self.db_config = db_config.get_connection_config()
            
            self.db_pool = psycopg2.pool.SimpleConnectionPool(
                1, 10, **self.db_config
            )
            self.logger.info(f"Database connection pool initialized: {db_config}")
        except Exception as e:
            self.logger.error(f"Failed to initialize database connection: {e}")
            raise
    
    def _get_database_connection(self):
        """Get database connection from pool."""
        if not self.db_pool:
            self._init_database_connection()
        return self.db_pool.getconn()
    
    def _return_database_connection(self, conn):
        """Return database connection to pool."""
        if self.db_pool:
            self.db_pool.putconn(conn)
    
    def _store_to_database(self, data: Dict[str, Any]) -> bool:
        """
        Store event data to PostgreSQL database.
        
        Args:
            data: Transformed JSON data to store
            
        Returns:
            True if successful, False otherwise
        """
        if not self.enable_database:
            self.logger.info("Database storage is disabled (enable_database=False)")
            return True
            
        try:
            conn = self._get_database_connection()
            cursor = conn.cursor()
            
            # Convert Python dict to JSON string for PostgreSQL
            json_string = json.dumps(data)
            
            # Use enhanced function that automatically syncs meter status in oms_meters
            cursor.execute("SELECT insert_kaifa_event_from_json_with_meter_sync(%s::jsonb)", (json_string,))
            
            event_id = cursor.fetchone()[0]
            conn.commit()
            
            # Enhanced logging for critical events (potential power loss)
            payload_data = data.get('payload', {})
            severity = payload_data.get('severity', 'unknown')
            if severity in ('critical', 'high'):
                assets = payload_data.get('assets', {})
                meter_id = None
                if isinstance(assets, dict):
                    meter_id = assets.get('ns2:mRID') or assets.get('mRID')
                
                self.logger.warning(f"CRITICAL Kaifa Event - Meter {meter_id} severity={severity}, meter status updated to OFF")
            
            self.logger.info(f"Successfully stored event {event_id} to database with meter sync")

            # Optionally call OMS ingestion API for real-time correlation
            # Enable by setting OMS_API_URL (e.g., http://localhost:9100)
            oms_api_url = os.getenv('OMS_API_URL')
            if oms_api_url:
                try:
                    # Extract event details for correlation
                    payload_data = data.get('payload', {})
                    assets = payload_data.get('assets', {})
                    
                    # Try to extract meter ID from assets
                    meter_id = None
                    if isinstance(assets, dict):
                        meter_id = assets.get('ns2:mRID') or assets.get('mRID')
                    
                    payload = {
                        "event_type": "outage",
                        "source_type": "kaifa",
                        "source_event_id": payload_data.get('event_id', f"kaifa_{event_id}"),
                        "timestamp": payload_data.get('created_date_time', datetime.now().isoformat()),
                        "latitude": None,  # Kaifa events typically don't have lat/lng
                        "longitude": None,
                        "correlation_window_minutes": int(os.getenv('OMS_CORR_WINDOW_MIN', '30')),
                        "spatial_radius_meters": int(os.getenv('OMS_SPATIAL_RADIUS_M', '1000')),
                        "metadata": {
                            "meter_id": meter_id,
                            "severity": payload_data.get('severity'),
                            "reason": payload_data.get('reason')
                        }
                    }
                    requests.post(f"{oms_api_url}/api/oms/events/correlate", json=payload, timeout=5)
                except Exception as e:
                    self.logger.warning(f"OMS API call failed (non-blocking): {e}")

            return True
            
        except Exception as e:
            self.logger.error(f"Failed to store event to database: {e}")
            if 'conn' in locals():
                conn.rollback()
            return False
        finally:
            if 'conn' in locals():
                cursor.close()
                self._return_database_connection(conn)
    
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
            # Extract EventMessage from SOAP body (be tolerant to namespace/case variants)
            event_message = (
                soap_body.get('ns1:EventMessage')
                or soap_body.get('EventMessage')
                or soap_body.get('ns:EventMessage')
            )

            if event_message is not None:
                # Support both prefixed and unprefixed Header/Payload keys
                header_dict = (
                    event_message.get('ns1:Header')
                    or event_message.get('Header')
                    or event_message.get('ns:Header')
                    or {}
                )
                payload_dict = (
                    event_message.get('ns1:Payload')
                    or event_message.get('Payload')
                    or event_message.get('ns:Payload')
                    or {}
                )

                # Transform the structure to a more readable JSON format
                transformed = {
                    'message_type': 'EndDeviceEvent',
                    'timestamp': datetime.now().isoformat(),
                    'header': self._extract_header(header_dict),
                    'payload': self._extract_payload(payload_dict),
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
        def first_of(keys):
            for k in keys:
                if k in header:
                    return header.get(k, '')
            return ''

        return {
            'verb': first_of(['ns1:Verb', 'Verb', 'ns:Verb', 'ns1:verb', 'verb']),
            'noun': first_of(['ns1:Noun', 'Noun', 'ns:Noun', 'ns1:noun', 'noun']),
            'revision': first_of(['ns1:Revision', 'Revision', 'ns:Revision', 'ns1:revision', 'revision']),
            'timestamp': first_of(['ns1:Timestamp', 'Timestamp', 'ns:Timestamp', 'ns1:timestamp', 'timestamp']),
            'source': first_of(['ns1:Source', 'Source', 'ns:Source', 'ns1:source', 'source']),
            'async_reply_flag': first_of(['ns1:AsyncReplyFlag', 'AsyncReplyFlag', 'ns:AsyncReplyFlag', 'ns1:async_reply_flag', 'async_reply_flag']),
            'ack_required': first_of(['ns1:AckRequired', 'AckRequired', 'ns:AckRequired', 'ns1:ack_required', 'ack_required']),
            'user': header.get('ns1:User', header.get('User', {})),
            'message_id': first_of(['ns1:MessageID', 'MessageID', 'ns:MessageID', 'ns1:MessageId', 'MessageId', 'ns1:message_id', 'message_id']),
            'correlation_id': first_of(['ns1:CorrelationID', 'CorrelationID', 'ns:CorrelationID', 'ns1:correlation_id', 'correlation_id']),
            'comment': first_of(['ns1:Comment', 'Comment', 'ns:Comment', 'ns1:comment', 'comment'])
        }
    
    def _extract_payload(self, payload: Dict[str, Any]) -> Dict[str, Any]:
        """Extract and clean payload information."""
        # Accept both prefixed and unprefixed payload structures
        events_container = payload.get('ns2:EndDeviceEvents') or payload.get('EndDeviceEvents') or {}
        event = None
        if isinstance(events_container, dict):
            event = events_container.get('ns2:EndDeviceEvent') or events_container.get('EndDeviceEvent')

        if isinstance(event, dict):
            def first_of_e(d, keys):
                for k in keys:
                    if k in d:
                        return d.get(k, '')
                return ''

            return {
                'event_id': first_of_e(event, ['ns2:mRID', 'mRID', 'ns2:event_id', 'event_id']),
                'created_date_time': first_of_e(event, ['ns2:createdDateTime', 'createdDateTime', 'created_date_time']),
                'issuer_id': first_of_e(event, ['ns2:issuerID', 'issuerID', 'issuer_id']),
                'issuer_tracking_id': first_of_e(event, ['ns2:issuerTrackingID', 'issuerTrackingID', 'issuer_tracking_id']),
                'reason': first_of_e(event, ['ns2:reason', 'reason']),
                'severity': first_of_e(event, ['ns2:severity', 'severity']),
                'user_id': first_of_e(event, ['ns2:userID', 'userID', 'user_id']),
                'assets': event.get('ns2:Assets', event.get('Assets', {})),
                'event_details': event.get('ns2:EndDeviceEventDetails', event.get('EndDeviceEventDetails', [])),
                'event_type': event.get('ns2:EndDeviceEventType', event.get('EndDeviceEventType', {})),
                'names': event.get('ns2:Names', event.get('Names', {})),
                'status': event.get('ns2:status', event.get('status', {})),
                'usage_point': event.get('ns2:UsagePoint', event.get('UsagePoint', {}))
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
            
            # Store to database if enabled and data is well-formed
            if self.enable_database and isinstance(data, dict) and data.get('message_type'):
                self._store_to_database(data)
            
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

                # If database is enabled, store only in DB (skip JSON files)
                if self.enable_database:
                    stored = self._store_to_database(transformed_data)
                    if stored:
                        self.logger.info("Successfully processed and stored message to database")
                        return True
                    self.logger.error("Processing failed during database store")
                    return False

                # Otherwise, save to JSON file (legacy/local mode)
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
            
            # Initialize database connection if enabled
            if self.enable_database:
                self._init_database_connection()
            
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
