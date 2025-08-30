package com.example.ctr;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.Objects;

public class Event {
    @JsonProperty("user_id")
    public String userId;

    @JsonProperty("product_id")
    public String productId;

    @JsonProperty("timestamp")
    public long timestamp;

    @JsonProperty("event_type")
    public String eventType;

    @JsonProperty("session_id")
    public String sessionId;

    public Event() {}

    public Event(String userId, String productId, long timestamp, String eventType, String sessionId) {
        this.userId = userId;
        this.productId = productId;
        this.timestamp = timestamp;
        this.eventType = eventType;
        this.sessionId = sessionId;
    }

    public String getUserId() {
        return userId;
    }

    public void setUserId(String userId) {
        this.userId = userId;
    }

    public String getProductId() {
        return productId;
    }

    public void setProductId(String productId) {
        this.productId = productId;
    }

    public long getTimestamp() {
        return timestamp;
    }

    public void setTimestamp(long timestamp) {
        this.timestamp = timestamp;
    }

    public String getEventType() {
        return eventType;
    }

    public void setEventType(String eventType) {
        this.eventType = eventType;
    }

    public String getSessionId() {
        return sessionId;
    }

    public void setSessionId(String sessionId) {
        this.sessionId = sessionId;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        Event event = (Event) o;
        return timestamp == event.timestamp &&
                Objects.equals(userId, event.userId) &&
                Objects.equals(productId, event.productId) &&
                Objects.equals(eventType, event.eventType) &&
                Objects.equals(sessionId, event.sessionId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, productId, timestamp, eventType, sessionId);
    }

    @Override
    public String toString() {
        return "Event{" +
                "userId='" + userId + '\'' +
                ", productId='" + productId + '\'' +
                ", timestamp=" + timestamp +
                ", eventType='" + eventType + '\'' +
                ", sessionId='" + sessionId + '\'' +
                '}';
    }
}