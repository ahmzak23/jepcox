#!/usr/bin/env python3
import json
import logging
from datetime import datetime
from flask import Flask, request, jsonify
from kafka import KafkaProducer
import os

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

app = Flask(__name__)

class KafkaPublisher:
    def __init__(self):
        self.kafka_producer = None
        self.topic = "hes-kaifa-outage-topic"
        
    def connect_kafka(self):
        try:
            self.kafka_producer = KafkaProducer(
                bootstrap_servers=['kafka:9092'],
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
    
    def publish_request_to_kafka(self, request_data):
        try:
            # Create message for Kafka
            message = {
                "timestamp": datetime.now().isoformat(),
                "source": "web2-hes-mock-generator",
                "request": {
                    "method": request_data["method"],
                    "uri": request_data["uri"],
                    "remote_addr": request_data["remote_addr"],
                    "user_agent": request_data.get("user_agent", ""),
                    "content_type": request_data.get("content_type", ""),
                    "content_length": request_data.get("content_length", 0),
                    "body": request_data.get("body", ""),
                    "headers": request_data.get("headers", {})
                },
                "topic": self.topic,
                "processed_at": datetime.now().isoformat()
            }
            
            # Generate a unique key
            key = f"web2-{request_data['remote_addr']}-{datetime.now().timestamp()}"
            
            # Publish to Kafka
            future = self.kafka_producer.send(self.topic, key=key, value=message)
            record_metadata = future.get(timeout=10)
            
            logger.info(f"✅ Published to Kafka: {record_metadata.topic}:{record_metadata.partition}:{record_metadata.offset}")
            return True, record_metadata
            
        except Exception as e:
            logger.error(f"❌ Failed to publish to Kafka: {e}")
            return False, str(e)

# Global Kafka publisher instance
kafka_publisher = KafkaPublisher()

@app.route('/', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
@app.route('/<path:path>', methods=['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS'])
def handle_request(path=None):
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
        success, result = kafka_publisher.publish_request_to_kafka(request_data)
        
        # Prepare response
        response_data = {
            "message": "hello web2 - Request published to Kafka topic: hes-kaifa-outage-topic",
            "kafka_topic": "hes-kaifa-outage-topic",
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
        else:
            response_data["kafka_error"] = result
        
        return jsonify(response_data), 200
        
    except Exception as e:
        logger.error(f"❌ Error handling request: {e}")
        return jsonify({
            "error": "Internal server error",
            "message": str(e)
        }), 500

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "web2-kafka-service",
        "timestamp": datetime.now().isoformat()
    })

if __name__ == "__main__":
    logger.info("🚀 Starting Web2 Kafka Service")
    
    # Connect to Kafka
    if kafka_publisher.connect_kafka():
        logger.info("✅ Kafka connection established")
        app.run(host='0.0.0.0', port=80, debug=False)
    else:
        logger.error("❌ Failed to connect to Kafka. Exiting.")
        exit(1)
