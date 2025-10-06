#!/usr/bin/env python3
"""
Kafka Consumer for SCADA events
Consumes JSON events from scada-outage-topic and acknowledges processing.
"""

import json
import os
import logging
import psycopg2
import psycopg2.pool
import signal
import sys
from datetime import datetime
from typing import Dict, Any

from kafka import KafkaConsumer
from kafka.errors import KafkaError
import requests


class ScadaConsumer:
    def __init__(
        self,
        bootstrap_servers: str = "localhost:9092",
        topic: str = "scada-outage-topic",
        group_id: str = "scada-consumer-group",
        output_dir: str = ".",
    ) -> None:
        self.bootstrap_servers = bootstrap_servers
        self.topic = topic
        self.group_id = group_id
        self.output_dir = output_dir

        self.consumer = None
        self.running = True
        self.db_pool = None

        os.makedirs(self.output_dir, exist_ok=True)
        self._setup_logging()
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

        # Initialize DB pool eagerly so we fail fast if DB is unreachable
        try:
            self._init_database_connection()
        except Exception as e:
            self.logger.error(f"Failed to initialize database: {e}")
            raise

    def _setup_logging(self) -> None:
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(self.output_dir, 'scada_consumer.log')),
                logging.StreamHandler(sys.stdout),
            ],
        )
        self.logger = logging.getLogger(__name__)

    def _signal_handler(self, signum, frame) -> None:
        self.logger.info(f"Received signal {signum}, shutting down...")
        self.running = False
        if self.consumer:
            self.consumer.close()
        if self.db_pool:
            self.db_pool.closeall()

    def _init_database_connection(self) -> None:
        # Load database config co-located with this consumer
        try:
            import os as _os, sys as _sys
            _sys.path.append(_os.path.dirname(_os.path.abspath(__file__)))
            from database_config import get_database_config  # type: ignore
            db_cfg = get_database_config().get_connection_config()
            self.db_pool = psycopg2.pool.SimpleConnectionPool(1, 10, **db_cfg)
            self.logger.info("Database pool initialized for SCADA consumer")
        except Exception as e:
            self.logger.error(f"Failed to init DB pool: {e}")
            raise

    def _store_to_database(self, event: Dict[str, Any], source: str) -> bool:
        if not self.db_pool:
            self.logger.error("DB pool not initialized")
            return False
        try:
            # enrich event with source for the insert function
            payload = dict(event)
            payload['source'] = source or 'scada-consumer'
            conn = self.db_pool.getconn()
            cur = conn.cursor()
            
            # Use enhanced function that automatically checks meters when SCADA events occur
            cur.execute("SELECT insert_scada_event_with_meter_check(%s::jsonb)", (json.dumps(payload),))
            result = cur.fetchone()[0]
            conn.commit()
            
            # Enhanced logging with meter check results
            if isinstance(result, dict):
                ev_id = result.get('scada_event_id')
                meters_checked = result.get('meters_checked', False)
                self.logger.info(f"Stored SCADA event {ev_id} to database")
                
                if meters_checked:
                    total_meters = result.get('total_meters', 0)
                    offline_meters = result.get('offline_meters', 0)
                    online_meters = result.get('online_meters', 0)
                    unknown_meters = result.get('unknown_meters', 0)
                    outage_event_id = result.get('outage_event_id')
                    
                    self.logger.info(f"Meter Check Results:")
                    self.logger.info(f"  Total meters: {total_meters}")
                    self.logger.info(f"  Offline meters: {offline_meters}")
                    self.logger.info(f"  Online meters: {online_meters}")
                    self.logger.info(f"  Unknown meters: {unknown_meters}")
                    
                    if outage_event_id:
                        self.logger.warning(f"OUTAGE DETECTED - Event ID: {outage_event_id}, {offline_meters} meters offline")
                    else:
                        self.logger.info("No outage detected - all meters responding normally")
                else:
                    self.logger.info(f"Meters not checked (non-critical alarm type: {event.get('alarmType')})")
            else:
                # Fallback for legacy function response
                self.logger.info(f"Stored SCADA event {result} to database")
                ev_id = result

            # Optionally call OMS ingestion API for real-time correlation
            # Enable by setting OMS_API_URL (e.g., http://localhost:9100)
            oms_api_url = os.getenv('OMS_API_URL')
            if oms_api_url:
                try:
                    payload = {
                        "event_type": "outage",
                        "source_type": "scada",
                        "source_event_id": f"scada_{ev_id}",
                        "timestamp": event.get('timestamp', datetime.now().isoformat()),
                        "latitude": event.get('latitude'),
                        "longitude": event.get('longitude'),
                        "correlation_window_minutes": int(os.getenv('OMS_CORR_WINDOW_MIN', '30')),
                        "spatial_radius_meters": int(os.getenv('OMS_SPATIAL_RADIUS_M', '1000')),
                        "metadata": {
                            "event_type": event.get('eventType'),
                            "substation_id": event.get('substationId'),
                            "feeder_id": event.get('feederId'),
                            "alarm_type": event.get('alarmType'),
                            "voltage": event.get('voltage')
                        }
                    }
                    requests.post(f"{oms_api_url}/api/oms/events/correlate", json=payload, timeout=5)
                except Exception as e:
                    self.logger.warning(f"OMS API call failed (non-blocking): {e}")

            return True
        except Exception as e:
            self.logger.error(f"Failed to store SCADA event: {e}")
            if 'conn' in locals():
                conn.rollback()
            return False
        finally:
            if 'cur' in locals():
                cur.close()
            if 'conn' in locals():
                self.db_pool.putconn(conn)

    def _create_consumer(self) -> KafkaConsumer:
        try:
            consumer = KafkaConsumer(
                self.topic,
                bootstrap_servers=self.bootstrap_servers,
                group_id=self.group_id,
                auto_offset_reset='latest',
                enable_auto_commit=True,
                value_deserializer=lambda x: json.loads(x.decode('utf-8')),
                consumer_timeout_ms=1000,
            )
            self.logger.info(f"Connected to topic: {self.topic}")
            return consumer
        except KafkaError as e:
            self.logger.error(f"Failed to create consumer: {e}")
            raise

    def _acknowledge(self, event: Dict[str, Any]) -> None:
        # Placeholder for integration with OMS / acknowledgement logic
        self.logger.info("Acknowledged SCADA event")

    def _is_valid_event(self, event: Dict[str, Any]) -> bool:
        required = [
            "eventType",
            "substationId",
            "feederId",
            "mainStationId",
            "alarmType",
            "timestamp",
            "voltage",
        ]
        return all(k in event for k in required)

    def _process_message(self, message) -> bool:
        try:
            data = message.value
            # Log entire message value as received from Kafka
            try:
                self.logger.info("Kafka message value: %s", json.dumps(data, ensure_ascii=False))
            except Exception:
                # Fallback if data isn't JSON serializable for any reason
                self.logger.info("Kafka message value (raw): %s", str(data))
            # Expected envelope from producer
            event = data.get("event", {}) if isinstance(data, dict) else {}
            if not self._is_valid_event(event):
                self.logger.warning("Invalid SCADA event payload; skipping")
                return False

            source = data.get("source", "") if isinstance(data, dict) else ""
            stored = self._store_to_database(event, source)
            if not stored:
                return False
            # Acknowledge (placeholder)
            self._acknowledge(event)
            return True
        except Exception as e:
            self.logger.error(f"Error processing SCADA message: {e}")
            return False

    def start(self) -> None:
        try:
            self.logger.info("Starting SCADA consumer...")
            self.consumer = self._create_consumer()
            self.logger.info(f"Listening on topic: {self.topic}")

            while self.running:
                try:
                    batch = self.consumer.poll(timeout_ms=1000)
                    if not batch:
                        continue
                    for tp, messages in batch.items():
                        for msg in messages:
                            if not self.running:
                                break
                            self._process_message(msg)
                            self.consumer.commit()
                except KafkaError as e:
                    self.logger.error(f"Kafka error: {e}")
                    break
                except Exception as e:
                    self.logger.error(f"Unexpected error: {e}")
                    break
        except Exception as e:
            self.logger.error(f"Fatal error: {e}")
        finally:
            if self.consumer:
                self.consumer.close()
            self.logger.info("SCADA consumer stopped")


def main():
    output_dir = os.getenv('OUTPUT_DIR', '/workspace/scada-outbox')
    os.makedirs(output_dir, exist_ok=True)
    consumer = ScadaConsumer(
        bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092'),
        topic=os.getenv('SCADA_TOPIC', 'scada-outage-topic'),
        group_id=os.getenv('SCADA_GROUP_ID', 'scada-consumer-group'),
        output_dir=output_dir,
    )
    consumer.start()


if __name__ == "__main__":
    main()


