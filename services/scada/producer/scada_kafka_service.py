#!/usr/bin/env python3
import json
import logging
import time
from datetime import datetime
from typing import Dict, List, Tuple

from flask import Flask, request, jsonify
from kafka import KafkaProducer


app = Flask(__name__)


def build_kafka_producer() -> KafkaProducer:
    return KafkaProducer(
        bootstrap_servers=["kafka:9092"],
        value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        key_serializer=lambda k: k.encode("utf-8") if k else None,
        retries=3,
        linger_ms=10,
    )


producer = None
TOPIC = "scada-outage-topic"
LOG_PATH = "scada-events.log"


def validate_scada_event(payload: Dict) -> Tuple[bool, List[str]]:
    required = [
        ("eventType", str),
        ("substationId", str),
        ("feederId", str),
        ("mainStationId", str),
        ("alarmType", str),
        ("timestamp", str),
        ("voltage", (int, float)),
    ]
    missing_or_invalid: List[str] = []
    for field, ftype in required:
        if field not in payload:
            missing_or_invalid.append(field)
        else:
            val = payload[field]
            if isinstance(ftype, tuple):
                if not isinstance(val, ftype):
                    missing_or_invalid.append(field)
            else:
                if not isinstance(val, ftype):
                    missing_or_invalid.append(field)
    return (len(missing_or_invalid) == 0), missing_or_invalid


def persist_scada_log(event: Dict, source: str) -> None:
    record = {
        "timestamp": datetime.now().isoformat(),
        "type": "SCADA_EVENT",
        "event": event,
        "source": source or "",
    }
    with open(LOG_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(record) + "\n")


@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "service": "scada-kafka-service"})


@app.route("/scada-mock-generator", methods=["POST"])
def scada_mock_generator():
    start = time.time()
    try:
        if request.content_type is None or not request.content_type.startswith("application/json"):
            return (
                jsonify({"success": False, "error": "Content-Type must be application/json"}),
                400,
            )

        payload = request.get_json(silent=True)
        if payload is None:
            return jsonify({"success": False, "error": "Invalid JSON"}), 400

        ok, problems = validate_scada_event(payload)
        if not ok:
            return (
                jsonify({
                    "success": False,
                    "error": f"Missing required fields: {', '.join(problems)}",
                }),
                400,
            )

        source = request.headers.get("X-SCADA-Source", "")

        # persist structured log
        persist_scada_log(payload, source)

        # publish to Kafka
        key = f"scada-{payload['substationId']}-{int(time.time()*1000)}"
        message = {
            "timestamp": datetime.now().isoformat(),
            "source": source or "scada-mock-generator",
            "event": payload,
            "topic": TOPIC,
            "processed_at": datetime.now().isoformat(),
        }
        future = producer.send(TOPIC, key=key, value=message)
        meta = future.get(timeout=10)

        resp = {
            "success": True,
            "message": "SCADA event processed successfully",
            "data": {
                "eventId": key,
                "status": "Processed",
                "omsResponse": "200 OK",
                "processingTime": round((time.time() - start) * 1000, 1),
                "timestamp": datetime.now().isoformat(),
            },
            "event": payload,
            "kafka": {
                "topic": meta.topic,
                "partition": meta.partition,
                "offset": meta.offset,
            },
        }
        return jsonify(resp), 200

    except Exception as e:
        return jsonify({"success": False, "error": str(e)}), 500


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    try:
        producer = build_kafka_producer()
        logging.info("Kafka producer connected for SCADA service")
    except Exception as e:
        logging.error(f"Failed to initialize Kafka producer: {e}")
        raise

    app.run(host="0.0.0.0", port=80, debug=False)


