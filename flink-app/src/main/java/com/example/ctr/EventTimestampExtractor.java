package com.example.ctr;

import org.apache.flink.api.common.eventtime.SerializableTimestampAssigner;

public class EventTimestampExtractor implements SerializableTimestampAssigner<Event> {
    
    @Override
    public long extractTimestamp(Event event, long recordTimestamp) {
        return event.getTimestamp();
    }
}