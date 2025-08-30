package com.example.ctr;

import java.util.Objects;

public class ProductEventCounts {
    public String productId;
    public long impressions;
    public long clicks;

    public ProductEventCounts() {
        this.impressions = 0;
        this.clicks = 0;
    }

    public ProductEventCounts(String productId) {
        this.productId = productId;
        this.impressions = 0;
        this.clicks = 0;
    }

    public ProductEventCounts(String productId, long impressions, long clicks) {
        this.productId = productId;
        this.impressions = impressions;
        this.clicks = clicks;
    }

    public void addImpression() {
        this.impressions++;
    }

    public void addClick() {
        this.clicks++;
    }

    public void merge(ProductEventCounts other) {
        this.impressions += other.impressions;
        this.clicks += other.clicks;
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

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;
        ProductEventCounts that = (ProductEventCounts) o;
        return impressions == that.impressions &&
                clicks == that.clicks &&
                Objects.equals(productId, that.productId);
    }

    @Override
    public int hashCode() {
        return Objects.hash(productId, impressions, clicks);
    }

    @Override
    public String toString() {
        return "ProductEventCounts{" +
                "productId='" + productId + '\'' +
                ", impressions=" + impressions +
                ", clicks=" + clicks +
                '}';
    }
}