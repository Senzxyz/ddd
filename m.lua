--[[
    SENZY HUB - Roll Anime to Fight (v5.0 - Information First & Free Script Text)
]]

if getgenv().AutoRollSystem then
    getgenv().AutoRollSystem.Enabled = false
    if getgenv().AutoRollSystem.Connection then
        pcall(function() getgenv().AutoRollSystem.Connection:Disconnect() end)
    end
    getgenv().AutoRollSystem = nil
end

getgenv().AutoRollSystem = {
    Enabled = false,
    Connection = nil
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------
-- Configuration Maps & Arrays
---------------------------------------------------------
local CharacterRarityMap = {
    Common = {
        "Ussop", "Krillin", "Luffy", "Zoro", "Itadori"
    },
    Rare = {
        "Goku", "Maki", "Junwoo", "Mob", "Sakura"
    },
    Epic = {
        "Shinra", "Manji", "Ban", "Guts", "Renji", "Tanjiro", "Piccolo"
    },
    Legendary = {
        "Erwin", "Gojo", "Grimmjow", "Nanami", "Naruto", "NarutoClone", "Saitama", "Sukuna", "Trunks", "Zenitsu"
    },
    Mythic = {
        "Ace", "Akaza", "Broly", "Hoshina", "Kashimo", "Kisuke", "Kokushibo", "Orihime", "Rengoku", "Simo Hayha", "Stark", "Toji", "Yoruichi"
    },
    Secret = {
        "Byakuya", "Dio", "Douma", "Frieren", "Gyomei", "Hakari", "Jiren", "Kenpachi", "Mahoraga", "Megumi", "Mojuro", "Rika", "Ulquiorra", "Yhwatch", "Yuta"
    },
    God = {
        "Ainz", "Aizen (Transcendent)", "Beerus", "Dabura", "Death Knight", "Gojo (Shibuya)", "Goku (Black)", "Ichigo", "Muzan", "Muzan (Evolved)", "Rimuru", "Shanks", "Sukuna (Heian)", "Whis", "Yamamoto", "Yorichi", "Yuji (Modulo)"
    },
    Limited = {
        "Albedo", "Black Frieza", "Britain Army", "Cosmic Garou", "DarkMagician", "DarkMagicianGirl", "Entoma", "Frieza", "Genos", "Hakari (JackPot)", "Juuzou", "Julius", "Katakuri", "Lelouch", "Mash", "Milim", "Okurun", "Saitama (Serious)", "Sakamoto", "Sakamoto (Fit)", "Shalltear", "Spider (Entoma)", "Tatsumaki", "Yor", "Yugi"
    }
}

-- Hex Color Code Map for Headers
local RarityColorMap = {
    Common    = "#A6A6A6", -- สีเทา
    Rare      = "#1E90FF", -- สีฟ้า
    Epic      = "#9370DB", -- สีม่วงอ่อน
    Legendary = "#FFD700", -- สีทอง
    Mythic    = "#FF4500", -- สีส้มแดง
    Secret    = "#8A2BE2", -- สีม่วงเข้ม
    God       = "#FF0000", -- สีแดงสด
    Limited   = "#00FFFF"  -- สีฟ้าสว่าง / Cyan
}

local AllMutations = {
    "Astronaut", "Cursed", "Demon", "Destroyer", "Diamond", "Gold", "Hollow", "No Mutation", "Slayer"
}

local LowRarities = { "Common", "Rare", "Epic", "Legendary" }
local HighRarities = { "Mythic", "Secret", "God", "Limited" }

-- Target Settings (Auto Buy)
local SelectedTargetCharacters = {}
local SelectedTargetMutations = {}

-- Auto Sell Filter Settings (Default to ALL FALSE)
local AutoSellRarities = { ["Common"] = false, ["Rare"] = false, ["Epic"] = false, ["Legendary"] = false }
local AutoSellCharacters = {}
local AutoSellMutations = {
    ["astronaut"] = false,
    ["cursed"] = false,
    ["demon"] = false,
    ["destroyer"] = false,
    ["diamond"] = false,
    ["gold"] = false,
    ["hollow"] = false,
    ["no mutation"] = false,
    ["slayer"] = false
}

-- Global State Flags
local AutoSummonEnabled = false
local AutoBuyEnabled = false
local AutoSellEnabled = false
local AutoMergeEnabled = false
local DisplayTagEnabled = false

-- Webhook Settings
local WebhookURL = ""
local DiscordUserID = ""

local isBuying = false
local ROLL_SPEED = 1.6
local MERGE_DELAY = 2.0
local latestRollData = nil
local originalDisplayName = LocalPlayer.DisplayName

-- Remote References
local RollRemote = nil
local BuyRemote = nil
local SellRemote = nil

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

local cachedRollPrompts = {}
local cachedMergePrompts = {}

---------------------------------------------------------
-- Helper Functions
---------------------------------------------------------
local function GetRarityOfCharacter(charName)
    if not charName or charName == "" then return "Unknown" end
    for rarity, list in pairs(CharacterRarityMap) do
        for _, name in ipairs(list) do
            if string.lower(name) == string.lower(charName) then
                return rarity
            end
        end
    end
    return "Unknown"
end

local function GetToolUUID(tool)
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
    local mut = tool:GetAttribute("Mutation") or tool:GetAttribute("mutation") or tool:GetAttribute("Buff")
    if mut then return tostring(mut) end

    local mutVal = tool:FindFirstChild("Mutation") or tool:FindFirstChild("Buff")
    if mutVal and mutVal:IsA("ValueBase") then return tostring(mutVal.Value) end

    return "No Mutation"
end

local function SendDiscordWebhook(charName, mutationName, rarity)
    if WebhookURL == "" or not WebhookURL:find("http") then return end

    -- ตรวจสอบฟังก์ชัน HTTP Request ที่รองรับโดย Executor ทุกค่าย
    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not requestFunc then return end

    local mentionText = ""
    if DiscordUserID ~= "" and DiscordUserID:match("%d+") then
        mentionText = "<@" .. DiscordUserID:match("%d+") .. ">"
    end

    -- กำหนดสี Embed ตาม Rarity
    local colorCode = 0x00FFFF
    if rarity == "God" then colorCode = 0xFF0000
    elseif rarity == "Secret" then colorCode = 0x8A2BE2
    elseif rarity == "Mythic" then colorCode = 0xFF4500
    elseif rarity == "Limited" then colorCode = 0x00FFFF
    elseif rarity == "Legendary" then colorCode = 0xFFD700
    end

    local headshotUrl = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=420&height=420&format=png", LocalPlayer.UserId)

    local embedData = {
        ["title"] = "🎉 Auto Buy Success - SENZY HUB",
        ["color"] = colorCode,
        ["thumbnail"] = { ["url"] = headshotUrl },
        ["fields"] = {
            { ["name"] = "👤 Player", ["value"] = LocalPlayer.Name, ["inline"] = true },
            { ["name"] = "⚔️ Character", ["value"] = charName or "Unknown", ["inline"] = true },
            { ["name"] = "⭐ Rarity", ["value"] = rarity or "Unknown", ["inline"] = true },
            { ["name"] = "🧬 Mutation", ["value"] = mutationName or "No Mutation", ["inline"] = true }
        },
        ["footer"] = { ["text"] = "SENZY HUB • " .. os.date("%X") }
    }

    local payload = HttpService:JSONEncode({
        ["content"] = mentionText ~= "" and mentionText or nil,
        ["embeds"] = { embedData }
    })

    task.spawn(function()
        pcall(function()
            requestFunc({
                Url = WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = payload
            })
        end)
    end)
end

local function RefreshPromptsCache()
    table.clear(cachedRollPrompts)
    table.clear(cachedMergePrompts)
    
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            if prompt.Name == "RollPrompt" then
                table.insert(cachedRollPrompts, prompt)
            else
                local objectText = tostring(prompt.ObjectText):lower()
                local actionText = tostring(prompt.ActionText):lower()
                local promptName = tostring(prompt.Name):lower()
                
                if actionText:find("level up") or objectText:find("character slot") or promptName:find("levelup") then
                    table.insert(cachedMergePrompts, prompt)
                end
            end
        end
    end
end

RefreshPromptsCache()

workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("ProximityPrompt") then
        task.wait(0.1)
        RefreshPromptsCache()
    end
end)

