--[[
    SENZY HUB - Roll Anime to Fight (v8.0 - Enhanced Auto Buy & Method 2 Support)
]]

-- -----------------------------------------------------------------
-- 1. Services & Cleanup System
-- -----------------------------------------------------------------
local function getService(serviceName)
    local service = game:GetService(serviceName)
    return (cloneref and cloneref(service)) or service
end

local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")
local HttpService = getService("HttpService")
local Lighting = getService("Lighting")
local VirtualUser = getService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

if getgenv().AutoRollSystem then
    getgenv().AutoRollSystem.Running = false
    
    if getgenv().AutoRollSystem.Connections then
        for _, conn in ipairs(getgenv().AutoRollSystem.Connections) do
            pcall(function() conn:Disconnect() end)
        end
    end
    
    if getgenv().AutoRollSystem.Connection then
        pcall(function() getgenv().AutoRollSystem.Connection:Disconnect() end)
    end
    
    getgenv().AutoRollSystem = nil
end

getgenv().AutoRollSystem = { 
    Enabled = false, 
    Running = true, 
    Connection = nil, 
    Connections = {} 
}

-- -----------------------------------------------------------------
-- 2. Configuration & Data Mappings
-- -----------------------------------------------------------------
local isLoadingConfig = true

local Config = {
    AutoSummon = false,
    AutoBuy = false,
    AutoSell = false,
    AutoMerge = false,
    AutoSpinWheel = false,
    AutoUpgradeGold = false,
    AutoUpgradeLuck = false,
    AutoUpgradeSlots = false,
    AutoUpgradeInventory = false,
    AutoClaimQuests = false,
    AutoClaimBP = false,
    DisplayTag = false,
    AntiAFK = true,
    RollSpeed = 1.6,
    MergeDelay = 2.0,
    WebhookURL = "",
    DiscordUserID = "",
    
    -- Method 1 Filters
    SelectedCharacters = {},
    SelectedMutations = {},
    
    -- Method 2 Filters (New)
    Method2_Enabled = false,
    Method2_Units = {}, -- Format: ["aizen"] = { Rarity = { God = true, Secret = true, All = false } }
    Method2_Mutations = {}, -- Format: ["god"] = { demon = true }
    
    SellRarities = { Common = false, Rare = false, Epic = false, Legendary = false, Mythic = false, Secret = false, God = false, Limited = false },
    SellCharacters = {},
    SellMutations = {}
}

local UIElements = {
    Toggles = {},
    Textboxes = {},
    Dropdowns = {}
}

local CharacterRarityMap = {
    Common = { "Ussop", "Krillin", "Luffy", "Zoro", "Itadori" },
    Rare = { "Goku", "Maki", "Junwoo", "Mob", "Sakura" },
    Epic = { "Shinra", "Manji", "Ban", "Guts", "Renji", "Tanjiro", "Piccolo" },
    Legendary = { "Erwin", "Gojo", "Grimmjow", "Nanami", "Naruto", "NarutoClone", "Saitama", "Sukuna", "Trunks", "Zenitsu" },
    Mythic = { "Ace", "Akaza", "Broly", "Hoshina", "Kashimo", "Kisuke", "Kokushibo", "Orihime", "Rengoku", "Simo Hayha", "Stark", "Toji", "Yoruichi" },
    Secret = { "Byakuya", "Dio", "Douma", "Frieren", "Gyomei", "Hakari", "Jiren", "Kenpachi", "Mahoraga", "Megumi", "Mojuro", "Rika", "Ulquiorra", "Yhwatch", "Yuta" },
    God = { "Ainz", "Aizen (Transcendent)", "Beerus", "Dabura", "Death Knight", "Gojo (Shibuya)", "Goku (Black)", "Ichigo", "Muzan", "Muzan (Evolved)", "Rimuru", "Shanks", "Sukuna (Heian)", "Whis", "Yamamoto", "Yorichi", "Yuji (Modulo)" },
    Limited = { "Albedo", "Black Frieza", "Britain Army", "Cosmic Garou", "DarkMagician", "DarkMagicianGirl", "Entoma", "Frieza", "Genos", "Hakari (JackPot)", "Juuzou", "Julius", "Katakuri", "Lelouch", "Mash", "Milim", "Okurun", "Saitama (Serious)", "Sakamoto", "Sakamoto (Fit)", "Shalltear", "Spider (Entoma)", "Tatsumaki", "Yor", "Yugi" }
}

local RarityList = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" }

local RarityColorMap = {
    Common = "#A6A6A6", Rare = "#1E90FF", Epic = "#9370DB", Legendary = "#FFD700",
    Mythic = "#FF4500", Secret = "#8A2BE2", God = "#FF0000", Limited = "#00FFFF"
}

local AllMutations = { "Astronaut", "Cursed", "Demon", "Destroyer", "Diamond", "Gold", "Hollow", "No Mutation", "Slayer" }
local LowRarities = { "Common", "Rare", "Epic", "Legendary" }
local HighRarities = { "Mythic", "Secret", "God", "Limited" }

-- Flatten All Units for Method 2 Selection
local AllUnitsList = {}
for _, list in pairs(CharacterRarityMap) do
    for _, unitName in ipairs(list) do
        table.insert(AllUnitsList, unitName)
    end
end
table.sort(AllUnitsList)

local isBuying = false
local latestRollData = nil
local sentWebhookCache = {}
local cachedRollPrompts = {}
local cachedMergePrompts = {}
local originalDisplayName = LocalPlayer.DisplayName

local RollRemote, BuyRemote, SellRemote
pcall(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if Remotes then
        local Characters = Remotes:WaitForChild("Characters", 5)
        if Characters then
            RollRemote = Characters:WaitForChild("Roll", 5)
            BuyRemote = Characters:WaitForChild("Buy", 5)
            SellRemote = Characters:WaitForChild("Sell", 5)
        end
    end
end)

-- -----------------------------------------------------------------
-- 3. Core Helper Functions
-- -----------------------------------------------------------------
local function CleanName(str)
    if not str then return "" end
    return string.lower(tostring(str)):gsub("[%s%c%p]", "")
end

local function GetRarityOfCharacter(charName)
    if not charName or charName == "" then return "Unknown" end
    local cleanTarget = CleanName(charName)
    for rarity, list in pairs(CharacterRarityMap) do
        for _, name in ipairs(list) do
            if CleanName(name) == cleanTarget then return rarity end
        end
    end
    return "Unknown"
end

