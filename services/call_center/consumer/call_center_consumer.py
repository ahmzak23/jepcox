#!/usr/bin/env python3
"""
Kafka Consumer for Call Center upstream
Consumes JSON messages from call_center_upstream_topic and writes them to JSON files.
"""

import json
import os
import logging
import signal
import sys
from datetime import datetime
from typing import Dict, Any

from kafka import KafkaConsumer
from kafka.errors import KafkaError
import psycopg2
import psycopg2.pool
import requests


class CallCenterConsumer:
    def __init__(
        self,
        bootstrap_servers: str = "kafka:9092",
        topic: str = "call_center_upstream_topic",
        group_id: str = "call-center-consumer-group",
        output_dir: str = "/workspace/call-center-outbox",
    ) -> None:
        self.bootstrap_servers = bootstrap_servers
        self.topic = topic
        self.group_id = group_id
        self.output_dir = output_dir

        self.consumer = None
        self.running = True
        self.db_pool: psycopg2.pool.SimpleConnectionPool | None = None

        os.makedirs(self.output_dir, exist_ok=True)
        self._setup_logging()
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        # initialize DB pool at start
        self._init_database_connection()

    def _setup_logging(self) -> None:
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(self.output_dir, 'call_center_consumer.log')),
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
        try:
            sys.path.append(os.path.dirname(os.path.abspath(__file__)))
            from database_config import get_database_config  # type: ignore
            cfg = get_database_config().get_connection_config()
            self.db_pool = psycopg2.pool.SimpleConnectionPool(1, 10, **cfg)
            self.logger.info("Database pool initialized for Call Center consumer")
        except Exception as e:
            self.logger.error(f"Failed to initialize DB pool: {e}")
            raise

    def _store_to_database(self, payload: Dict[str, Any]) -> bool:
        if not self.db_pool:
            self.logger.error("DB pool not available")
            return False
        try:
            conn = self.db_pool.getconn()
            cur = conn.cursor()
            cur.execute("SELECT insert_callcenter_ticket_from_json(%s::jsonb)", (json.dumps(payload),))
            ticket_id = cur.fetchone()[0]
            conn.commit()
            self.logger.info(f"Stored Call Center ticket {ticket_id}")

            # Optionally call OMS ingestion API for real-time correlation
            # Enable by setting OMS_API_URL (e.g., http://localhost:9100)
            oms_api_url = os.getenv('OMS_API_URL')
            if oms_api_url:
                try:
                    payload = {
                        "event_type": "outage",
                        "source_type": "call_center",
                        "source_event_id": f"cc_{ticket_id}",
                        "timestamp": payload.get('timestamp', datetime.now().isoformat()),
                        "latitude": None,  # Call center events typically don't have lat/lng
                        "longitude": None,
                        "correlation_window_minutes": int(os.getenv('OMS_CORR_WINDOW_MIN', '30')),
                        "spatial_radius_meters": int(os.getenv('OMS_SPATIAL_RADIUS_M', '1000')),
                        "metadata": {
                            "ticket_id": payload.get('ticketId'),
                            "phone": payload.get('customer', {}).get('phone'),
                            "address": payload.get('customer', {}).get('address'),
                            "meter_number": payload.get('customer', {}).get('meterNumber')
                        }
                    }
                    requests.post(f"{oms_api_url}/api/oms/events/correlate", json=payload, timeout=5)
                except Exception as e:
                    self.logger.warning(f"OMS API call failed (non-blocking): {e}")

            return True
        except Exception as e:
            self.logger.error(f"Failed to store Call Center ticket: {e}")
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

    def _process_message(self, message) -> bool:
        try:
            data = message.value
            try:
                self.logger.info("Kafka message value: %s", json.dumps(data, ensure_ascii=False))
            except Exception:
                self.logger.info("Kafka message value (raw): %s", str(data))

            # Messages can be either from generic handle_request (body in request.body JSON string)
            # or from intake endpoint (event field). Prefer event; fallback to parsing request.body.
            payload = None
            if isinstance(data, dict) and isinstance(data.get("event"), dict):
                event = data["event"]
            elif isinstance(data, dict) and isinstance(data.get("request"), dict):
                try:
                    event = json.loads(data["request"].get("body", "") or "{}")
                except Exception:
                    event = {}
            else:
                event = {}

            if isinstance(event, dict) and all(k in event for k in ("ticketId", "timestamp", "customer")):
                payload = {
                    "ticketId": event["ticketId"],
                    "timestamp": event["timestamp"],
                    "customer": event.get("customer", {}),
                    "intake": data.get("intake", {}),
                    "source": data.get("source", "call-center-consumer"),
                    "status": "Registered",
                }
            # If not an intake event, store raw for observability through insert function (will error without required fields)
            if not payload:
                self.logger.warning("Skipping non-intake message; missing required fields")
                return True

            stored = self._store_to_database(payload)
            return stored
        except Exception as e:
            self.logger.error(f"Error processing Call Center message: {e}")
            return False

    def start(self) -> None:
        try:
            self.logger.info("Starting Call Center consumer...")
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
            self.logger.info("Call Center consumer stopped")


def main():
    output_dir = os.getenv('OUTPUT_DIR', '/workspace/call-center-outbox')
    os.makedirs(output_dir, exist_ok=True)
    consumer = CallCenterConsumer(
        bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092'),
        topic=os.getenv('CALL_CENTER_TOPIC', 'call_center_upstream_topic'),
        group_id=os.getenv('CALL_CENTER_GROUP_ID', 'call-center-consumer-group'),
        output_dir=output_dir,
    )
    consumer.start()


if __name__ == "__main__":
    main()


