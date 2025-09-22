-- Prometheus Metrics Collector for APISIX
-- Enhanced monitoring with custom metrics collection

local core = require("apisix.core")

-- Metrics storage
local metrics_store = ngx.shared.prometheus_metrics or {}

-- Metric types
local METRIC_TYPES = {
    COUNTER = "counter",
    GAUGE = "gauge",
    HISTOGRAM = "histogram",
    SUMMARY = "summary"
}

-- Helper function to create metric key
local function create_metric_key(name, labels)
    local key = name
    if labels and next(labels) then
        local label_parts = {}
        for k, v in pairs(labels) do
            table.insert(label_parts, k .. "=" .. v)
        end
        key = key .. "{" .. table.concat(label_parts, ",") .. "}"
    end
    return key
end

-- Helper function to increment counter
local function increment_counter(name, labels, value)
    value = value or 1
    local key = create_metric_key(name, labels)
    local current = metrics_store:get(key) or 0
    metrics_store:set(key, current + value, 3600) -- 1 hour TTL
end

-- Helper function to set gauge
local function set_gauge(name, labels, value)
    local key = create_metric_key(name, labels)
    metrics_store:set(key, value, 3600) -- 1 hour TTL
end

-- Helper function to observe histogram
local function observe_histogram(name, labels, value, buckets)
    buckets = buckets or {0.1, 0.5, 1.0, 2.5, 5.0, 10.0}
    
    -- Increment total count
    increment_counter(name .. "_count", labels)
    
    -- Add to sum
    increment_counter(name .. "_sum", labels, value)
    
    -- Add to appropriate buckets
    for _, bucket in ipairs(buckets) do
        local bucket_labels = labels or {}
        bucket_labels.le = tostring(bucket)
        if value <= bucket then
            increment_counter(name .. "_bucket", bucket_labels)
        end
    end
    
    -- Add to +Inf bucket
    local inf_labels = labels or {}
    inf_labels.le = "+Inf"
    increment_counter(name .. "_bucket", inf_labels)
end

-- Helper function to get all metrics
local function get_all_metrics()
    local metrics = {}
    local keys = metrics_store:get_keys()
    
    for _, key in ipairs(keys) do
        local value = metrics_store:get(key)
        if value then
            table.insert(metrics, {
                key = key,
                value = value,
                timestamp = ngx.time()
            })
        end
    end
    
    return metrics
end

-- Helper function to format metrics for Prometheus
local function format_prometheus_metrics(metrics)
    local output = {}
    
    -- Group metrics by name
    local grouped = {}
    for _, metric in ipairs(metrics) do
        local name = string.match(metric.key, "^([^{]+)")
        if not grouped[name] then
            grouped[name] = {}
        end
        table.insert(grouped[name], metric)
    end
    
    -- Format each metric group
    for name, metric_list in pairs(grouped) do
        -- Add help and type comments
        table.insert(output, "# HELP " .. name .. " " .. name .. " metric")
        table.insert(output, "# TYPE " .. name .. " " .. METRIC_TYPES.COUNTER)
        
        -- Add metric values
        for _, metric in ipairs(metric_list) do
            table.insert(output, metric.key .. " " .. tostring(metric.value))
        end
        
        table.insert(output, "") -- Empty line between metric groups
    end
    
    return table.concat(output, "\\n")
end

-- Helper function to send metrics to Prometheus
local function send_metrics_to_prometheus(metrics_endpoint)
    local metrics = get_all_metrics()
    local formatted_metrics = format_prometheus_metrics(metrics)
    
    local http = require("resty.http")
    local httpc = http.new()
    
    local res, err = httpc:request_uri(metrics_endpoint, {
        method = "POST",
        body = formatted_metrics,
        headers = {
            ["Content-Type"] = "text/plain"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send metrics to Prometheus: ", err)
        return false
    end
    
    return true
end

-- Main metrics collection function
return function(conf, ctx)
    local start_time = ngx.ctx.start_time or ngx.now()
    local response_time = (ngx.now() - start_time) * 1000 -- Convert to milliseconds
    
    -- Basic request metrics
    local labels = {
        method = ngx.var.request_method,
        uri = ngx.var.request_uri,
        status = tostring(ngx.status),
        upstream = ngx.var.upstream_addr or "unknown"
    }
    
    -- Increment request counter
    increment_counter("apisix_requests_total", labels)
    
    -- Set response time histogram
    observe_histogram("apisix_request_duration_seconds", labels, response_time / 1000)
    
    -- Set response size gauge
    set_gauge("apisix_response_size_bytes", labels, ngx.var.bytes_sent)
    
    -- Set active connections gauge
    set_gauge("apisix_active_connections", {}, ngx.var.connection_requests)
    
    -- Set upstream response time
    if ngx.var.upstream_response_time then
        local upstream_time = tonumber(ngx.var.upstream_response_time) * 1000
        set_gauge("apisix_upstream_response_time_ms", labels, upstream_time)
    end
    
    -- Error rate metrics
    if ngx.status >= 400 then
        increment_counter("apisix_errors_total", labels)
    end
    
    -- 4xx errors
    if ngx.status >= 400 and ngx.status < 500 then
        increment_counter("apisix_client_errors_total", labels)
    end
    
    -- 5xx errors
    if ngx.status >= 500 then
        increment_counter("apisix_server_errors_total", labels)
    end
    
    -- Custom OMS metrics
    if string.match(ngx.var.request_uri, "/oms/") then
        local oms_labels = {
            service = "oms",
            endpoint = string.match(ngx.var.request_uri, "/oms/([^/]+)") or "unknown"
        }
        
        increment_counter("oms_requests_total", oms_labels)
        set_gauge("oms_response_time_ms", oms_labels, response_time)
        
        -- Simulate OMS-specific metrics
        local active_outages = math.random(0, 10)
        set_gauge("oms_active_outages", {}, active_outages)
        
        local resolved_outages = math.random(50, 100)
        increment_counter("oms_resolved_outages_total", {}, resolved_outages)
    end
    
    -- Send metrics to Prometheus if configured
    if conf.send_to_prometheus and conf.prometheus_endpoint then
        send_metrics_to_prometheus(conf.prometheus_endpoint)
    end
    
    -- Log metrics for debugging
    if conf.log_metrics then
        ngx.log(ngx.INFO, "Metrics collected: ", core.json.encode({
            request_time = response_time,
            status = ngx.status,
            bytes_sent = ngx.var.bytes_sent,
            uri = ngx.var.request_uri
        }))
    end
end




