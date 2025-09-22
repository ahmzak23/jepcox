-- Response Transformer Filter for APISIX
-- Transforms API responses for consistency and monitoring

local core = require("apisix.core")

-- Helper function to safely decode JSON
local function safe_json_decode(str)
    if not str then
        return nil
    end
    
    local ok, result = pcall(cjson.decode, str)
    if ok then
        return result
    else
        ngx.log(ngx.ERR, "JSON decode error: ", result)
        return nil
    end
end

-- Helper function to safely encode JSON
local function safe_json_encode(data)
    local ok, result = pcall(cjson.encode, data)
    if ok then
        return result
    else
        ngx.log(ngx.ERR, "JSON encode error: ", result)
        return '{"error": "JSON encoding failed"}'
    end
end

-- Helper function to add monitoring metadata
local function add_monitoring_metadata(data, conf)
    if not conf.add_monitoring_metadata then
        return data
    end
    
    local metadata = {
        request_id = ngx.var.request_id,
        response_time_ms = ngx.var.request_time * 1000,
        upstream_time_ms = ngx.var.upstream_response_time and (ngx.var.upstream_response_time * 1000) or nil,
        status_code = ngx.status,
        timestamp = ngx.time(),
        server = "apisix"
    }
    
    if conf.include_request_info then
        metadata.request = {
            method = ngx.var.request_method,
            uri = ngx.var.request_uri,
            client_ip = ngx.var.remote_addr,
            user_agent = ngx.var.http_user_agent
        }
    end
    
    if conf.include_performance_metrics then
        metadata.performance = {
            bytes_sent = ngx.var.bytes_sent,
            connection_requests = ngx.var.connection_requests,
            connection_status = ngx.var.connection_status
        }
    end
    
    return {
        data = data,
        metadata = metadata
    }
end

-- Helper function to standardize error responses
local function standardize_error_response(data, conf)
    if not conf.standardize_errors then
        return data
    end
    
    local status_code = ngx.status
    
    if status_code >= 400 then
        local error_response = {
            success = false,
            error = {
                code = status_code,
                message = get_error_message(status_code),
                timestamp = ngx.time(),
                request_id = ngx.var.request_id
            }
        }
        
        -- Preserve original error data if it exists
        if data and type(data) == "table" then
            error_response.error.details = data
        end
        
        return error_response
    end
    
    return data
end

-- Helper function to get error message by status code
local function get_error_message(status_code)
    local error_messages = {
        [400] = "Bad Request",
        [401] = "Unauthorized",
        [403] = "Forbidden",
        [404] = "Not Found",
        [405] = "Method Not Allowed",
        [408] = "Request Timeout",
        [409] = "Conflict",
        [422] = "Unprocessable Entity",
        [429] = "Too Many Requests",
        [500] = "Internal Server Error",
        [502] = "Bad Gateway",
        [503] = "Service Unavailable",
        [504] = "Gateway Timeout"
    }
    
    return error_messages[status_code] or "Unknown Error"
end

-- Helper function to filter sensitive data
local function filter_sensitive_data(data, conf)
    if not conf.filter_sensitive_data or not data then
        return data
    end
    
    local sensitive_fields = conf.sensitive_fields or {
        "password", "token", "secret", "key", "auth", "credential"
    }
    
    if type(data) == "table" then
        local filtered = {}
        for key, value in pairs(data) do
            local is_sensitive = false
            for _, field in ipairs(sensitive_fields) do
                if string.match(string.lower(key), field) then
                    is_sensitive = true
                    break
                end
            end
            
            if is_sensitive then
                filtered[key] = "[FILTERED]"
            else
                filtered[key] = value
            end
        end
        return filtered
    end
    
    return data
end

-- Helper function to add CORS headers
local function add_cors_headers(conf)
    if not conf.add_cors_headers then
        return
    end
    
    local origin = ngx.var.http_origin
    local allowed_origins = conf.allowed_origins or {"*"}
    
    local is_allowed = false
    for _, allowed in ipairs(allowed_origins) do
        if allowed == "*" or origin == allowed then
            is_allowed = true
            break
        end
    end
    
    if is_allowed then
        ngx.header["Access-Control-Allow-Origin"] = origin or "*"
        ngx.header["Access-Control-Allow-Methods"] = conf.allowed_methods or "GET, POST, PUT, DELETE, OPTIONS"
        ngx.header["Access-Control-Allow-Headers"] = conf.allowed_headers or "Content-Type, Authorization, X-Requested-With"
        ngx.header["Access-Control-Allow-Credentials"] = "true"
        ngx.header["Access-Control-Max-Age"] = "86400"
    end
end

-- Helper function to compress response
local function compress_response(data, conf)
    if not conf.compress_response or not data then
        return data
    end
    
    local accept_encoding = ngx.var.http_accept_encoding or ""
    
    if string.match(accept_encoding, "gzip") then
        local compressed = ngx.deflate(data, "gzip")
        if compressed then
            ngx.header["Content-Encoding"] = "gzip"
            return compressed
        end
    elseif string.match(accept_encoding, "deflate") then
        local compressed = ngx.deflate(data, "deflate")
        if compressed then
            ngx.header["Content-Encoding"] = "deflate"
            return compressed
        end
    end
    
    return data
end

-- Main response transformer function
return function(conf, ctx)
    -- Add CORS headers if configured
    add_cors_headers(conf)
    
    -- Get response body
    local response_body = ngx.ctx.resp_body
    if not response_body then
        return
    end
    
    -- Parse JSON response
    local data = safe_json_decode(response_body)
    if not data then
        -- If not JSON, return as is
        return
    end
    
    -- Filter sensitive data
    data = filter_sensitive_data(data, conf)
    
    -- Standardize error responses
    data = standardize_error_response(data, conf)
    
    -- Add monitoring metadata
    data = add_monitoring_metadata(data, conf)
    
    -- Add custom headers
    if conf.custom_headers then
        for header_name, header_value in pairs(conf.custom_headers) do
            ngx.header[header_name] = header_value
        end
    end
    
    -- Add cache headers
    if conf.cache_headers then
        if conf.cache_headers.max_age then
            ngx.header["Cache-Control"] = "max-age=" .. conf.cache_headers.max_age
        end
        if conf.cache_headers.etag then
            ngx.header["ETag"] = conf.cache_headers.etag
        end
    end
    
    -- Transform response
    local transformed_data = data
    
    -- Apply custom transformation function if provided
    if conf.transform_function then
        local ok, result = pcall(loadstring(conf.transform_function), data, conf)
        if ok then
            transformed_data = result
        else
            ngx.log(ngx.ERR, "Transform function error: ", result)
        end
    end
    
    -- Encode back to JSON
    local json_response = safe_json_encode(transformed_data)
    
    -- Compress response if configured
    json_response = compress_response(json_response, conf)
    
    -- Update response
    ngx.ctx.resp_body = json_response
    ngx.arg[1] = json_response
    
    -- Log transformation
    if conf.log_transformations then
        ngx.log(ngx.INFO, "Response transformed: ", json_response)
    end
end