local function GetToolUUID(tool)
    if not tool or not tool.Parent then return nil end
    local uuid = tool:GetAttribute("UUID") or tool:GetAttribute("uuid") or tool:GetAttribute("ID") or tool:GetAttribute("Id")
    if uuid then return tostring(uuid) end
    
    for _, child in ipairs(tool:GetChildren()) do
        if child:IsA("ValueBase") then
            local cName = string.lower(child.Name)
            if cName:find("uuid") or cName:find("guid") or cName:find("id") then
                return tostring(child.Value)
            end
        end
    end
    return nil
end

local function GetToolMutation(tool)
    if not tool or not tool.Parent then return "No Mutation" end
    local mut = tool:GetAttribute("Mutation") or tool:GetAttribute("mutation") or tool:GetAttribute("Buff")
    if mut then return tostring(mut) end
    local mutVal = tool:FindFirstChild("Mutation") or tool:FindFirstChild("Buff")
    return (mutVal and mutVal:IsA("ValueBase")) and tostring(mutVal.Value) or "No Mutation"
end

-- Enhanced Inventory Detection Counter
local function CountInventoryItems(charName, mutationName)
    local count = 0
    local targetCharClean = CleanName(charName)
    local targetMutClean = CleanName(mutationName or "No Mutation")

    local function CheckContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local itemNameClean = CleanName(item.Name)
                local itemMutClean = CleanName(GetToolMutation(item))
                
                if (itemNameClean == targetCharClean or itemNameClean:find(targetCharClean)) and (itemMutClean == targetMutClean) then
                    count = count + 1
                end
            end
        end
    end

    CheckContainer(LocalPlayer:FindFirstChild("Backpack"))
    CheckContainer(LocalPlayer.Character)
    return count
end

-- Filter Logic supporting Method 1 and Method 2
local function MatchesTargetFilter(charName, mutationName, actualRarity)
    if not charName then return false end
    local charClean = CleanName(charName)
    local currentRarity = actualRarity or GetRarityOfCharacter(charName)
    local rarityClean = CleanName(currentRarity)
    local currentMutation = CleanName(mutationName or "No Mutation")

    -- METHOD 2 CHECK
    if Config.Method2_Enabled then
        local unitData = Config.Method2_Units[charClean]
        if unitData then
            local allowedRarities = unitData.Rarity or {}
            local isRarityMatch = allowedRarities["all"] == true or allowedRarities[rarityClean] == true
            
            if isRarityMatch then
                local mutFilters = Config.Method2_Mutations[rarityClean] or {}
                local hasMutFilter = false
                for _, active in pairs(mutFilters) do
                    if active then hasMutFilter = true; break end
                end
                
                if not hasMutFilter or mutFilters[currentMutation] == true then
                    return true
                end
            end
        end
    end

    -- METHOD 1 CHECK (Fallback / Parallel)
    if Config.SelectedCharacters[charClean] then
        local mutationFilters = Config.SelectedMutations[rarityClean] or {}
        local hasFilterActive = false
        for _, isSelected in pairs(mutationFilters) do
            if isSelected then hasFilterActive = true; break end
        end

        return not hasFilterActive or (mutationFilters[currentMutation] == true)
    end

    return false
end

-- -----------------------------------------------------------------
-- 3.5 Robust Config Engine
-- -----------------------------------------------------------------
local ConfigFolder = "SenzyHub/RollAnimeToFight"
local AutoSaveFilePath = ConfigFolder .. "/autosave_" .. tostring(LocalPlayer.UserId) .. ".json"

local function EnsureConfigFolder()
    if isfolder and makefolder then
        pcall(function()
            if not isfolder("SenzyHub") then makefolder("SenzyHub") end
            if not isfolder(ConfigFolder) then makefolder(ConfigFolder) end
        end)
    end
end

local function ResetConfigToDefault()
    Config.AutoSummon = false
    Config.AutoBuy = false
    Config.AutoSell = false
    Config.AutoMerge = false
    Config.AutoSpinWheel = false
    Config.AutoUpgradeGold = false
    Config.AutoUpgradeLuck = false
    Config.AutoUpgradeSlots = false
    Config.AutoUpgradeInventory = false
    Config.AutoClaimQuests = false
    Config.AutoClaimBP = false
    Config.DisplayTag = false
    Config.AntiAFK = true
    Config.RollSpeed = 1.6
    Config.MergeDelay = 2.0
    Config.WebhookURL = ""
    Config.DiscordUserID = ""
    Config.SelectedCharacters = {}
    Config.SelectedMutations = {}
    Config.Method2_Enabled = false
    Config.Method2_Units = {}
    Config.Method2_Mutations = {}
    Config.SellRarities = { Common = false, Rare = false, Epic = false, Legendary = false, Mythic = false, Secret = false, God = false, Limited = false }
    Config.SellCharacters = {}
    Config.SellMutations = {}
end

