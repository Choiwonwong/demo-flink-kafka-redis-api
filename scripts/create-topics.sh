#!/bin/bash

echo "=== Creating Kafka Topics ==="

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Kafka 클러스터 연결 확인
print_step "Checking Kafka cluster connection..."
if ! docker exec kafka1 kafka-topics --bootstrap-server localhost:9092 --list &> /dev/null; then
    print_error "Cannot connect to Kafka cluster. Make sure Kafka is running."
    exit 1
fi

print_success "Connected to Kafka cluster"

# impressions 토픽 생성
print_step "Creating 'impressions' topic..."
docker exec kafka1 kafka-topics \
    --create \
    --bootstrap-server localhost:9092 \
    --replication-factor 3 \
    --partitions 3 \
    --topic impressions \
    --if-not-exists

if [ $? -eq 0 ]; then
    print_success "Topic 'impressions' created successfully"
else
    print_error "Failed to create topic 'impressions'"
    exit 1
fi

# clicks 토픽 생성  
print_step "Creating 'clicks' topic..."
docker exec kafka1 kafka-topics \
    --create \
    --bootstrap-server localhost:9092 \
    --replication-factor 3 \
    --partitions 3 \
    --topic clicks \
    --if-not-exists

if [ $? -eq 0 ]; then
    print_success "Topic 'clicks' created successfully"
else
    print_error "Failed to create topic 'clicks'"
    exit 1
fi

# 토픽 리스트 확인
print_step "Listing all topics..."
docker exec kafka1 kafka-topics --bootstrap-server localhost:9092 --list

# 토픽 상세 정보 확인
print_step "Topic details:"
echo ""
echo "Impressions topic:"
docker exec kafka1 kafka-topics --bootstrap-server localhost:9092 --describe --topic impressions

echo ""
echo "Clicks topic:"
docker exec kafka1 kafka-topics --bootstrap-server localhost:9092 --describe --topic clicks

print_success "All topics created and configured successfully!"
echo ""
echo "You can now:"
echo "1. View topics in Kafka UI: http://localhost:8080"
echo "2. Start producing data: ./scripts/start-producers.sh"