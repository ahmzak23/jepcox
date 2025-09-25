#!/usr/bin/env python3
import json
import logging
import time
from datetime import datetime
from typing import Dict, List, Tuple, Optional
from flask import Flask, request, jsonify
from kafka import KafkaProducer

app = Flask(__name__)

_STATUS_STORE: Dict[str, Dict] = {}
_STATUS_SEQUENCE = [
    (0, "Registered"),
    (60, "Crew Assigned"),
    (180, "In Progress"),
    (360, "Partially Restored"),
    (600, "Restored"),
]


class KafkaPublisher:
    def __init__(self) -> None:
        self.kafka_producer: KafkaProducer | None = None
        self.topic: str = "call_center_upstream_topic"

    def connect_kafka(self) -> bool:
        try:
            self.kafka_producer = KafkaProducer(
                bootstrap_servers=["kafka:9092"],
                value_serializer=lambda v: json.dumps(v).encode("utf-8"),
                key_serializer=lambda k: k.encode("utf-8") if k else None,
                retries=3,
                batch_size=16384,
                linger_ms=10,
                buffer_memory=33554432,
            )
            app.logger.info("✅ Connected to Kafka producer (call center)")
            return True
        except Exception as e:
            app.logger.error(f"❌ Failed to connect to Kafka: {e}")
            return False

    def publish_request_to_kafka(self, request_data: dict) -> tuple[bool, object]:
        try:
            message = {
                "timestamp": datetime.now().isoformat(),
                "source": "call-center-upstream",
                "request": request_data,
                "topic": self.topic,
                "processed_at": datetime.now().isoformat(),
            }
            key = f"callcenter-{request_data['remote_addr']}-{int(datetime.now().timestamp()*1000)}"
            future = self.kafka_producer.send(self.topic, key=key, value=message)  # type: ignore[arg-type]
            record_metadata = future.get(timeout=10)
            app.logger.info(
                f"✅ Published to Kafka: {record_metadata.topic}:{record_metadata.partition}:{record_metadata.offset}"
            )
            return True, record_metadata
        except Exception as e:
            app.logger.error(f"❌ Failed to publish to Kafka: {e}")
            return False, str(e)


kafka_publisher = KafkaPublisher()


def validate_intake(payload: Dict) -> Tuple[bool, List[str]]:
    required = [
        ("ticketId", str),
        ("timestamp", str),
        ("customer", dict),
    ]
    problems: List[str] = []
    for field, ftype in required:
        if field not in payload:
            problems.append(field)
        else:
            if not isinstance(payload[field], ftype):
                problems.append(field)
    return (len(problems) == 0), problems


def generate_ids(ticket_id: str) -> Tuple[str, str]:
    base = ticket_id.replace(" ", "_")
    millis = int(time.time() * 1000)
    intake_id = f"tc_{millis}_{base[-6:]}"
    oms_event_id = f"evt_{base[:3]}{millis % 1000:03d}"
    return intake_id, oms_event_id


def compute_status(created_at: float) -> str:
    elapsed = time.time() - created_at
    current = _STATUS_SEQUENCE[0][1]
    for sec, status in _STATUS_SEQUENCE:
        if elapsed >= sec:
            current = status
        else:
            break
    return current


def find_status(ticket_id: Optional[str], oms_event_id: Optional[str]) -> Optional[Dict]:
    if ticket_id and ticket_id in _STATUS_STORE:
        return _STATUS_STORE[ticket_id]
    if oms_event_id:
        for v in _STATUS_STORE.values():
            if v.get("omsEventId") == oms_event_id:
                return v
    return None


@app.route('/', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
@app.route('/call-center-ticket-generator', methods=['GET', 'POST'])
def handle_request(path=None):
    try:
        request_data = {
            "method": request.method,
            "uri": request.url,
            "path": path or request.path,
            "remote_addr": request.environ.get('REMOTE_ADDR', 'unknown'),
            "user_agent": request.headers.get('User-Agent', ''),
            "content_type": request.content_type or '',
            "content_length": request.content_length or 0,
            "body": "",
            "headers": dict(request.headers)
        }

        if request.method in ['POST', 'PUT', 'PATCH']:
            try:
                request_data["body"] = request.get_data(as_text=True) or ""
            except Exception:
                request_data["body"] = ""

        success, result = kafka_publisher.publish_request_to_kafka(request_data)

        response_data = {
            "message": f"call-center upstream published: {request_data['method']} {request_data['path']}",
            "kafka_topic": kafka_publisher.topic,
            "kafka_published": success,
            "request_method": request_data["method"],
            "request_uri": request_data["uri"],
            "request_path": request_data["path"],
            "timestamp": datetime.now().isoformat()
        }

        if success:
            response_data["kafka_info"] = {
                "topic": result.topic,
                "partition": result.partition,
                "offset": result.offset
            }
            return jsonify(response_data), 200
        else:
            response_data["kafka_error"] = result
            return jsonify(response_data), 500

    except Exception as e:
        app.logger.error(f"❌ Error handling request: {e}")
        return jsonify({"error": "Internal server error", "message": str(e)}), 500


@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "call-center-kafka-service",
        "timestamp": datetime.now().isoformat()
    })