local function SafeTableMerge(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then target[key] = {} end
            SafeTableMerge(target[key], value)
        else
            target[key] = value
        end
    end
end

local function UpdateUIElement(elem, val)
    if not elem or val == nil then return end
    pcall(function()
        if type(elem.Set) == "function" then
            elem:Set(val)
        elseif type(elem.SetValue) == "function" then
            elem:SetValue(val)
        elseif type(elem.SetState) == "function" then
            elem:SetState(val)
        elseif type(elem.SetText) == "function" then
            elem:SetText(tostring(val))
        elseif type(elem.Update) == "function" then
            elem:Update(val)
        end
    end)
end

local function SyncUIFromConfig()
    local wasLoading = isLoadingConfig
    isLoadingConfig = true
    
    UpdateUIElement(UIElements.Toggles["AutoSummon"], Config.AutoSummon)
    UpdateUIElement(UIElements.Toggles["AutoBuy"], Config.AutoBuy)
    UpdateUIElement(UIElements.Toggles["Method2_Enabled"], Config.Method2_Enabled)
    UpdateUIElement(UIElements.Toggles["AutoSell"], Config.AutoSell)
    UpdateUIElement(UIElements.Toggles["AutoMerge"], Config.AutoMerge)
    UpdateUIElement(UIElements.Toggles["AutoSpinWheel"], Config.AutoSpinWheel)
    UpdateUIElement(UIElements.Toggles["AutoUpgradeGold"], Config.AutoUpgradeGold)
    UpdateUIElement(UIElements.Toggles["AutoUpgradeLuck"], Config.AutoUpgradeLuck)
    UpdateUIElement(UIElements.Toggles["AutoUpgradeSlots"], Config.AutoUpgradeSlots)
    UpdateUIElement(UIElements.Toggles["AutoUpgradeInventory"], Config.AutoUpgradeInventory)
    UpdateUIElement(UIElements.Toggles["AutoClaimQuests"], Config.AutoClaimQuests)
    UpdateUIElement(UIElements.Toggles["AutoClaimBP"], Config.AutoClaimBP)
    UpdateUIElement(UIElements.Toggles["DisplayTag"], Config.DisplayTag)
    UpdateUIElement(UIElements.Toggles["AntiAFK"], Config.AntiAFK)
    
    UpdateUIElement(UIElements.Textboxes["WebhookURL"], Config.WebhookURL)
    UpdateUIElement(UIElements.Textboxes["DiscordUserID"], Config.DiscordUserID)

    -- Sync Dropdowns Multi Values
    for key, dropElem in pairs(UIElements.Dropdowns) do
        if key:find("^BuyChar_") then
            local rarity = key:gsub("^BuyChar_", "")
            local chars = CharacterRarityMap[rarity] or {}
            local activeList = {}
            for _, name in ipairs(chars) do
                if Config.SelectedCharacters[CleanName(name)] then
                    table.insert(activeList, name)
                end
            end
            UpdateUIElement(dropElem, activeList)
        elseif key:find("^BuyMut_") then
            local rarityLower = key:gsub("^BuyMut_", "")
            local muts = Config.SelectedMutations[rarityLower] or {}
            local activeList = {}
            for _, mut in ipairs(AllMutations) do
                if muts[CleanName(mut)] then
                    table.insert(activeList, mut)
                end
            end
            UpdateUIElement(dropElem, activeList)
        end
    end

    for r, val in pairs(Config.SellRarities or {}) do
        UpdateUIElement(UIElements.Toggles["SellRarity_" .. r], val)
    end

    for mutLower, val in pairs(Config.SellMutations or {}) do
        UpdateUIElement(UIElements.Toggles["SellMut_" .. mutLower], val)
    end

    for charLower, val in pairs(Config.SellCharacters or {}) do
        UpdateUIElement(UIElements.Toggles["SellChar_" .. charLower], val)
    end

    isLoadingConfig = wasLoading
end

local function SaveAutoState()
    if isLoadingConfig or not writefile then return end
    EnsureConfigFolder()
    pcall(function()
        writefile(AutoSaveFilePath, HttpService:JSONEncode(Config))
    end)
end

local function SaveConfigFile(fileName)
    if not writefile then return false end
    local name = (fileName and fileName:gsub("%s+", "") ~= "") and fileName or "default"
    EnsureConfigFolder()
    local filePath = ConfigFolder .. "/" .. name .. ".json"
    
    local success, err = pcall(function()
        local jsonString = HttpService:JSONEncode(Config)
        writefile(filePath, jsonString)
        SaveAutoState()
    end)
    if not success then warn("[SENZY HUB] Save Error:", err) end
    return success
end

local function LoadConfigFile(fileName)
    if not (readfile and isfile) then return false end
    local name = (fileName and fileName:gsub("%s+", "") ~= "") and fileName or "default"
    local filePath = ConfigFolder .. "/" .. name .. ".json"
    
    if not isfile(filePath) then return false end
    
    local success, err = pcall(function()
        local content = readfile(filePath)
        local decoded = HttpService:JSONDecode(content)
        if type(decoded) == "table" then
            local wasLoading = isLoadingConfig
            isLoadingConfig = true
            ResetConfigToDefault()
            SafeTableMerge(Config, decoded)
            SyncUIFromConfig()
            isLoadingConfig = wasLoading
            SaveAutoState()
        end
    end)
    if not success then warn("[SENZY HUB] Load Error:", err) end
    return success
end

local function DeleteConfigFile(fileName)
    if not (delfile and isfile) then return false end
    local name = (fileName and fileName:gsub("%s+", "") ~= "") and fileName or "default"
    local filePath = ConfigFolder .. "/" .. name .. ".json"
    
    if not isfile(filePath) then return false end
    
    local success = pcall(function()
        delfile(filePath)
    end)
    return success
end

local function GetSavedConfigsList()
    local configs = {}
    local seen = {}
    EnsureConfigFolder()
    if listfiles then
        pcall(function()
            local files = listfiles(ConfigFolder)
            for _, file in ipairs(files) do
                local normalized = tostring(file):gsub("\\", "/")
                local filename = normalized:match("([^/]+)$")
                if filename and not filename:find("^autosave_") then
                    local cleanName = filename:match("^(.-)%.[jJ][sS][oO][nN]$")
                    if cleanName and cleanName ~= "" and not seen[cleanName] then
                        seen[cleanName] = true
                        table.insert(configs, cleanName)
                    end
                end
            end
        end)
    end
    if not seen["default"] then
        table.insert(configs, 1, "default")
        seen["default"] = true
    end
    return configs
end

pcall(function()
    EnsureConfigFolder()
    if isfile and isfile(AutoSaveFilePath) then
        local content = readfile(AutoSaveFilePath)
        local ok, decoded = pcall(function() return HttpService:JSONEncode(content) end)
        if ok and type(decoded) == "table" then
            ResetConfigToDefault()
            SafeTableMerge(Config, decoded)
        end
    end
end)

-- -----------------------------------------------------------------
-- 4. Discord Webhook Service
-- -----------------------------------------------------------------
local function SendDiscordWebhook(charName, mutationName, rarity)
    if Config.WebhookURL == "" or not Config.WebhookURL:find("http") then return end

    local cacheKey = string.format("%s_%s_%s", tostring(charName), tostring(mutationName), tostring(rarity))
    local currentTime = os.time()
    if sentWebhookCache[cacheKey] and (currentTime - sentWebhookCache[cacheKey]) < 5 then return end
    sentWebhookCache[cacheKey] = currentTime

    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not requestFunc then return end

    local colorCode = 0x2B2D31
    if rarity == "God" then colorCode = 0xFF0055
    elseif rarity == "Secret" then colorCode = 0xA020F0
    elseif rarity == "Limited" then colorCode = 0x00FFFF
    elseif rarity == "Mythic" then colorCode = 0xFF6600
    elseif rarity == "Legendary" then colorCode = 0xFFD700
    elseif rarity == "Epic" then colorCode = 0x9370DB
    end

    local playerAvatarUrl = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", LocalPlayer.UserId)
    local logoUrl = "https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/senz2.png"

    local embedData = {
        ["title"] = "✨ AUTO BUY SUCCESSFUL!",
        ["description"] = string.format("> 🎉 **%s** has successfully obtained a target unit!", LocalPlayer.DisplayName),
        ["color"] = colorCode,
        ["author"] = { ["name"] = "SENZY HUB • AUTOMATION", ["icon_url"] = logoUrl },
        ["thumbnail"] = { ["url"] = logoUrl },
        ["fields"] = {
            { ["name"] = "👤 Player Name", ["value"] = string.format("```%s (@%s)```", LocalPlayer.DisplayName, LocalPlayer.Name), ["inline"] = false },
            { ["name"] = "⚔️ Character", ["value"] = string.format("**` %s `**", charName or "Unknown"), ["inline"] = true },
            { ["name"] = "👑 Rarity", ["value"] = string.format("**` %s `**", rarity or "Unknown"), ["inline"] = true },
            { ["name"] = "🧬 Mutation", ["value"] = string.format("**` %s `**", mutationName or "No Mutation"), ["inline"] = true }
        },
        ["footer"] = { ["text"] = "SENZY HUB LOG SYSTEM", ["icon_url"] = playerAvatarUrl },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payload = HttpService:JSONEncode({
        ["username"] = "SENZY HUB NOTIFIER",
        ["avatar_url"] = logoUrl,
        ["content"] = Config.DiscordUserID ~= "" and ("<@" .. Config.DiscordUserID:match("%d+") .. ">") or nil,
        ["embeds"] = { embedData }
    })

    task.spawn(function()
        pcall(function()
            requestFunc({ Url = Config.WebhookURL, Method = "POST", Headers = { ["Content-Type"] = "application/json" }, Body = payload })
        end)
    end)
end

-- -----------------------------------------------------------------
-- 5. Auto Buy Processor (Validated Purchase & Retry System)
-- -----------------------------------------------------------------
local function ExecuteAutoBuy(data)
    if not data or not Config.AutoBuy or isBuying or not data.charactersList then return end

    local matchingSlots = {}
    for slotKey, charData in pairs(data.charactersList) do
        if typeof(charData) == "table" then
            local charName = charData.Name or charData.name or charData.Character or charData.Unit or charData.ItemName or charData.id
            local charMutation = charData.Mutation or charData.mutation or charData.Buff or "No Mutation"
            local charRarity = charData.Rarity or charData.rarity or GetRarityOfCharacter(charName)
            local slotIndex = tonumber(slotKey) or charData.Slot or charData.slot

            if MatchesTargetFilter(charName, charMutation, charRarity) then
                table.insert(matchingSlots, {
                    slotIndex = slotIndex or slotKey,
                    charName = charName,
                    charMutation = charMutation,
                    charRarity = charRarity
                })
            end
        end
    end

    if #matchingSlots > 0 then
        isBuying = true
        task.spawn(function()
            for _, item in ipairs(matchingSlots) do
                if data.rollId and item.slotIndex and BuyRemote then
                    local initialCount = CountInventoryItems(item.charName, item.charMutation)
                    local purchaseSuccess = false

                    -- Controlled Retry System
                    for attempt = 1, 3 do
                        pcall(function() 
                            BuyRemote:FireServer(data.rollId, tonumber(item.slotIndex)) 
                        end)
                        task.wait(0.25)

                        -- Validate Inventory Status
                        local currentCount = CountInventoryItems(item.charName, item.charMutation)
                        if currentCount > initialCount then
                            purchaseSuccess = true
                            break
                        end
                    end

                    -- Send Webhook ONLY when validated
                    if purchaseSuccess then
                        SendDiscordWebhook(item.charName, item.charMutation, item.charRarity)
                    end
                end
            end
            isBuying = false
        end)
    end
end

-- -----------------------------------------------------------------
-- 6. Auto Sell Processor
-- -----------------------------------------------------------------
local function ExecuteAutoSell()
    if not Config.AutoSell or not SellRemote then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    local itemsToScan = {}

    if backpack then for _, item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") then table.insert(itemsToScan, item) end end end
    if character then for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") then table.insert(itemsToScan, item) end end end

    for _, item in ipairs(itemsToScan) do
        if not item or not item.Parent then continue end
        local charName = item.Name
        local charClean = CleanName(charName)
        local mutation = GetToolMutation(item)
        local mutClean = CleanName(mutation)

        if not (Config.AutoBuy and MatchesTargetFilter(charName, mutation)) then
            local rarity = GetRarityOfCharacter(charName)
            local rarityMatch = Config.SellRarities[rarity] == true
            local charMatch = Config.SellCharacters[charClean] == true
            local mutMatch = Config.SellMutations[mutClean] == true

            local hasMutFilter = false
            for _, active in pairs(Config.SellMutations) do if active then hasMutFilter = true; break end end
            local mutCheck = not hasMutFilter or mutMatch

            if rarity == "Unknown" and (Config.SellRarities["Common"] or Config.SellRarities["Rare"]) then
                rarityMatch = true
            end

            if (rarityMatch or charMatch) and mutCheck then
                local uuid = GetToolUUID(item)
                if uuid then
                    pcall(function() SellRemote:FireServer({ uuid }) end)
                    task.wait(0.15)
                end
            end
        end
    end
end

-- -----------------------------------------------------------------
-- 7. Prompts Scanner
-- -----------------------------------------------------------------
local isRefreshingPrompts = false
local function RefreshPrompts()
    table.clear(cachedRollPrompts)
    table.clear(cachedMergePrompts)
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            if prompt.Name == "RollPrompt" then
                table.insert(cachedRollPrompts, prompt)
            else
                local txt = (prompt.ActionText .. prompt.ObjectText .. prompt.Name):lower()
                if txt:find("level up") or txt:find("character slot") or txt:find("levelup") then
                    table.insert(cachedMergePrompts, prompt)
                end
            end
        end
    end
    isRefreshingPrompts = false
end

local function RequestPromptRefresh()
    if not isRefreshingPrompts then
        isRefreshingPrompts = true
        task.delay(0.2, RefreshPrompts)
    end
end

RefreshPrompts()

local connAdded = workspace.DescendantAdded:Connect(function(d) if d:IsA("ProximityPrompt") then RequestPromptRefresh() end end)
local connRemoved = workspace.DescendantRemoving:Connect(function(d) if d:IsA("ProximityPrompt") then RequestPromptRefresh() end end)
table.insert(getgenv().AutoRollSystem.Connections, connAdded)
table.insert(getgenv().AutoRollSystem.Connections, connRemoved)

-- -----------------------------------------------------------------
-- 8. Visuals / Name Tag System
-- -----------------------------------------------------------------
local function UpdateOverheadDisplay(char)
    if not char then return end
    task.spawn(function()
        local humanoid = char:WaitForChild("Humanoid", 10)
        if not humanoid then return end
        
        if Config.DisplayTag then
            humanoid.DisplayName = "SENZY HUB ON TOP"
        else
            humanoid.DisplayName = originalDisplayName
        end

        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Name ~= "Title" then
                if not obj:FindFirstAncestorWhichIsA("Tool") then
                    if Config.DisplayTag then 
                        obj.Text = "SENZY HUB ON TOP" 
                    end
                end
            end
        end
    end)
end

local connCharAdded = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    UpdateOverheadDisplay(char)
end)
table.insert(getgenv().AutoRollSystem.Connections, connCharAdded)

-- -----------------------------------------------------------------
-- 9. UI Construction
-- -----------------------------------------------------------------
local Library
local uiSuccess, uiErr = pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/Main.lua"))()
end)

