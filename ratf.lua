--[[
    SENZY HUB - Roll Anime to Fight (v6.4 - Dropdown Edition)
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
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local LocalPlayer = Players.LocalPlayer

---------------------------------------------------------
-- Configuration Maps & Arrays
---------------------------------------------------------
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

local AllMutations = {
    "Astronaut", "Cursed", "Demon", "Destroyer", "Diamond", "Gold", "Hollow", "No Mutation", "Slayer"
}

local LowRarities = { "Common", "Rare", "Epic", "Legendary" }
local HighRarities = { "Mythic", "Secret", "God", "Limited" }

-- Target Settings (Auto Buy)
local SelectedTargetCharacters = {}
local SelectedRarityMutations = {}

-- Auto Sell Filter Settings
local AutoSellRarities = { ["Common"] = false, ["Rare"] = false, ["Epic"] = false, ["Legendary"] = false }
local AutoSellCharacters = {}
local AutoSellMutations = {
    ["astronaut"] = false, ["cursed"] = false, ["demon"] = false, ["destroyer"] = false,
    ["diamond"] = false, ["gold"] = false, ["hollow"] = false, ["no mutation"] = false, ["slayer"] = false
}

-- Global State Flags
local AutoSummonEnabled = false
local AutoBuyEnabled = false
local AutoSellEnabled = false
local AutoMergeEnabled = false
local DisplayTagEnabled = false
local AntiAFKEnabled = false

-- Webhook Settings
local WebhookURL = ""
local DiscordUserID = ""
local sentWebhookCache = {}

local isBuying = false
local ROLL_SPEED = 1.6
local MERGE_DELAY = 2.0
local latestRollData = nil
local originalDisplayName = LocalPlayer.DisplayName

-- Remote References
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
    local cacheKey = string.format("%s_%s", tostring(charName), tostring(mutationName))
    local currentTime = os.time()
    if sentWebhookCache[cacheKey] and (currentTime - sentWebhookCache[cacheKey]) < 5 then return end
    sentWebhookCache[cacheKey] = currentTime

    local requestFunc = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if not requestFunc then return end

    local mentionText = (DiscordUserID ~= "" and DiscordUserID:match("%d+")) and ("<@" .. DiscordUserID:match("%d+") .. ">") or ""
    local colorCode = 0x2B2D31
    if rarity == "God" then colorCode = 0xFF0055
    elseif rarity == "Secret" then colorCode = 0xA020F0
    elseif rarity == "Limited" then colorCode = 0x00FFFF
    elseif rarity == "Mythic" then colorCode = 0xFF6600
    elseif rarity == "Legendary" then colorCode = 0xFFD700
    elseif rarity == "Epic" then colorCode = 0x9370DB end

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

    task.spawn(function()
        pcall(function()
            requestFunc({
                Url = WebhookURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode({ ["username"] = "SENZY HUB NOTIFIER", ["avatar_url"] = logoUrl, ["content"] = mentionText ~= "" and mentionText or nil, ["embeds"] = { embedData } })
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
workspace.DescendantAdded:Connect(function(desc) if desc:IsA("ProximityPrompt") then task.wait(0.1) RefreshPromptsCache() end end)

local function isCharacterAndRarityMutationSelected(charName, mutationName)
    if not charName then return false end
    local charLower = string.lower(tostring(charName))
    if not SelectedTargetCharacters[charLower] then return false end

    local rarityLower = string.lower(GetRarityOfCharacter(charName))
    local currentMutation = string.lower(tostring(mutationName or "No Mutation"))
    
    SelectedRarityMutations[rarityLower] = SelectedRarityMutations[rarityLower] or {}
    local rarityMutations = SelectedRarityMutations[rarityLower]

    local hasAnyMutationSelected = false
    for _, isSelected in pairs(rarityMutations) do
        if isSelected == true then hasAnyMutationSelected = true; break end
    end

    if not hasAnyMutationSelected then return true end
    return rarityMutations[currentMutation] == true
end

---------------------------------------------------------
-- Core Execution Logic
---------------------------------------------------------
local function checkAndBuyFromData(data)
    if not data or not AutoBuyEnabled or isBuying then return end
    local charactersList, rollId, plot = data.charactersList, data.rollId, data.plot
    if not charactersList then return end

    local matchingSlots = {}
    for slotKey, charData in pairs(charactersList) do
        if typeof(charData) == "table" then
            local charName = charData.Name or charData.name or charData.Character
            local charMutation = charData.Mutation or charData.mutation or charData.Buff or "No Mutation"
            local slotIndex = tonumber(slotKey) or charData.Slot or charData.slot

            if isCharacterAndRarityMutationSelected(charName, charMutation) then
                table.insert(matchingSlots, { slotIndex = slotIndex or slotKey, charName = charName, charMutation = charMutation })
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
                        pcall(function() BuyRemote:FireServer(rollId, slotIndex) end)
                    end
                end
                if plot then
                    for _, obj in ipairs(plot:GetDescendants()) do
                        if obj:IsA("ProximityPrompt") and obj.Name ~= "RollPrompt" then
                            pcall(function() if fireproximityprompt then fireproximityprompt(obj, 0) end end)
                        end
                    end
                end
                task.wait(0.1)
            end
            for _, item in ipairs(matchingSlots) do
                SendDiscordWebhook(item.charName, item.charMutation, GetRarityOfCharacter(item.charName))
            end
            isBuying = false
        end)
    end
end

---------------------------------------------------------
-- UI Setup (Fluent UI Library - Dropdown Edition)
---------------------------------------------------------
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Window = Fluent:CreateWindow({
    Title = "Senzy Hub | Roll Anime to Fight",
    SubTitle = "v6.4 - Dropdown Edition",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = true,
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

local Tabs = {
    Info = Window:AddTab({ Title = "Information", Icon = "info" }),
    Main = Window:AddTab({ Title = "Main", Icon = "play" }),
    LowBuy = Window:AddTab({ Title = "Buy: Low", Icon = "shield" }),
    HighBuy = Window:AddTab({ Title = "Buy: High", Icon = "zap" }),
    Sell = Window:AddTab({ Title = "Sell", Icon = "trash-2" }),
    Merge = Window:AddTab({ Title = "Merge", Icon = "layers" }),
    Extra = Window:AddTab({ Title = "Extra", Icon = "cpu" }),
    Visuals = Window:AddTab({ Title = "Visuals", Icon = "eye" })
}

-- TAB 0: INFO
Tabs.Info:AddParagraph({ Title = "Senzy Hub Information", Content = "Welcome to Senzy Hub! Automated rolling, buying, selling, and merging utility." })
Tabs.Info:AddInput("WebhookURLInput", { Title = "Webhook URL", Default = "", Placeholder = "https://discord.com/api/webhooks/...", Finished = true, Callback = function(v) WebhookURL = v end })
Tabs.Info:AddInput("DiscordIDInput", { Title = "Discord User ID", Default = "", Placeholder = "Enter User ID for tags", Finished = true, Callback = function(v) DiscordUserID = v end })

-- TAB 1: MAIN
Tabs.Main:AddToggle("AutoSummonToggle", { Title = "Auto Summon", Default = false, Callback = function(v) AutoSummonEnabled = v getgenv().AutoRollSystem.Enabled = v end })
Tabs.Main:AddToggle("AutoBuyToggle", { Title = "Enable Auto Buy", Default = false, Callback = function(v) AutoBuyEnabled = v if v and latestRollData then isBuying = false checkAndBuyFromData(latestRollData) end end })

---------------------------------------------------------
-- Helper UI Generator: Dropdown Edition
---------------------------------------------------------
local function CreateDropdownRarityUI(tabTarget, rarityList)
    for _, rarityName in ipairs(rarityList) do
        local charList = CharacterRarityMap[rarityName]
        if charList and #charList > 0 then
            local rarityLower = string.lower(rarityName)
            SelectedRarityMutations[rarityLower] = SelectedRarityMutations[rarityLower] or {}

            -- Character Multi-Dropdown
            tabTarget:AddDropdown(rarityName .. "_CharsDropdown", {
                Title = rarityName .. " Characters",
                Description = "Select target units to auto-buy",
                Values = charList,
                Multi = true,
                Default = {},
                Callback = function(valueTable)
                    for _, cName in ipairs(charList) do
                        SelectedTargetCharacters[string.lower(cName)] = valueTable[cName] == true
                    end
                    if AutoBuyEnabled and latestRollData then isBuying = false checkAndBuyFromData(latestRollData) end
                end
            })

            -- Mutation Multi-Dropdown
            tabTarget:AddDropdown(rarityName .. "_MutDropdown", {
                Title = rarityName .. " Mutations",
                Description = "Select allowed mutations (Leave empty = All)",
                Values = AllMutations,
                Multi = true,
                Default = {},
                Callback = function(valueTable)
                    for _, mName in ipairs(AllMutations) do
                        SelectedRarityMutations[rarityLower][string.lower(mName)] = valueTable[mName] == true
                    end
                    if AutoBuyEnabled and latestRollData then isBuying = false checkAndBuyFromData(latestRollData) end
                end
            })
        end
    end
end

-- TAB 2 & 3: BUY LOW / HIGH
CreateDropdownRarityUI(Tabs.LowBuy, LowRarities)
CreateDropdownRarityUI(Tabs.HighBuy, HighRarities)

-- TAB 4: SELL
Tabs.Sell:AddToggle("MasterSellToggle", { Title = "Master Auto Sell", Default = false, Callback = function(v) AutoSellEnabled = v end })
for _, rarity in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" }) do
    Tabs.Sell:AddToggle("SellRarity_" .. rarity, { Title = "Sell Rarity: " .. rarity, Default = false, Callback = function(v) AutoSellRarities[rarity] = v end })
end

-- TAB 5: MERGE
Tabs.Merge:AddToggle("AutoMergeToggle", { Title = "Auto Merge (Level Up)", Default = false, Callback = function(v) AutoMergeEnabled = v end })

-- TAB 6: EXTRA
Tabs.Extra:AddToggle("AntiAFKToggle", { Title = "Anti-AFK Disconnect", Default = true, Callback = function(v) AntiAFKEnabled = v end })
LocalPlayer.Idled:Connect(function() if AntiAFKEnabled then VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end end)

-- TAB 7: VISUALS
Tabs.Visuals:AddToggle("CustomNameTagToggle", { Title = "Enable Custom Name Tag", Default = false, Callback = function(v) DisplayTagEnabled = v if LocalPlayer.Character then 
    local hum = LocalPlayer.Character:FindFirstChild("Humanoid")
    if hum then hum.DisplayName = v and "SENZY HUB ON TOP" or originalDisplayName end
end end })

-- Loops
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
            if AutoBuyEnabled then checkAndBuyFromData(latestRollData) end
        end)
    end
end)

task.spawn(function()
    while true do
        if AutoSellEnabled then
            pcall(function()
                local backpack = LocalPlayer:FindFirstChild("Backpack")
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            local r = GetRarityOfCharacter(item.Name)
                            local m = GetToolMutation(item)
                            if AutoSellRarities[r] or AutoSellMutations[string.lower(m)] then
                                local uuid = GetToolUUID(item)
                                if uuid and SellRemote then SellRemote:FireServer({uuid}) task.wait(0.15) end
                            end
                        end
                    end
                end
            end)
        end
        task.wait(1.0)
    end
end)

task.spawn(function()
    while true do
        if AutoSummonEnabled and not isBuying then
            for _, prompt in ipairs(cachedRollPrompts) do
                if prompt and prompt.Parent then pcall(function() if fireproximityprompt then fireproximityprompt(prompt, 0) end end) end
            end
        end
        task.wait(ROLL_SPEED)
    end
end)

task.spawn(function()
    while true do
        if AutoMergeEnabled then
            for _, prompt in ipairs(cachedMergePrompts) do
                if prompt and prompt.Parent then pcall(function() if fireproximityprompt then fireproximityprompt(prompt, 0) end end) end
            end
        end
        task.wait(MERGE_DELAY)
    end
end)

Window:SelectTab(1)
Fluent:Notify({ Title = "Senzy Hub Loaded", Content = "v6.4 - Dropdown Edition Ready!", Duration = 5 })
