package com.example.ctr;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.flink.api.common.eventtime.WatermarkStrategy;
import org.apache.flink.api.common.functions.AggregateFunction;
import org.apache.flink.api.common.serialization.DeserializationSchema;
import org.apache.flink.api.common.typeinfo.TypeInformation;
import org.apache.flink.api.java.functions.KeySelector;
import org.apache.flink.connector.kafka.source.KafkaSource;
import org.apache.flink.connector.kafka.source.enumerator.initializer.OffsetsInitializer;
import org.apache.flink.streaming.api.datastream.DataStream;
import org.apache.flink.streaming.api.datastream.SingleOutputStreamOperator;
import org.apache.flink.streaming.api.environment.StreamExecutionEnvironment;
import org.apache.flink.streaming.api.functions.sink.SinkFunction;
import org.apache.flink.streaming.api.functions.windowing.ProcessWindowFunction;
import org.apache.flink.streaming.api.windowing.assigners.TumblingEventTimeWindows;
import org.apache.flink.streaming.api.windowing.time.Time;
import org.apache.flink.streaming.api.windowing.windows.TimeWindow;
import org.apache.flink.util.Collector;
import redis.clients.jedis.Jedis;
import redis.clients.jedis.JedisPool;
import redis.clients.jedis.JedisPoolConfig;

import java.io.IOException;
import java.time.Duration;
import java.util.HashMap;
import java.util.Map;

public class CTRCalculatorJob {

    public static void main(String[] args) throws Exception {
        final StreamExecutionEnvironment env = StreamExecutionEnvironment.getExecutionEnvironment();

        env.setParallelism(2);

        ObjectMapper objectMapper = new ObjectMapper();

        KafkaSource<Event> impressionSource = KafkaSource.<Event>builder()
                .setBootstrapServers("kafka1:29092,kafka2:29093,kafka3:29094")
                .setTopics("impressions")
                .setGroupId("ctr-calculator-impressions")
                .setStartingOffsets(OffsetsInitializer.latest())
                .setValueOnlyDeserializer(new EventDeserializationSchema(objectMapper))
                .build();

        KafkaSource<Event> clickSource = KafkaSource.<Event>builder()
                .setBootstrapServers("kafka1:29092,kafka2:29093,kafka3:29094")
                .setTopics("clicks")
                .setGroupId("ctr-calculator-clicks")
                .setStartingOffsets(OffsetsInitializer.latest())
                .setValueOnlyDeserializer(new EventDeserializationSchema(objectMapper))
                .build();

        WatermarkStrategy<Event> watermarkStrategy = WatermarkStrategy
                .<Event>forBoundedOutOfOrderness(Duration.ofSeconds(3))
                .withTimestampAssigner(new EventTimestampExtractor());

        DataStream<Event> impressionStream = env
                .fromSource(impressionSource, watermarkStrategy, "Impression Source")
                .filter(event -> "impression".equals(event.getEventType()));

        DataStream<Event> clickStream = env
                .fromSource(clickSource, watermarkStrategy, "Click Source")
                .filter(event -> "click".equals(event.getEventType()));

        DataStream<Event> combinedStream = impressionStream.union(clickStream);

        SingleOutputStreamOperator<CTRResult> ctrResults = combinedStream
                .keyBy(new ProductKeySelector())
                .window(TumblingEventTimeWindows.of(Time.seconds(10)))
                .allowedLateness(Time.seconds(5))
                .aggregate(new EventCountAggregator(), new CTRResultWindowProcessFunction());

        ctrResults.print("CTR Results");

        ctrResults.addSink(new RedisSink());

        env.execute("CTR Calculator Job");
    }

    public static class EventDeserializationSchema implements DeserializationSchema<Event> {
        private final ObjectMapper objectMapper;

        public EventDeserializationSchema(ObjectMapper objectMapper) {
            this.objectMapper = objectMapper;
        }

        @Override
        public Event deserialize(byte[] message) throws IOException {
            return objectMapper.readValue(message, Event.class);
        }

        @Override
        public boolean isEndOfStream(Event nextElement) {
            return false;
        }

        @Override
        public TypeInformation<Event> getProducedType() {
            return TypeInformation.of(Event.class);
        }
    }

    public static class ProductKeySelector implements KeySelector<Event, String> {
        @Override
        public String getKey(Event event) throws Exception {
            return event.getProductId();
        }
    }

    public static class EventCountAggregator implements AggregateFunction<Event, ProductEventCounts, ProductEventCounts> {

        @Override
        public ProductEventCounts createAccumulator() {
            return new ProductEventCounts();
        }

        @Override
        public ProductEventCounts add(Event event, ProductEventCounts accumulator) {
            if (accumulator.getProductId() == null) {
                accumulator.setProductId(event.getProductId());
            }

            if ("impression".equals(event.getEventType())) {
                accumulator.addImpression();
            } else if ("click".equals(event.getEventType())) {
                accumulator.addClick();
            }

            return accumulator;
        }

