-- Alert Manager for APISIX
-- Advanced alerting system with multiple notification channels

local core = require("apisix.core")

-- Alert configuration
local ALERT_CONFIG = {
    channels = {
        webhook = {
            url = "http://localhost:9091/webhook",
            timeout = 5000
        },
        email = {
            smtp_server = "localhost",
            smtp_port = 587,
            from = "alerts@apisix.local",
            to = "admin@apisix.local"
        },
        slack = {
            webhook_url = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK",
            timeout = 5000
        }
    },
    rules = {
        high_response_time = {
            threshold = 1000, -- 1 second
            severity = "warning",
            message = "High response time detected"
        },
        error_rate = {
            threshold = 5.0, -- 5%
            severity = "critical",
            message = "High error rate detected"
        },
        service_down = {
            threshold = 1,
            severity = "critical",
            message = "Service is down"
        },
        memory_usage = {
            threshold = 80.0, -- 80%
            severity = "warning",
            message = "High memory usage"
        }
    }
}

-- Alert storage
local alert_store = ngx.shared.alerts or {}

-- Helper function to create alert
local function create_alert(rule_name, rule_config, current_value, context)
    local alert = {
        id = "ALERT-" .. ngx.time() .. "-" .. math.random(1000, 9999),
        rule = rule_name,
        severity = rule_config.severity,
        message = rule_config.message,
        current_value = current_value,
        threshold = rule_config.threshold,
        context = context or {},
        timestamp = ngx.time(),
        status = "active"
    }
    
    return alert
end

-- Helper function to check alert rules
local function check_alert_rules(metrics)
    local alerts = {}
    
    -- Check response time
    if metrics.response_time and metrics.response_time > ALERT_CONFIG.rules.high_response_time.threshold then
        local alert = create_alert("high_response_time", ALERT_CONFIG.rules.high_response_time, 
                                 metrics.response_time, {uri = metrics.uri})
        table.insert(alerts, alert)
    end
    
    -- Check error rate
    if metrics.error_rate and metrics.error_rate > ALERT_CONFIG.rules.error_rate.threshold then
        local alert = create_alert("error_rate", ALERT_CONFIG.rules.error_rate, 
                                 metrics.error_rate, {service = metrics.service})
        table.insert(alerts, alert)
    end
    
    -- Check service status
    if metrics.service_status and metrics.service_status == "down" then
        local alert = create_alert("service_down", ALERT_CONFIG.rules.service_down, 
                                 0, {service = metrics.service})
        table.insert(alerts, alert)
    end
    
    -- Check memory usage
    if metrics.memory_usage and metrics.memory_usage > ALERT_CONFIG.rules.memory_usage.threshold then
        local alert = create_alert("memory_usage", ALERT_CONFIG.rules.memory_usage, 
                                 metrics.memory_usage, {})
        table.insert(alerts, alert)
    end
    
    return alerts
end

