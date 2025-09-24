#!/usr/bin/env python3
"""
Kafka Consumer for SCADA events
Consumes JSON events from scada-outage-topic and acknowledges processing.
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

        os.makedirs(self.output_dir, exist_ok=True)
        self._setup_logging()
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)

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

            # Persist lightweight processing log
            record = {
                "timestamp": datetime.now().isoformat(),
                "partition": message.partition,
                "offset": message.offset,
                "event": event,
                "source": data.get("source", "") if isinstance(data, dict) else "",
            }

            # Append to processing log
            log_path = os.path.join(self.output_dir, 'scada_events_processed.log')
            with open(log_path, 'a', encoding='utf-8') as f:
                f.write(json.dumps(record) + "\n")

            # Persist full event JSON to file
            ts = datetime.now().strftime('%Y%m%d_%H%M%S_%f')
            event_id_part = event.get('eventId') or event.get('issuerTrackingID') or "unknown"
            filename = f"scada_event_{ts}_{event_id_part}.json"
            file_path = os.path.join(self.output_dir, filename)
            with open(file_path, 'w', encoding='utf-8') as jf:
                json.dump({
                    "received_at": datetime.now().isoformat(),
                    "kafka_partition": message.partition,
                    "kafka_offset": message.offset,
                    "event": event,
                    "source": record["source"],
                }, jf, ensure_ascii=False, indent=2)

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
    output_dir = os.getenv('OUTPUT_DIR', '/workspace/Kaifa-HES-Events/SCADA')
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