workspace.DescendantRemoving:Connect(function(desc)
    if desc:IsA("ProximityPrompt") then
        for i = #cachedRollPrompts, 1, -1 do
            if cachedRollPrompts[i] == desc then
                table.remove(cachedRollPrompts, i)
            end
        end
        for i = #cachedMergePrompts, 1, -1 do
            if cachedMergePrompts[i] == desc then
                table.remove(cachedMergePrompts, i)
            end
        end
    end
end)

local function isCharacterSelected(charName)
    if not charName then return false end
    local target = string.lower(tostring(charName))
    return SelectedTargetCharacters[target] == true
end

local function isMutationSelected(mutationName)
    local hasAnyMutationSelected = false
    for _, state in pairs(SelectedTargetMutations) do
        if state == true then
            hasAnyMutationSelected = true
            break
        end
    end

    if not hasAnyMutationSelected then
        return true
    end

    local currentMutation = mutationName or "No Mutation"
    return SelectedTargetMutations[string.lower(tostring(currentMutation))] == true
end

---------------------------------------------------------
-- Core Execution Logic
---------------------------------------------------------
local function checkAndBuyFromData(data)
    if not data or not AutoBuyEnabled or isBuying then 
        return 
    end

    local charactersList = data.charactersList
    local rollId = data.rollId
    local plot = data.plot

    if not charactersList then return end

    local matchingSlots = {}
    for slotKey, charData in pairs(charactersList) do
        if typeof(charData) == "table" then
            local charName = charData.Name or charData.name or charData.Character
            local charMutation = charData.Mutation or charData.mutation or charData.Buff or "No Mutation"
            local slotIndex = tonumber(slotKey) or charData.Slot or charData.slot

            if isCharacterSelected(charName) and isMutationSelected(charMutation) then
                table.insert(matchingSlots, {
                    slotIndex = slotIndex or slotKey,
                    charData = charData,
                    charName = charName,
                    charMutation = charMutation
                })
            end
        end
    end

    if #matchingSlots > 0 then
        isBuying = true

        task.spawn(function()
            for retry = 1, 8 do
                for _, item in ipairs(matchingSlots) do
                    local slotIndex = tonumber(item.slotIndex)
                    if rollId and slotIndex and BuyRemote then
                        pcall(function()
                            BuyRemote:FireServer(rollId, slotIndex)
                        end)
                    end
                end

                if plot then
                    for _, obj in ipairs(plot:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Name ~= "RollPrompt" then
                            pcall(function()
                                if fireproximityprompt then
                                    fireproximityprompt(obj, 0)
                                end
                            end)
                        end
                    end
                end

                task.wait(0.1)
            end

            for _, item in ipairs(matchingSlots) do
                local rarity = GetRarityOfCharacter(item.charName)
                if rarity == "God" or rarity == "Secret" or rarity == "Limited" or rarity == "Mythic" then
                    SendDiscordWebhook(item.charName, item.charMutation, rarity)
                end
            end

            isBuying = false
        end)
    end
end

-- แก้ไขการสแกน UUID และยูนิตให้ครอบคลุมทั้ง Character และ Backpack
local function ProcessUUIDSell()
    if not AutoSellEnabled or not SellRemote then return end

    local itemsToScan = {}
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character

    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(itemsToScan, item)
            end
        end
    end

    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(itemsToScan, item)
            end
        end
    end

    for _, item in ipairs(itemsToScan) do
        local charName = item.Name
        local charLower = string.lower(charName)
        local rarity = GetRarityOfCharacter(charName)
        local mutation = GetToolMutation(item)
        local mutLower = string.lower(mutation)

        local isTargetBuy = AutoBuyEnabled and SelectedTargetCharacters[charLower] and (SelectedTargetMutations[mutLower] or next(SelectedTargetMutations) == nil)

        if not isTargetBuy then
            local rarityAllowed = (AutoSellRarities[rarity] == true)
            local charAllowed = (AutoSellCharacters[charLower] == true)
            local mutationAllowed = (AutoSellMutations[mutLower] == true)

            -- เช็คว่าผู้เล่นได้เปิดใช้งาน Filter Mutation ตัวไหนไว้บ้างหรือไม่
            local hasMutationFilter = false
            for _, val in pairs(AutoSellMutations) do
                if val == true then 
                    hasMutationFilter = true 
                    break 
                end
            end

            local finalMutationCheck = hasMutationFilter and mutationAllowed or true

            if rarity == "Unknown" and (AutoSellRarities["Common"] or AutoSellRarities["Rare"]) then
                rarityAllowed = true
            end

            if (rarityAllowed or charAllowed) and finalMutationCheck then
                local uuid = GetToolUUID(item)
                if uuid then
                    pcall(function()
                        SellRemote:FireServer({ uuid })
                    end)
                    task.wait(0.15)
                end
            end
        end
    end
end

---------------------------------------------------------
-- UI Setup
---------------------------------------------------------
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/main.lua"))()

local Window = Library:Window({
    Title = "Senzy Hub",
    Footer = "Free Script",
    Logo = 111116339097216
})

-- TAB 0: INFORMATION & WEBHOOK
local TabInfo = Window:MakeTab({ Title = "Information", Icon = 115960025411300 })

TabInfo:Label({ Title = "SENZY HUB", Desc = "Anime Roll Automation System" })

TabInfo:Button({
    Title = "Copy Discord Link",
    Desc = "https://discord.gg/rhPgnAJE4B",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/rhPgnAJE4B")
            Library:Notify({ Title = "Senzy Hub", Content = "Discord link copied to clipboard." })
        end
    end
})

TabInfo:Label({ Title = "DISCORD WEBHOOK", Desc = "Notifies when rare characters are purchased" })

TabInfo:Textbox({
    Title = "Webhook URL",
    Desc = "Paste Discord Webhook URL",
    Value = "",
    Callback = function(Value) WebhookURL = Value end
})

TabInfo:Textbox({
    Title = "Discord User ID",
    Desc = "User ID for mentions",
    Value = "",
    Callback = function(Value) DiscordUserID = Value end
})

TabInfo:Button({
    Title = "Test Webhook",
    Desc = "Send test payload",
    Callback = function()
        if WebhookURL ~= "" then
            SendDiscordWebhook("Test Character", "Demon", "God")
            Library:Notify({ Title = "Senzy Hub", Content = "Test webhook sent." })
        else
            Library:Notify({ Title = "Error", Content = "Webhook URL is missing." })
        end
    end
})

-- TAB 1: MAIN SETTINGS
local TabMain = Window:MakeTab({ Title = "Main Settings", Icon = 115960025411300 })

TabMain:Toggle({
    Title = "Auto Summon",
    Value = false,
    Callback = function(Value)
        AutoSummonEnabled = Value
        getgenv().AutoRollSystem.Enabled = Value
    end
})

TabMain:Toggle({
    Title = "Enable Auto Buy",
    Value = false,
    Callback = function(Value)
        AutoBuyEnabled = Value
        if Value and latestRollData then
            isBuying = false
            checkAndBuyFromData(latestRollData)
        end
    end
})

-- TAB 2: BUY (NORMAL - LEGENDARY)
local TabLowRarity = Window:MakeTab({ Title = "Buy: Normal - Legendary", Icon = 115960025411300 })

for _, rarityName in ipairs(LowRarities) do
    local charList = CharacterRarityMap[rarityName]
    if charList and #charList > 0 then
        local colorHex = RarityColorMap[rarityName] or "#FFFFFF"
        TabLowRarity:Label({ Title = string.format("<font color=\"%s\">%s</font>", colorHex, string.upper(rarityName)) })

        for _, charName in ipairs(charList) do
            TabLowRarity:Toggle({
                Title = charName,
                Value = false,
                Callback = function(Value)
                    SelectedTargetCharacters[string.lower(charName)] = Value
                    if AutoBuyEnabled and latestRollData then
                        isBuying = false
                        checkAndBuyFromData(latestRollData)
                    end
                end
            })
        end
    end
end

-- TAB 3: BUY (HIGH TIER)
local TabHighRarity = Window:MakeTab({ Title = "Buy: High Tier", Icon = 115960025411300 })

for _, rarityName in ipairs(HighRarities) do
    local charList = CharacterRarityMap[rarityName]
    if charList and #charList > 0 then
        local colorHex = RarityColorMap[rarityName] or "#FFFFFF"
        TabHighRarity:Label({ Title = string.format("<font color=\"%s\">%s</font>", colorHex, string.upper(rarityName)) })

        for _, charName in ipairs(charList) do
            TabHighRarity:Toggle({
                Title = charName,
                Value = false,
                Callback = function(Value)
                    SelectedTargetCharacters[string.lower(charName)] = Value
                    if AutoBuyEnabled and latestRollData then
                        isBuying = false
                        checkAndBuyFromData(latestRollData)
                    end
                end
            })
        end
    end
end

-- TAB 4: BUY MUTATIONS FILTER
local TabMutations = Window:MakeTab({ Title = "Mutations Filter", Icon = 115960025411300 })

TabMutations:Label({ Title = "<font color=\"#00FF7F\">TARGET MUTATIONS</font>" })

for _, mutName in ipairs(AllMutations) do
    TabMutations:Toggle({
        Title = "Mutation: " .. mutName,
        Value = false,
        Callback = function(Value)
            SelectedTargetMutations[string.lower(mutName)] = Value
            if AutoBuyEnabled and latestRollData then
                isBuying = false
                checkAndBuyFromData(latestRollData)
            end
        end
    })
end

-- TAB 5: AUTO SELL
local TabAutoSell = Window:MakeTab({ Title = "Auto Sell Settings", Icon = 115960025411300 })

TabAutoSell:Toggle({
    Title = "Master Auto Sell",
    Desc = "Automatically sells backpack items matching parameters",
    Value = false,
    Callback = function(Value) AutoSellEnabled = Value end
})

TabAutoSell:Navative()
TabAutoSell:Label({ Title = "<font color=\"#FFD700\">1. SELL BY RARITY</font>" })
for _, rarity in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" }) do
    TabAutoSell:Toggle({
        Title = "Sell Rarity: " .. rarity,
        Value = false,
        Callback = function(Value) AutoSellRarities[rarity] = Value end
    })
end

TabAutoSell:Navative()
TabAutoSell:Label({ Title = "<font color=\"#00FFFF\">2. SELL BY MUTATION</font>" })
for _, mutName in ipairs(AllMutations) do
    TabAutoSell:Toggle({
        Title = "Sell Mutation: " .. mutName,
        Value = false,
        Callback = function(Value) AutoSellMutations[string.lower(mutName)] = Value end
    })
end

TabAutoSell:Navative()
TabAutoSell:Label({ Title = "<font color=\"#FF69B4\">3. SELL SPECIFIC UNITS</font>" })
for _, rarityName in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic" }) do
    local list = CharacterRarityMap[rarityName]
    if list then
        for _, charName in ipairs(list) do
            TabAutoSell:Toggle({
                Title = "Sell Unit: " .. charName,
                Value = false,
                Callback = function(Value) AutoSellCharacters[string.lower(charName)] = Value end
            })
        end
    end
end

-- TAB 6: AUTO MERGE
local TabMerge = Window:MakeTab({ Title = "Auto Merge", Icon = 115960025411300 })

TabMerge:Toggle({
    Title = "Auto Merge (Level Up)",
    Value = false,
    Callback = function(Value) AutoMergeEnabled = Value end
})

-- TAB 7: VISUALS
local TabVisuals = Window:MakeTab({ Title = "Display & Tags", Icon = 115960025411300 })

local function UpdateOverheadDisplay(character)
    if not character then return end
    task.spawn(function()
        local humanoid = character:WaitForChild("Humanoid", 5)
        if humanoid then
            humanoid.DisplayName = DisplayTagEnabled and "SENZY HUB ON TOP" or originalDisplayName
        end
        for _, obj in ipairs(character:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Name ~= "Title" then
                if DisplayTagEnabled then
                    obj.Text = "SENZY HUB ON TOP"
                end
            end
        end
    end)
end

TabVisuals:Toggle({
    Title = "Enable Custom Name Tag",
    Value = false,
    Callback = function(Value)
        DisplayTagEnabled = Value
        if LocalPlayer.Character then
            UpdateOverheadDisplay(LocalPlayer.Character)
        end
    end
})

LocalPlayer.CharacterAdded:Connect(function(character)
    if DisplayTagEnabled then
        UpdateOverheadDisplay(character)
    end
end)

---------------------------------------------------------
-- Execution Loops
---------------------------------------------------------
task.spawn(function()
    if RollRemote then
        getgenv().AutoRollSystem.Connection = RollRemote.OnClientEvent:Connect(function(...)
            local args = {...}
            local charactersList, rollId, plot
            for _, arg in ipairs(args) do
                if typeof(arg) == "table" then charactersList = arg
                elseif typeof(arg) == "number" then rollId = arg
                elseif typeof(arg) == "Instance" then plot = arg end
            end
            if not charactersList then return end

            latestRollData = { charactersList = charactersList, rollId = rollId, plot = plot }

            if AutoBuyEnabled then
                checkAndBuyFromData(latestRollData)
            end
        end)
    end
end)

-- Auto Sell Loop
task.spawn(function()
    while true do
        if AutoSellEnabled then
            pcall(ProcessUUIDSell)
        end
        task.wait(1.0)
    end
end)

-- Auto Summon Loop
task.spawn(function()
    while true do
        if AutoSummonEnabled and not isBuying then
            for i = 1, #cachedRollPrompts do
                local prompt = cachedRollPrompts[i]
                if prompt and prompt.Parent then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(prompt, 0)
                        end
                    end)
                end
            end
        end
        task.wait(ROLL_SPEED)
    end
end)

-- Auto Merge Loop
task.spawn(function()
    while true do
        if AutoMergeEnabled then
            for i = 1, #cachedMergePrompts do
                local prompt = cachedMergePrompts[i]
                if prompt and prompt.Parent then
                    pcall(function()
                        if fireproximityprompt then
                            fireproximityprompt(prompt, 0)
                        end
                    end)
                end
            end
        end
        task.wait(MERGE_DELAY)
    end
end)

Library:Notify({
    Title = "Senzy Hub Loaded",
    Content = "v5.0 - Free Script Updated!",
    Duration = 5
})
