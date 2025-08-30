#!/usr/bin/env python3
import json
import time
import random
from datetime import datetime
from kafka import KafkaProducer

class ClickProducer:
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
        # 상품별 클릭률 차등 적용 (product1이 가장 높은 클릭률)
        self.product_click_rates = {
            'product1': 0.8,  # 80% 확률
            'product2': 0.6,  # 60% 확률
            'product3': 0.4,  # 40% 확률
            'product4': 0.3,  # 30% 확률
            'product5': 0.2   # 20% 확률
        }
        self.session_counter = 1000
    
    def generate_click_event(self):
        current_time = int(datetime.now().timestamp() * 1000)
        user_id = random.choice(self.users)
        product_id = random.choice(self.products)
        
        # 상품별 클릭 확률에 따라 클릭 이벤트 생성 여부 결정
        click_probability = self.product_click_rates[product_id]
        
        if random.random() < click_probability:
            event = {
                "user_id": user_id,
                "product_id": product_id,
                "timestamp": current_time,
                "event_type": "click",
                "session_id": f"session_{self.session_counter + random.randint(1, 100)}"
            }
            return event
        return None
    
    def run(self):
        print("Starting click producer...")
        print(f"Sending click events every 0.5 seconds (2x increased rate, probabilistic)")
        print(f"Click rates: {self.product_click_rates}")
        
        try:
            while True:
                event = self.generate_click_event()
                
                if event:
                    # Send to Kafka topic with product_id as key for partitioning
                    future = self.producer.send(
                        'clicks',
                        key=event['product_id'],
                        value=event
                    )
                    
                    # Log the sent event
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] Sent click: {event['user_id']} -> {event['product_id']}")
                else:
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] No click generated")
                
                time.sleep(0.002)  # 0.5초마다 시도 (기존 2배 증가)
                
        except KeyboardInterrupt:
            print("\nStopping click producer...")
        finally:
            self.producer.close()

if __name__ == "__main__":
    producer = ClickProducer()
    producer.run()