# Using Lua in APISIX - Complete Guide

## Overview

APISIX is built on top of OpenResty (Nginx + LuaJIT), which means you can use Lua scripts to extend APISIX functionality. This guide covers various ways to use Lua in APISIX for your monitoring and API gateway needs.

## Table of Contents

1. [Lua Plugin Development](#lua-plugin-development)
2. [Serverless Functions](#serverless-functions)
3. [Custom Filters](#custom-filters)
4. [Route-level Lua Scripts](#route-level-lua-scripts)
5. [Monitoring with Lua](#monitoring-with-lua)
6. [Best Practices](#best-practices)

## 1. Lua Plugin Development

### Creating a Custom Plugin

APISIX allows you to create custom plugins using Lua. Here's how to create a simple logging plugin:

```lua
-- plugins/custom-logger.lua
local core = require("apisix.core")
local plugin_name = "custom-logger"

local schema = {
    type = "object",
    properties = {
        log_level = {
            type = "string",
            default = "info"
        },
        include_headers = {
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

function _M.access(conf, ctx)
    local log_data = {
        timestamp = ngx.time(),
        method = ngx.var.request_method,
        uri = ngx.var.request_uri,
        remote_addr = ngx.var.remote_addr,
        user_agent = ngx.var.http_user_agent,
    }
    
    if conf.include_headers then
        log_data.headers = ngx.req.get_headers()
    end
    
    core.log.info("Custom Logger: ", core.json.encode(log_data))
end

return _M
```

### Plugin Lifecycle Hooks

APISIX plugins can implement various lifecycle hooks:

- `init()` - Plugin initialization
- `access()` - Before forwarding to upstream
- `header_filter()` - Before sending response headers
- `body_filter()` - Before sending response body
- `log()` - After request completion

## 2. Serverless Functions

### Pre-function (Before Request)

Use `serverless-pre-function` plugin to execute Lua code before forwarding requests:

```lua
-- Example: Add custom headers and validate requests
return function(conf, ctx)
    -- Add custom headers
    ngx.req.set_header("X-Custom-Request-ID", ngx.var.request_id)
    ngx.req.set_header("X-Request-Time", ngx.time())
    
    -- Validate API key format
    local api_key = ngx.var.arg_api_key
    if api_key and not string.match(api_key, "^[a-f0-9]{32}$") then
        ngx.status = 400
        ngx.say('{"error": "Invalid API key format"}')
        ngx.exit(400)
    end
    
    -- Log request details
    ngx.log(ngx.INFO, "Request to: ", ngx.var.request_uri)
end
```

### Post-function (After Response)

Use `serverless-post-function` plugin to execute Lua code after receiving upstream response:

```lua
-- Example: Transform response and add monitoring data
return function(conf, ctx)
    -- Get response body
    local res = ngx.ctx.resp_body
    if res then
        -- Parse JSON response
        local json = require("cjson")
        local data = json.decode(res)
        
        -- Add monitoring metadata
        data.monitoring = {
            response_time = ngx.var.request_time,
            upstream_time = ngx.var.upstream_response_time,
            status_code = ngx.status
        }
        
        -- Update response
        ngx.say(json.encode(data))
    end
end
```

## 3. Custom Filters

### Request Filtering

```lua
-- Filter malicious requests
return function(conf, ctx)
    local uri = ngx.var.request_uri
    local user_agent = ngx.var.http_user_agent or ""
    
    -- Block suspicious patterns
    local suspicious_patterns = {
        "script.*alert",
        "union.*select",
        "drop.*table",
        "exec.*cmd"
    }
    
    for _, pattern in ipairs(suspicious_patterns) do
        if string.match(uri:lower(), pattern) then
            ngx.status = 403
            ngx.say('{"error": "Request blocked by security filter"}')
            ngx.exit(403)
        end
    end
    
    -- Block suspicious user agents
    if string.match(user_agent:lower(), "bot|crawler|scanner") then
        ngx.status = 403
        ngx.say('{"error": "Bot access denied"}')
        ngx.exit(403)
    end
end
```

### Response Transformation

```lua
-- Transform API responses for consistency
return function(conf, ctx)
    local res = ngx.ctx.resp_body
    if res and ngx.status == 200 then
        local json = require("cjson")
        local data = json.decode(res)
        
        -- Standardize response format
        local standardized = {
            success = true,
            data = data,
            timestamp = ngx.time(),
            request_id = ngx.var.request_id
        }
        
        ngx.say(json.encode(standardized))
    end
end
```

## 4. Route-level Lua Scripts

### Dynamic Routing

```lua
-- Route based on request content
return function(conf, ctx)
    local body = ngx.req.get_body_data()
    if body then
        local json = require("cjson")
        local data = json.decode(body)
        
        -- Route to different upstreams based on data
        if data.priority == "high" then
            ngx.var.upstream = "high-priority-backend"
        elseif data.priority == "low" then
            ngx.var.upstream = "low-priority-backend"
        else
            ngx.var.upstream = "default-backend"
        end
    end
end
```

### Rate Limiting with Custom Logic

```lua
-- Custom rate limiting based on user tier
return function(conf, ctx)
    local user_id = ngx.var.arg_user_id
    local user_tier = get_user_tier(user_id) -- Custom function
    
    local limits = {
        basic = 100,    -- requests per minute
        premium = 1000,
        enterprise = 10000
    }
    
    local limit = limits[user_tier] or limits.basic
    local current_count = get_request_count(user_id) -- Custom function
    
    if current_count > limit then
        ngx.status = 429
        ngx.say('{"error": "Rate limit exceeded for tier: ' .. user_tier .. '"}')
        ngx.exit(429)
    end
end
```

## 5. Monitoring with Lua

### Custom Metrics Collection

```lua
-- Collect custom metrics for Prometheus
return function(conf, ctx)
    local metrics = {
        request_count = 1,
        request_duration = ngx.var.request_time,
        response_size = ngx.var.bytes_sent,
        status_code = ngx.status
    }
    
    -- Send to custom metrics endpoint
    local http = require("resty.http")
    local httpc = http.new()
    local res, err = httpc:request_uri("http://localhost:9091/metrics", {
        method = "POST",
        body = ngx.encode_base64(cjson.encode(metrics))
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send metrics: ", err)
    end
end
```

### Health Check Enhancement

```lua
-- Enhanced health check with dependency validation
return function(conf, ctx)
    local health_status = {
        status = "healthy",
        timestamp = ngx.time(),
        dependencies = {}
    }
    
    -- Check database connectivity
    local db_ok = check_database_health()
    health_status.dependencies.database = db_ok and "up" or "down"
    
    -- Check Redis connectivity
    local redis_ok = check_redis_health()
    health_status.dependencies.redis = redis_ok and "up" or "down"
    
    -- Check external API
    local api_ok = check_external_api_health()
    health_status.dependencies.external_api = api_ok and "up" or "down"
    
    -- Determine overall health
    if not (db_ok and redis_ok and api_ok) then
        health_status.status = "degraded"
    end
    
    ngx.say(cjson.encode(health_status))
end
```

## 6. Best Practices

### Performance Considerations

1. **Use ngx.shared.DICT for caching**:
```lua
local shared = ngx.shared.cache
local cached = shared:get("key")
if not cached then
    cached = expensive_operation()
    shared:set("key", cached, 60) -- 60 seconds TTL
end
```

2. **Avoid blocking operations**:
```lua
-- Use non-blocking HTTP requests
local http = require("resty.http")
local httpc = http.new()
httpc:set_timeout(1000) -- 1 second timeout
```

3. **Optimize string operations**:
```lua
-- Use string.find instead of string.match when possible
local pos = string.find(uri, "api/", 1, true)
```

### Error Handling

```lua
-- Always handle errors gracefully
local function safe_json_decode(str)
    local ok, result = pcall(cjson.decode, str)
    if ok then
        return result
    else
        ngx.log(ngx.ERR, "JSON decode error: ", result)
        return nil
    end
end
```

### Logging

```lua
-- Use appropriate log levels
ngx.log(ngx.ERR, "Error message")      -- Errors
ngx.log(ngx.WARN, "Warning message")   -- Warnings
ngx.log(ngx.INFO, "Info message")      -- Information
ngx.log(ngx.DEBUG, "Debug message")    -- Debug (only in debug mode)
```

## Configuration Examples

### Route with Lua Script

```json
{
    "uri": "/api/*",
    "plugins": {
        "serverless-pre-function": {
            "phase": "access",
            "functions": ["return function(conf, ctx) ngx.log(ngx.INFO, 'Custom logic executed') end"]
        }
    },
    "upstream": {
        "nodes": {
            "httpbin.org": 1
        }
    }
}
```

### Global Plugin Configuration

```json
{
    "plugins": {
        "custom-logger": {
            "log_level": "info",
            "include_headers": true
        }
    }
}
```

## Next Steps

1. Start with simple serverless functions
2. Create custom plugins for reusable functionality
3. Implement monitoring and logging
4. Add security filters
5. Optimize for performance

This guide provides the foundation for using Lua effectively in APISIX. Each example can be adapted to your specific monitoring and API gateway requirements.




