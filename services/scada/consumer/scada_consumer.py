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
            cur.execute("SELECT insert_scada_event_from_json(%s::jsonb)", (json.dumps(payload),))
            ev_id = cur.fetchone()[0]
            conn.commit()
            self.logger.info(f"Stored SCADA event {ev_id} to database")
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


