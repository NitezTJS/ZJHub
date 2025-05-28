--[[
    ZSecurity SDK
    Version: 1.0.0
    
    This SDK provides an interface to interact with the ZSecurity API
    for key validation and management in Roblox exploits.
]]

-- Configuration
local API_URL = "https://zsecurity-api.onrender.com" -- Replace with your actual API URL
local DEFAULT_TIMEOUT = 10 -- Seconds

-- Utility functions
local function generateMachineId()
    -- Generate a unique machine identifier based on hardware information
    local getMacAddress = function()
        local result = ""
        pcall(function()
            -- Try to get MAC address using different methods based on OS
            if identifyexecutor then
                -- Some exploits provide this function
                result = tostring(identifyexecutor())
            end
            
            -- Fallback to a mix of available system info
            if result == "" then
                local placeid = game.PlaceId
                local jobid = game.JobId
                local username = game:GetService("Players").LocalPlayer.Name
                local userid = game:GetService("Players").LocalPlayer.UserId
                result = placeid .. "-" .. jobid .. "-" .. username .. "-" .. userid
            end
        end)
        
        return result
    end
    
    -- Get system information that is unlikely to change
    local macAddress = getMacAddress()
    local username = game:GetService("Players").LocalPlayer.Name
    local userId = game:GetService("Players").LocalPlayer.UserId
    local platform = "roblox"
    
    -- Combine all information
    local combinedInfo = string.format("%s|%s|%s|%s", macAddress, username, userId, platform)
    
    -- Create a simple hash of the combined information
    local function simpleHash(str)
        local hash = 0
        for i = 1, #str do
            hash = ((hash << 5) - hash) + string.byte(str, i)
            hash = hash & hash -- Convert to 32bit integer
        end
        return tostring(hash)
    end
    
    local hash = simpleHash(combinedInfo)
    
    -- Format as UUID v4-like string
    local p1 = hash:sub(1, 8)
    local p2 = hash:sub(9, 12)
    local p3 = hash:sub(13, 16)
    local p4 = hash:sub(17, 20)
    local p5 = hash:sub(21, 32)
    
    if #p5 < 12 then p5 = p5 .. string.rep("0", 12 - #p5) end
    
    return string.format("%s-%s-%s-%s-%s", p1, p2, p3, p4, p5:sub(1, 12))
end

local function httpRequest(method, endpoint, data, timeout)
    timeout = timeout or DEFAULT_TIMEOUT
    
    -- Prepare the request
    local url = API_URL .. endpoint
    local headers = {
        ["Content-Type"] = "application/json"
    }
    
    local options = {
        Url = url,
        Method = method,
        Headers = headers,
        Body = data and game:GetService("HttpService"):JSONEncode(data) or nil
    }
    
    -- Make the request
    local success, response = pcall(function()
        -- Different exploits have different HTTP request functions
        if syn and syn.request then
            return syn.request(options)
        elseif http and http.request then
            return http.request(options)
        elseif request then
            return request(options)
        elseif httpRequest then
            return httpRequest(options)
        else
            error("HTTP request function not found")
        end
    end)
    
    if not success then
        return {
            success = false,
            error = "HTTP request failed: " .. tostring(response)
        }
    end
    
    -- Parse the response
    local body = response.Body
    local status = response.StatusCode
    
    local parsed = {
        success = status >= 200 and status < 300,
        status = status
    }
    
    if body then
        pcall(function()
            local jsonData = game:GetService("HttpService"):JSONDecode(body)
            for k, v in pairs(jsonData) do
                parsed[k] = v
            end
        end)
    end
    
    return parsed
end

-- ZSecurity API
local ZSecurity = {}

-- Initialize the SDK
function ZSecurity.init(config)
    if config then
        if config.apiUrl then
            API_URL = config.apiUrl
        end
        if config.timeout then
            DEFAULT_TIMEOUT = config.timeout
        end
    end
    
    -- Return the machine ID for reference
    return {
        machineId = generateMachineId()
    }
end

-- Generate a new key
function ZSecurity.generateKey()
    local machineId = generateMachineId()
    return httpRequest("POST", "/api/keys/generate", {
        machineId = machineId
    })
end

-- Validate a key
function ZSecurity.validateKey(key)
    if not key then
        return {
            success = false,
            valid = false,
            error = "Key is required"
        }
    end
    
    local machineId = generateMachineId()
    return httpRequest("POST", "/api/validate", {
        key = key,
        machineId = machineId
    })
end

-- Check if a key is valid (without incrementing usage count)
function ZSecurity.checkKey(key)
    if not key then
        return {
            success = false,
            valid = false,
            error = "Key is required"
        }
    end
    
    local machineId = generateMachineId()
    return httpRequest("POST", "/api/validate/check", {
        key = key,
        machineId = machineId
    })
end

-- Refresh a key (extend expiration)
function ZSecurity.refreshKey(key)
    if not key then
        return {
            success = false,
            error = "Key is required"
        }
    end
    
    local machineId = generateMachineId()
    return httpRequest("POST", "/api/keys/refresh", {
        key = key,
        machineId = machineId
    })
end

-- Revoke a key
function ZSecurity.revokeKey(key)
    if not key then
        return {
            success = false,
            error = "Key is required"
        }
    end
    
    local machineId = generateMachineId()
    return httpRequest("POST", "/api/keys/revoke", {
        key = key,
        machineId = machineId
    })
end

-- Get key information
function ZSecurity.getKeyInfo(key)
    if not key then
        return {
            success = false,
            error = "Key is required"
        }
    end
    
    return httpRequest("GET", "/api/keys/info/" .. key)
end

-- Return the SDK
return ZSecurity
