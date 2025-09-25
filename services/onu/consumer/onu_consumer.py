#!/usr/bin/env python3
"""
ONU Kafka Consumer
Consumes ONU events from Kafka and stores them in the database
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


class OnuConsumer:
    def __init__(
        self,
        bootstrap_servers: str = "kafka:9092",
        topic: str = "onu-events-topic",
        group_id: str = "onu-consumer-group",
        output_dir: str = "/workspace/onu-outbox",
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
        self._init_database_connection()

    def _setup_logging(self) -> None:
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
            handlers=[
                logging.FileHandler(os.path.join(self.output_dir, 'onu_consumer.log')),
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

    def _save_message_to_file(self, data: Dict[str, Any], prefix: str = "onu_message") -> str:
        """Persist the consumed Kafka message (raw) to a JSON file under output_dir"""
        try:
            timestamp_str = datetime.now().strftime("%Y%m%d_%H%M%S_%f")[:-3]
            filename = f"{prefix}_{timestamp_str}.json"
            filepath = os.path.join(self.output_dir, filename)
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            self.logger.info(f"Saved consumed message to file: {filepath}")
            return filepath
        except Exception as e:
            self.logger.error(f"Failed to write consumed message to file: {e}")
            return ""

    def _init_database_connection(self) -> None:
        try:
            sys.path.append(os.path.dirname(os.path.abspath(__file__)))
            from database_config import get_database_config  # type: ignore
            cfg = get_database_config().get_connection_config()
            self.db_pool = psycopg2.pool.SimpleConnectionPool(1, 10, **cfg)
            self.logger.info("Database pool initialized for ONU consumer")
        except Exception as e:
            self.logger.error(f"Failed to initialize DB pool: {e}")
            raise

    def _store_to_database(self, event: Dict[str, Any]) -> bool:
        if not self.db_pool:
            self.logger.error("DB pool not available")
            return False
        try:
            conn = self.db_pool.getconn()
            cur = conn.cursor()
            
            # Call the PostgreSQL function to insert ONU event
            cur.execute("SELECT insert_onu_event_from_json(%s::jsonb)", (json.dumps(event),))
            event_id = cur.fetchone()[0]
            conn.commit()
            self.logger.info(f"Stored ONU event {event_id} to database")
            return True
        except Exception as e:
            self.logger.error(f"Failed to store ONU event to database: {e}")
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
            self.logger.info("Kafka message value: %s", json.dumps(data, ensure_ascii=False))

            # Always persist raw consumed message to JSON
            # self._save_message_to_file(data, prefix="onu_message")

            # Extract ONU event from the message
            event_data = None
            if isinstance(data, dict) and isinstance(data.get("event"), dict):
                event_data = data["event"]
                # If this is a generic envelope from upstream (body as JSON string), parse it
                if isinstance(event_data.get("body"), str):
                    try:
                        parsed = json.loads(event_data["body"])
                        if isinstance(parsed, dict):
                            event_data = parsed
                            # Ensure an eventId exists for DB uniqueness
                            if "eventId" not in event_data or not event_data.get("eventId"):
                                event_data["eventId"] = f"onu_{int(datetime.now().timestamp()*1000)}"
                    except Exception as e:
                        self.logger.warning(f"Request body is not valid JSON; skipping DB store. Error: {e}")
                        return True
            elif isinstance(data, dict) and data.get("event_type") == "ONU_Event":
                event_data = data.get("event", {})
            
            if not event_data:
                self.logger.warning("No valid ONU event found in message")
                return True

            # Validate required fields
            required_fields = ["eventId", "type", "onuId", "timestamp"]
            missing_fields = [f for f in required_fields if f not in event_data]
            if missing_fields:
                self.logger.warning(f"Missing required fields in ONU event: {missing_fields}")
                return True

            # Store to database
            stored = self._store_to_database(event_data)
            return stored

        except Exception as e:
            self.logger.error(f"Error processing ONU message: {e}")
            return False

    def start(self) -> None:
        try:
            self.logger.info("Starting ONU consumer...")
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
            self.logger.info("ONU consumer stopped")


def main():
    output_dir = os.getenv('OUTPUT_DIR', '/workspace/onu-outbox')
    os.makedirs(output_dir, exist_ok=True)
    consumer = OnuConsumer(
        bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:9092'),
        topic=os.getenv('ONU_TOPIC', 'onu-events-topic'),
        group_id=os.getenv('ONU_GROUP_ID', 'onu-consumer-group'),
        output_dir=output_dir,
    )
    consumer.start()


if __name__ == "__main__":
    main()
