#!/usr/bin/env python3
"""
ONU Kafka Producer Service
Handles ONU events, meter mapping, and SSE alarm streaming
"""

import json
import time
import logging
import secrets
import threading
from datetime import datetime
from typing import Dict, Any, List, Set
from flask import Flask, request, jsonify, Response, stream_with_context
from kafka import KafkaProducer
from kafka.errors import KafkaError

# Flask app setup
app = Flask(__name__)

# Configuration
KAFKA_BOOTSTRAP_SERVERS = ['kafka:9092']
TOPIC = 'onu-events-topic'
LOG_FILE = '/workspace/onu/logs/onu_events.log'

# Global variables for SSE
sse_clients: Set[Any] = set()
sse_lock = threading.Lock()

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class KafkaPublisher:
    def __init__(self):
        self.kafka_producer = None
        self.topic = TOPIC
        
    def connect_kafka(self):
        try:
            self.kafka_producer = KafkaProducer(
                bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS,
                value_serializer=lambda v: json.dumps(v).encode('utf-8'),
                key_serializer=lambda k: k.encode('utf-8') if k else None,
                retries=3,
                batch_size=16384,
                linger_ms=10,
                buffer_memory=33554432,
            )
            logger.info("✅ Connected to Kafka producer")
            return True
        except Exception as e:
            logger.error(f"❌ Failed to connect to Kafka: {e}")
            return False
    
    def publish_event_to_kafka(self, event_data: Dict[str, Any], source: str = "onu-upstream") -> tuple[bool, str]:
        if not self.kafka_producer:
            if not self.connect_kafka():
                return False, "Kafka connection failed"
        
        try:
            # Prepare message for Kafka
            kafka_message = {
                "timestamp": datetime.now().isoformat(),
                "source": source,
                "event_type": "ONU_Event",
                "event": event_data,
                "topic": self.topic,
                "processed_at": datetime.now().isoformat()
            }
            
            # Publish to Kafka
            future = self.kafka_producer.send(
                self.topic,
                key=str(event_data.get('onuId', 'unknown')),
                value=kafka_message
            )
            
            # Wait for confirmation
            record_metadata = future.get(timeout=10)
            logger.info(f"✅ Published ONU event to Kafka: {record_metadata.topic}:{record_metadata.partition}:{record_metadata.offset}")
            
            return True, "Event published successfully"
            
        except Exception as e:
            logger.error(f"❌ Failed to publish ONU event to Kafka: {e}")
            return False, str(e)
    
    def close(self):
        if self.kafka_producer:
            self.kafka_producer.close()


# Initialize Kafka publisher
kafka_publisher = KafkaPublisher()


def _validate_onu_event_payload(payload: Dict[str, Any]) -> tuple[bool, List[str]]:
    """Validate ONU event payload"""
    required_fields = ["type", "onuId", "timestamp"]
    missing_fields = [f for f in required_fields if f not in payload]
    
    if missing_fields:
        return False, missing_fields
    
    # Validate event type
    valid_types = ["ONU_LastGaspAlert", "ONU_PowerRestored"]
    if payload.get("type") not in valid_types:
        return False, ["Invalid event type. Must be one of: " + ", ".join(valid_types)]
    
    return True, []


def _validate_meter_mapping_payload(payload: Dict[str, Any]) -> tuple[bool, List[str]]:
    """Validate meter mapping payload"""
    required_fields = ["meterId"]
    missing_fields = [f for f in required_fields if f not in payload]
    
    if missing_fields:
        return False, missing_fields
    
    return True, []


def _log_onu_event(event_data: Dict[str, Any], source: str = "onu-upstream"):
    """Log ONU event to file"""
    try:
        log_entry = {
            "timestamp": datetime.now().isoformat(),
            "type": "ONU_EVENT",
            "event": event_data,
            "source": source
        }
        
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            f.write(json.dumps(log_entry, ensure_ascii=False) + '\n')
            
    except Exception as e:
        logger.error(f"Failed to log ONU event: {e}")


def _broadcast_sse_alarm(alarm_data: Dict[str, Any]):
    """Broadcast alarm to all SSE clients"""
    try:
        with sse_lock:
            if not sse_clients:
                return
            
            # Format alarm data for SSE
            sse_data = {
                "category": alarm_data.get("category", "fault"),
                "parcel": alarm_data.get("parcel", ""),
                "serial": alarm_data.get("serial", ""),
                "alarmType": alarm_data.get("alarmType", "power")
            }
            
            # Send to all connected clients
            disconnected_clients = set()
            for client in sse_clients:
                try:
                    client.write(f"data: {json.dumps(sse_data)}\n\n")
                    client.flush()
                except Exception:
                    disconnected_clients.add(client)
            
            # Remove disconnected clients
            sse_clients -= disconnected_clients
            
    except Exception as e:
        logger.error(f"Failed to broadcast SSE alarm: {e}")


