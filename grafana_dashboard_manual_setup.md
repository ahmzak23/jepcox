# Grafana Dashboard Manual Setup Guide

## Step 1: Access Grafana
1. Go to http://localhost:3000
2. Login with username: `admin`, password: `admin`

## Step 2: Create New Dashboard
1. Click the **"+"** icon in the left sidebar
2. Select **"Dashboard"**
3. Click **"Add new panel"**

## Step 3: Add Panels One by One

### Panel 1: Active Outages by Severity
1. **Panel Title**: `🚨 Active Outages by Severity`
2. **Visualization**: Stat
3. **Query**: `oms_active_outages{severity="CRITICAL"}`
4. **Field**: 
   - Unit: `short`
   - Color mode: `Background`
   - Thresholds: Green (0), Yellow (1), Red (5)

### Panel 2: High Severity Outages
1. **Panel Title**: `⚠️ High Severity Outages`
2. **Visualization**: Stat
3. **Query**: `oms_active_outages{severity="HIGH"}`
4. **Field**:
   - Unit: `short`
   - Color mode: `Background`
   - Thresholds: Green (0), Yellow (3), Red (10)

### Panel 3: Total Outages Today
1. **Panel Title**: `📊 Total Outages Today`
2. **Visualization**: Stat
3. **Query**: `increase(oms_total_outages[1d])`
4. **Field**:
   - Unit: `short`

### Panel 4: System Health Score
1. **Panel Title**: `⚡ System Health Score`
2. **Visualization**: Gauge
3. **Query**: `oms_system_health_score`
4. **Field**:
   - Min: 0, Max: 100
   - Unit: `percent`
   - Thresholds: Red (0), Yellow (70), Green (90)

### Panel 5: Outage Trends (Last 24h)
1. **Panel Title**: `📈 Outage Trends (Last 24h)`
2. **Visualization**: Time series
3. **Queries**:
   - `rate(oms_outages_created_total[5m])` (Legend: "Outages Created")
   - `rate(oms_outages_resolved_total[5m])` (Legend: "Outages Resolved")
4. **Field**:
   - Unit: `short`

### Panel 6: Latest Outage Events
1. **Panel Title**: `📋 Latest Outage Events`
2. **Visualization**: Table
3. **Query**: `oms_latest_outages`
4. **Format**: Table
5. **Instant**: true

### Panel 7: Kafka Message Flow
1. **Panel Title**: `🔄 Kafka Message Flow`
2. **Visualization**: Time series
3. **Queries**:
   - `rate(kafka_consumer_messages_consumed_total{topic="outage-events"}[1m])` (Legend: "Outage Events")
   - `rate(kafka_consumer_messages_consumed_total{topic="meter-readings"}[1m])` (Legend: "Meter Readings")
   - `rate(kafka_consumer_messages_consumed_total{topic="system-health"}[1m])` (Legend: "System Health")
   - `rate(kafka_consumer_messages_consumed_total{topic="network-events"}[1m])` (Legend: "Network Events")
4. **Field**:
   - Unit: `short`

### Panel 8: Performance Metrics
1. **Panel Title**: `⚡ Performance Metrics`
2. **Visualization**: Time series
3. **Queries**:
   - `histogram_quantile(0.95, rate(oms_api_request_duration_seconds_bucket[5m]))` (Legend: "95th Percentile")
   - `histogram_quantile(0.50, rate(oms_api_request_duration_seconds_bucket[5m]))` (Legend: "50th Percentile")
4. **Field**:
   - Unit: `s`

### Panel 9: Error Rate
1. **Panel Title**: `📊 Error Rate`
2. **Visualization**: Time series
3. **Query**: `rate(oms_errors_total[5m])`
4. **Field**:
   - Unit: `short`
   - Thresholds: Green (0), Yellow (0.1), Red (1.0)

### Panel 10: Top Affected Locations
1. **Panel Title**: `🔍 Top Affected Locations`
2. **Visualization**: Bar gauge
3. **Query**: `topk(10, sum by (location) (oms_outages_by_location))`
4. **Field**:
   - Unit: `short`
   - Orientation: Horizontal

## Step 4: Configure Dashboard Settings
1. Click the **gear icon** (Settings) in the top right
2. **General**:
   - Title: `OMS System - Advanced Monitoring`
   - Tags: `oms`, `kafka`, `outage-management`
3. **Time**:
   - From: `now-1h`
   - To: `now`
4. **Refresh**: `5s`

## Step 5: Save Dashboard
1. Click **"Save"** in the top right
2. Enter dashboard name: `OMS System - Advanced Monitoring`
3. Click **"Save"**

## Step 6: Test the Dashboard
1. Make sure the enhanced metrics collector is running
2. Check that metrics are available at http://localhost:8000/metrics
3. Verify data appears in the dashboard panels