@app.route("/trouble-call/intake", methods=["POST"])
def trouble_call_intake():
    if request.content_type is None or not request.content_type.startswith("application/json"):
        return jsonify({"success": False, "error": "Content-Type must be application/json"}), 400

    payload = request.get_json(silent=True)
    if payload is None:
        return jsonify({"success": False, "error": "Invalid JSON"}), 400

    ok, problems = validate_intake(payload)
    if not ok:
        return jsonify({"success": False, "error": f"Missing required fields: {', '.join(problems)}"}), 400

    intake_id, oms_event_id = generate_ids(payload["ticketId"])
    _STATUS_STORE[payload["ticketId"]] = {
        "intakeId": intake_id,
        "omsEventId": oms_event_id,
        "created_at": time.time(),
    }

    # publish intake to Kafka (optional envelope similar to handle_request)
    message = {
        "timestamp": datetime.now().isoformat(),
        "source": request.headers.get("X-Source", "call-center-intake"),
        "event": payload,
        "intake": {"intakeId": intake_id, "omsEventId": oms_event_id},
        "topic": kafka_publisher.topic,
        "processed_at": datetime.now().isoformat(),
    }
    try:
        key = f"callcenter-{payload['ticketId']}"
        kafka_publisher.kafka_producer.send(kafka_publisher.topic, key=key, value=message).get(timeout=10)  # type: ignore[arg-type]
    except Exception:
        pass

    return jsonify({
        "success": True,
        "message": "Trouble call ingested",
        "data": {
            "intakeId": intake_id,
            "omsEventId": oms_event_id,
            "status": "Received",
            "timestamp": payload.get("timestamp", datetime.now().isoformat()),
        }
    }), 200


@app.route("/trouble-call/status", methods=["GET"])
def trouble_call_status():
    ticket_id = request.args.get("ticketId")
    oms_event_id = request.args.get("omsEventId")
    if not ticket_id and not oms_event_id:
        return jsonify({"success": False, "error": "Provide ticketId or omsEventId"}), 400
    info = find_status(ticket_id, oms_event_id)
    if not info:
        return jsonify({"success": False, "error": "Not found"}), 404
    status = compute_status(info["created_at"])
    return jsonify({
        "success": True,
        "ticketId": ticket_id or "",
        "omsEventId": info["omsEventId"],
        "status": status,
        "updatedAt": datetime.now().isoformat(),
    }), 200


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    if kafka_publisher.connect_kafka():
        logging.info("✅ Kafka connection established (call-center)")
        app.run(host='0.0.0.0', port=80, debug=False)
    else:
        logging.error("❌ Failed to connect to Kafka. Exiting.")
        exit(1)


# Generic catch-all similar to web2_kafka_service to mirror upstream handling
@app.route('/call-center-ticket-generator', methods=['GET', 'POST'])
@app.route('/', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
def handle_request(path=None):
    try:
        request_data = {
            "method": request.method,
            "uri": request.url,
            "path": path or request.path,
            "remote_addr": request.environ.get('REMOTE_ADDR', 'unknown'),
            "user_agent": request.headers.get('User-Agent', ''),
            "content_type": request.content_type or '',
            "content_length": request.content_length or 0,
            "body": "",
            "headers": dict(request.headers)
        }

        if request.method in ['POST', 'PUT', 'PATCH']:
            try:
                request_data["body"] = request.get_data(as_text=True) or ""
            except Exception:
                request_data["body"] = ""

        message = {
            "timestamp": datetime.now().isoformat(),
            "source": "call-center-handle-request",
            "request": request_data,
            "topic": TOPIC,
            "processed_at": datetime.now().isoformat()
        }
        key = f"callcenter-{request_data['remote_addr']}-{int(time.time()*1000)}"
        meta = producer.send(TOPIC, key=key, value=message).get(timeout=10)

        resp = {
            "message": f"Call center upstream received {request_data['method']} {request_data['path']}",
            "kafka_topic": TOPIC,
            "kafka_info": {"topic": meta.topic, "partition": meta.partition, "offset": meta.offset},
            "timestamp": datetime.now().isoformat()
        }
        return jsonify(resp), 200
    except Exception as e:
        return jsonify({"error": "Internal server error", "message": str(e)}), 500


