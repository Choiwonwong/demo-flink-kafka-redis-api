#!/bin/bash

echo "=== Stopping Flink Jobs ==="

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

# 실행 중인 job 확인
print_step "Checking for running jobs..."
JOBS_INFO=$(curl -s http://localhost:8081/jobs | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    jobs = data.get('jobs', [])
    running_jobs = []
    for job in jobs:
        if job.get('status') == 'RUNNING':
            running_jobs.append(job['id'])
    
    if running_jobs:
        print('RUNNING_JOBS=' + ' '.join(running_jobs))
    else:
        print('NO_RUNNING_JOBS')
except Exception as e:
    print('ERROR')
")

if [ "$JOBS_INFO" = "ERROR" ]; then
    print_error "Failed to fetch job information"
    exit 1
elif [ "$JOBS_INFO" = "NO_RUNNING_JOBS" ]; then
    print_warning "No running jobs found"
    echo ""
    echo "Current jobs status:"
    curl -s http://localhost:8081/jobs | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    jobs = data.get('jobs', [])
    if not jobs:
        print('No jobs found')
    else:
        for job in jobs:
            print(f\"Job ID: {job['id']}, Status: {job['status']}\")
except:
    print('Failed to parse job information')
"
    exit 0
fi

# 실행 중인 job들 추출
RUNNING_JOBS=$(echo "$JOBS_INFO" | grep "RUNNING_JOBS=" | cut -d'=' -f2)

if [ -z "$RUNNING_JOBS" ]; then
    print_warning "No running jobs to stop"
    exit 0
fi

print_warning "Found running jobs. Stopping them..."
echo "Jobs to stop: $RUNNING_JOBS"

# 각 job 중단
for job_id in $RUNNING_JOBS; do
    print_step "Stopping job: $job_id"
    
    # Job 상세 정보 가져오기
    JOB_DETAILS=$(curl -s "http://localhost:8081/jobs/$job_id")
    JOB_NAME=$(echo "$JOB_DETAILS" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data.get('name', 'Unknown Job'))
except:
    print('Unknown Job')
")
    
    echo "Job Name: $JOB_NAME"
    
    # Job 중단 요청
    CANCEL_RESPONSE=$(curl -s -X PATCH "http://localhost:8081/jobs/$job_id")
    
    if [ $? -eq 0 ]; then
        print_success "Stop request sent for job: $job_id"
    else
        print_error "Failed to send stop request for job: $job_id"
        continue
    fi
done

# 잠시 대기 후 상태 확인
print_step "Waiting for jobs to stop..."
sleep 5

# 최종 상태 확인
print_step "Checking final job status..."
for job_id in $RUNNING_JOBS; do
    JOB_STATUS=$(curl -s "http://localhost:8081/jobs/$job_id" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(data['state'])
except:
    print('UNKNOWN')
")
    
    if [ "$JOB_STATUS" = "CANCELED" ] || [ "$JOB_STATUS" = "FINISHED" ]; then
        print_success "Job $job_id stopped successfully (Status: $JOB_STATUS)"
    elif [ "$JOB_STATUS" = "CANCELLING" ]; then
        print_warning "Job $job_id is still stopping (Status: $JOB_STATUS)"
    else
        print_error "Job $job_id may not have stopped properly (Status: $JOB_STATUS)"
    fi
done

echo ""
print_success "Job stop process completed!"
echo ""
echo "Useful commands:"
echo "- Check all jobs: curl -s http://localhost:8081/jobs | python3 -m json.tool"
echo "- View Flink UI: http://localhost:8081"
echo "- Restart jobs: ./scripts/deploy-flink-job.sh"