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

local CharacterRarityMap = {
    ["Common"] = { "Ussop", "Krillin", "Luffy", "Zoro", "Itadori" },
    ["Rare"] = { "Goku", "Maki", "Junwoo", "Mob" },
    ["Epic"] = { "Shinra", "Manji", "Ban", "Guts", "Renji", "Tanjiro", "Piccolo" },
    ["Legendary"] = { "Erwin", "Gojo", "Grimmjow", "Nanami", "Naruto", "NarutoClone", "Saitama", "Sukuna", "Trunks", "Zenitsu" },
    ["Mythic"] = { "Ace", "Akaza", "Broly", "Hoshina", "Kisuke", "Kokushibo", "Orihime", "Rengoku", "Simo Hayha", "Stark", "Toji", "Yoruichi" },
    ["Secret"] = { "Byakuya", "Dio", "Douma", "Frieren", "Gyomei", "Jiren", "Kenpachi", "Mahoraga", "Megumi", "Rika", "Ulquiorra", "Yhwatch", "Yuta" },
    ["God"] = { "Ainz", "Aizen (Transcendent)", "Beerus", "Death Knight", "Gojo (Shibuya)", "Goku (Black)", "Ichigo", "Muzan", "Muzan (Evolved)", "Rimuru", "Shanks", "Sukuna (Heian)", "Whis", "Yamamoto", "Yorichi" },
    ["Limited"] = { "Albedo", "Black Frieza", "Britain Army", "Cosmic Garou", "Entoma", "Frieza", "Genos", "Lelouch", "Mash", "Okurun", "Saitama (Serious)", "Sakamoto", "Sakamoto (Fit)", "Shalltear", "Spider (Entoma)", "Yor" }
}

local SecretMutations = {
    "Astronaut",
    "Cursed",
    "Demon",
    "Destroyer",
    "Diamond",
    "Gold",
    "Hollow",
    "No Mutation",
    "Slayer"
}

local LowRarities = { "Common", "Rare", "Epic", "Legendary" }
local HighRarities = { "Mythic", "Secret", "God", "Limited" }

local SelectedTargetCharacters = {}
local SelectedTargetMutations = {}

local AutoSummonEnabled = false
local AutoBuyEnabled = false
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

local RollRemote = nil
local BuyRemote = nil

local cachedRollPrompts = {}
local cachedMergePrompts = {}

---------------------------------------------------------
-- Helper Functions
---------------------------------------------------------
local function GetRarityOfCharacter(charName)
    if not charName then return "Unknown" end
    local lowerName = string.lower(charName)
    for rarity, list in pairs(CharacterRarityMap) do
        for _, name in ipairs(list) do
            if string.lower(name) == lowerName then
                return rarity
            end
        end
    end
    return "Unknown"
end

