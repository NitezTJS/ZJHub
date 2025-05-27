--[[
    ZJ/HUB Loader
    Version: 1.6
    Author: NitezTJS
]]--

-- Main 
local MAIN_SCRIPT_URL = 'https://raw.githubusercontent.com/YourUsername/ZJHub/main/main.lua'

-- Load
local success, result = pcall(function()
    return game:HttpGet(MAIN_SCRIPT_URL)
end)

if success then
    -- Execute main
    local mainFunc = loadstring(result)
    if mainFunc then
        mainFunc()
    else
        warn("Failed to compile ZJ/HUB main script")
    end
else
    warn("Failed to download ZJ/HUB: " .. tostring(result))
    
    -- Show error notification
    game.StarterGui:SetCore("SendNotification", {
        Title = "ZJ/HUB Error",
        Text = "Failed to load script. Check your internet connection.",
        Duration = 5
    })
end