        @Override
        public ProductEventCounts getResult(ProductEventCounts accumulator) {
            return accumulator;
        }

        @Override
        public ProductEventCounts merge(ProductEventCounts a, ProductEventCounts b) {
            if (a.getProductId() == null && b.getProductId() != null) {
                a.setProductId(b.getProductId());
            }
            a.merge(b);
            return a;
        }
    }

    public static class CTRResultWindowProcessFunction extends ProcessWindowFunction<ProductEventCounts, CTRResult, String, TimeWindow> {
        @Override
        public void process(String key, Context context, Iterable<ProductEventCounts> elements, Collector<CTRResult> out) throws Exception {
            ProductEventCounts counts = elements.iterator().next();
            CTRResult result = new CTRResult(
                    key,
                    counts.getImpressions(),
                    counts.getClicks(),
                    context.window().getStart(),
                    context.window().getEnd()
            );
            out.collect(result);
        }
    }

    public static class RedisSink implements SinkFunction<CTRResult> {
        private transient JedisPool jedisPool;
        private transient ObjectMapper objectMapper;

        @Override
        public void invoke(CTRResult ctrResult, Context context) throws Exception {
            if (jedisPool == null) {
                JedisPoolConfig config = new JedisPoolConfig();
                config.setMaxTotal(10);
                config.setMaxIdle(5);
                config.setMinIdle(1);
                jedisPool = new JedisPool(config, "redis", 6379);
                objectMapper = new ObjectMapper();
                System.out.println("RedisSink: JedisPool and ObjectMapper initialized.");
            }

            System.out.println("RedisSink: Invoked for product_id: " + ctrResult.getProductId() + ", CTR: " + ctrResult.getCtr());

            try (Jedis jedis = jedisPool.getResource()) {
                String latestHashKey = "ctr:latest";
                String previousHashKey = "ctr:previous";
                String field = ctrResult.getProductId();

                // 1. Get the current "latest" value for this product.
                String currentLatestValue = jedis.hget(latestHashKey, field);
                System.out.println("RedisSink: currentLatestValue for " + field + ": " + currentLatestValue);

                // Create the new JSON value for the "latest" hash.
                Map<String, Object> newJsonData = new HashMap<>();
                newJsonData.put("product_id", ctrResult.getProductId());
                newJsonData.put("ctr", Double.parseDouble(String.format("%.4f", ctrResult.getCtr())));
                newJsonData.put("impressions", ctrResult.getImpressions());
                newJsonData.put("clicks", ctrResult.getClicks());
                newJsonData.put("window_start", ctrResult.getWindowStartMs());
                newJsonData.put("window_end", ctrResult.getWindowEndMs());
                String newJsonValue = objectMapper.writeValueAsString(newJsonData);
                System.out.println("RedisSink: newJsonValue for " + field + ": " + newJsonValue);

                // 2. If a "latest" value exists, decide whether to move it to "previous".
                if (currentLatestValue != null) {
                    // Parse the existing value to check its window timestamp.
                    Map<String, Object> currentLatestData = objectMapper.readValue(currentLatestValue, new TypeReference<Map<String, Object>>() {
                    });

                    // ✨ 수정된 안전한 로직
                    Object windowEndObj = currentLatestData.get("window_end");
                    long currentWindowEnd = 0L; // 기본값 초기화

                    if (windowEndObj instanceof Number) {
                        // 값이 이미 숫자 타입인 경우
                        currentWindowEnd = ((Number) windowEndObj).longValue();
                    } else if (windowEndObj instanceof String) {
                        // 값이 문자열인 경우, 숫자로 파싱
                        try {
                            currentWindowEnd = Long.parseLong((String) windowEndObj);
                        } catch (NumberFormatException e) {
                            System.err.println("Could not parse window_end string to long: " + windowEndObj);
                            // 에러 처리 또는 무시
                        }
                    }
                    // Move the current latest value to previous
                    jedis.hset(previousHashKey, field, currentLatestValue);
                    jedis.expire(previousHashKey, 3600); // Also set TTL for previous
                    System.out.println("RedisSink: Moved current latest for " + field + " to previous.");
                } // End of if (currentLatestValue != null)

                // 3. Always update the "latest" hash with the new value.
                jedis.hset(latestHashKey, field, newJsonValue);
                jedis.expire(latestHashKey, 3600); // 1 hour TTL

                System.out.println("Updated Redis Hashes (Robust Logic) - Key: " + latestHashKey + ", Field: " + field);

            } catch(Exception e){
                System.err.println("Error saving to Redis: " + e.getMessage());
                e.printStackTrace();
            }
        }
    }
}