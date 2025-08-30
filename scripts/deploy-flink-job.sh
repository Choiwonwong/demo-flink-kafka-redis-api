#!/bin/bash

echo "=== Deploying Flink CTR Calculator Job ==="

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

# Flink 클러스터 상태 확인
print_step "Checking Flink cluster status..."
if ! curl -s http://localhost:8081/overview &> /dev/null; then
    print_error "Flink cluster is not accessible. Make sure Flink is running."
    echo "Try: docker-compose up -d flink-jobmanager flink-taskmanager"
    exit 1
fi

print_success "Flink cluster is accessible"

# JAR 파일 존재 확인
print_step "Checking for Flink application JAR..."
JAR_FILE="flink-app/target/ctr-calculator-1.0-SNAPSHOT.jar"

if [ ! -f "$JAR_FILE" ]; then
    print_warning "JAR file not found. Building Flink application..."
    
    # Maven 확인
    if ! command -v mvn &> /dev/null; then
        print_error "Maven is not installed. Cannot build Flink application."
        print_error "Please install Maven and run: cd flink-app && mvn clean package"
        exit 1
    fi
    
    # 빌드 실행
    cd flink-app
    mvn clean package -DskipTests
    
    if [ $? -ne 0 ]; then
        print_error "Failed to build Flink application"
        exit 1
    fi
    
    cd ..
    print_success "Flink application built successfully"
fi

print_success "JAR file found: $JAR_FILE"

# 기존 job 확인 및 취소
print_step "Checking for existing jobs..."
RUNNING_JOBS=$(curl -s http://localhost:8081/jobs | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for job in data.get('jobs', []):
        if job.get('status') == 'RUNNING':
            print(job['id'])
except:
    pass
")

if [ ! -z "$RUNNING_JOBS" ]; then
    print_warning "Found running jobs. Cancelling them..."
    for job_id in $RUNNING_JOBS; do
        echo "Cancelling job: $job_id"
        curl -s -X PATCH "http://localhost:8081/jobs/$job_id" &> /dev/null
    done
    sleep 5
    print_success "Existing jobs cancelled"
fi

# JAR 업로드
print_step "Uploading JAR to Flink cluster..."
UPLOAD_RESPONSE=$(curl -s -X POST -H "Expect:" -F "jarfile=@$JAR_FILE" http://localhost:8081/jars/upload)

if [ $? -ne 0 ]; then
    print_error "Failed to upload JAR file"
    exit 1
fi

# JAR ID 추출
JAR_ID=$(echo $UPLOAD_RESPONSE | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    filename = data['filename']
    print(filename.split('/')[-1])
except Exception as e:
    print('', file=sys.stderr)
    exit(1)
")

if [ -z "$JAR_ID" ]; then
    print_error "Failed to extract JAR ID from upload response"
    echo "Upload response: $UPLOAD_RESPONSE"
    exit 1
fi

print_success "JAR uploaded successfully. JAR ID: $JAR_ID"

# Job 실행
print_step "Starting CTR Calculator job..."
JOB_RESPONSE=$(curl -s -X POST "http://localhost:8081/jars/$JAR_ID/run" \
    -H "Content-Type: application/json" \
    -d '{
        "entryClass": "com.example.ctr.CTRCalculatorJob",
        "parallelism": 2,
        "programArgs": "",
        "savepointPath": null
    }')

if [ $? -ne 0 ]; then
    print_error "Failed to start job"
    exit 1
fi

# Job ID 추출
JOB_ID=$(echo $JOB_RESPONSE | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['jobid'])
except:
    print('', file=sys.stderr)
    exit(1)
")

if [ -z "$JOB_ID" ]; then
    print_error "Failed to extract job ID from response"
    echo "Job response: $JOB_RESPONSE"
    exit 1
fi

print_success "CTR Calculator job started successfully!"
echo ""
echo "Job Information:"
echo "================"
echo "Job ID: $JOB_ID"
echo "JAR ID: $JAR_ID"
echo ""
echo "Monitoring:"
echo "- Flink Web UI: http://localhost:8081"
echo "- Job Details: http://localhost:8081/#/job/$JOB_ID/overview"
echo ""

# Job 상태 확인
print_step "Checking job status..."
sleep 5

JOB_STATUS=$(curl -s "http://localhost:8081/jobs/$JOB_ID" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['state'])
except:
    print('UNKNOWN')
")

echo "Current job status: $JOB_STATUS"

if [ "$JOB_STATUS" = "RUNNING" ]; then
    print_success "Job is running successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Make sure producers are running: ./scripts/start-producers.sh"
    echo "2. Monitor CTR results in RedisInsight: http://localhost:8001"
    echo "3. View job metrics in Flink UI: http://localhost:8081"
elif [ "$JOB_STATUS" = "CREATED" ] || [ "$JOB_STATUS" = "INITIALIZING" ]; then
    print_warning "Job is initializing. Check status in a few moments."
else
    print_warning "Job status is: $JOB_STATUS. Check Flink UI for details."
fi

echo ""
echo "To monitor job logs:"
echo "docker logs flink-taskmanager"
echo ""
echo "To cancel the job:"
echo "curl -X PATCH http://localhost:8081/jobs/$JOB_ID"