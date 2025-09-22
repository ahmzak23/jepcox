-- Custom Logger Plugin for APISIX
-- This plugin provides enhanced logging capabilities for your monitoring setup

local core = require("apisix.core")
local plugin_name = "custom-logger"

local schema = {
    type = "object",
    properties = {
        log_level = {
            type = "string",
            enum = {"debug", "info", "warn", "error"},
            default = "info"
        },
        include_headers = {
            type = "boolean",
            default = true
        },
        include_body = {
            type = "boolean",
            default = false
        },
        log_to_file = {
            type = "boolean",
            default = false
        },
        log_file_path = {
            type = "string",
            default = "/tmp/apisix-custom.log"
        },
        metrics_enabled = {
            type = "boolean",
            default = true
        }
    }
}

local _M = {
    version = 0.1,
    priority = 1000,
    name = plugin_name,
    schema = schema,
}

-- Helper function to get log level number
local function get_log_level(level)
    local levels = {
        debug = ngx.DEBUG,
        info = ngx.INFO,
        warn = ngx.WARN,
        error = ngx.ERR
    }
    return levels[level] or ngx.INFO
end

-- Helper function to safely get request body
local function get_request_body()
    ngx.req.read_body()
    return ngx.req.get_body_data()
end

-- Helper function to safely get response body
local function get_response_body()
    return ngx.ctx.resp_body
end

-- Log to file function
local function log_to_file(data, file_path)
    local file = io.open(file_path, "a")
    if file then
        file:write(core.json.encode(data) .. "\n")
        file:close()
    end
end

-- Send metrics to Prometheus
local function send_metrics(metrics_data)
    if not metrics_data.metrics_enabled then
        return
    end
    
    local http = require("resty.http")
    local httpc = http.new()
    
    local metrics = {
        apisix_request_count = 1,
        apisix_request_duration = metrics_data.request_time,
        apisix_response_size = metrics_data.response_size,
        apisix_status_code = metrics_data.status_code
    }
    
    -- Send to your Prometheus pushgateway or metrics endpoint
    local res, err = httpc:request_uri("http://localhost:9091/metrics", {
        method = "POST",
        body = core.json.encode(metrics),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send metrics: ", err)
    end
end

function _M.access(conf, ctx)
    local log_data = {
        timestamp = ngx.time(),
        request_id = ngx.var.request_id,
        method = ngx.var.request_method,
        uri = ngx.var.request_uri,
        remote_addr = ngx.var.remote_addr,
        user_agent = ngx.var.http_user_agent,
        phase = "access"
    }
    
    if conf.include_headers then
        log_data.headers = ngx.req.get_headers()
    end
    
    if conf.include_body then
        log_data.request_body = get_request_body()
    end
    
    -- Store for later use
    ngx.ctx.custom_log_data = log_data
    
    local log_level = get_log_level(conf.log_level)
    ngx.log(log_level, "Custom Logger [ACCESS]: ", core.json.encode(log_data))
    
    if conf.log_to_file then
        log_to_file(log_data, conf.log_file_path)
    end
end

function _M.header_filter(conf, ctx)
    local log_data = ngx.ctx.custom_log_data or {}
    log_data.phase = "header_filter"
    log_data.response_headers = ngx.resp.get_headers()
    log_data.status_code = ngx.status
    
    local log_level = get_log_level(conf.log_level)
    ngx.log(log_level, "Custom Logger [HEADER_FILTER]: ", core.json.encode(log_data))
    
    if conf.log_to_file then
        log_to_file(log_data, conf.log_file_path)
    end
end

function _M.body_filter(conf, ctx)
    local log_data = ngx.ctx.custom_log_data or {}
    log_data.phase = "body_filter"
    log_data.response_body = get_response_body()
    log_data.response_size = ngx.var.bytes_sent
    log_data.request_time = ngx.var.request_time
    
    local log_level = get_log_level(conf.log_level)
    ngx.log(log_level, "Custom Logger [BODY_FILTER]: ", core.json.encode(log_data))
    
    if conf.log_to_file then
        log_to_file(log_data, conf.log_file_path)
    end
end

function _M.log(conf, ctx)
    local log_data = ngx.ctx.custom_log_data or {}
    log_data.phase = "log"
    log_data.upstream_time = ngx.var.upstream_response_time
    log_data.final_status = ngx.status
    
    -- Send metrics
    send_metrics({
        request_time = ngx.var.request_time,
        response_size = ngx.var.bytes_sent,
        status_code = ngx.status,
        metrics_enabled = conf.metrics_enabled
    })
    
    local log_level = get_log_level(conf.log_level)
    ngx.log(log_level, "Custom Logger [LOG]: ", core.json.encode(log_data))
    
    if conf.log_to_file then
        log_to_file(log_data, conf.log_file_path)
    end
end

return _M




