-- Health Checker for APISIX
-- Comprehensive health monitoring for all services

local core = require("apisix.core")

-- Health check configuration
local HEALTH_CHECK_CONFIG = {
    timeout = 5000, -- 5 seconds
    interval = 30000, -- 30 seconds
    retries = 3,
    services = {
        etcd = {
            url = "http://etcd:2379/health",
            method = "GET",
            expected_status = 200
        },
        prometheus = {
            url = "http://localhost:9090/-/healthy",
            method = "GET",
            expected_status = 200
        },
        grafana = {
            url = "http://localhost:3000/api/health",
            method = "GET",
            expected_status = 200
        },
        kafka = {
            url = "http://localhost:9092",
            method = "GET",
            expected_status = 200
        }
    }
}

-- Health status storage
local health_store = ngx.shared.health_status or {}

-- Helper function to perform HTTP health check
local function check_http_service(service_name, config)
    local http = require("resty.http")
    local httpc = http.new()
    httpc:set_timeout(config.timeout or HEALTH_CHECK_CONFIG.timeout)
    
    local res, err = httpc:request_uri(config.url, {
        method = config.method or "GET",
        headers = {
            ["User-Agent"] = "APISIX-Health-Checker/1.0"
        }
    })
    
    if not res then
        return {
            status = "down",
            error = err,
            timestamp = ngx.time()
        }
    end
    
    local is_healthy = res.status == (config.expected_status or 200)
    
    return {
        status = is_healthy and "up" or "down",
        response_time = res.elapsed,
        status_code = res.status,
        timestamp = ngx.time()
    }
end

-- Helper function to check service health
local function check_service_health(service_name, config)
    local health_result = check_http_service(service_name, config)
    
    -- Store health status
    local key = "health_" .. service_name
    health_store:set(key, core.json.encode(health_result), 60) -- 1 minute TTL
    
    return health_result
end

-- Helper function to get all health statuses
local function get_all_health_statuses()
    local statuses = {}
    local keys = health_store:get_keys()
    
    for _, key in ipairs(keys) do
        if string.match(key, "^health_") then
            local service_name = string.match(key, "^health_(.+)")
            local health_data = health_store:get(key)
            
            if health_data then
                local ok, result = pcall(cjson.decode, health_data)
                if ok then
                    statuses[service_name] = result
                end
            end
        end
    end
    
    return statuses
end

-- Helper function to determine overall health
local function get_overall_health()
    local statuses = get_all_health_statuses()
    local overall_status = "healthy"
    local unhealthy_services = {}
    
    for service_name, status in pairs(statuses) do
        if status.status ~= "up" then
            overall_status = "unhealthy"
            table.insert(unhealthy_services, service_name)
        end
    end
    
    return {
        status = overall_status,
        unhealthy_services = unhealthy_services,
        services = statuses,
        timestamp = ngx.time()
    }
end

-- Helper function to send health alerts
local function send_health_alert(service_name, health_result)
    local alert_data = {
        type = "health_check_failed",
        service = service_name,
        status = health_result.status,
        error = health_result.error,
        timestamp = ngx.time(),
        severity = "high"
    }
    
    -- Log alert
    ngx.log(ngx.ERR, "Health Check Alert: ", core.json.encode(alert_data))
    
    -- Send to monitoring system
    local http = require("resty.http")
    local httpc = http.new()
    
    local res, err = httpc:request_uri("http://localhost:9091/alerts", {
        method = "POST",
        body = core.json.encode(alert_data),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send health alert: ", err)
    end
end

-- Main health check function
return function(conf, ctx)
    local health_results = {}
    local failed_checks = 0
    
    -- Check each service
    for service_name, config in pairs(HEALTH_CHECK_CONFIG.services) do
        local health_result = check_service_health(service_name, config)
        health_results[service_name] = health_result
        
        if health_result.status ~= "up" then
            failed_checks = failed_checks + 1
            send_health_alert(service_name, health_result)
        end
    end
    
    -- Get overall health status
    local overall_health = get_overall_health()
    
    -- Add APISIX-specific health checks
    local apisix_health = {
        status = "up",
        uptime = ngx.var.uptime,
        version = "1.0.0",
        worker_processes = ngx.worker.count(),
        active_connections = ngx.var.connection_requests,
        timestamp = ngx.time()
    }
    
    health_results.apisix = apisix_health
    
    -- Create comprehensive health response
    local health_response = {
        overall = overall_health,
        services = health_results,
        summary = {
            total_services = #HEALTH_CHECK_CONFIG.services + 1, -- +1 for APISIX
            healthy_services = #HEALTH_CHECK_CONFIG.services + 1 - failed_checks,
            unhealthy_services = failed_checks,
            check_timestamp = ngx.time()
        }
    }
    
    -- Log health status
    ngx.log(ngx.INFO, "Health Check Complete: ", core.json.encode(health_response))
    
    -- Return health response
    return health_response
end




