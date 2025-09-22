-- Security Filter for APISIX
-- Provides comprehensive security filtering for your API gateway

local core = require("apisix.core")

-- Security patterns to detect malicious requests
local security_patterns = {
    -- SQL Injection patterns
    sql_injection = {
        "union.*select",
        "drop.*table",
        "insert.*into",
        "delete.*from",
        "update.*set",
        "exec.*cmd",
        "xp_cmdshell",
        "sp_executesql"
    },
    
    -- XSS patterns
    xss = {
        "script.*alert",
        "javascript:",
        "onload=",
        "onerror=",
        "onclick=",
        "<script",
        "</script>",
        "eval\\(",
        "expression\\("
    },
    
    -- Path traversal patterns
    path_traversal = {
        "\\.\\./",
        "\\.\\.\\\\",
        "%2e%2e%2f",
        "%2e%2e%5c",
        "..%2f",
        "..%5c"
    },
    
    -- Command injection patterns
    command_injection = {
        ";.*rm",
        ";.*cat",
        ";.*ls",
        "\\|.*cat",
        "\\|.*ls",
        "`.*cat",
        "`.*ls",
        "\\$\\(",
        "\\$\\(.*\\)"
    },
    
    -- LDAP injection patterns
    ldap_injection = {
        "\\*\\|\\(",
        "\\*\\|\\)",
        "\\*\\|\\*",
        "\\*\\|&",
        "\\*\\|\\|",
        "\\*\\|="
    }
}

-- Suspicious user agents
local suspicious_user_agents = {
    "bot",
    "crawler",
    "scanner",
    "spider",
    "harvester",
    "nmap",
    "nikto",
    "sqlmap",
    "w3af",
    "zap"
}

-- Rate limiting storage
local rate_limit_store = ngx.shared.rate_limit or {}

-- Helper function to check patterns
local function check_patterns(text, patterns, pattern_type)
    if not text then
        return false, nil
    end
    
    local lower_text = string.lower(text)
    
    for _, pattern in ipairs(patterns) do
        if string.match(lower_text, pattern) then
            return true, {
                type = pattern_type,
                pattern = pattern,
                matched_text = string.sub(text, 1, 100) -- First 100 chars
            }
        end
    end
    
    return false, nil
end

-- Helper function to check user agent
local function check_user_agent(user_agent)
    if not user_agent then
        return false, nil
    end
    
    local lower_ua = string.lower(user_agent)
    
    for _, suspicious in ipairs(suspicious_user_agents) do
        if string.match(lower_ua, suspicious) then
            return true, {
                type = "suspicious_user_agent",
                user_agent = user_agent,
                matched_pattern = suspicious
            }
        end
    end
    
    return false, nil
end

-- Helper function for rate limiting
local function check_rate_limit(client_ip, limit, window)
    local key = "rate_limit_" .. client_ip
    local current = rate_limit_store:get(key) or 0
    
    if current >= limit then
        return false, {
            type = "rate_limit_exceeded",
            current = current,
            limit = limit,
            window = window
        }
    end
    
    rate_limit_store:incr(key, 1)
    if current == 0 then
        rate_limit_store:expire(key, window)
    end
    
    return true, nil
end

-- Helper function to log security events
local function log_security_event(event_type, details, client_ip)
    local log_data = {
        timestamp = ngx.time(),
        event_type = event_type,
        client_ip = client_ip,
        request_uri = ngx.var.request_uri,
        request_method = ngx.var.request_method,
        user_agent = ngx.var.http_user_agent,
        details = details
    }
    
    ngx.log(ngx.WARN, "Security Event: ", core.json.encode(log_data))
    
    -- Send to security monitoring system if available
    local http = require("resty.http")
    local httpc = http.new()
    
    local res, err = httpc:request_uri("http://localhost:9091/security-events", {
        method = "POST",
        body = core.json.encode(log_data),
        headers = {
            ["Content-Type"] = "application/json"
        }
    })
    
    if not res then
        ngx.log(ngx.ERR, "Failed to send security event: ", err)
    end
