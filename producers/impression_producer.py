#!/usr/bin/env python3
import json
import time
import random
from datetime import datetime
from kafka import KafkaProducer

class ImpressionProducer:
    def __init__(self, bootstrap_servers=['localhost:9092', 'localhost:9093', 'localhost:9094']):
        self.producer = KafkaProducer(
            bootstrap_servers=bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode('utf-8'),
            key_serializer=lambda k: k.encode('utf-8'),
            acks='all',
            retries=3,
            retry_backoff_ms=100
        )
        self.users = ['user1', 'user2', 'user3', 'user4', 'user5']
        self.products = ['product1', 'product2', 'product3', 'product4', 'product5']
        self.session_counter = 1000
    
    def generate_impression_event(self):
        current_time = int(datetime.now().timestamp() * 1000)
        user_id = random.choice(self.users)
        product_id = random.choice(self.products)
        
        event = {
            "user_id": user_id,
            "product_id": product_id,
            "timestamp": current_time,
            "event_type": "impression",
            "session_id": f"session_{self.session_counter + random.randint(1, 100)}"
        }
        return event
    
    def run(self):
        print("Starting impression producer...")
        print(f"Sending impression events every 0.25 seconds (2x increased rate)")
        
        try:
            while True:
                event = self.generate_impression_event()
                
                # Send to Kafka topic with product_id as key for partitioning
                future = self.producer.send(
                    'impressions',
                    key=event['product_id'],
                    value=event
                )
                
                # Log the sent event
                print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent impression: {event['user_id']} -> {event['product_id']}")
                
                time.sleep(0.001)  # 0.25초마다 전송 (기존 2배 증가)
                
        except KeyboardInterrupt:
            print("\nStopping impression producer...")
        finally:
            self.producer.close()

if __name__ == "__main__":
    producer = ImpressionProducer()
    producer.run()