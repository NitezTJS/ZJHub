
--[[
    ZJ/HUB Main Loader
    Version: 1.6
    Author: NitezTJS
]]

local CURRENT_VERSION = "1.6"
local scriptName = "ZJHub_" .. math.random(1000, 9999)

local moduleUrls = {
    config = "https://raw.githubusercontent.com/NitezTJS/ZJHub/refs/heads/main/modules/config.lua",
    utils = "https://raw.githubusercontent.com/NitezTJS/ZJHub/refs/heads/main/modules/utils.lua",
    tracking = "https://raw.githubusercontent.com/NitezTJS/ZJHub/refs/heads/main/modules/tracking.lua",
    ores = "https://raw.githubusercontent.com/NitezTJS/ZJHub/refs/heads/main/modules/ores.lua",
    esp = "https://raw.githubusercontent.com/NitezTJS/ZJHub/refs/heads/main/modules/esp.lua",
    ui = "https://raw.githubusercontent.com/NitezTJS/ZJHub/refs/heads/main/modules/ui.lua"
}

local moduleCache = {}

local function loadModule(moduleName)
    if moduleCache[moduleName] then 
        return moduleCache[moduleName] 
    end
    
    if not moduleUrls[moduleName] then
        warn("Module URL not found: " .. moduleName)
        return nil
    end
    
    local success, moduleContent = pcall(function()
        return game:HttpGet(moduleUrls[moduleName])
    end)
    
    if not success then
        warn("Failed to load module: " .. moduleName)
        return nil
    end
    
    local moduleFunc = loadstring(moduleContent)
    if not moduleFunc then
        warn("Failed to compile module: " .. moduleName)
        return nil
    end
    
    local env = setmetatable({
        require = function(dependencyName)
            return loadModule(dependencyName)
        end,
        CURRENT_VERSION = CURRENT_VERSION,
        scriptName = scriptName
    }, {__index = getfenv()})
    
    setfenv(moduleFunc, env)
    local module = moduleFunc()
    moduleCache[moduleName] = module
    
    return module
end

local config = loadModule("config")
local utils = loadModule("utils")
local tracking = loadModule("tracking")
local ores = loadModule("ores")
local esp = loadModule("esp")
local ui = loadModule("ui")

if not utils.checkVersion(CURRENT_VERSION) then
    return
end

tracking.init()

ui.init({
    version = CURRENT_VERSION,
    ores = ores,
    esp = esp,
    tracking = tracking,
    utils = utils,
    config = config
})

print("ZJ/HUB v" .. CURRENT_VERSION .. " loaded successfully!")

