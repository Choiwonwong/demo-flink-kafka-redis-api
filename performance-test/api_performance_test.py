#!/usr/bin/env python3
import asyncio
import aiohttp
import time
import json
from datetime import datetime
from collections import defaultdict
import statistics

class APIPerformanceTest:
    def __init__(self, api_url="http://localhost:8000"):
        self.api_url = api_url
        self.test_duration = 35  # seconds
        self.call_interval = 0.001  # seconds
        
        self.response_times = []
        self.api_calls_count = 0
        self.data_snapshots = []
        self.errors = []
        
    async def call_api(self, session, endpoint="/ctr/latest"):
        """API 호출하고 응답시간 측정"""
        try:
            start_time = time.time()
            async with session.get(f"{self.api_url}{endpoint}") as response:
                data = await response.json()
                end_time = time.time()
                
                response_time = end_time - start_time
                self.response_times.append(response_time)
                self.api_calls_count += 1
                
                # window_end 값 추출
                window_ends = []
                if isinstance(data, dict):
                    for product_data in data.values():
                        if isinstance(product_data, dict) and 'window_end' in product_data:
                            window_ends.append(product_data['window_end'])
                
                # 데이터 스냅샷 저장 (변화 감지용)
                current_time = datetime.now().strftime("%H:%M:%S.%f")[:-3]
                self.data_snapshots.append({
                    "timestamp": current_time,
                    "response_time": response_time,
                    "data": data,
                    "window_ends": window_ends
                })
                
                print(f"[{current_time}] API Call #{self.api_calls_count} - "
                      f"Response time: {response_time:.3f}s - "
                      f"Window ends: {set(window_ends) if window_ends else 'None'}")
                
                return data
                
        except Exception as e:
            error_msg = f"API call failed: {str(e)}"
            self.errors.append(error_msg)
            print(f"ERROR: {error_msg}")
            return None
    
    def detect_window_end_changes(self):
        """window_end 값 변화 감지 및 지속시간 계산"""
        if len(self.data_snapshots) < 2:
            return []
            
        changes = []
        prev_window_ends = set(self.data_snapshots[0]["window_ends"])
        window_start_time = datetime.strptime(self.data_snapshots[0]["timestamp"], "%H:%M:%S.%f")
        
        for i, snapshot in enumerate(self.data_snapshots[1:], 1):
            current_window_ends = set(snapshot["window_ends"])
            current_time = datetime.strptime(snapshot["timestamp"], "%H:%M:%S.%f")
            
            # window_end 값이 변경되었는지 확인
            if prev_window_ends != current_window_ends:
                # 이전 윈도우의 지속시간 계산 (ms 단위)
                duration_ms = (current_time - window_start_time).total_seconds() * 1000
                
                changes.append({
                    "change_number": len(changes) + 1,
                    "timestamp": snapshot["timestamp"],
                    "call_number": i + 1,
                    "prev_window_ends": sorted(prev_window_ends),
                    "current_window_ends": sorted(current_window_ends),
                    "new_windows": sorted(current_window_ends - prev_window_ends),
                    "removed_windows": sorted(prev_window_ends - current_window_ends),
                    "duration_ms": duration_ms
                })
                print(f"🔄 WINDOW_END CHANGE #{len(changes)} detected at {snapshot['timestamp']} (Call #{i + 1})")
                print(f"   Previous window lasted: {duration_ms:.0f}ms")
                print(f"   New windows: {sorted(current_window_ends - prev_window_ends)}")
                
                prev_window_ends = current_window_ends
                window_start_time = current_time
        
        # 마지막 윈도우의 지속시간도 계산 (ms 단위)
        if changes and len(self.data_snapshots) > 0:
            last_snapshot = self.data_snapshots[-1]
            last_time = datetime.strptime(last_snapshot["timestamp"], "%H:%M:%S.%f")
            final_duration_ms = (last_time - window_start_time).total_seconds() * 1000
            
            print(f"📊 Final window duration: {final_duration_ms:.0f}ms (until test end)")
                
        return changes
    
    def calculate_performance_metrics(self):
        """성능 지표 계산"""
        if not self.response_times:
            return {}
            
        return {
            "total_calls": self.api_calls_count,
            "total_errors": len(self.errors),
            "success_rate": (self.api_calls_count - len(self.errors)) / self.api_calls_count * 100,
            "avg_response_time": statistics.mean(self.response_times),
            "min_response_time": min(self.response_times),
            "max_response_time": max(self.response_times),
            "median_response_time": statistics.median(self.response_times),
            "p95_response_time": statistics.quantiles(self.response_times, n=20)[18] if len(self.response_times) >= 20 else max(self.response_times),
            "calls_per_second": self.api_calls_count / self.test_duration
        }
    
    async def run_test(self):
        """35초간 0.5초마다 API 호출하는 테스트 실행"""
        print(f"🚀 Starting API Performance Test")
        print(f"⏱️  Test Duration: {self.test_duration} seconds")
        print(f"📞 Call Interval: {self.call_interval} seconds")
        print(f"🎯 Expected Calls: ~{int(self.test_duration / self.call_interval)}")
        print(f"🔗 API URL: {self.api_url}")
        print("-" * 80)
        
        start_time = time.time()
        
        async with aiohttp.ClientSession() as session:
            while time.time() - start_time < self.test_duration:
                await self.call_api(session)
                await asyncio.sleep(self.call_interval)
        
        print("-" * 80)
        print("✅ Test completed!")
        
        # window_end 변화 감지
        changes = self.detect_window_end_changes()
        
        # 성능 지표 계산
        metrics = self.calculate_performance_metrics()
        
        # 결과 출력
        self.print_results(changes, metrics)
    
    def print_results(self, changes, metrics):
        """테스트 결과 출력"""
        print("\n" + "="*80)
        print("📊 TEST RESULTS")
        print("="*80)
        
        print(f"\n🔄 WINDOW_END CHANGES:")
        print(f"📊 Total window_end changes detected: {len(changes)}")
        if changes:
            print(f"✅ Window end transitions successfully tracked!")
            total_duration_ms = 0
            for change in changes:
                print(f"   Change #{change['change_number']}: {change['timestamp']} (Call #{change['call_number']})")
                print(f"     ⏱️  Previous window duration: {change['duration_ms']:.0f}ms")
                if change['new_windows']:
                    print(f"     ➡️  New windows: {change['new_windows']}")
                total_duration_ms += change['duration_ms']
            
            if len(changes) > 0:
                avg_duration_ms = total_duration_ms / len(changes)
                print(f"\n📈 WINDOW DURATION STATS:")
                print(f"   Average window duration: {avg_duration_ms:.0f}ms")
                print(f"   Total measured duration: {total_duration_ms:.0f}ms")
        else:
            print(f"⚠️  No window_end changes detected during test period")
        
        print(f"\n⚡ PERFORMANCE METRICS:")
        print(f"   Total API Calls: {metrics['total_calls']}")
        print(f"   Total Errors: {metrics['total_errors']}")
        print(f"   Success Rate: {metrics['success_rate']:.1f}%")
        print(f"   Calls per Second: {metrics['calls_per_second']:.1f}")
        
        print(f"\n⏱️  RESPONSE TIME ANALYSIS:")
        print(f"   Average: {metrics['avg_response_time']:.3f}s")
        print(f"   Minimum: {metrics['min_response_time']:.3f}s")
        print(f"   Maximum: {metrics['max_response_time']:.3f}s")
        print(f"   Median: {metrics['median_response_time']:.3f}s")
        print(f"   95th Percentile: {metrics['p95_response_time']:.3f}s")
        
        # 1초 이내 요구사항 체크
        under_1s = sum(1 for rt in self.response_times if rt < 1.0)
        under_1s_rate = under_1s / len(self.response_times) * 100
        
        print(f"\n🎯 LATENCY REQUIREMENT (< 1 second):")
        if under_1s_rate >= 95:
            print(f"   ✅ SUCCESS: {under_1s_rate:.1f}% of calls under 1s ({under_1s}/{len(self.response_times)})")
        else:
            print(f"   ⚠️  WARNING: {under_1s_rate:.1f}% of calls under 1s ({under_1s}/{len(self.response_times)})")
        
        if self.errors:
            print(f"\n❌ ERRORS:")
            for error in self.errors:
                print(f"   {error}")

if __name__ == "__main__":
    test = APIPerformanceTest()
    asyncio.run(test.run_test())