if not uiSuccess or not Library then
    warn("[SENZY HUB] Failed to load UI Library:", uiErr)
    return
end

local Window = Library:Window({ Title = "Senzy Hub", Footer = "Free Script", Logo = 111116339097216 })

-- TAB 0: INFO & WEBHOOK
local TabInfo = Window:MakeTab({ Title = "Information", Icon = 115960025411300 })
TabInfo:Label({ Title = "SENZY HUB", Desc = "Anime Roll Automation System" })
TabInfo:Button({ 
    Title = "Copy Discord Link", 
    Desc = "https://discord.gg/rhPgnAJE4B",
    Callback = function() 
        if setclipboard then 
            setclipboard("https://discord.gg/rhPgnAJE4B")
        end 
    end 
})
TabInfo:Label({ Title = "DISCORD WEBHOOK", Desc = "Notifies when your selected characters are purchased" })

UIElements.Textboxes["WebhookURL"] = TabInfo:Textbox({ 
    Title = "Webhook URL", 
    Desc = "Paste Discord Webhook URL", 
    Value = Config.WebhookURL,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.WebhookURL = v 
        SaveAutoState()
    end 
})

UIElements.Textboxes["DiscordUserID"] = TabInfo:Textbox({ 
    Title = "Discord User ID", 
    Desc = "User ID for mentions", 
    Value = Config.DiscordUserID,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.DiscordUserID = v 
        SaveAutoState()
    end 
})

