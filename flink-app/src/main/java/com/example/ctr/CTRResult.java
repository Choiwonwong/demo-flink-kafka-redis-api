package com.example.ctr;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Objects;

public class CTRResult {
    @JsonProperty("product_id")
    public String productId;

    @JsonProperty("impressions")
    public long impressions;

    @JsonProperty("clicks")
    public long clicks;

    @JsonProperty("ctr")
    public double ctr;

    @JsonProperty("window_start")
    public String windowStart;

    @JsonProperty("window_end")
    public String windowEnd;

    // Keep original milliseconds for comparisons
    public long windowStartMs;
    public long windowEndMs;

    @JsonProperty("calculated_at")
    public long calculatedAt;

    public CTRResult() {}

    public CTRResult(String productId, long impressions, long clicks, long windowStartMs, long windowEndMs) {
        this.productId = productId;
        this.impressions = impressions;
        this.clicks = clicks;
        this.ctr = impressions > 0 ? (double) clicks / impressions : 0.0;
        this.calculatedAt = System.currentTimeMillis();

        // Set long timestamps
        this.windowStartMs = windowStartMs;
        this.windowEndMs = windowEndMs;

        DateTimeFormatter formatter = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss'+09:00'")
                .withZone(ZoneId.of("Asia/Seoul"));
        this.windowStart = formatter.format(Instant.ofEpochMilli(windowStartMs));
        this.windowEnd = formatter.format(Instant.ofEpochMilli(windowEndMs));
    }

    public String getProductId() {
        return productId;
    }

    public void setProductId(String productId) {
        this.productId = productId;
    }

    public long getImpressions() {
        return impressions;
    }

    public void setImpressions(long impressions) {
        this.impressions = impressions;
    }

    public long getClicks() {
        return clicks;
    }

    public void setClicks(long clicks) {
        this.clicks = clicks;
    }

    public double getCtr() {
        return ctr;
    }

    public void setCtr(double ctr) {
        this.ctr = ctr;
    }

    public String getWindowStart() {
        return windowStart;
    }

    public void setWindowStart(String windowStart) {
        this.windowStart = windowStart;
    }

    public String getWindowEnd() {
        return windowEnd;
    }

    public void setWindowEnd(String windowEnd) {
        this.windowEnd = windowEnd;
    }

    public long getWindowStartMs() {
        return windowStartMs;
    }

    public long getWindowEndMs() {
        return windowEndMs;
    }

    public long getCalculatedAt() {
        return calculatedAt;
    }

    public void setCalculatedAt(long calculatedAt) {
        this.calculatedAt = calculatedAt;
    }

    public String getRedisKey(long windowStartMs) {
        Instant instant = Instant.ofEpochMilli(windowStartMs);
        String windowTimestamp = DateTimeFormatter.ofPattern("yyyyMMdd_HH:mm")
                .withZone(ZoneId.of("Asia/Seoul"))
                .format(instant);
        return String.format("ctr:%s:%s", productId, windowTimestamp);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        CTRResult ctrResult = (CTRResult) o;
        return impressions == ctrResult.impressions &&
                clicks == ctrResult.clicks &&
                Double.compare(ctrResult.ctr, ctr) == 0 &&
                calculatedAt == ctrResult.calculatedAt &&
                Objects.equals(productId, ctrResult.productId) &&
                Objects.equals(windowStart, ctrResult.windowStart) &&
                Objects.equals(windowEnd, ctrResult.windowEnd);
    }

    @Override
    public int hashCode() {
        return Objects.hash(productId, impressions, clicks, ctr, windowStart, windowEnd, calculatedAt);
    }

    @Override
    public String toString() {
        return "CTRResult{" +
                "productId='" + productId + '\'' +
                ", impressions=" + impressions +
                ", clicks=" + clicks +
                ", ctr=" + String.format("%.4f", ctr) +
                ", windowStart='" + windowStart + '\'' +
                ", windowEnd='" + windowEnd + '\'' +
                ", calculatedAt=" + calculatedAt +
                '}';
    }
}