@app.route("/onu-event", methods=["POST"])
def onu_event():
    """Handle ONU event processing"""
    start_time = time.time()
    
    try:
        payload = request.get_json(silent=True)
        if payload is None:
            return jsonify({"success": False, "error": "Invalid JSON"}), 400
        
        # Validate payload
        is_valid, missing_fields = _validate_onu_event_payload(payload)
        if not is_valid:
            return jsonify({"success": False, "error": f"Missing required fields: {', '.join(missing_fields)}"}), 400
        
        # Generate unique event ID
        event_id = f"onu_{int(time.time()*1000)}_{secrets.token_hex(3)}"
        
        # Prepare event data
        event_data = {
            "eventId": event_id,
            "type": payload["type"],
            "onuId": payload["onuId"],
            "onuSerial": payload.get("onuSerial", ""),
            "timestamp": payload["timestamp"],
            "location": payload.get("location", {}),
            "associatedMeters": payload.get("associatedMeters", []),
            "nmsType": payload.get("nmsType", ""),
            "alarmData": payload.get("alarmData", {}),
            "status": "Received"
        }
        
        # Log event
        _log_onu_event(event_data)
        
        # Publish to Kafka
        success, result = kafka_publisher.publish_event_to_kafka(event_data)
        if not success:
            logger.error(f"Failed to publish ONU event to Kafka: {result}")
        
        # Broadcast alarm via SSE if it's an alarm event
        if payload.get("alarmData"):
            _broadcast_sse_alarm(payload["alarmData"])
        
        # Calculate processing time
        processing_time = round((time.time() - start_time) * 1000, 1)
        
        response_data = {
            "success": True,
            "message": "ONU event processed",
            "data": {
                "eventId": event_id,
                "status": "Received",
                "timestamp": payload["timestamp"]
            }
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"Error processing ONU event: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@app.route("/api/onu/map-meter", methods=["POST"])
def map_meter():
    """Handle meter-to-ONU mapping"""
    try:
        payload = request.get_json(silent=True)
        if payload is None:
            return jsonify({"success": False, "error": "Invalid JSON"}), 400
        
        # Validate payload
        is_valid, missing_fields = _validate_meter_mapping_payload(payload)
        if not is_valid:
            return jsonify({"success": False, "error": f"Missing required fields: {', '.join(missing_fields)}"}), 400
        
        meter_id = payload["meterId"]
        
        # Simulate database lookup (in real implementation, this would query the database)
        # For now, return mock data based on the meter ID
        mock_mapping = {
            "M12345678": {
                "onuId": 3230316,
                "buildingId": "05040835035",
                "location": {"lat": 31.9454, "lng": 35.9284},
                "nmsType": "FiberTech"
            },
            "M23456789": {
                "onuId": 3230317,
                "buildingId": "05040835036",
                "location": {"lat": 31.9464, "lng": 35.9294},
                "nmsType": "FiberTech"
            }
        }
        
        if meter_id not in mock_mapping:
            return jsonify({"success": False, "error": "Meter not found"}), 404
        
        mapping_data = mock_mapping[meter_id]
        
        response_data = {
            "success": True,
            "message": "Meter mapping successful",
            "data": mapping_data
        }
        
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"Error processing meter mapping: {e}")
        return jsonify({"success": False, "error": "Internal server error"}), 500


@app.route("/api/onu/alarms")
def sse_alarms():
    """Server-Sent Events endpoint for real-time alarm streaming"""
    def event_stream():
        # Add client to the set
        with sse_lock:
            sse_clients.add(request.environ['wsgi.input'])
        
        try:
            # Send initial connection message
            yield f"data: {json.dumps({'type': 'connected', 'timestamp': datetime.now().isoformat()})}\n\n"
            
            # Keep connection alive with periodic pings
            while True:
                yield f"data: {json.dumps({'type': 'ping', 'timestamp': datetime.now().isoformat()})}\n\n"
                time.sleep(30)  # Send ping every 30 seconds
                
        except GeneratorExit:
            # Client disconnected
            with sse_lock:
                sse_clients.discard(request.environ['wsgi.input'])
    
    return Response(
        stream_with_context(event_stream()),
        mimetype='text/event-stream',
        headers={
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Access-Control-Allow-Origin': '*'
        }
    )


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    return jsonify({
        "status": "healthy",
        "service": "onu-upstream",
        "timestamp": datetime.now().isoformat(),
        "kafka_connected": kafka_publisher.kafka_producer is not None
    }), 200


@app.route('/', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
def handle_request(path=None):
    """Generic request handler for any requests"""
    try:
        # Collect request information
        request_data = {
            "method": request.method,
            "uri": request.url,
            "path": path or "/",
            "remote_addr": request.environ.get('REMOTE_ADDR', 'unknown'),
            "user_agent": request.headers.get('User-Agent', ''),
            "content_type": request.content_type or '',
            "content_length": request.content_length or 0,
            "body": "",
            "headers": dict(request.headers)
        }
        
        # Read request body for POST/PUT/PATCH requests
        if request.method in ['POST', 'PUT', 'PATCH']:
            try:
                request_data["body"] = request.get_data(as_text=True) or ""
            except Exception as e:
                logger.warning(f"Could not read request body: {e}")
        
        # Publish to Kafka
        success, result = kafka_publisher.publish_event_to_kafka(request_data, "onu-generic-request")
        
        # Prepare response
        response_data = {
            "message": "hello onu - Request published to Kafka topic: onu-events-topic",
            "kafka_topic": "onu-events-topic",
            "kafka_published": success,
            "request_method": request_data["method"],
            "request_uri": request_data["uri"],
            "request_path": request_data["path"],
            "timestamp": datetime.now().isoformat()
        }
        
        if success:
            response_data["kafka_info"] = {
                "message": "Published successfully",
                "result": result
            }
        else:
            response_data["kafka_error"] = result
        
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"❌ Error handling request: {e}")
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500


if __name__ == "__main__":
    # Initialize Kafka connection
    kafka_publisher.connect_kafka()
    
    # Start Flask app
    app.run(host='0.0.0.0', port=80, debug=False)