TabInfo:Button({
    Title = "Test Webhook",
    Desc = "Send test notification payload",
    Callback = function()
        if Config.WebhookURL ~= "" then
            SendDiscordWebhook("Ainz", "Demon", "God")
        end
    end
})

-- TAB 1: MAIN SETTINGS
local TabMain = Window:MakeTab({ Title = "Main Settings", Icon = 115960025411300 })

UIElements.Toggles["AutoSummon"] = TabMain:Toggle({ 
    Title = "Auto Summon", 
    Value = Config.AutoSummon,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AutoSummon = v
        getgenv().AutoRollSystem.Enabled = v 
        SaveAutoState()
    end 
})

UIElements.Toggles["AutoBuy"] = TabMain:Toggle({ 
    Title = "Enable Auto Buy (Master Switch)", 
    Value = Config.AutoBuy,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AutoBuy = v
        if v and latestRollData then ExecuteAutoBuy(latestRollData) end 
        SaveAutoState()
    end 
})

-- TAB: AUTO BUY METHOD 2 (NEWLY ADDED)
local TabMethod2 = Window:MakeTab({ Title = "Buy: Method 2 (Custom)", Icon = 115960025411300 })

UIElements.Toggles["Method2_Enabled"] = TabMethod2:Toggle({
    Title = "Enable Auto Buy Method 2",
    Desc = "Target specific units with custom Rarity overrides",
    Value = Config.Method2_Enabled,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.Method2_Enabled = v
        SaveAutoState()
    end
})

TabMethod2:Label({ Title = "<font color=\"#00FF7F\">1. SELECT UNIT & ALLOWED RARITIES</font>" })

local currentSelectedM2Unit = AllUnitsList[1] or "Ainz"

TabMethod2:Dropdown({
    Title = "Select Target Unit",
    List = AllUnitsList,
    Value = currentSelectedM2Unit,
    Callback = function(selected)
        if type(selected) == "table" then selected = selected[1] end
        if selected then currentSelectedM2Unit = selected end
    end
})

local M2_RarityOptions = { "All Rarity", "God", "Secret", "Mythic", "Legendary", "Epic", "Rare", "Common", "Limited" }

TabMethod2:Dropdown({
    Title = "Set Allowed Rarities For Unit",
    List = M2_RarityOptions,
    Multi = true,
    Callback = function(selectedList)
        if isLoadingConfig or not currentSelectedM2Unit then return end
        local unitClean = CleanName(currentSelectedM2Unit)
        Config.Method2_Units[unitClean] = Config.Method2_Units[unitClean] or { Rarity = {} }
        
        local selectedSet = {}
        if type(selectedList) == "table" then
            for _, rName in ipairs(selectedList) do
                local rClean = CleanName(rName:gsub(" Rarity", ""))
                selectedSet[rClean] = true
            end
        end

        Config.Method2_Units[unitClean].Rarity = selectedSet
        SaveAutoState()
    end
})

TabMethod2:Label({ Title = "<font color=\"#FFD700\">2. METHOD 2 MUTATION FILTERS</font>" })

for _, rarityName in ipairs(RarityList) do
    local rClean = CleanName(rarityName)
    Config.Method2_Mutations[rClean] = Config.Method2_Mutations[rClean] or {}

    TabMethod2:Dropdown({
        Title = rarityName .. " Allowed Mutations",
        List = AllMutations,
        Multi = true,
        Callback = function(selectedList)
            if isLoadingConfig then return end
            local selectedSet = {}
            if type(selectedList) == "table" then
                for _, mutName in ipairs(selectedList) do
                    selectedSet[CleanName(mutName)] = true
                end
            end
            Config.Method2_Mutations[rClean] = selectedSet
            SaveAutoState()
        end
    })
end

-- TAB 2: AUTOMATION & UPGRADES
local TabAutoMore = Window:MakeTab({ Title = "Auto Features", Icon = 115960025411300 })

TabAutoMore:Label({ Title = "<font color=\"#00FF7F\">1. SPIN WHEEL & QUESTS</font>" })