-- Helper function to send webhook alert
local function send_webhook_alert(alert)
    local http = require("resty.http")
    local httpc = http.new()
    httpc:set_timeout(ALERT_CONFIG.channels.webhook.timeout)
    
    local webhook_data = {
        text = "🚨 APISIX Alert",
        attachments = {{
            color = alert.severity == "critical" and "danger" or "warning",
            title = alert.message,
            fields = {
                {title = "Rule", value = alert.rule, short = true},
                {title = "Severity", value = alert.severity, short = true},
                {title = "Current Value", value = tostring(alert.current_value), short = true},
                {title = "Threshold", value = tostring(alert.threshold), short = true},
                {title = "Timestamp", value = os.date("%Y-%m-%d %H:%M:%S", alert.timestamp), short = true}
            }
        }}
    }
    
    local res, err = httpc:request_uri(ALERT_CONFIG.channels.webhook.url, {
        method = "POST",
        body = core.json.encode(webhook_data),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send webhook alert: ", err)
        return false
    end
    
    return true
end

-- Helper function to send Slack alert
local function send_slack_alert(alert)
    local http = require("resty.http")
    local httpc = http.new()
    httpc:set_timeout(ALERT_CONFIG.channels.slack.timeout)
    
    local slack_data = {
        text = "🚨 *APISIX Alert*",
        attachments = {{
            color = alert.severity == "critical" and "danger" or "warning",
            title = alert.message,
            fields = {
                {title = "Rule", value = alert.rule, short = true},
                {title = "Severity", value = alert.severity, short = true},
                {title = "Current Value", value = tostring(alert.current_value), short = true},
                {title = "Threshold", value = tostring(alert.threshold), short = true}
            },
            footer = "APISIX Monitoring",
            ts = alert.timestamp
        }}
    }
    
    local res, err = httpc:request_uri(ALERT_CONFIG.channels.slack.webhook_url, {
        method = "POST",
        body = core.json.encode(slack_data),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send Slack alert: ", err)
        return false
    end
    
    return true
end

-- Helper function to store alert
local function store_alert(alert)
    local key = "alert_" .. alert.id
    alert_store:set(key, core.json.encode(alert), 86400) -- 24 hours TTL
end

-- Helper function to get active alerts
local function get_active_alerts()
    local alerts = {}
    local keys = alert_store:get_keys()
    
    for _, key in ipairs(keys) do
        if string.match(key, "^alert_") then
            local alert_data = alert_store:get(key)
            if alert_data then
                local ok, alert = pcall(cjson.decode, alert_data)
                if ok and alert.status == "active" then
                    table.insert(alerts, alert)
                end
            end
        end
    end
    
    return alerts
end

-- Helper function to resolve alert
local function resolve_alert(alert_id)
    local key = "alert_" .. alert_id
    local alert_data = alert_store:get(key)
    
    if alert_data then
        local ok, alert = pcall(cjson.decode, alert_data)
        if ok then
            alert.status = "resolved"
            alert.resolved_at = ngx.time()
            alert_store:set(key, core.json.encode(alert), 86400)
            return true
        end
    end
    
    return false
end

-- Main alert manager function
return function(conf, ctx)
    local metrics = {
        response_time = ngx.var.request_time * 1000, -- Convert to milliseconds
        uri = ngx.var.request_uri,
        status = ngx.status,
        service = "apisix",
        memory_usage = math.random(60, 90), -- Simulated memory usage
        error_rate = math.random(0, 10) -- Simulated error rate
    }
    
    -- Check for alerts
    local alerts = check_alert_rules(metrics)
    
    -- Process each alert
    for _, alert in ipairs(alerts) do
        -- Store alert
        store_alert(alert)
        
        -- Send notifications
        if conf.enable_webhook then
            send_webhook_alert(alert)
        end
        
        if conf.enable_slack then
            send_slack_alert(alert)
        end
        
        -- Log alert
        ngx.log(ngx.WARN, "Alert triggered: ", core.json.encode(alert))
    end
    
    -- Check for resolved alerts
    local active_alerts = get_active_alerts()
    for _, alert in ipairs(active_alerts) do
        -- Simple resolution logic - resolve if conditions are no longer met
        local should_resolve = false
        
        if alert.rule == "high_response_time" and metrics.response_time <= ALERT_CONFIG.rules.high_response_time.threshold then
            should_resolve = true
        elseif alert.rule == "error_rate" and metrics.error_rate <= ALERT_CONFIG.rules.error_rate.threshold then
            should_resolve = true
        elseif alert.rule == "service_down" and metrics.status < 400 then
            should_resolve = true
        elseif alert.rule == "memory_usage" and metrics.memory_usage <= ALERT_CONFIG.rules.memory_usage.threshold then
            should_resolve = true
        end
        
        if should_resolve then
            resolve_alert(alert.id)
            ngx.log(ngx.INFO, "Alert resolved: ", alert.id)
        end
    end
    
    -- Return alert summary
    return {
        alerts_triggered = #alerts,
        active_alerts = #get_active_alerts(),
        timestamp = ngx.time()
    }
end




