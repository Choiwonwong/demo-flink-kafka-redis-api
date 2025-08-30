#!/bin/bash

echo "=== Kafka-Flink-Redis CTR Calculator Setup ==="

# 전체 환경 셋업 스크립트

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

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Docker 확인
print_step "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker Desktop."
    exit 1
fi

if ! docker info &> /dev/null; then
    print_error "Docker is not running. Please start Docker Desktop."
    exit 1
fi

print_success "Docker is installed and running"

# Docker Compose 확인
print_step "Checking Docker Compose installation..."
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose."
    exit 1
fi

print_success "Docker Compose is installed"

# Python 확인
print_step "Checking Python installation..."
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is not installed. Please install Python 3."
    exit 1
fi

print_success "Python 3 is installed"

# Maven 확인
print_step "Checking Maven installation..."
if ! command -v mvn &> /dev/null; then
    print_warning "Maven is not installed. Flink app building may fail."
    print_warning "Please install Maven or build the Flink app manually."
else
    print_success "Maven is installed"
fi

# 기존 컨테이너 중지 및 제거
print_step "Stopping and removing existing containers..."
docker-compose down -v
print_success "Existing containers stopped and removed"

# 네트워크 정리
print_step "Cleaning up Docker networks..."
docker network prune -f &> /dev/null
print_success "Docker networks cleaned up"

# Flink 애플리케이션 빌드
if command -v mvn &> /dev/null; then
    print_step "Building Flink application..."
    cd flink-app
    mvn clean package -DskipTests
    if [ $? -eq 0 ]; then
        print_success "Flink application built successfully"
    else
        print_error "Failed to build Flink application"
        exit 1
    fi
    cd ..
else
    print_warning "Skipping Flink app build due to missing Maven"
fi

# Python 의존성 설치
print_step "Installing Python dependencies..."
cd producers

# uv 설치 확인
if command -v uv &> /dev/null; then
    print_step "Using uv for dependency management..."
    uv sync
    if [ $? -eq 0 ]; then
        print_success "Python dependencies installed with uv"
    else
        print_error "Failed to install dependencies with uv"
        exit 1
    fi
elif [ -f "requirements.txt" ]; then
    print_step "Using pip for dependency management..."
    pip3 install -r requirements.txt
    if [ $? -eq 0 ]; then
        print_success "Python dependencies installed with pip"
    else
        print_error "Failed to install Python dependencies with pip"
        exit 1
    fi
else
    print_error "Neither uv nor requirements.txt found"
    exit 1
fi
cd ..

# Docker 서비스 시작
print_step "Starting Docker services..."
docker-compose up -d

# 서비스 시작 대기
print_step "Waiting for services to start..."
sleep 30

# Kafka 클러스터 상태 확인
print_step "Checking Kafka cluster status..."
for i in {1..30}; do
    if docker exec kafka1 kafka-topics --bootstrap-server localhost:9092 --list &> /dev/null; then
        print_success "Kafka cluster is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Kafka cluster failed to start"
        exit 1
    fi
    echo "Waiting for Kafka... ($i/30)"
    sleep 2
done

# Kafka 토픽 생성
print_step "Creating Kafka topics..."
chmod +x scripts/create-topics.sh
./scripts/create-topics.sh

# 서비스 상태 확인
print_step "Checking service status..."
echo ""
echo "Services Status:"
echo "=================="
echo "Kafka UI: http://localhost:8080"
echo "Flink Web UI: http://localhost:8081"
echo "RedisInsight: http://localhost:5540"
echo "Fast API: http://localhost:8000"
echo ""

print_success "Setup completed successfully!"
echo ""
echo "Next steps:"
echo "1. Access Kafka UI at http://localhost:8080 to verify topics"
echo "2. Access Flink Web UI at http://localhost:8081"  
echo "3. Deploy Flink job: ./scripts/deploy-flink-job.sh"
echo "4. Start data producers: ./scripts/start-producers.sh"
echo "5. Monitor results in RedisInsight: http://localhost:5540"
echo "6. Serving API in FastAPI: http://localhost:8000"