UIElements.Toggles["AutoSpinWheel"] = TabAutoMore:Toggle({
    Title = "Auto Spin Wheel",
    Desc = "Spins wheel automatically",
    Value = Config.AutoSpinWheel,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoSpinWheel = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoClaimQuests"] = TabAutoMore:Toggle({
    Title = "Auto Claim Quests",
    Desc = "Automatically claims Daily quests",
    Value = Config.AutoClaimQuests,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClaimQuests = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoClaimBP"] = TabAutoMore:Toggle({
    Title = "Auto Claim Battle Pass",
    Desc = "Automatically claims Free BP rewards",
    Value = Config.AutoClaimBP,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClaimBP = v
        SaveAutoState()
    end
})

TabAutoMore:Label({ Title = "<font color=\"#FFD700\">2. AUTO UPGRADES</font>" })

UIElements.Toggles["AutoUpgradeGold"] = TabAutoMore:Toggle({
    Title = "Auto Upgrade Gold",
    Value = Config.AutoUpgradeGold,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeGold = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoUpgradeLuck"] = TabAutoMore:Toggle({
    Title = "Auto Upgrade Luck",
    Value = Config.AutoUpgradeLuck,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeLuck = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoUpgradeSlots"] = TabAutoMore:Toggle({
    Title = "Auto Upgrade Slots",
    Value = Config.AutoUpgradeSlots,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeSlots = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoUpgradeInventory"] = TabAutoMore:Toggle({
    Title = "Auto Upgrade Inventory",
    Value = Config.AutoUpgradeInventory,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeInventory = v
        SaveAutoState()
    end
})

-- Helper UI Builder for Target Buy (Method 1 Multi Dropdown Version)
local function BuildRarityUI(tab, rarities)
    for _, rarity in ipairs(rarities) do
        local chars = CharacterRarityMap[rarity]
        if chars then
            local color = RarityColorMap[rarity] or "#FFFFFF"
            local rarityLower = rarity:lower()
            tab:Label({ Title = string.format("<font color=\"%s\">=== %s ===</font>", color, rarity:upper()) })

            local initialCharValues = {}
            for _, name in ipairs(chars) do
                if Config.SelectedCharacters[CleanName(name)] then
                    table.insert(initialCharValues, name)
                end
            end

            UIElements.Dropdowns["BuyChar_" .. rarity] = tab:Dropdown({
                Title = "Select " .. rarity .. " Units",
                List = chars,
                Multi = true,
                Value = initialCharValues,
                Callback = function(selectedList)
                    if isLoadingConfig then return end
                    
                    local selectedSet = {}
                    if type(selectedList) == "table" then
                        for _, name in ipairs(selectedList) do
                            selectedSet[CleanName(name)] = true
                        end
                    elseif type(selectedList) == "string" and selectedList ~= "" then
                        selectedSet[CleanName(selectedList)] = true
                    end

                    for _, name in ipairs(chars) do
                        local nameClean = CleanName(name)
                        Config.SelectedCharacters[nameClean] = selectedSet[nameClean] == true
                    end

                    if Config.AutoBuy and latestRollData then ExecuteAutoBuy(latestRollData) end
                    SaveAutoState()
                end
            })

            Config.SelectedMutations[rarityLower] = Config.SelectedMutations[rarityLower] or {}
            local initialMutValues = {}
            for _, mut in ipairs(AllMutations) do
                if Config.SelectedMutations[rarityLower][CleanName(mut)] then
                    table.insert(initialMutValues, mut)
                end
            end

            UIElements.Dropdowns["BuyMut_" .. rarityLower] = tab:Dropdown({
                Title = rarity .. " Mutation Filter",
                List = AllMutations,
                Multi = true,
                Value = initialMutValues,
                Callback = function(selectedList)
                    if isLoadingConfig then return end
                    
                    local selectedSet = {}
                    if type(selectedList) == "table" then
                        for _, mut in ipairs(selectedList) do
                            selectedSet[CleanName(mut)] = true
                        end
                    elseif type(selectedList) == "string" and selectedList ~= "" then
                        selectedSet[CleanName(selectedList)] = true
                    end

                    for _, mut in ipairs(AllMutations) do
                        local mutClean = CleanName(mut)
                        Config.SelectedMutations[rarityLower][mutClean] = selectedSet[mutClean] == true
                    end

                    if Config.AutoBuy and latestRollData then ExecuteAutoBuy(latestRollData) end
                    SaveAutoState()
                end
            })
        end
    end
end

local TabLowRarity = Window:MakeTab({ Title = "Buy: Normal - Legendary", Icon = 115960025411300 })
BuildRarityUI(TabLowRarity, LowRarities)

local TabHighRarity = Window:MakeTab({ Title = "Buy: High Tier", Icon = 115960025411300 })
BuildRarityUI(TabHighRarity, HighRarities)

-- TAB 3: AUTO SELL
local TabSell = Window:MakeTab({ Title = "Auto Sell Settings", Icon = 115960025411300 })

UIElements.Toggles["AutoSell"] = TabSell:Toggle({ 
    Title = "Master Auto Sell", 
    Desc = "Automatically sells backpack items matching parameters", 
    Value = Config.AutoSell,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AutoSell = v 
        SaveAutoState()
    end 
})

TabSell:Label({ Title = "<font color=\"#FFD700\">1. SELL BY RARITY</font>" })
for _, r in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" }) do
    UIElements.Toggles["SellRarity_" .. r] = TabSell:Toggle({ 
        Title = "Sell Rarity: " .. r, 
        Value = Config.SellRarities[r] == true,
        Callback = function(v) 
            if isLoadingConfig then return end
            Config.SellRarities[r] = v 
            SaveAutoState()
        end 
    })
end

TabSell:Label({ Title = "<font color=\"#00FFFF\">2. SELL BY MUTATION</font>" })
for _, mutName in ipairs(AllMutations) do
    local mutClean = CleanName(mutName)
    UIElements.Toggles["SellMut_" .. mutClean] = TabSell:Toggle({ 
        Title = "Sell Mutation: " .. mutName, 
        Value = Config.SellMutations[mutClean] == true,
        Callback = function(v) 
            if isLoadingConfig then return end
            Config.SellMutations[mutClean] = v 
            SaveAutoState()
        end 
    })
end