local function SendDiscordWebhook(charName, mutationName, rarity)
    if WebhookURL == "" or not WebhookURL:find("http") then return end

    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not requestFunc then return end

    local mentionText = ""
    if DiscordUserID ~= "" and DiscordUserID:match("%d+") then
        mentionText = "<@" .. DiscordUserID:match("%d+") .. ">"
    end

    local colorCode = 65535 -- Default Cyan
    if rarity == "God" then colorCode = 16711680 -- Red
    elseif rarity == "Secret" then colorCode = 10181046 -- Purple
    elseif rarity == "Limited" then colorCode = 16753920 -- Orange
    end

    local embedData = {
        ["title"] = "🎉 Auto Buy Success! (SENZY HUB)",
        ["color"] = colorCode,
        ["fields"] = {
            { ["name"] = "👤 Player", ["value"] = LocalPlayer.Name, ["inline"] = true },
            { ["name"] = "⭐ Character", ["value"] = charName or "Unknown", ["inline"] = true },
            { ["name"] = "🔥 Rarity", ["value"] = rarity or "Unknown", ["inline"] = true },
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

local function ProcessPrompt(prompt)
    if not prompt:IsA("ProximityPrompt") then return end
    if prompt.Name == "RollPrompt" then
        if not table.find(cachedRollPrompts, prompt) then
            table.insert(cachedRollPrompts, prompt)
        end
    else
        local objectText = tostring(prompt.ObjectText):lower()
        local actionText = tostring(prompt.ActionText):lower()
        local promptName = tostring(prompt.Name):lower()
        
        if actionText:find("level up") or objectText:find("character slot") or promptName:find("levelup") then
            if not table.find(cachedMergePrompts, prompt) then
                table.insert(cachedMergePrompts, prompt)
            end
        end
    end
end

local function RefreshPromptsCache()
    table.clear(cachedRollPrompts)
    table.clear(cachedMergePrompts)
    
    for _, prompt in ipairs(workspace:GetDescendants()) do
        ProcessPrompt(prompt)
    end
end

RefreshPromptsCache()

workspace.DescendantAdded:Connect(function(desc)
    if desc:IsA("ProximityPrompt") then
        task.wait(0.1)
        ProcessPrompt(desc)
    end
end)

workspace.DescendantRemoving:Connect(function(desc)
    if desc:IsA("ProximityPrompt") then
        local idxRoll = table.find(cachedRollPrompts, desc)
        if idxRoll then table.remove(cachedRollPrompts, idxRoll) end
        
        local idxMerge = table.find(cachedMergePrompts, desc)
        if idxMerge then table.remove(cachedMergePrompts, idxMerge) end
    end
end)

local function isCharacterSelected(charName)
    if not charName then return false end
    return SelectedTargetCharacters[string.lower(tostring(charName))] == true
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

            -- Webhook notification trigger
            for _, item in ipairs(matchingSlots) do
                local rarity = GetRarityOfCharacter(item.charName)
                if rarity == "God" or rarity == "Secret" or rarity == "Limited" then
                    SendDiscordWebhook(item.charName, item.charMutation, rarity)
                end
            end

            isBuying = false
        end)
    end
end

---------------------------------------------------------
-- UI Setup (Senzy Hub Library)
---------------------------------------------------------
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/main.lua"))()

local Window = Library:Window({
    Title = "Senzy Hub",
    Footer = "Free Script",
    Logo = 111116339097216
})

-- TAB 0: INFO & WEBHOOK
local TabInfo = Window:MakeTab({
    Title = "Information",
    Icon = 115960025411300
})

TabInfo:Label({
    Title = "=== SENZY HUB ===",
    Desc = "Welcome to Senzy Hub Auto Roll System!"
})

TabInfo:Button({
    Title = "Copy Discord Link",
    Desc = "https://discord.gg/rhPgnAJE4B",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/rhPgnAJE4B")
            Library:Notify({ Title = "Senzy Hub", Content = "Discord link copied to clipboard!" })
        end
    end
})

TabInfo:Label({
    Title = "=== DISCORD WEBHOOK ===",
    Desc = "Notifies when Secret/God/Limited character is bought"
})

TabInfo:Textbox({
    Title = "Discord Webhook URL",
    Desc = "Paste your Webhook URL here",
    Value = "",
    Callback = function(Value)
        WebhookURL = Value
    end
})

TabInfo:Textbox({
    Title = "Discord User ID (Optional)",
    Desc = "Enter ID to mention you (e.g. 123456789)",
    Value = "",
    Callback = function(Value)
        DiscordUserID = Value
    end
})

TabInfo:Button({
    Title = "Test Webhook Notification",
    Desc = "Sends a test message to your Webhook",
    Callback = function()
        if WebhookURL ~= "" then
            SendDiscordWebhook("Test Character", "Demon", "God")
            Library:Notify({ Title = "Senzy Hub", Content = "Test Webhook sent!" })
        else
            Library:Notify({ Title = "Error", Content = "Please enter a Webhook URL first!" })
        end
    end
})

-- TAB 1: MAIN SETTINGS
local TabMain = Window:MakeTab({
    Title = "Main Settings",
    Icon = 115960025411300
})

TabMain:Toggle({
    Title = "Auto Summon",
    Desc = "Automatically Summon",
    Value = false,
    Callback = function(Value)
        AutoSummonEnabled = Value
        getgenv().AutoRollSystem.Enabled = Value
    end
})

TabMain:Toggle({
    Title = "Enable Auto Buy",
    Desc = "Master switch to buy selected characters/mutations",
    Value = false,
    Callback = function(Value)
        AutoBuyEnabled = Value
        if Value and latestRollData then
            isBuying = false
            checkAndBuyFromData(latestRollData)
        end
    end
})

-- TAB 2: COMMON -> LEGENDARY
local TabLowRarity = Window:MakeTab({
    Title = "Buy: Normal - Legendary",
    Icon = 115960025411300
})

for _, rarityName in ipairs(LowRarities) do
    local charList = CharacterRarityMap[rarityName]
    if charList and #charList > 0 then
        TabLowRarity:Label({
            Title = "=== " .. string.upper(rarityName) .. " ===",
            Desc = "Toggle characters you want to buy"
        })

        for _, charName in ipairs(charList) do
            TabLowRarity:Toggle({
                Title = charName,
                Desc = "Buy " .. charName .. " automatically",
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

-- TAB 3: MYTHIC / SECRET / GOD / LIMITED
local TabHighRarity = Window:MakeTab({
    Title = "Buy: High Tier",
    Icon = 115960025411300
})

for _, rarityName in ipairs(HighRarities) do
    local charList = CharacterRarityMap[rarityName]
    if charList and #charList > 0 then
        TabHighRarity:Label({
            Title = "=== " .. string.upper(rarityName) .. " ===",
            Desc = "Toggle high tier characters you want to buy"
        })

        for _, charName in ipairs(charList) do
            TabHighRarity:Toggle({
                Title = charName,
                Desc = "Buy " .. charName .. " automatically",
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

-- TAB 4: MUTATIONS FILTER
local TabMutations = Window:MakeTab({
    Title = "Mutations Filter",
    Icon = 115960025411300
})

TabMutations:Label({
    Title = "=== MUTATIONS FILTER ===",
    Desc = "Select specific mutations to target"
})

for _, mutName in ipairs(SecretMutations) do
    TabMutations:Toggle({
        Title = "Mutation: " .. mutName,
        Desc = "Buy characters with " .. mutName .. " buff",
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

-- TAB 5: AUTO MERGE
local TabMerge = Window:MakeTab({
    Title = "Auto Merge",
    Icon = 115960025411300
})

TabMerge:Toggle({
    Title = "Auto Merge (Level Up)",
    Desc = "Automatically triggers Level Up prompts across slots",
    Value = false,
    Callback = function(Value)
        AutoMergeEnabled = Value
    end
})

-- TAB 6: VISUALS & DISPLAY
local TabVisuals = Window:MakeTab({
    Title = "Display & Tags",
    Icon = 115960025411300
})

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
    Desc = "Overrides overhead display text to 'SENZY HUB ON TOP'",
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
-- Event Connection & Optimization Loops
---------------------------------------------------------
task.spawn(function()
    pcall(function()
        local RS = ReplicatedStorage
        local Remotes = RS:WaitForChild("Remotes", 10)
        if Remotes then
            local CharactersRemotes = Remotes:WaitForChild("Characters", 10)
            if CharactersRemotes then
                RollRemote = CharactersRemotes:WaitForChild("Roll", 10)
                BuyRemote = CharactersRemotes:WaitForChild("Buy", 10)
            end
        end
    end)

    if RollRemote then
        getgenv().AutoRollSystem.Connection = RollRemote.OnClientEvent:Connect(function(...)
            local args = { ... }
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