end

-- Main security filter function
return function(conf, ctx)
    local client_ip = ngx.var.remote_addr
    local uri = ngx.var.request_uri
    local method = ngx.var.request_method
    local user_agent = ngx.var.http_user_agent
    local query_string = ngx.var.query_string
    local request_body = ngx.req.get_body_data()
    
    -- Rate limiting check
    local rate_limit_ok, rate_limit_error = check_rate_limit(client_ip, conf.rate_limit or 100, conf.rate_window or 60)
    if not rate_limit_ok then
        log_security_event("rate_limit_exceeded", rate_limit_error, client_ip)
        ngx.status = 429
        ngx.say('{"error": "Rate limit exceeded", "retry_after": ' .. conf.rate_window .. '}')
        ngx.exit(429)
    end
    
    -- User agent check
    local ua_suspicious, ua_details = check_user_agent(user_agent)
    if ua_suspicious then
        log_security_event("suspicious_user_agent", ua_details, client_ip)
        ngx.status = 403
        ngx.say('{"error": "Access denied: Suspicious user agent"}')
        ngx.exit(403)
    end
    
    -- Check URI for malicious patterns
    local uri_malicious, uri_details = check_patterns(uri, 
        core.table.concat(security_patterns.sql_injection, security_patterns.xss, 
                         security_patterns.path_traversal, security_patterns.command_injection), 
        "malicious_uri")
    if uri_malicious then
        log_security_event("malicious_uri", uri_details, client_ip)
        ngx.status = 403
        ngx.say('{"error": "Access denied: Malicious request pattern detected"}')
        ngx.exit(403)
    end
    
    -- Check query string
    if query_string then
        local qs_malicious, qs_details = check_patterns(query_string, 
            core.table.concat(security_patterns.sql_injection, security_patterns.xss, 
                             security_patterns.ldap_injection), 
            "malicious_query")
        if qs_malicious then
            log_security_event("malicious_query", qs_details, client_ip)
            ngx.status = 403
            ngx.say('{"error": "Access denied: Malicious query parameters"}')
            ngx.exit(403)
        end
    end
    
    -- Check request body
    if request_body then
        local body_malicious, body_details = check_patterns(request_body, 
            core.table.concat(security_patterns.sql_injection, security_patterns.xss, 
                             security_patterns.command_injection), 
            "malicious_body")
        if body_malicious then
            log_security_event("malicious_body", body_details, client_ip)
            ngx.status = 403
            ngx.say('{"error": "Access denied: Malicious request body"}')
            ngx.exit(403)
        end
    end
    
    -- Check request headers
    local headers = ngx.req.get_headers()
    for header_name, header_value in pairs(headers) do
        local header_malicious, header_details = check_patterns(header_value, 
            core.table.concat(security_patterns.xss, security_patterns.command_injection), 
            "malicious_header")
        if header_malicious then
            log_security_event("malicious_header", {
                header_name = header_name,
                header_value = header_value,
                details = header_details
            }, client_ip)
            ngx.status = 403
            ngx.say('{"error": "Access denied: Malicious header detected"}')
            ngx.exit(403)
        end
    end
    
    -- IP whitelist check (if configured)
    if conf.ip_whitelist then
        local ip_allowed = false
        for _, allowed_ip in ipairs(conf.ip_whitelist) do
            if string.match(client_ip, allowed_ip) then
                ip_allowed = true
                break
            end
        end
        
        if not ip_allowed then
            log_security_event("ip_not_whitelisted", {client_ip = client_ip}, client_ip)
            ngx.status = 403
            ngx.say('{"error": "Access denied: IP not whitelisted"}')
            ngx.exit(403)
        end
    end
    
    -- Log successful security check
    ngx.log(ngx.INFO, "Security filter passed for client: ", client_ip)
end