TabSell:Label({ Title = "<font color=\"#FF69B4\">3. SELL SPECIFIC UNITS</font>" })
for _, rarityName in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic" }) do
    local list = CharacterRarityMap[rarityName]
    if list then
        for _, charName in ipairs(list) do
            local charClean = CleanName(charName)
            UIElements.Toggles["SellChar_" .. charClean] = TabSell:Toggle({ 
                Title = "Sell Unit: " .. charName, 
                Value = Config.SellCharacters[charClean] == true,
                Callback = function(v) 
                    if isLoadingConfig then return end
                    Config.SellCharacters[charClean] = v 
                    SaveAutoState()
                end 
            })
        end
    end
end

-- TAB 4: MERGE
local TabMerge = Window:MakeTab({ Title = "Auto Merge", Icon = 115960025411300 })
UIElements.Toggles["AutoMerge"] = TabMerge:Toggle({ 
    Title = "Auto Merge (Level Up)", 
    Value = Config.AutoMerge,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AutoMerge = v 
        SaveAutoState()
    end 
})

-- TAB 5: PERFORMANCE & DUAL ANTI-AFK
local TabPerf = Window:MakeTab({ Title = "Performance", Icon = 115960025411300 })
TabPerf:Label({ Title = "<font color=\"#00FF7F\">ANTI-AFK SYSTEM</font>" })

UIElements.Toggles["AntiAFK"] = TabPerf:Toggle({ 
    Title = "Anti-AFK Disconnect", 
    Desc = "Prevents getting kicked after 20 minutes of inactivity", 
    Value = Config.AntiAFK, 
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AntiAFK = v 
        SaveAutoState()
    end 
})

if getconnections then
    for index, connection in getconnections(cloneref(game:GetService('Players')).LocalPlayer.Idled) do
        connection:Disconnect()
    end
end

local customVirtualUser = cloneref(game:GetService('VirtualUser'))
local idledConn = cloneref(game:GetService('Players')).LocalPlayer.Idled:Connect(function()
    if Config.AntiAFK then
        pcall(function()
            customVirtualUser:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
            customVirtualUser:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
        end)
    end
end)
table.insert(getgenv().AutoRollSystem.Connections, idledConn)

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        task.wait(600)
        if Config.AntiAFK and LocalPlayer.Character then
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
            end
        end
    end
end)

TabPerf:Label({ Title = "<font color=\"#FFD700\">FPS BOOSTER & ANTI-LAG</font>" })
TabPerf:Button({
    Title = "Boost FPS & Reduce Lag",
    Desc = "Disables shadows, fog, and caps FPS higher",
    Callback = function()
        pcall(function()
            Lighting.GlobalShadows = false
            Lighting.FogEnd = 9e9
            Lighting.ShadowSoftness = 0
            if setfpscap then setfpscap(240) end
        end)
    end
})

TabPerf:Button({
    Title = "Full Potato Graphics (Lowest Quality)",
    Desc = "Changes materials to SmoothPlastic & removes textures",
    Callback = function()
        pcall(function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v:IsA("MeshPart") then
                    v.Material = Enum.Material.SmoothPlastic
                    v.Reflectance = 0
                elseif v:IsA("Decal") or v:IsA("Texture") then
                    v:Destroy()
                end
            end
        end)
    end
})

TabPerf:Button({
    Title = "Remove Effects & Particles",
    Desc = "Removes ParticleEmitters, Trails, and Beams",
    Callback = function()
        pcall(function()
            for _, v in ipairs(workspace:GetDescendants()) do
                if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") or v:IsA("Sparkles") or v:IsA("Beam") then
                    v:Destroy()
                end
            end
        end)
    end
})

-- TAB 6: VISUALS & TAGS
local TabVisuals = Window:MakeTab({ Title = "Display & Tags", Icon = 115960025411300 })
UIElements.Toggles["DisplayTag"] = TabVisuals:Toggle({
    Title = "Enable Custom Name Tag",
    Value = Config.DisplayTag,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.DisplayTag = v
        if LocalPlayer.Character then UpdateOverheadDisplay(LocalPlayer.Character) end
        SaveAutoState()
    end
})

-- TAB 7: SAVE / CONFIG SYSTEM
local TabSaveConfig = Window:MakeTab({ Title = "Save / Config", Icon = 115960025411300 })
local saveNameInput = ""
local selectedDropdownConfig = "default"
local ConfigDropdownElement = nil

local function RefreshDropdownOptions(targetSelect)
    local savedFiles = GetSavedConfigsList()
    if type(savedFiles) ~= "table" or #savedFiles == 0 then
        savedFiles = { "default" }
    end

    if ConfigDropdownElement then
        pcall(function()
            if ConfigDropdownElement.Refresh then
                ConfigDropdownElement:Refresh(savedFiles, targetSelect)
            elseif ConfigDropdownElement.SetList then
                ConfigDropdownElement:SetList(savedFiles, targetSelect)
            elseif ConfigDropdownElement.Clear then
                ConfigDropdownElement:Clear()
                for _, opt in ipairs(savedFiles) do
                    if ConfigDropdownElement.AddList then
                        ConfigDropdownElement:AddList(opt)
                    elseif ConfigDropdownElement.Add then
                        ConfigDropdownElement:Add(opt)
                    end
                end
                if targetSelect and ConfigDropdownElement.Set then
                    ConfigDropdownElement:Set(targetSelect)
                end
            end
        end)
    end

    if targetSelect then
        selectedDropdownConfig = targetSelect
    end
end

TabSaveConfig:Label({ Title = "<font color=\"#00FF7F\">1. CREATE NEW PROFILE</font>" })

TabSaveConfig:Textbox({
    Title = "New Profile Name",
    Desc = "Type a name for new config (e.g. main, farm)",
    Callback = function(val)
        if val and val:gsub("%s+", "") ~= "" then
            saveNameInput = val:gsub("%s+", "")
        else
            saveNameInput = ""
        end
    end
})

TabSaveConfig:Button({
    Title = "💾 Create & Save New Profile",
    Desc = "Saves current settings into new file name typed above",
    Callback = function()
        local profileToSave = (saveNameInput ~= "") and saveNameInput or "default"
        local success = SaveConfigFile(profileToSave)
        if success then
            RefreshDropdownOptions(profileToSave)
        end
    end
})

TabSaveConfig:Label({ Title = "<font color=\"#00FFFF\">2. PROFILE MANAGEMENT</font>" })

