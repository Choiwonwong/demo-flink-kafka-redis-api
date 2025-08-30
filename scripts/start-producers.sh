#!/bin/bash

echo "=== Starting Data Producers ==="

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Python 의존성 확인
print_step "Checking Python dependencies..."
cd producers

# uv로 Python 실행하거나 일반 python3 사용
if command -v uv &> /dev/null && [ -f "pyproject.toml" ]; then
    print_step "Using uv environment..."
    PYTHON_CMD="uv run python"
    if ! $PYTHON_CMD -c "import kafka" &> /dev/null; then
        print_warning "Dependencies not found. Installing with uv..."
        uv sync
        if [ $? -ne 0 ]; then
            print_error "Failed to install dependencies with uv"
            exit 1
        fi
    fi
else
    print_step "Using system Python..."
    PYTHON_CMD="python3"
    if ! $PYTHON_CMD -c "import kafka" &> /dev/null; then
        print_warning "kafka-python not found. Installing dependencies..."
        if [ -f "requirements.txt" ]; then
            pip3 install -r requirements.txt
            if [ $? -ne 0 ]; then
                print_error "Failed to install dependencies with pip"
                exit 1
            fi
        else
            print_error "No requirements.txt found"
            exit 1
        fi
    fi
fi

print_success "Python dependencies are ready"

# Kafka 클러스터 연결 확인
print_step "Checking Kafka cluster connection..."
if ! docker exec kafka1 kafka-topics --bootstrap-server localhost:9092 --list | grep -E "(impressions|clicks)" &> /dev/null; then
    print_error "Required Kafka topics not found. Please run ./scripts/create-topics.sh first"
    exit 1
fi

print_success "Kafka topics are available"

# 기존 프로듀서 프로세스 종료
print_step "Stopping existing producer processes..."
pkill -f "impression_producer.py" &> /dev/null
pkill -f "click_producer.py" &> /dev/null
sleep 2
print_success "Existing producers stopped"

# 로그 디렉토리 생성
mkdir -p ../logs

# Impression Producer 시작
print_step "Starting impression producer..."
nohup $PYTHON_CMD impression_producer.py > ../logs/impression_producer.log 2>&1 &
IMPRESSION_PID=$!

if ps -p $IMPRESSION_PID > /dev/null; then
    print_success "Impression producer started (PID: $IMPRESSION_PID)"
    echo "Impression Producer PID: $IMPRESSION_PID" > ../logs/producer_pids.txt
else
    print_error "Failed to start impression producer"
    exit 1
fi

# Click Producer 시작
print_step "Starting click producer..."
nohup $PYTHON_CMD click_producer.py > ../logs/click_producer.log 2>&1 &
CLICK_PID=$!

if ps -p $CLICK_PID > /dev/null; then
    print_success "Click producer started (PID: $CLICK_PID)"
    echo "Click Producer PID: $CLICK_PID" >> ../logs/producer_pids.txt
else
    print_error "Failed to start click producer"
    kill $IMPRESSION_PID 2> /dev/null
    exit 1
fi

cd ..

# 프로듀서 상태 확인
print_step "Verifying producers are running..."
sleep 5

if ps -p $IMPRESSION_PID > /dev/null && ps -p $CLICK_PID > /dev/null; then
    print_success "Both producers are running successfully"
else
    print_error "One or more producers failed to start properly"
    exit 1
fi

print_success "Data producers started successfully!"
echo ""
echo "Producer Information:"
echo "===================="
echo "Impression Producer PID: $IMPRESSION_PID"
echo "Click Producer PID: $CLICK_PID"
echo ""
echo "Log files:"
echo "- Impression Producer: logs/impression_producer.log"
echo "- Click Producer: logs/click_producer.log"
echo ""
echo "Monitoring commands:"
echo "- View impression logs: tail -f logs/impression_producer.log"
echo "- View click logs: tail -f logs/click_producer.log"
echo "- View live topics: docker exec kafka1 kafka-console-consumer --bootstrap-server localhost:9092 --topic impressions --from-beginning"
echo ""
echo "To stop producers: ./scripts/stop-producers.sh"
echo ""
echo "You can now:"
echo "1. Monitor data in Kafka UI: http://localhost:8080"
echo "2. Deploy Flink job to process the data: ./scripts/deploy-flink-job.sh"
echo "3. View results in RedisInsight: http://localhost:8001"