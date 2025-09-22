-- OMS Monitor Plugin for APISIX
-- This plugin provides specialized monitoring for your OMS (Outage Management System)

local core = require("apisix.core")
local plugin_name = "oms-monitor"

local schema = {
    type = "object",
    properties = {
        monitor_endpoints = {
            type = "array",
            items = {
                type = "object",
                properties = {
                    path = {type = "string"},
                    method = {type = "string", default = "GET"},
                    timeout = {type = "integer", default = 5000}
                }
            }
        },
        alert_thresholds = {
            type = "object",
            properties = {
                response_time_ms = {type = "integer", default = 1000},
                error_rate_percent = {type = "number", default = 5.0},
                consecutive_errors = {type = "integer", default = 3}
            }
        },
        metrics_endpoint = {
            type = "string",
            default = "http://localhost:9091/metrics"
        },
        enable_alerts = {
            type = "boolean",
            default = true
        }
    }
}

local _M = {
    version = 0.1,
    priority = 2000,
    name = plugin_name,
    schema = schema,
}

-- Shared dictionary for storing metrics
local metrics_store = ngx.shared.oms_metrics or {}

-- Helper function to send metrics to Prometheus
local function send_oms_metrics(metric_data)
    local http = require("resty.http")
    local httpc = http.new()
    
    local metrics = {
        oms_request_count = 1,
        oms_request_duration_seconds = metric_data.response_time / 1000,
        oms_response_size_bytes = metric_data.response_size,
        oms_status_code = metric_data.status_code,
        oms_endpoint = metric_data.endpoint,
        oms_method = metric_data.method
    }
    
    local res, err = httpc:request_uri(metric_data.metrics_endpoint, {
        method = "POST",
        body = core.json.encode(metrics),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send OMS metrics: ", err)
    end
end

-- Helper function to check alert conditions
local function check_alerts(conf, metric_data)
    if not conf.enable_alerts then
        return
    end
    
    local alerts = {}
    
    -- Check response time threshold
    if metric_data.response_time > conf.alert_thresholds.response_time_ms then
        table.insert(alerts, {
            type = "high_response_time",
            message = "Response time exceeded threshold",
            value = metric_data.response_time,
            threshold = conf.alert_thresholds.response_time_ms
        })
    end
    
    -- Check error rate
    local error_key = "error_count_" .. metric_data.endpoint
    local total_key = "total_count_" .. metric_data.endpoint
    
    local error_count = metrics_store:get(error_key) or 0
    local total_count = metrics_store:get(total_key) or 0
    
    if total_count > 0 then
        local error_rate = (error_count / total_count) * 100
        if error_rate > conf.alert_thresholds.error_rate_percent then
            table.insert(alerts, {
                type = "high_error_rate",
                message = "Error rate exceeded threshold",
                value = error_rate,
                threshold = conf.alert_thresholds.error_rate_percent
            })
        end
    end
    
    -- Check consecutive errors
    local consecutive_key = "consecutive_errors_" .. metric_data.endpoint
    local consecutive_errors = metrics_store:get(consecutive_key) or 0
    
    if consecutive_errors >= conf.alert_thresholds.consecutive_errors then
        table.insert(alerts, {
            type = "consecutive_errors",
            message = "Too many consecutive errors",
            value = consecutive_errors,
            threshold = conf.alert_thresholds.consecutive_errors
        })
    end
    
    -- Log alerts
    if #alerts > 0 then
        ngx.log(ngx.WARN, "OMS Monitor Alerts: ", core.json.encode(alerts))
    end
    
    return alerts
end

-- Helper function to update metrics counters
local function update_metrics_counters(endpoint, is_error)
    local error_key = "error_count_" .. endpoint
    local total_key = "total_count_" .. endpoint
    local consecutive_key = "consecutive_errors_" .. endpoint
    
    -- Update total count
    local total_count = metrics_store:get(total_key) or 0
    metrics_store:set(total_key, total_count + 1, 3600) -- 1 hour TTL
    
    -- Update error count
    if is_error then
        local error_count = metrics_store:get(error_key) or 0
        metrics_store:set(error_key, error_count + 1, 3600)
        
        -- Update consecutive errors
        local consecutive_errors = metrics_store:get(consecutive_key) or 0
        metrics_store:set(consecutive_key, consecutive_errors + 1, 3600)
    else
        -- Reset consecutive errors on successful request
        metrics_store:set(consecutive_key, 0, 3600)
    end
end

function _M.access(conf, ctx)
    local start_time = ngx.now()
    ngx.ctx.oms_start_time = start_time
    
    -- Check if this is an OMS endpoint
    local uri = ngx.var.request_uri
    local is_oms_endpoint = false
    
    for _, endpoint in ipairs(conf.monitor_endpoints or {}) do
        if string.match(uri, endpoint.path) then
            is_oms_endpoint = true
            ngx.ctx.oms_endpoint = endpoint.path
            ngx.ctx.oms_method = endpoint.method
            break
        end
    end
    
    if is_oms_endpoint then
        ngx.log(ngx.INFO, "OMS Monitor: Monitoring endpoint ", uri)
    end
end

function _M.log(conf, ctx)
    if not ngx.ctx.oms_start_time then
        return
    end
    
    local response_time = (ngx.now() - ngx.ctx.oms_start_time) * 1000 -- Convert to milliseconds
    local endpoint = ngx.ctx.oms_endpoint or ngx.var.request_uri
    local method = ngx.ctx.oms_method or ngx.var.request_method
    local is_error = ngx.status >= 400
    
    local metric_data = {
        endpoint = endpoint,
        method = method,
        response_time = response_time,
        response_size = ngx.var.bytes_sent,
        status_code = ngx.status,
        timestamp = ngx.time(),
        metrics_endpoint = conf.metrics_endpoint
    }
    
    -- Update counters
    update_metrics_counters(endpoint, is_error)
    
    -- Send metrics to Prometheus
    send_oms_metrics(metric_data)
    
    -- Check for alerts
    local alerts = check_alerts(conf, metric_data)
    
    -- Log monitoring data
    local log_data = {
        plugin = "oms-monitor",
        metric_data = metric_data,
        alerts = alerts
    }
    
    ngx.log(ngx.INFO, "OMS Monitor: ", core.json.encode(log_data))
end

return _M