local function CreateConfigDropdown()
    local initialOptions = GetSavedConfigsList()
    if type(initialOptions) ~= "table" or #initialOptions == 0 then
        initialOptions = { "default" }
    end

    local dropdownCfg = {
        Title = "Select Profile",
        List = initialOptions,
        Value = initialOptions[1] or "default",
        Callback = function(selectedOption)
            if type(selectedOption) == "table" then
                selectedOption = selectedOption[1] or selectedOption.Value or selectedOption.Name or selectedOption.Text
            end
            if selectedOption and selectedOption ~= "" then
                selectedDropdownConfig = tostring(selectedOption)
            end
        end
    }

    local ok, result = pcall(function()
        return TabSaveConfig:Dropdown(dropdownCfg)
    end)

    if ok and result then
        ConfigDropdownElement = result
        return true
    end
    return false
end

CreateConfigDropdown()
RefreshDropdownOptions("default")

TabSaveConfig:Button({
    Title = "💾 Save Over Selected Profile",
    Desc = "Overwrite current settings into the selected Profile in Dropdown",
    Callback = function()
        local profileToSave = selectedDropdownConfig
        if not profileToSave or profileToSave == "" then profileToSave = "default" end
        local success = SaveConfigFile(profileToSave)
        if success then
            RefreshDropdownOptions(profileToSave)
        end
    end
})

TabSaveConfig:Button({
    Title = "📂 Load Selected Profile",
    Desc = "Load configuration from chosen profile",
    Callback = function()
        local success = LoadConfigFile(selectedDropdownConfig)
        if success then
            getgenv().AutoRollSystem.Enabled = Config.AutoSummon
            if LocalPlayer.Character then
                UpdateOverheadDisplay(LocalPlayer.Character)
            end
        end
    end
})

TabSaveConfig:Button({
    Title = "🗑️ Delete Selected Profile",
    Desc = "Permanently delete selected profile file",
    Callback = function()
        local success = DeleteConfigFile(selectedDropdownConfig)
        if success then
            selectedDropdownConfig = "default"
            RefreshDropdownOptions("default")
        end
    end
})

TabSaveConfig:Button({
    Title = "🔄 Refresh Config List",
    Desc = "Scan folder and rebuild profile list",
    Callback = function()
        RefreshDropdownOptions()
    end
})

-- -----------------------------------------------------------------
-- INITIAL UI SYNC & UNLOCK AUTOSAVE ENGINE
-- -----------------------------------------------------------------
SyncUIFromConfig()

isLoadingConfig = false

getgenv().AutoRollSystem.Enabled = Config.AutoSummon

if LocalPlayer.Character then
    UpdateOverheadDisplay(LocalPlayer.Character)
end

-- -----------------------------------------------------------------
-- 10. Background Execution Threads
-- -----------------------------------------------------------------
if RollRemote then
    getgenv().AutoRollSystem.Connection = RollRemote.OnClientEvent:Connect(function(...)
        local charactersList, rollId, plot
        for _, arg in ipairs({...}) do
            if typeof(arg) == "table" then charactersList = arg
            elseif typeof(arg) == "number" then rollId = arg
            elseif typeof(arg) == "Instance" then plot = arg end
        end
        if charactersList then
            latestRollData = { charactersList = charactersList, rollId = rollId, plot = plot }
            if Config.AutoBuy then ExecuteAutoBuy(latestRollData) end
        end
    end)
end

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoSell then pcall(ExecuteAutoSell) end
        task.wait(1.0)
    end
end)

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoSummon and not isBuying then
            for _, prompt in ipairs(cachedRollPrompts) do
                if prompt and prompt.Parent and fireproximityprompt then
                    pcall(function() fireproximityprompt(prompt, 0) end)
                end
            end
        end
        task.wait(Config.RollSpeed)
    end
end)

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoMerge then
            for _, prompt in ipairs(cachedMergePrompts) do
                if prompt and prompt.Parent and fireproximityprompt then
                    pcall(function() fireproximityprompt(prompt, 0) end)
                end
            end
        end
        task.wait(Config.MergeDelay)
    end
end)

-- -----------------------------------------------------------------
-- 11. NEW AUTOMATION THREADS (Spin, Upgrades, Quests, BP)
-- -----------------------------------------------------------------

-- Auto Spin Wheel Loop
task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoSpinWheel then
            pcall(function()
                local spinRemote = ReplicatedStorage:FindFirstChild("Remotes") 
                    and ReplicatedStorage.Remotes:FindFirstChild("SpinWheel") 
                    and ReplicatedStorage.Remotes.SpinWheel:FindFirstChild("Spin")
                if spinRemote then
                    spinRemote:FireServer("Spin")
                end
            end)
        end
        task.wait(3)
    end
end)

-- Auto Upgrade Stats Loop
task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        pcall(function()
            local upgradeRemote = ReplicatedStorage:FindFirstChild("Remotes") 
                and ReplicatedStorage.Remotes:FindFirstChild("Upgrade")
            if upgradeRemote then
                if Config.AutoUpgradeGold then
                    upgradeRemote:FireServer("Gold", "Gold")
                end
                if Config.AutoUpgradeLuck then
                    upgradeRemote:FireServer("Gold", "Luck")
                end
                if Config.AutoUpgradeSlots then
                    upgradeRemote:FireServer("Gold", "Slots")
                end
                if Config.AutoUpgradeInventory then
                    upgradeRemote:FireServer("Gold", "Inventory")
                end
            end
        end)
        task.wait(1.5)
    end
end)

-- Auto Claim Quests & Battle Pass Loop
task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        pcall(function()
            -- Quests
            if Config.AutoClaimQuests then
                local questRemote = ReplicatedStorage:FindFirstChild("Modules") 
                    and ReplicatedStorage.Modules:FindFirstChild("Battlepass") 
                    and ReplicatedStorage.Modules.Battlepass:FindFirstChild("BattlepassQuest") 
                    and ReplicatedStorage.Modules.Battlepass.BattlepassQuest:FindFirstChild("ClaimQuest")
                if questRemote then
                    questRemote:FireServer("Daily", "25_000_000_damage")
                end
            end

            -- Battle Pass
            if Config.AutoClaimBP then
                local claimBpRemote = ReplicatedStorage:FindFirstChild("Modules") 
                    and ReplicatedStorage.Modules:FindFirstChild("Battlepass") 
                    and ReplicatedStorage.Modules.Battlepass:FindFirstChild("Claim")
                if claimBpRemote then
                    for tier = 1, 50 do
                        claimBpRemote:FireServer(tier, "Free")
                        task.wait(0.05)
                    end
                end
            end
        end)
        task.wait(10)
    end
end)
