# API Performance Test

35초간 0.5초마다 API를 호출하여 성능을 측정하고 데이터 업데이트 3회를 확인하는 테스트입니다.

## 실행 방법

1. **의존성 설치:**
```bash
cd performance-test
pip install -r requirements.txt
# 또는
uv pip install aiohttp
```

2. **API 서버 실행 확인:**
- `docker-compose up -d serving-api` 또는 API 서버가 http://localhost:8000에서 실행 중인지 확인

3. **프로듀서 실행 (데이터 생성용):**
```bash
uv run producers/click_producer.py &
uv run producers/impression_producer.py &
```

4. **Flink 작업 실행 (10분 윈도우 집계용):**
```bash
./scripts/deploy-flink-job.sh
```

5. **테스트 실행:**
```bash
python3 api_performance_test.py
```

## 테스트 내용

- **지속시간**: 35초
- **호출 간격**: 0.1초 (총 ~350회 API 호출)
- **검증사항**: 
  - window_end 값 변화 감지 및 횟수 집계
  - 응답시간 1초 이내 (95% 이상)
  - API 성능 지표 측정 (평균 응답시간 포함)

## 출력 예시

```
🔄 WINDOW_END CHANGES:
📊 Total window_end changes detected: 3
✅ Window end transitions successfully tracked!
   Change #1: 14:23:15.123 (Call #120)
     ⏱️  Previous window duration: 12456ms
     ➡️  New windows: [1693564995000]
   Change #2: 14:23:25.456 (Call #225) 
     ⏱️  Previous window duration: 10333ms
     ➡️  New windows: [1693565595000]
   Change #3: 14:23:35.789 (Call #330)
     ⏱️  Previous window duration: 10333ms
     ➡️  New windows: [1693566195000]

📈 WINDOW DURATION STATS:
   Average window duration: 11041ms
   Total measured duration: 33122ms
📊 Final window duration: 1867ms (until test end)

⚡ PERFORMANCE METRICS:
   Total API Calls: 350
   Success Rate: 100.0%
   Calls per Second: 10.0

⏱️  RESPONSE TIME ANALYSIS:
   Average: 0.045s
   95th Percentile: 0.089s

🎯 LATENCY REQUIREMENT (< 1 second):
   ✅ SUCCESS: 100.0% of calls under 1s (350/350)
```