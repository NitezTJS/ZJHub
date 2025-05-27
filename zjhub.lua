--[[
    Ore ESP and Collector
    
    Features:
    - ESP for ores with distance indicators
    - Bring selected ores by tier
    - Bring Aura to automatically collect nearby ores
    - Anti-detection measures
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()

-- Configuration
local ESPEnabled = false
local ESPLabels = {}
local BringingItems = false
local BringDistance = 5
local BringSpeed = 2
local BringAuraEnabled = false
local BringAuraRadius = 50
local BringAuraSpeed = 3
local BringAuraConnection = nil

-- Anti-detection measures
local _G = getfenv and getfenv() or _G
local oldNamecall = nil
local randomStrings = {"_", "__", "___", "____", "_____"}
local scriptName = randomStrings[math.random(1, #randomStrings)] .. string.char(math.random(97, 122)) .. string.char(math.random(97, 122)) .. string.char(math.random(97, 122))

-- Selected ores (defined early to avoid undefined global)
local SelectedOres = {}

-- Exploit function declarations to avoid undefined globals
local getrawmetatable = getrawmetatable or function() return {} end
local setreadonly = setreadonly or function() return true end
local newcclosure = newcclosure or function(f) return f end
local getnamecallmethod = getnamecallmethod or function() return "" end

-- Function to check if an item is a selected ore
local function IsSelectedOre(item)
    -- Check if the item name contains any of the selected ores
    for oreName, selected in pairs(SelectedOres) do
        if selected and string.find(item.Name, oreName) then
            return true
        end
    end
    return false
end

-- Anti-detection: Metamethod hooking (with pcall for safety)
pcall(function()
    local mt = getrawmetatable(game)
    if mt then
        local oldIndex = mt.__index
        local oldNamecall = mt.__namecall
        
        -- Only proceed if we can modify the metatable
        pcall(function() setreadonly(mt, false) end)
        
        -- Create a random variable name for our functions
        local funcNames = {}
        for i = 1, 5 do
            funcNames[i] = string.char(math.random(97, 122)) .. string.char(math.random(97, 122)) .. string.char(math.random(97, 122)) .. string.char(math.random(97, 122))
        end
        
        -- Hook __namecall to avoid detection
        pcall(function()
            mt.__namecall = newcclosure(function(self, ...)
                local method = getnamecallmethod()
                local args = {...}
                
                -- Avoid detection of our script
                if method == "FindFirstChild" or method == "FindFirstChildOfClass" or method == "FindFirstChildWhichIsA" then
                    if args[1] == scriptName then
                        return nil
                    end
                end
                
                -- Avoid detection when checking for scripts
                if method == "GetChildren" or method == "GetDescendants" then
                    local results = oldNamecall(self, ...)
                    local filtered = {}
                    
                    for i, v in ipairs(results) do
                        if v.Name ~= scriptName then
                            table.insert(filtered, v)
                        end
                    end
                    
                    return filtered
                end
                
                return oldNamecall(self, ...)
            end)
        end)
        
        -- Hook __index to avoid detection
        pcall(function()
            mt.__index = newcclosure(function(self, key)
                -- Avoid detection by hiding our variables
                if key == scriptName or table.find(funcNames, key) then
                    return nil
                end
                
                return oldIndex(self, key)
            end)
        end)
        
        -- Set metatable back to readonly
        pcall(function() setreadonly(mt, true) end)
    end
end)

-- Ore tiers
local OreTiers = {
    ["Common"] = {
        "Silver Ore",
        "Coal Ore",
        "Zinc Ore",
        "Copper Ore",
        "Nickel Ore"
    },
    ["Uncommon"] = {
        "Sapphire Ore",
        "Gold Ore",
        "Quartz Ore",
        "Tin Ore",
        "Iron Ore"
    },
    ["Rare"] = {
        "Cobalt Ore",
        "Amethyst Ore",
        "Ruby Ore",
        "Dinosaur Bone",
        "Turquoise Ore",
        "Platinum Ore"
    },
    ["Epic"] = {
        "Treasure Chest",
        "King's Ring",
        "Ancient Skull",
        "Fossil Fin",
        "Fossil Hand",
        "Giant Cobalt",
        "Giant Platinum",
        "Uranium",
        "Giant Diamond"
    },
    ["Legendary"] = {
        "Lava Rock",
        "Giant Treasure Chest",
        "Ancient Coin",
        "Alien Artifact",
        "Bat Wing",
        "Giant Fossil Fin",
        "Rainbow Crystal",
        "Glowing Mushroom",
        "Moai Head",
        "Passage Key",
        "Ancient Arrow",
        "Ancient Relic"
    },
    ["Mythical"] = {
        "Pirate Ship",
        "Corrupted UFO",
        "Nuke",
        "King's Sword"
    }
}

-- Selected ores
local SelectedTiers = {}
-- SelectedOres is already defined above
local DropdownOptions = {}

-- Prepare dropdown options
for tier, ores in pairs(OreTiers) do
    table.insert(DropdownOptions, tier)
    for _, ore in ipairs(ores) do
        SelectedOres[ore] = false
    end
end

-- Load Rayfield UI Library
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- Create Window with randomized name for anti-detection
local windowNames = {
    "Mining Helper",
    "Ore Finder",
    "Resource Locator",
    "Mineral Detector",
    "Gem Collector"
}
local selectedName = windowNames[math.random(1, #windowNames)]

local Window = Rayfield:CreateWindow({
    Name = selectedName,
    LoadingTitle = selectedName,
    LoadingSubtitle = "by NiteZTJS",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = nil,
        FileName = "MiningConfig_" .. math.random(1000, 9999)
    },
    KeySystem = false
})

-- Create Main Tab
local MainTab = Window:CreateTab("Main", "map-pin")

-- Create Tier Selection Section
MainTab:CreateSection("Ore Tier Selection")

-- Create Tier Dropdowns
for tier, ores in pairs(OreTiers) do
    -- Create tier toggle
    MainTab:CreateToggle({
        Name = tier .. " Tier",
        CurrentValue = false,
        Flag = "Toggle" .. tier,
        Callback = function(Value)
            SelectedTiers[tier] = Value
            
            -- Auto-select/deselect all ores in this tier
            for _, ore in ipairs(ores) do
                SelectedOres[ore] = Value
            end
            
            -- Check if any tiers are selected
            local anySelected = false
            for _, selected in pairs(SelectedTiers) do
                if selected then
                    anySelected = true
                    break
                end
            end
            
            -- Show warning if no tiers selected and bring aura is enabled
            if not anySelected and BringAuraEnabled then
                Rayfield:Notify({
                    Title = "Warning",
                    Content = "No ore tiers selected. Please select at least one tier.",
                    Duration = 5,
                })
            end
        end,
    })
    
    -- Create dropdown for specific ores in this tier
    local oreOptions = {}
    for _, ore in ipairs(ores) do
        table.insert(oreOptions, ore)
    end
    
    MainTab:CreateDropdown({
        Name = "Select " .. tier .. " Ores",
        Options = oreOptions,
        CurrentOption = "",
        MultiSelection = true,
        Flag = "Dropdown" .. tier,
        Callback = function(Options)
            -- Reset all ores in this tier
            for _, ore in ipairs(ores) do
                SelectedOres[ore] = false
            end
            
            -- Set selected ores
            for _, option in ipairs(Options) do
                SelectedOres[option] = true
            end
            
            -- Update tier toggle based on selections
            local allSelected = true
            for _, ore in ipairs(ores) do
                if not SelectedOres[ore] then
                    allSelected = false
                    break
                end
            end
            
            SelectedTiers[tier] = #Options > 0
        end,
    })
end

-- Create ESP and Bring Section
MainTab:CreateSection("ESP & Collection Controls")

-- Function to create ESP for an item
local function CreateESP(item)
    if not item:IsA("BasePart") and not item:IsA("Model") then return end
    
    -- Create ESP BillboardGui
    local BillboardGui = Instance.new("BillboardGui")
    BillboardGui.Name = "ESP"
    BillboardGui.AlwaysOnTop = true
    BillboardGui.Size = UDim2.new(0, 200, 0, 50)
    BillboardGui.StudsOffset = Vector3.new(0, 2, 0)
    BillboardGui.Adornee = item:IsA("Model") and item.PrimaryPart or item
    
    -- Create ESP Text Label
    local TextLabel = Instance.new("TextLabel")
    TextLabel.BackgroundTransparency = 1
    TextLabel.Size = UDim2.new(1, 0, 1, 0)
    TextLabel.Font = Enum.Font.SourceSansBold
    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TextLabel.TextStrokeTransparency = 0
    TextLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    TextLabel.TextSize = 14
    TextLabel.Parent = BillboardGui
    
    -- Add to Player's GUI
    BillboardGui.Parent = Player.PlayerGui
    
    -- Store in ESPLabels table
    ESPLabels[item] = {
        Object = BillboardGui,
        TextLabel = TextLabel
    }
    
    return BillboardGui
end

-- Function to update ESP information
local function UpdateESP()
    if not ESPEnabled then return end
    
    -- Get character's current position
    local character = Player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local rootPosition = character.HumanoidRootPart.Position
    
    -- Get all items from the Items folder
    local items = {}
    if workspace:FindFirstChild("Items") then
        for _, item in pairs(workspace.Items:GetChildren()) do
            -- Only add selected ores if any are selected, otherwise show all
            local anySelected = false
            for _, selected in pairs(SelectedOres) do
                if selected then
                    anySelected = true
                    break
                end
            end
            
            if not anySelected or IsSelectedOre(item) then
                table.insert(items, item)
            end
        end
    end
    
    -- Update existing ESP labels and create new ones
    for _, item in pairs(items) do
        -- Get item position
        local itemPosition
        if item:IsA("Model") and item.PrimaryPart then
            itemPosition = item.PrimaryPart.Position
        elseif item:IsA("BasePart") then
            itemPosition = item.Position
        else
            continue
        end
        
        -- Calculate distance
        local distance = (rootPosition - itemPosition).Magnitude
        
        -- Create ESP if it doesn't exist
        if not ESPLabels[item] then
            CreateESP(item)
        end
        
        -- Update ESP text
        if ESPLabels[item] and ESPLabels[item].TextLabel then
            local itemName = item.Name
            ESPLabels[item].TextLabel.Text = itemName .. "\nDistance: " .. math.floor(distance) .. " studs"
            
            -- Determine ore tier for color
            local oreTier = "Unknown"
            for tier, ores in pairs(OreTiers) do
                for _, ore in ipairs(ores) do
                    if string.find(itemName, ore) then
                        oreTier = tier
                        break
                    end
                end
                if oreTier ~= "Unknown" then break end
            end
            
            -- Set color based on tier
            local color = Color3.fromRGB(255, 255, 255) -- Default white
            
            if oreTier == "Common" then
                color = Color3.fromRGB(150, 150, 150) -- Gray
            elseif oreTier == "Uncommon" then
                color = Color3.fromRGB(0, 255, 0) -- Green
            elseif oreTier == "Rare" then
                color = Color3.fromRGB(0, 170, 255) -- Blue
            elseif oreTier == "Epic" then
                color = Color3.fromRGB(170, 0, 255) -- Purple
            elseif oreTier == "Legendary" then
                color = Color3.fromRGB(255, 170, 0) -- Orange
            elseif oreTier == "Mythical" then
                color = Color3.fromRGB(255, 0, 0) -- Red
            end
            
            ESPLabels[item].TextLabel.TextColor3 = color
        end
    end
    
    -- Clean up ESPLabels for items that no longer exist
    for item, espData in pairs(ESPLabels) do
        if not item or not item.Parent then
            if espData.Object then
                espData.Object:Destroy()
            end
            ESPLabels[item] = nil
        end
    end
end

-- This function is now defined at the top with anti-detection measures

-- Function to bring selected ores to the player
local function BringAllItems()
    if not workspace:FindFirstChild("Items") or BringingItems then return end
    
    -- Check if any ores are selected
    local anySelected = false
    for _, selected in pairs(SelectedOres) do
        if selected then
            anySelected = true
            break
        end
    end
    
    if not anySelected then
        Rayfield:Notify({
            Title = "No Ores Selected",
            Content = "Please select at least one ore type to bring",
            Duration = 3,
        })
        return
    end
    
    local character = Player.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    local rootPosition = character.HumanoidRootPart.Position
    
    -- Get all items from the Items folder
    local items = workspace.Items:GetChildren()
    local selectedItems = {}
    
    -- Filter for selected ores
    for _, item in ipairs(items) do
        if IsSelectedOre(item) then
            table.insert(selectedItems, item)
        end
    end
    
    local itemCount = #selectedItems
    
    if itemCount == 0 then
        Rayfield:Notify({
            Title = "No Selected Ores Found",
            Content = "Could not find any of the selected ore types",
            Duration = 3,
        })
        return
    end
    
    BringingItems = true
    
    -- Notify start
    Rayfield:Notify({
        Title = "Bringing Ores",
        Content = "Bringing " .. itemCount .. " selected ores to your position",
        Duration = 3,
    })
    
    -- Process items with a slight delay between each to prevent lag
    local processedItems = 0
    local function processNextItem()
        processedItems = processedItems + 1
        
        if processedItems > itemCount then
            -- All items processed
            BringingItems = false
            
            Rayfield:Notify({
                Title = "Ores Brought",
                Content = "Successfully brought " .. itemCount .. " selected ores to your position",
                Duration = 3,
            })
            return
        end
        
        local item = selectedItems[processedItems]
        if not item or not item.Parent then
            -- Skip invalid items
            task.spawn(processNextItem)
            return
        end
        
        -- Calculate target position (offset from player)
        local angle = (processedItems / itemCount) * (2 * math.pi)
        local offsetX = math.cos(angle) * BringDistance
        local offsetZ = math.sin(angle) * BringDistance
        local targetPosition = rootPosition + Vector3.new(offsetX, 0, offsetZ)
        
        -- Get item position and create tween
        local itemPosition
        if item:IsA("Model") and item.PrimaryPart then
            itemPosition = item.PrimaryPart.Position
        elseif item:IsA("BasePart") then
            itemPosition = item.Position
        else
            -- Skip non-physical items
            task.spawn(processNextItem)
            return
        end
        
        -- Calculate tween duration based on distance and speed
        local distance = (itemPosition - targetPosition).Magnitude
        local duration = distance / (50 * BringSpeed) -- Adjust for speed
        
        -- Create and configure the tween
        local tweenInfo = TweenInfo.new(
            duration,
            Enum.EasingStyle.Quad,
            Enum.EasingDirection.Out
        )
        
        -- Determine which part to tween
        local tweenPart
        if item:IsA("Model") and item.PrimaryPart then
            tweenPart = item.PrimaryPart
        elseif item:IsA("BasePart") then
            tweenPart = item
        else
            -- Skip non-physical items
            task.spawn(processNextItem)
            return
        end
        
        -- Create and play tween
        local tween = TweenService:Create(tweenPart, tweenInfo, {
            CFrame = CFrame.new(targetPosition)
        })
        tween:Play()
        
        -- Process next item after tween completes
        tween.Completed:Connect(function()
            task.spawn(processNextItem)
        end)
    end
    
    -- Start processing items
    task.spawn(processNextItem)
end

-- Function to enable bring aura
local function EnableBringAura()
    if BringAuraConnection then return end
    
    -- Check if any ores are selected
    local anySelected = false
    for _, selected in pairs(SelectedOres) do
        if selected then
            anySelected = true
            break
        end
    end
    
    if not anySelected then
        Rayfield:Notify({
            Title = "No Ores Selected",
            Content = "Please select at least one ore type for the aura",
            Duration = 3,
        })
        return
    end
    
    BringAuraConnection = RunService.Heartbeat:Connect(function()
        -- Check if Items folder exists
        if not workspace:FindFirstChild("Items") then return end
        
        -- Get character position
        local character = Player.Character
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        local rootPosition = character.HumanoidRootPart.Position
        
        -- Process each item in the Items folder
        for _, item in pairs(workspace.Items:GetChildren()) do
            -- Skip if not a selected ore
            if not IsSelectedOre(item) then
                continue
            end
            
            -- Get item position
            local itemPosition
            if item:IsA("Model") and item.PrimaryPart then
                itemPosition = item.PrimaryPart.Position
            elseif item:IsA("BasePart") then
                itemPosition = item.Position
            else
                continue
            end
            
            -- Check if item is within radius
            local distance = (rootPosition - itemPosition).Magnitude
            if distance <= BringAuraRadius and distance > BringDistance then
                -- Calculate target position (offset from player)
                local direction = (rootPosition - itemPosition).Unit
                local targetPosition = rootPosition - (direction * BringDistance)
                
                -- Calculate tween duration based on distance and speed
                local tweenDuration = math.min(distance / (100 * BringAuraSpeed), 1) -- Cap at 1 second
                
                -- Create tween info
                local tweenInfo = TweenInfo.new(
                    tweenDuration,
                    Enum.EasingStyle.Quad,
                    Enum.EasingDirection.Out
                )
                
                -- Determine which part to tween
                local tweenPart
                if item:IsA("Model") and item.PrimaryPart then
                    tweenPart = item.PrimaryPart
                elseif item:IsA("BasePart") then
                    tweenPart = item
                else
                    continue
                end
                
                -- Create and play tween
                local tween = TweenService:Create(tweenPart, tweenInfo, {
                    CFrame = CFrame.new(targetPosition)
                })
                tween:Play()
            end
        end
    end)
    
    Rayfield:Notify({
        Title = "Bring Aura Enabled",
        Content = "Selected ores within " .. BringAuraRadius .. " studs will be pulled toward you",
        Duration = 3,
    })
end

-- Function to disable bring aura
local function DisableBringAura()
    if BringAuraConnection then
        BringAuraConnection:Disconnect()
        BringAuraConnection = nil
        
        Rayfield:Notify({
            Title = "Bring Aura Disabled",
            Content = "Items will no longer be automatically pulled toward you",
            Duration = 3,
        })
    end
end

-- Create ESP Toggle
MainTab:CreateToggle({
    Name = "Enable ESP",
    CurrentValue = ESPEnabled,
    Flag = "ESPToggle",
    Callback = function(Value)
        ESPEnabled = Value
        if not ESPEnabled then
            -- Clear all ESP labels when disabled
            for _, label in pairs(ESPLabels) do
                if label and label.Object and label.Object.Parent then
                    label.Object:Destroy()
                end
            end
            ESPLabels = {}
        end
    end,
})

-- Create Bring Selected Ores Button
MainTab:CreateButton({
    Name = "Bring Selected Ores",
    Callback = function()
        if BringingItems then
            Rayfield:Notify({
                Title = "Already in Progress",
                Content = "Wait for the current bring operation to complete",
                Duration = 3,
            })
            return
        end
        BringAllItems()
    end,
})

-- Create Bring Speed Slider
MainTab:CreateSlider({
    Name = "Bring Speed",
    Range = {0.5, 10},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = BringSpeed,
    Flag = "BringSpeedSlider",
    Callback = function(Value)
        BringSpeed = Value
    end,
})

-- Create Bring Aura Toggle
MainTab:CreateToggle({
    Name = "Enable Bring Aura",
    CurrentValue = BringAuraEnabled,
    Flag = "BringAuraToggle",
    Callback = function(Value)
        BringAuraEnabled = Value
        if BringAuraEnabled then
            EnableBringAura()
        else
            DisableBringAura()
        end
    end,
})

-- Create Bring Aura Radius Slider
MainTab:CreateSlider({
    Name = "Bring Aura Radius",
    Range = {10, 200},
    Increment = 5,
    Suffix = " studs",
    CurrentValue = BringAuraRadius,
    Flag = "BringAuraRadiusSlider",
    Callback = function(Value)
        BringAuraRadius = Value
    end,
})

-- Create Bring Aura Speed Slider
MainTab:CreateSlider({
    Name = "Bring Aura Speed",
    Range = {1, 10},
    Increment = 0.5,
    Suffix = "x",
    CurrentValue = BringAuraSpeed,
    Flag = "BringAuraSpeedSlider",
    Callback = function(Value)
        BringAuraSpeed = Value
    end,
})



-- Update ESP continuously
RunService.Heartbeat:Connect(function()
    UpdateESP()
end)

-- Handle character respawn
Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    
    -- Reconnect bring aura if it was enabled
    if BringAuraEnabled then
        task.wait(1) -- Wait for character to fully load
        EnableBringAura()
    end
end)

-- Notify on load
Rayfield:Notify({
    Title = "Script Loaded",
    Content = "Simple Item ESP with Bring All Items and Bring Aura features",
    Duration = 3,
})

-- Load configuration
Rayfield:LoadConfiguration()
