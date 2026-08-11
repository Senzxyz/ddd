local function getService(serviceName)
    local service = game:GetService(serviceName)
    return (cloneref and cloneref(service)) or service
end

local Players = getService("Players")
local ReplicatedStorage = getService("ReplicatedStorage")
local HttpService = getService("HttpService")
local Lighting = getService("Lighting")
local VirtualUser = getService("VirtualUser")
local CoreGui = getService("CoreGui")
local TeleportService = getService("TeleportService")
local LocalPlayer = Players.LocalPlayer

-- =========================================================================
-- CLEANUP PREVIOUS UI & INSTANCES
-- =========================================================================
pcall(function()
    for _, gui in ipairs(CoreGui:GetChildren()) do
        if gui.Name:find("Senzy") or gui.Name:find("Library") or gui:FindFirstChild("Main") then
            gui:Destroy()
        end
    end
    for _, gui in ipairs(LocalPlayer.PlayerGui:GetChildren()) do
        if gui.Name:find("Senzy") then
            gui:Destroy()
        end
    end
end)

local Roll = ReplicatedStorage.Remotes.Characters.Roll

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

getgenv().SenzyIntentionalTeleport = false

local isLoadingConfig = true

local Config = {
    AutoSummon = false,
    AutoBuy = false,
    AutoSell = false,
    AutoEvo = false,
    SelectedEvoUnits = {},
    
    AutoClone = false,
    SelectedCloneUnits = {},
    CloneDelay = 5.0,

    AutoSpinWheel = false,
    AutoUpgradeGold = false,
    AutoUpgradeLuck = false,
    AutoUpgradeSlots = false,
    AutoUpgradeInventory = false,
    
    -- Quest System Config
    AutoClaimQuests = false,
    AutoClaimWeeklyQuests = false,
    AutoClaimBP = false,
    
    -- Faction System Config
    AutoClaimFactionQuests = false,

    AutoJoinTower = false,
    AutoLuckPotion = false,
    
    AutoStopWave = false,
    TargetWave = 30,

    DisplayTag = false,
    AntiAFK = true,
    RollSpeed = 1.6,
    EvoDelay = 3.0,
    WebhookURL = "",
    DiscordUserID = "",
    NotifyDisconnect = false,
    
    SelectedCharacters = {},
    SelectedMutations = {},
    
    Method2_Enabled = false,
    Method2_Units = {},
    Method2_UnitList = {},
    
    SellRarities = { Common = false, Rare = false, Epic = false, Legendary = false, Mythic = false, Secret = false, God = false, Limited = false },
    SellCharacters = {},
    SellMutations = {},

    AutoExecute = false
}

local UIElements = {
    Toggles = {},
    Textboxes = {},
    Dropdowns = {}
}

local LOGO_URL = "https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/Senz1.png"
local BANNER_URL = "https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/67.png"

-- =========================================================================
-- MODULE LOADERS (Battlepass & Faction)
-- =========================================================================
local BPQuestModule, FactionInfoModule, FactionQuestModule
pcall(function()
    BPQuestModule = require(ReplicatedStorage.Modules.Battlepass.BattlepassQuest.Quest)
end)
pcall(function()
    FactionInfoModule = require(ReplicatedStorage.Modules.Shared.Faction.FactionInfo)
end)
pcall(function()
    FactionQuestModule = require(ReplicatedStorage.Modules.Shared.Faction.FactionQuest)
end)

local DataService = nil
pcall(function()
    local module = ReplicatedStorage:WaitForChild("Data", 3):WaitForChild("DataService", 3):WaitForChild("DataServiceClient", 3)
    DataService = require(module)
end)

local EvolutionInfo = {}
pcall(function()
    EvolutionInfo = require(ReplicatedStorage.Modules.Shared.Evolve.EvolutionInfo)
end)

local EvolutionList = {}
if EvolutionInfo and EvolutionInfo.Characters then
    for evolutionName in pairs(EvolutionInfo.Characters) do
        table.insert(EvolutionList, evolutionName)
    end
    table.sort(EvolutionList)
end

local CloneInfo
pcall(function()
    CloneInfo = require(ReplicatedStorage.Modules.Shared.CloneStuff.CloneInfo)
end)

local CharactersInfo = { Characters = {} }
pcall(function()
    CharactersInfo = require(ReplicatedStorage.Modules.Characters.CharactersInfo)
end)

local RarityOrder = {
    Common = 1,
    Rare = 2,
    Epic = 3,
    Legendary = 4,
    Mythic = 5,
    Secret = 6,
    God = 7,
    Limited = 8
}

local Characters = table.clone(CharactersInfo.Characters or {})

table.sort(Characters, function(a, b)
    return (RarityOrder[a.Rarity] or 999) < (RarityOrder[b.Rarity] or 999)
end)

local CharacterRarityMap = {}
for _, v in ipairs(Characters) do
    if not CharacterRarityMap[v.Rarity] then
        CharacterRarityMap[v.Rarity] = {}
    end
    table.insert(CharacterRarityMap[v.Rarity], v.Name)
end

local RarityList = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" }

local RarityColorMap = {
    Common = "#A6A6A6", Rare = "#1E90FF", Epic = "#9370DB", Legendary = "#FFD700",
    Mythic = "#FF4500", Secret = "#8A2BE2", God = "#FF0000", Limited = "#00FFFF"
}

local MutationInfo = { Mutations = {} }
pcall(function()
    local modules = ReplicatedStorage:FindFirstChild("Modules")
    if modules then
        local shared = modules:FindFirstChild("Shared")
        local chars = modules:FindFirstChild("Characters")
        if shared and shared:FindFirstChild("MutationInfo") then
            MutationInfo = require(shared.MutationInfo)
        elseif chars and chars:FindFirstChild("MutationInfo") then
            MutationInfo = require(chars.MutationInfo)
        end
    end
end)

local AllMutations = { "No Mutation" }

if MutationInfo and MutationInfo.Mutations then
    for mutation, data in pairs(MutationInfo.Mutations) do
        table.insert(AllMutations, mutation)
    end

    table.sort(AllMutations, function(a, b)
        if a == "No Mutation" then return true end
        if b == "No Mutation" then return false end
        return (MutationInfo.Mutations[a].Chance or 0) > (MutationInfo.Mutations[b].Chance or 0)
    end)
end

local AllUnitsList = {}
for _, v in ipairs(Characters) do
    table.insert(AllUnitsList, v.Name)
end
table.sort(AllUnitsList)

local isBuying = false
local latestRollData = nil
local sentWebhookCache = {}
local cachedRollPrompts = {}
local originalDisplayName = LocalPlayer.DisplayName

local RollRemote, BuyRemote, SellRemote, EvoRemote, CloneRemote, QuestClaimRemote, BpClaimRemote, FactionQuestRemote
RollRemote = Roll
pcall(function()
    local Remotes = ReplicatedStorage:WaitForChild("Remotes", 5)
    if Remotes then
        local CharactersRemote = Remotes:WaitForChild("Characters", 5)
        if CharactersRemote then
            BuyRemote = CharactersRemote:WaitForChild("Buy", 5)
            SellRemote = CharactersRemote:WaitForChild("Sell", 5)
        end
        local EvoFolder = Remotes:WaitForChild("EvolutionRemotes", 5)
        if EvoFolder then
            EvoRemote = EvoFolder:WaitForChild("Evolve", 5)
        end
        local CloneFolder = Remotes:WaitForChild("CloneRemotes", 5)
        if CloneFolder then
            CloneRemote = CloneFolder:WaitForChild("Request", 5)
        end
    end

    local bpModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Battlepass")
    if bpModule then
        local bpQuestFolder = bpModule:FindFirstChild("BattlepassQuest")
        if bpQuestFolder then
            QuestClaimRemote = bpQuestFolder:FindFirstChild("ClaimQuest")
        end
        BpClaimRemote = bpModule:FindFirstChild("Claim")
    end

    local factionModule = ReplicatedStorage:FindFirstChild("Modules") and ReplicatedStorage.Modules:FindFirstChild("Shared") and ReplicatedStorage.Modules.Shared:FindFirstChild("Faction")
    if factionModule then
        FactionQuestRemote = factionModule:FindFirstChild("FactionQuest") or factionModule:FindFirstChild("FactionUpdate")
    end
end)

local RequestPromptRefresh

local function CleanName(str)
    if not str then return "" end
    return string.lower(tostring(str)):gsub("[%s%c%p]", "")
end

local function GetRealToolName(tool)
    if not tool or not tool.Parent then return "" end
    local realName = tool:GetAttribute("Character") or tool:GetAttribute("Unit") or tool:GetAttribute("Name") or tool:GetAttribute("id")
    if realName then return tostring(realName) end
    local charVal = tool:FindFirstChild("Character") or tool:FindFirstChild("Unit") or tool:FindFirstChild("Name")
    if charVal and charVal:IsA("ValueBase") then return tostring(charVal.Value) end
    return tool.Name
end

local function GetRarityOfCharacter(charName)
    if not charName or charName == "" then return "Unknown" end
    local cleanTarget = CleanName(charName)
    for _, character in ipairs(CharactersInfo.Characters or {}) do
        if CleanName(character.Name) == cleanTarget then
            return character.Rarity
        end
    end
    return "Unknown"
end

local function GetCharacterIdByName(charName)
    if not charName or charName == "" then return nil end
    local cleanTarget = CleanName(charName)
    for id, character in pairs(CharactersInfo.Characters or {}) do
        if CleanName(character.Name) == cleanTarget then
            return character.Id or character.ID or id
        end
    end
    return nil
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

local function GetInventoryUnits()
    local units = {}
    local function ScanContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local name = GetRealToolName(item)
                local uuid = GetToolUUID(item)
                local mutation = GetToolMutation(item)
                local rarity = GetRarityOfCharacter(name)
                local charId = GetCharacterIdByName(name)
                table.insert(units, {
                    Name = name,
                    UUID = uuid,
                    Mutation = mutation,
                    Rarity = rarity,
                    CharacterId = charId,
                    Instance = item
                })
            end
        end
    end
    ScanContainer(LocalPlayer:FindFirstChild("Backpack"))
    ScanContainer(LocalPlayer.Character)
    local dataInv = GetData("Inventory") or GetData("Items")
    if type(dataInv) == "table" then
        for k, v in pairs(dataInv) do
            if type(v) == "table" then
                table.insert(units, {
                    Name = v.Name or v.Character or tostring(k),
                    UUID = v.UUID or v.uuid or v.ID,
                    Mutation = v.Mutation or v.Buff or "No Mutation",
                    Rarity = v.Rarity or GetRarityOfCharacter(v.Name),
                    CharacterId = v.Id or v.id,
                    Instance = nil
                })
            end
        end
    end
    return units
end

local function CountInventoryItems(charName, mutationName)
    local count = 0
    local targetCharClean = CleanName(charName)
    local targetMutClean = CleanName(mutationName or "No Mutation")

    local function CheckContainer(container)
        if not container then return end
        for _, item in ipairs(container:GetChildren()) do
            if item:IsA("Tool") then
                local itemNameClean = CleanName(GetRealToolName(item))
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

local currentM2ConfigUnit = nil

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
        elseif type(elem.Refresh) == "function" then
            elem:Refresh(val)
        elseif type(elem.Clear) == "function" and type(elem.Add) == "function" and type(val) == "table" then
            elem:Clear()
            for _, v in ipairs(val) do
                elem:Add(v)
            end
        end
    end)
end

local function SyncM2UnitConfigToUI(unitName)
    if not unitName then
        UpdateUIElement(UIElements.Dropdowns["M2_UnitRarities"], {})
        UpdateUIElement(UIElements.Dropdowns["M2_UnitMutations"], {})
        return
    end
    local unitClean = CleanName(unitName)
    local data = Config.Method2_Units[unitClean] or { Rarities = {}, Mutations = {} }

    local rarityValues = {}
    for rKey, _ in pairs(data.Rarities or {}) do
        if rKey == "all" then
            table.insert(rarityValues, "All Rarity")
        else
            for _, rName in ipairs(RarityList) do
                if CleanName(rName) == rKey then
                    table.insert(rarityValues, rName)
                    break
                end
            end
        end
    end
    UpdateUIElement(UIElements.Dropdowns["M2_UnitRarities"], rarityValues)

    local mutValues = {}
    for mKey, _ in pairs(data.Mutations or {}) do
        if mKey == "all" then
            table.insert(mutValues, "All Mutation")
        else
            for _, mName in ipairs(AllMutations) do
                if CleanName(mName) == mKey then
                    table.insert(mutValues, mName)
                    break
                end
            end
        end
    end
    UpdateUIElement(UIElements.Dropdowns["M2_UnitMutations"], mutValues)
end

local function UpdateM2ConfigUnitSelector()
    local list = {}
    for _, name in ipairs(Config.Method2_UnitList or {}) do
        table.insert(list, name)
    end
    if UIElements.Dropdowns["M2_ConfigUnitSelector"] then
        pcall(function()
            local elem = UIElements.Dropdowns["M2_ConfigUnitSelector"]
            if elem.Refresh then
                elem:Refresh(list, currentM2ConfigUnit)
            elseif elem.SetList then
                elem:SetList(list, currentM2ConfigUnit)
            elseif elem.Clear then
                elem:Clear()
                for _, opt in ipairs(list) do
                    if elem.Add then elem:Add(opt) end
                end
            end
        end)
    end
    if #list > 0 then
        if not currentM2ConfigUnit or not Config.Method2_Units[CleanName(currentM2ConfigUnit)] then
            currentM2ConfigUnit = list[1]
        end
        SyncM2UnitConfigToUI(currentM2ConfigUnit)
    else
        currentM2ConfigUnit = nil
    end
end

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

local function MatchesTargetFilter(charName, mutationName, actualRarity)
    if not charName then return false end
    local charClean = CleanName(charName)
    local currentRarity = actualRarity or GetRarityOfCharacter(charName)
    local rarityClean = CleanName(currentRarity)
    local currentMutation = CleanName(mutationName or "No Mutation")

    if Config.Method2_Enabled then
        local unitData = Config.Method2_Units[charClean]
        if unitData then
            local allowedRarities = unitData.Rarities or {}
            local allowedMutations = unitData.Mutations or {}

            local hasRarityFilter = false
            for _ in pairs(allowedRarities) do hasRarityFilter = true; break end

            local hasMutFilter = false
            for _ in pairs(allowedMutations) do hasMutFilter = true; break end

            local isRarityMatch = allowedRarities["all"] == true or allowedRarities[rarityClean] == true
            local isMutMatch = allowedMutations["all"] == true or allowedMutations[currentMutation] == true

            local rarityCheck = not hasRarityFilter or isRarityMatch
            local mutCheck = not hasMutFilter or isMutMatch

            if rarityCheck and mutCheck then
                return true
            end
        end
    end

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

local autoSaveTimer = nil
local function SaveAutoState()
    if isLoadingConfig or not writefile then return end
    if autoSaveTimer then
        task.cancel(autoSaveTimer)
        autoSaveTimer = nil
    end
    autoSaveTimer = task.delay(0.5, function()
        EnsureConfigFolder()
        pcall(function()
            local saveTable = {}
            for k, v in pairs(Config) do
                if k ~= "AutoSpinWheel" and k ~= "AutoClaimQuests" and k ~= "AutoClaimWeeklyQuests" and k ~= "AutoClaimBP" and k ~= "AutoClaimFactionQuests" and k ~= "AutoJoinTower" then
                    saveTable[k] = v
                end
            end
            writefile(AutoSaveFilePath, HttpService:JSONEncode(saveTable))
        end)
        autoSaveTimer = nil
    end)
end

-- =========================================================================
-- SYSTEM: AUTO EXECUTE SYSTEM (WITH DEBOUNCE TO PREVENT DUPLICATE QUEUES)
-- =========================================================================

local isQueuedForTeleport = false

local function GetQueueFunction()
    return queue_on_teleport 
        or queueonteleport 
        or (syn and syn.queue_on_teleport) 
        or (fluxus and fluxus.queue_on_teleport) 
        or (getgenv and getgenv().queue_on_teleport)
end

local AUTO_EXECUTE_SCRIPT = [[
    repeat task.wait() until game:IsLoaded()
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/senzxyz2xxx/SenzyHub/refs/heads/main/Loader.lua"))()
    end)
    if not success then
        warn("[SenzyHub] Auto Execute Loader Error: " .. tostring(err))
    end
]]

local function SafeQueueOnTeleport(code)
    if not Config.AutoExecute or isQueuedForTeleport then return false end
    
    local queueFunc = GetQueueFunction()
    if not queueFunc then
        warn("[SenzyHub] Auto Execute is not supported by this executor")
        return false
    end

    isQueuedForTeleport = true
    local success, err = pcall(function()
        queueFunc(code)
    end)

    if not success then
        isQueuedForTeleport = false
        warn("[SenzyHub] Failed to queue script on teleport: " .. tostring(err))
        return false
    end

    return true
end

local function SetupAutoExecute()
    if Config.AutoExecute then
        return SafeQueueOnTeleport(AUTO_EXECUTE_SCRIPT)
    end
    return false
end

if hookmetamethod then
    local oldNamecall
    oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
        local method = getnamecallmethod()
        if self == TeleportService and (method == "Teleport" or method == "TeleportAsync" or method == "TeleportToPlaceInstance" or method == "TeleportToPartyInstance") then
            if Config.AutoExecute then
                SetupAutoExecute()
            end
            getgenv().SenzyIntentionalTeleport = true
        end
        return oldNamecall(self, ...)
    end)
end

pcall(function()
    if LocalPlayer then
        LocalPlayer.OnTeleport:Connect(function()
            if Config.AutoExecute then
                SetupAutoExecute()
            end
        end)
    end
end)

-- =========================================================================

local function ApplyLoadedConfig()
    if getgenv().AutoRollSystem then
        getgenv().AutoRollSystem.Enabled = Config.AutoSummon
    end

    if Config.AutoExecute then
        SetupAutoExecute()
    end

    pcall(function()
        if RequestPromptRefresh then RequestPromptRefresh() end
    end)

    pcall(function()
        UpdateM2ConfigUnitSelector()

        if Config.Method2_UnitList and #Config.Method2_UnitList > 0 then
            if not currentM2ConfigUnit or not Config.Method2_Units[CleanName(currentM2ConfigUnit)] then
                currentM2ConfigUnit = Config.Method2_UnitList[1]
            end
            SyncM2UnitConfigToUI(currentM2ConfigUnit)
        end
    end)

    if LocalPlayer.Character then
        task.spawn(function()
            task.wait(0.3)
            UpdateOverheadDisplay(LocalPlayer.Character)
        end)
    end
end

local function ResetConfigToDefault()
    Config.AutoSummon = false
    Config.AutoBuy = false
    Config.AutoSell = false
    Config.AutoEvo = false
    Config.SelectedEvoUnits = {}
    Config.AutoClone = false
    Config.SelectedCloneUnits = {}
    Config.CloneDelay = 5.0

    Config.AutoSpinWheel = false
    Config.AutoUpgradeGold = false
    Config.AutoUpgradeLuck = false
    Config.AutoUpgradeSlots = false
    Config.AutoUpgradeInventory = false
    Config.AutoClaimQuests = false
    Config.AutoClaimWeeklyQuests = false
    Config.AutoClaimBP = false
    Config.AutoClaimFactionQuests = false
    Config.AutoJoinTower = false
    Config.AutoLuckPotion = false
    
    Config.AutoStopWave = false
    Config.TargetWave = 30

    Config.DisplayTag = false
    Config.AntiAFK = true
    Config.RollSpeed = 1.6
    Config.EvoDelay = 3.0
    Config.WebhookURL = ""
    Config.DiscordUserID = ""
    Config.NotifyDisconnect = false
    
    Config.SelectedCharacters = {}
    Config.SelectedMutations = {}
    
    Config.Method2_Enabled = false
    Config.Method2_Units = {}
    Config.Method2_UnitList = {}
    
    Config.SellRarities = { Common = false, Rare = false, Epic = false, Legendary = false, Mythic = false, Secret = false, God = false, Limited = false }
    Config.SellCharacters = {}
    Config.SellMutations = {}

    Config.AutoExecute = false
end

local function SafeTableMerge(target, source)
    for key, value in pairs(source) do
        if key ~= "AutoSpinWheel" and key ~= "AutoClaimQuests" and key ~= "AutoClaimWeeklyQuests" and key ~= "AutoClaimBP" and key ~= "AutoClaimFactionQuests" and key ~= "AutoJoinTower" then
            if type(value) == "table" then
                if type(target[key]) ~= "table" then target[key] = {} end
                SafeTableMerge(target[key], value)
            else
                target[key] = value
            end
        end
    end
end

local function EnforceDisabledExceptions()
end

local function SyncUIFromConfig()
    isLoadingConfig = true

    for key, elem in pairs(UIElements.Toggles or {}) do
        local val = nil
        if key == "AutoSummon" then val = Config.AutoSummon
        elseif key == "AutoBuy" then val = Config.AutoBuy
        elseif key == "Method2_Enabled" then val = Config.Method2_Enabled
        elseif key == "AutoSell" then val = Config.AutoSell
        elseif key == "AutoEvo" then val = Config.AutoEvo
        elseif key == "AutoClone" then val = Config.AutoClone
        elseif key == "AutoSpinWheel" then val = Config.AutoSpinWheel
        elseif key == "AutoUpgradeGold" then val = Config.AutoUpgradeGold
        elseif key == "AutoUpgradeLuck" then val = Config.AutoUpgradeLuck
        elseif key == "AutoUpgradeSlots" then val = Config.AutoUpgradeSlots
        elseif key == "AutoUpgradeInventory" then val = Config.AutoUpgradeInventory
        elseif key == "AutoClaimQuests" then val = Config.AutoClaimQuests
        elseif key == "AutoClaimWeeklyQuests" then val = Config.AutoClaimWeeklyQuests
        elseif key == "AutoClaimBP" then val = Config.AutoClaimBP
        elseif key == "AutoClaimFactionQuests" then val = Config.AutoClaimFactionQuests
        elseif key == "AutoJoinTower" then val = Config.AutoJoinTower
        elseif key == "AutoLuckPotion" then val = Config.AutoLuckPotion
        elseif key == "AutoStopWave" then val = Config.AutoStopWave
        elseif key == "DisplayTag" then val = Config.DisplayTag
        elseif key == "AntiAFK" then val = Config.AntiAFK
        elseif key == "AutoExecute" then val = Config.AutoExecute
        elseif key == "NotifyDisconnect" then val = Config.NotifyDisconnect
        elseif key:find("^SellMut_") then
            local m = key:gsub("^SellMut_", "")
            val = Config.SellMutations[m]
        elseif key:find("^SellChar_") then
            local c = key:gsub("^SellChar_", "")
            val = Config.SellCharacters[c]
        end
        if val ~= nil then UpdateUIElement(elem, val) end
    end

    UpdateUIElement(UIElements.Textboxes["WebhookURL"], Config.WebhookURL)
    UpdateUIElement(UIElements.Textboxes["DiscordUserID"], Config.DiscordUserID)
    UpdateUIElement(UIElements.Textboxes["TargetWave"], tostring(Config.TargetWave))
    UpdateUIElement(UIElements.Textboxes["RollSpeed"], tostring(Config.RollSpeed))

    for key, dropElem in pairs(UIElements.Dropdowns or {}) do
        if key == "SellRarities" then
            local activeRarities = {}
            for rName, active in pairs(Config.SellRarities) do
                if active then table.insert(activeRarities, rName) end
            end
            UpdateUIElement(dropElem, activeRarities)
        elseif key:find("^BuyChar_") then
            local rarity = key:gsub("^BuyChar_", "")
            local chars = CharacterRarityMap[rarity] or {}
            local activeList = {}
            for _, name in ipairs(chars) do
                if Config.SelectedCharacters[CleanName(name)] == true then
                    table.insert(activeList, name)
                end
            end
            UpdateUIElement(dropElem, activeList)
        elseif key:find("^BuyMut_") then
            local rarityLower = key:gsub("^BuyMut_", "")
            local muts = Config.SelectedMutations[rarityLower] or {}
            local activeList = {}
            for _, mut in ipairs(AllMutations) do
                if muts[CleanName(mut)] == true then
                    table.insert(activeList, mut)
                end
            end
            UpdateUIElement(dropElem, activeList)
        elseif key == "SelectedEvoUnits" then
            local activeEvo = {}
            for _, evoName in ipairs(EvolutionList) do
                if Config.SelectedEvoUnits[evoName] then
                    table.insert(activeEvo, evoName)
                end
            end
            UpdateUIElement(dropElem, activeEvo)
        elseif key == "SelectedCloneUnits" then
            local activeClone = {}
            for _, unitName in ipairs(AllUnitsList) do
                if Config.SelectedCloneUnits[CleanName(unitName)] then
                    table.insert(activeClone, unitName)
                end
            end
            UpdateUIElement(dropElem, activeClone)
        end
    end

    local m2UnitListValues = {}
    for _, name in ipairs(Config.Method2_UnitList or {}) do
        table.insert(m2UnitListValues, name)
    end
    UpdateUIElement(UIElements.Dropdowns["M2_UnitSelector"], m2UnitListValues)

    UpdateM2ConfigUnitSelector()

    if currentM2ConfigUnit then
        SyncM2UnitConfigToUI(currentM2ConfigUnit)
    elseif Config.Method2_UnitList and #Config.Method2_UnitList > 0 then
        currentM2ConfigUnit = Config.Method2_UnitList[1]
        SyncM2UnitConfigToUI(currentM2ConfigUnit)
    end
end

local function SaveConfigFile(fileName)
    if not writefile then return false end
    local name = (fileName and fileName:gsub("%s+", "") ~= "") and fileName or "default"
    EnsureConfigFolder()
    local filePath = ConfigFolder .. "/" .. name .. ".json"
    
    local success = pcall(function()
        local saveTable = {}
        for k, v in pairs(Config) do
            if k ~= "AutoSpinWheel" and k ~= "AutoClaimQuests" and k ~= "AutoClaimWeeklyQuests" and k ~= "AutoClaimBP" and k ~= "AutoClaimFactionQuests" and k ~= "AutoJoinTower" then
                saveTable[k] = v
            end
        end
        local jsonString = HttpService:JSONEncode(saveTable)
        writefile(filePath, jsonString)
        SaveAutoState()
    end)
    return success
end

local function LoadConfigFile(fileName)
    if not (readfile and isfile) then return false end
    local name = (fileName and fileName:gsub("%s+", "") ~= "") and fileName or "default"
    local filePath = ConfigFolder .. "/" .. name .. ".json"
    
    if not isfile(filePath) then return false end
    
    local success = pcall(function()
        local content = readfile(filePath)
        local decoded = HttpService:JSONDecode(content)
        if type(decoded) == "table" then
            local wasLoading = isLoadingConfig
            isLoadingConfig = true
            ResetConfigToDefault()
            SafeTableMerge(Config, decoded)
            EnforceDisabledExceptions()
            SyncUIFromConfig()
            isLoadingConfig = wasLoading
            SaveAutoState()

            task.defer(function()
                ApplyLoadedConfig()
            end)
        end
    end)
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
        local fileContent = readfile(AutoSaveFilePath)
        local ok, decoded = pcall(function() return HttpService:JSONDecode(fileContent) end)
        if ok and type(decoded) == "table" then
            isLoadingConfig = true
            ResetConfigToDefault()
            SafeTableMerge(Config, decoded)
            EnforceDisabledExceptions()
            isLoadingConfig = false

            task.defer(function()
                ApplyLoadedConfig()
            end)
        end
    end
end)

local function GetHttpRequest()
    if type(request) == "function" then return request end
    if type(http_request) == "function" then return http_request end
    if syn and type(syn.request) == "function" then return syn.request end
    if http and type(http.request) == "function" then return http.request end
    if fluxus and type(fluxus.request) == "function" then return fluxus.request end
    return nil
end

local RequestFunc = GetHttpRequest()

local function GetData(path)
    if not DataService then return nil end
    local success, result = pcall(function() return DataService:get(path) end)
    return success and result or nil
end

local function GetItemEmoji(itemName)
    local lower = string.lower(itemName)
    if lower:find("trait") or lower:find("shard") then return "🔮" end
    if lower:find("gem") or lower:find("diamond") then return "💎" end
    if lower:find("cash") or lower:find("ticket") or lower:find("token") then return "🎫" end
    if lower:find("luck") and lower:find("super") then return "🍷" end
    if lower:find("luck") and lower:find("ultra") then return "🍾" end
    if lower:find("luck") or lower:find("potion") then return "🧪" end
    if lower:find("fast") or lower:find("speed") then return "⚡" end
    if lower:find("damage") or lower:find("atk") then return "⚔️" end
    if lower:find("xp") or lower:find("exp") then return "🌟" end
    if lower:find("reroll") then return "🪙" end
    if lower:find("mythic") or lower:find("god") then return "👑" end
    if lower:find("key") then return "🔑" end
    if lower:find("spin") or lower:find("wheel") then return "🎡" end
    if lower:find("coin") or lower:find("money") then return "💰" end
    if lower:find("capsule") or lower:find("box") or lower:find("gift") then return "🎁" end
    return "📦"
end

local function BuildImportantInventoryText()
    local itemsFound = {}
    local paths = { "Inventory", "Items", "Item", "Materials", "Potions", "Tickets", "Currencies" }

    for _, path in ipairs(paths) do
        local data = GetData(path)
        if type(data) == "table" then
            local successCount = 0
            for key, val in pairs(data) do
                local name = nil
                local amount = nil

                if type(val) == "number" then
                    name = tostring(key)
                    amount = val
                elseif type(val) == "table" then
                    name = val.Name or val.DisplayName or val.id or val.Id or tostring(key)
                    amount = val.Amount or val.amount or val.Count or val.count or val.Quantity or val.quantity or val.Value
                end

                if name and amount and type(amount) == "number" and amount > 0 then
                    if not itemsFound[name] then
                        itemsFound[name] = amount
                    end
                end
                successCount = successCount + 1
                if successCount > 500 then break end
            end
        end
    end

    local itemList = {}
    for name, amount in pairs(itemsFound) do
        local emoji = GetItemEmoji(name)
        table.insert(itemList, { Name = name, Amount = amount, Emoji = emoji })
    end

    if #itemList == 0 then
        return "⚠️ *No readable inventory items found.*"
    end

    table.sort(itemList, function(a, b) return a.Name < b.Name end)

    local lines = {}
    for _, item in ipairs(itemList) do
        table.insert(lines, string.format("• %s **%s** × `%s`", item.Emoji, item.Name, tostring(item.Amount)))
    end

    local text = table.concat(lines, "\n")
    if #text > 1000 then text = string.sub(text, 1, 997) .. "..." end
    return text
end

local function SendDiscordWebhook(charName, mutationName, rarity)
    if not RequestFunc then return end

    local targetURL = Config.WebhookURL
    if targetURL == "" or targetURL == "PASTE_YOUR_DISCORD_WEBHOOK_HERE" or not targetURL:find("http") then return end

    local colorCode = 0x2B2D31
    if rarity == "God" then colorCode = 0xFF0055
    elseif rarity == "Secret" then colorCode = 0xA020F0
    elseif rarity == "Limited" then colorCode = 0x00FFFF
    elseif rarity == "Mythic" then colorCode = 0xFF6600
    elseif rarity == "Legendary" then colorCode = 0xFFD700
    elseif rarity == "Epic" then colorCode = 0x9370DB
    end

    local inventoryText = BuildImportantInventoryText()

    local embedData = {
        ["title"] = "✨ AUTO BUY SUCCESSFUL!",
        ["description"] = string.format("> 🎉 **||%s||** has successfully obtained a target unit!", LocalPlayer.DisplayName),
        ["color"] = colorCode,
        ["author"] = { ["name"] = "SENZY HUB • AUTOMATION", ["icon_url"] = LOGO_URL },
        ["thumbnail"] = { ["url"] = LOGO_URL },
        ["image"] = { ["url"] = BANNER_URL },
        ["fields"] = {
            { ["name"] = "👤 Player Name", ["value"] = string.format("||%s (@%s)||", LocalPlayer.DisplayName, LocalPlayer.Name), ["inline"] = false },
            { ["name"] = "⚔️ Character", ["value"] = string.format("**` %s `**", charName or "Unknown"), ["inline"] = true },
            { ["name"] = "👑 Rarity", ["value"] = string.format("**` %s `**", rarity or "Unknown"), ["inline"] = true },
            { ["name"] = "🧬 Mutation", ["value"] = string.format("**` %s `**", mutationName or "No Mutation"), ["inline"] = true },
            { ["name"] = "🎒 CURRENT INVENTORY", ["value"] = inventoryText, ["inline"] = false }
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payloadTable = {
        ["username"] = "SENZY HUB NOTIFIER",
        ["avatar_url"] = LOGO_URL,
        ["embeds"] = { embedData }
    }

    if Config.DiscordUserID ~= "" then
        local id = string.match(Config.DiscordUserID, "%d+")
        if id then payloadTable["content"] = "<@" .. id .. ">" end
    end

    task.spawn(function()
        pcall(function()
            RequestFunc({
                Url = targetURL,
                Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = HttpService:JSONEncode(payloadTable)
            })
        end)
    end)
end

local isDisconnectWebhookSent = false
local function SendDisconnectWebhook(reason)
    if not RequestFunc or isDisconnectWebhookSent then return end
    if not Config.NotifyDisconnect then return end

    local targetURL = Config.WebhookURL
    if targetURL == "" or targetURL == "PASTE_YOUR_DISCORD_WEBHOOK_HERE" or not targetURL:find("http") then return end

    isDisconnectWebhookSent = true

    local embedData = {
        ["title"] = "🔌 GAME DISCONNECTED",
        ["color"] = 0xFF0000,
        ["author"] = { ["name"] = "SENZY HUB • MONITOR", ["icon_url"] = LOGO_URL },
        ["thumbnail"] = { ["url"] = LOGO_URL },
        ["fields"] = {
            { ["name"] = "👤 Player", ["value"] = string.format("||%s||", LocalPlayer.DisplayName), ["inline"] = true },
            { ["name"] = "📌 Reason", ["value"] = string.format("`%s`", tostring(reason or "Unknown")), ["inline"] = true },
            { ["name"] = "🕐 Time", ["value"] = string.format("`%s`", os.date("%Y-%m-%d %H:%M:%S")), ["inline"] = false }
        },
        ["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%SZ")
    }

    local payloadTable = {
        ["username"] = "SENZY HUB NOTIFIER",
        ["avatar_url"] = LOGO_URL,
        ["embeds"] = { embedData }
    }
    
    if Config.DiscordUserID ~= "" then
        local id = string.match(Config.DiscordUserID, "%d+")
        if id then payloadTable["content"] = "<@" .. id .. ">" end
    end

    pcall(function()
        RequestFunc({
            Url = targetURL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(payloadTable)
        })
    end)
end

pcall(function()
    local coreGui = CoreGui
    local errorPrompt = coreGui:FindFirstChild("RobloxPromptGui") and coreGui.RobloxPromptGui:FindFirstChild("promptOverlay")
    if errorPrompt then
        errorPrompt.DescendantAdded:Connect(function(child)
            if child.Name == "ErrorTitle" or child.Name == "ErrorMessage" then
                task.delay(0.5, function()
                    if getgenv().SenzyIntentionalTeleport then return end
                    SendDisconnectWebhook(child.Text or "Connection Lost")
                end)
            end
        end)
    end
end)

pcall(function()
    TeleportService.TeleportInitFailed:Connect(function(_, result, errorMessage)
        if getgenv().SenzyIntentionalTeleport then return end
        SendDisconnectWebhook(errorMessage or tostring(result))
    end)
end)

pcall(function()
    game:GetService("LogService").MessageOut:Connect(function(message, messageType)
        if messageType == Enum.MessageType.MessageError then
            if message:find("Disconnected") or message:find("Timeout") or message:find("Lost connection") then
                if getgenv().SenzyIntentionalTeleport then return end
                SendDisconnectWebhook(message)
            end
        end
    end)
end)

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

                    for attempt = 1, 3 do
                        pcall(function() 
                            BuyRemote:FireServer(data.rollId, tonumber(item.slotIndex)) 
                        end)
                        task.wait(0.25)

                        local currentCount = CountInventoryItems(item.charName, item.charMutation)
                        if currentCount > initialCount then
                            purchaseSuccess = true
                            break
                        end
                    end

                    if purchaseSuccess then
                        SendDiscordWebhook(item.charName, item.charMutation, item.charRarity)
                    end
                end
            end
            isBuying = false
        end)
    end
end

local function ExecuteAutoSell()
    if not Config.AutoSell or not SellRemote then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    local itemsToScan = {}

    if backpack then for _, item in ipairs(backpack:GetChildren()) do if item:IsA("Tool") then table.insert(itemsToScan, item) end end end
    if character then for _, item in ipairs(character:GetChildren()) do if item:IsA("Tool") then table.insert(itemsToScan, item) end end end

    for _, item in ipairs(itemsToScan) do
        if not item or not item.Parent then continue end
        
        local charName = GetRealToolName(item)
        if not charName or charName == "" then continue end
        
        local rarity = GetRarityOfCharacter(charName)
        if not rarity or rarity == "" or rarity == "Unknown" then continue end

        local uuid = GetToolUUID(item)
        if not uuid then continue end

        local charClean = CleanName(charName)
        local mutation = GetToolMutation(item)
        local mutClean = CleanName(mutation)

        if not (Config.AutoBuy and MatchesTargetFilter(charName, mutation)) then
            local rarityMatch = Config.SellRarities[rarity] == true
            local charMatch = Config.SellCharacters[charClean] == true
            local mutMatch = Config.SellMutations[mutClean] == true

            local hasMutFilter = false
            for _, active in pairs(Config.SellMutations) do if active then hasMutFilter = true; break end end
            local mutCheck = not hasMutFilter or mutMatch

            if (rarityMatch or charMatch) and mutCheck then
                local existsCheck = item and item.Parent and GetToolUUID(item) == uuid
                if existsCheck then
                    pcall(function() SellRemote:FireServer({ tostring(uuid) }) end)
                    task.wait(0.15)
                end
            end
        end
    end
end

local function ExecuteAutoEvo()
    if not Config.AutoEvo or not EvoRemote then return end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    local character = LocalPlayer.Character
    local itemsToEvo = {}

    local function CheckItemAndAdd(item)
        if not item or not item:IsA("Tool") then return end
        local realCharName = GetRealToolName(item)
        local charClean = CleanName(realCharName)

        local isSelected = false

        for selectedKey, active in pairs(Config.SelectedEvoUnits) do
            if active then
                local selClean = CleanName(selectedKey)
                
                if charClean == selClean or charClean:find(selClean) or selClean:find(charClean) then
                    isSelected = true
                    break
                end

                if EvolutionInfo and EvolutionInfo.Characters then
                    local evoData = EvolutionInfo.Characters[selectedKey]
                    if evoData then
                        local baseCharClean = CleanName(evoData.BaseCharacter or evoData.RequiredCharacter or evoData.Character or "")
                        if baseCharClean ~= "" and (charClean == baseCharClean or charClean:find(baseCharClean) or baseCharClean:find(charClean)) then
                            isSelected = true
                            break
                        end
                    end
                end
            end
        end

        if isSelected then
            local uuid = GetToolUUID(item)
            if uuid then
                table.insert(itemsToEvo, tostring(uuid))
            end
        end
    end

    if backpack then for _, item in ipairs(backpack:GetChildren()) do CheckItemAndAdd(item) end end
    if character then for _, item in ipairs(character:GetChildren()) do CheckItemAndAdd(item) end end

    for _, targetUUID in ipairs(itemsToEvo) do
        pcall(function()
            EvoRemote:FireServer({
                UUID = tostring(targetUUID),
                Action = "Start"
            })
        end)
        task.wait(0.4)
    end
end

local isRefreshingPrompts = false
local function RefreshPrompts()
    table.clear(cachedRollPrompts)
    for _, prompt in ipairs(workspace:GetDescendants()) do
        if prompt:IsA("ProximityPrompt") then
            if prompt.Name == "RollPrompt" then
                table.insert(cachedRollPrompts, prompt)
            end
        end
    end
    isRefreshingPrompts = false
end

RequestPromptRefresh = function()
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

local connCharAdded = LocalPlayer.CharacterAdded:Connect(function(char)
    task.wait(0.5)
    UpdateOverheadDisplay(char)
end)
table.insert(getgenv().AutoRollSystem.Connections, connCharAdded)

local Library
local uiSuccess, uiErr = pcall(function()
    Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/senzxyz2xxx/Ui/refs/heads/main/Main.lua"))()
end)

if not uiSuccess or not Library then return end

local Window = Library:Window({ Title = "Senzy Hub", Footer = "Free Script", Logo = 111116339097216 })

local TabInfo = Window:MakeTab({ Title = "Information", Icon = 115960025411300 })
TabInfo:Label({ Title = "SENZY HUB", Desc = "Anime Roll Automation System" })
TabInfo:Button({ 
    Title = "Copy Discord Link", 
    Desc = "https://discord.gg/rhPgnAJE4B",
    Callback = function() 
        if setclipboard then setclipboard("https://discord.gg/rhPgnAJE4B") end 
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

UIElements.Toggles["NotifyDisconnect"] = TabInfo:Toggle({
    Title = "Notify Game Disconnect",
    Desc = "Sends a notification to Webhook URL when disconnected unexpectedly",
    Value = Config.NotifyDisconnect,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.NotifyDisconnect = v
        SaveAutoState()
    end
})

TabInfo:Button({
    Title = "🔌 Test Disconnect Webhook",
    Desc = "Test sending Disconnect Notification to Webhook URL",
    Callback = function()
        SendDisconnectWebhook("Manual Test Disconnect")
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
    Title = "🧪 Test Webhook Payload",
    Desc = "Test sending notification with banner image and inventory to Discord",
    Callback = function()
        SendDiscordWebhook("Ainz (Test)", "Demon", "God")
    end
})

local TabMain = Window:MakeTab({ Title = "Main & Automation", Icon = 115960025411300 })

TabMain:Label({ Title = "<font color=\"#00FF7F\">1. CORE AUTOMATION</font>" })

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

UIElements.Toggles["AutoExecute"] = TabMain:Toggle({
    Title = "Auto Execute After Rejoin",
    Desc = "Automatically re-executes script after server teleport or rejoin",
    Value = Config.AutoExecute,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoExecute = v
        SaveAutoState()
        if v then
            SetupAutoExecute()
        end
    end
})

UIElements.Textboxes["RollSpeed"] = TabMain:Textbox({
    Title = "Roll Speed Delay",
    Desc = "Set roll speed delay (seconds)",
    Value = tostring(Config.RollSpeed),
    Callback = function(v)
        if isLoadingConfig then return end
        local num = tonumber(v)
        if num and num >= 0 then
            Config.RollSpeed = num
            SaveAutoState()
        end
    end
})

UIElements.Toggles["AutoJoinTower"] = TabMain:Toggle({
    Title = "Auto Join Tower",
    Desc = "Automatically joins Tower event",
    Value = Config.AutoJoinTower,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoJoinTower = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoLuckPotion"] = TabMain:Toggle({
    Title = "Auto Use Luck Potion",
    Desc = "Automatically drinks Luck Potion during Mutation Events",
    Value = Config.AutoLuckPotion,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoLuckPotion = v
        SaveAutoState()
    end
})

TabMain:Label({ Title = "<font color=\"#FF5733\">2. AUTO STOP WAVE</font>" })

UIElements.Toggles["AutoStopWave"] = TabMain:Toggle({
    Title = "Enable Auto Stop Wave",
    Desc = "Stops automatically when reaching target wave",
    Value = Config.AutoStopWave,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoStopWave = v
        if v then
            autoStopTriggered = false
        end
        SaveAutoState()
    end
})

UIElements.Textboxes["TargetWave"] = TabMain:Textbox({
    Title = "Target Wave Number",
    Desc = "Enter the wave number to stop at",
    Value = tostring(Config.TargetWave),
    Callback = function(v)
        if isLoadingConfig then return end
        local num = tonumber(v)
        if num then
            Config.TargetWave = num
            SaveAutoState()
        end
    end
})

TabMain:Label({ Title = "<font color=\"#00FFFF\">3. REWARDS</font>" })

UIElements.Toggles["AutoSpinWheel"] = TabMain:Toggle({
    Title = "Auto Spin Wheel",
    Desc = "Spins wheel automatically",
    Value = Config.AutoSpinWheel,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoSpinWheel = v
        SaveAutoState()
    end
})

TabMain:Label({ Title = "<font color=\"#FFD700\">4. AUTO UPGRADES</font>" })

UIElements.Toggles["AutoUpgradeGold"] = TabMain:Toggle({
    Title = "Auto Upgrade Gold",
    Value = Config.AutoUpgradeGold,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeGold = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoUpgradeLuck"] = TabMain:Toggle({
    Title = "Auto Upgrade Luck",
    Value = Config.AutoUpgradeLuck,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeLuck = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoUpgradeSlots"] = TabMain:Toggle({
    Title = "Auto Upgrade Slots",
    Value = Config.AutoUpgradeSlots,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeSlots = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoUpgradeInventory"] = TabMain:Toggle({
    Title = "Auto Upgrade Inventory",
    Value = Config.AutoUpgradeInventory,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoUpgradeInventory = v
        SaveAutoState()
    end
})

-- =========================================================================
-- TAB: QUESTS & BATTLEPASS (SEPARATED TAB)
-- =========================================================================
local TabQuests = Window:MakeTab({ Title = "Quests & Battlepass", Icon = 115960025411300 })

TabQuests:Label({ Title = "<font color=\"#00FFFF\">=== BATTLEPASS QUESTS ===</font>" })

UIElements.Toggles["AutoClaimQuests"] = TabQuests:Toggle({
    Title = "Auto Claim Daily Quests",
    Desc = "Automatically claims Daily quests",
    Value = Config.AutoClaimQuests,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClaimQuests = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoClaimWeeklyQuests"] = TabQuests:Toggle({
    Title = "Auto Claim Weekly Quests",
    Desc = "Automatically claims Weekly quests",
    Value = Config.AutoClaimWeeklyQuests,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClaimWeeklyQuests = v
        SaveAutoState()
    end
})

UIElements.Toggles["AutoClaimBP"] = TabQuests:Toggle({
    Title = "Auto Claim Battle Pass Rewards",
    Desc = "Automatically claims Free BP rewards",
    Value = Config.AutoClaimBP,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClaimBP = v
        SaveAutoState()
    end
})

TabQuests:Button({
    Title = "🎁 Manual Claim All Quests Now",
    Desc = "Claim all Battlepass quests instantly 1 time",
    Callback = function()
        pcall(function()
            if QuestClaimRemote and BPQuestModule then
                for _, q in ipairs(BPQuestModule.Daily or {}) do QuestClaimRemote:FireServer("Daily", q.ID) task.wait(0.1) end
                for _, q in ipairs(BPQuestModule.Weekly or {}) do QuestClaimRemote:FireServer("Weekly", q.ID) task.wait(0.1) end
            end
        end)
    end
})

-- =========================================================================
-- TAB: FACTION EVENT (SEPARATED TAB)
-- =========================================================================
local TabFaction = Window:MakeTab({ Title = "Faction Event", Icon = 115960025411300 })

TabFaction:Label({ Title = "<font color=\"#FFD700\">=== FACTION SYSTEM ===</font>" })

if FactionInfoModule and FactionInfoModule.Config then
    local cfg = FactionInfoModule.Config
    local blueTeam = cfg.Characters and cfg.Characters.Blue and cfg.Characters.Blue.TeamName or "Order"
    local redTeam = cfg.Characters and cfg.Characters.Red and cfg.Characters.Red.TeamName or "Chaos"
    
    TabFaction:Label({ Title = string.format("Season %s: %s VS %s", tostring(cfg.Season or 1), blueTeam, redTeam) })
    TabFaction:Label({ Title = "Season Reward: " .. tostring(cfg.SeasonReward or "Unknown") })
end

UIElements.Toggles["AutoClaimFactionQuests"] = TabFaction:Toggle({
    Title = "Auto Claim Faction Quests",
    Desc = "Automatically claims Faction quests and grants Points/Currency",
    Value = Config.AutoClaimFactionQuests,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClaimFactionQuests = v
        SaveAutoState()
    end
})

TabFaction:Button({
    Title = "⚔️ Manual Claim Faction Quests",
    Desc = "Claim all available Faction quests immediately",
    Callback = function()
        pcall(function()
            if FactionQuestRemote and FactionQuestModule then
                for _, q in ipairs(FactionQuestModule.Daily or {}) do
                    FactionQuestRemote:FireServer("Daily", q.ID)
                    task.wait(0.1)
                end
            end
        end)
    end
})

local TabBuyMethod1 = Window:MakeTab({ Title = "Buy: Method 1", Icon = 115960025411300 })

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

BuildRarityUI(TabBuyMethod1, { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" })

local TabBuyMethod2 = Window:MakeTab({ Title = "Buy: Method 2", Icon = 115960025411300 })

UIElements.Toggles["Method2_Enabled"] = TabBuyMethod2:Toggle({
    Title = "Enable Auto Buy Method 2",
    Desc = "Target multiple specific units with individual Rarity & Mutation filters",
    Value = Config.Method2_Enabled,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.Method2_Enabled = v
        SaveAutoState()
    end
})

TabBuyMethod2:Label({ Title = "<font color=\"#00FF7F\">1. SELECT TARGET UNITS (Multi Dropdown)</font>" })

UIElements.Dropdowns["M2_UnitSelector"] = TabBuyMethod2:Dropdown({
    Title = "Select Target Units",
    List = AllUnitsList,
    Multi = true,
    Value = Config.Method2_UnitList or {},
    Callback = function(selectedList)
        if isLoadingConfig then return end

        local newUnitList = {}
        local newUnitsConfig = {}

        if type(selectedList) == "table" then
            for _, unitName in ipairs(selectedList) do
                table.insert(newUnitList, unitName)
                local unitClean = CleanName(unitName)
                newUnitsConfig[unitClean] = Config.Method2_Units[unitClean] or { Rarities = {}, Mutations = {} }
            end
        end

        Config.Method2_UnitList = newUnitList
        Config.Method2_Units = newUnitsConfig

        UpdateM2ConfigUnitSelector()
        SaveAutoState()
    end
})

TabBuyMethod2:Label({ Title = "<font color=\"#FFD700\">2. CONFIGURE INDIVIDUAL UNIT</font>" })

UIElements.Dropdowns["M2_ConfigUnitSelector"] = TabBuyMethod2:Dropdown({
    Title = "Select Unit to Configure",
    List = {},
    Multi = false,
    Value = currentM2ConfigUnit,
    Callback = function(selected)
        if isLoadingConfig then return end
        local chosen = nil
        if type(selected) == "table" then
            chosen = selected[1]
        elseif type(selected) == "string" then
            chosen = selected
        end
        if chosen and chosen ~= "" then
            currentM2ConfigUnit = chosen
            SyncM2UnitConfigToUI(chosen)
        end
    end
})

local M2_RarityOptions = { "All Rarity", "God", "Secret", "Mythic", "Legendary", "Epic", "Rare", "Common", "Limited" }

UIElements.Dropdowns["M2_UnitRarities"] = TabBuyMethod2:Dropdown({
    Title = "Allowed Rarities for Selected Unit",
    List = M2_RarityOptions,
    Multi = true,
    Value = {},
    Callback = function(selectedList)
        if isLoadingConfig or not currentM2ConfigUnit then return end
        local unitClean = CleanName(currentM2ConfigUnit)
        if not unitClean or unitClean == "" then return end

        Config.Method2_Units[unitClean] = Config.Method2_Units[unitClean] or { Rarities = {}, Mutations = {} }
        local rarities = {}

        if type(selectedList) == "table" then
            for _, rName in ipairs(selectedList) do
                local rClean = CleanName(rName)
                if rClean == "allrarity" then
                    rarities["all"] = true
                else
                    rarities[rClean] = true
                end
            end
        end

        Config.Method2_Units[unitClean].Rarities = rarities
        SaveAutoState()
    end
})

local M2_MutOptions = { "All Mutation" }
for _, mut in ipairs(AllMutations) do
    table.insert(M2_MutOptions, mut)
end

UIElements.Dropdowns["M2_UnitMutations"] = TabBuyMethod2:Dropdown({
    Title = "Allowed Mutations for Selected Unit",
    List = M2_MutOptions,
    Multi = true,
    Value = {},
    Callback = function(selectedList)
        if isLoadingConfig or not currentM2ConfigUnit then return end
        local unitClean = CleanName(currentM2ConfigUnit)
        if not unitClean or unitClean == "" then return end

        Config.Method2_Units[unitClean] = Config.Method2_Units[unitClean] or { Rarities = {}, Mutations = {} }
        local mutations = {}

        if type(selectedList) == "table" then
            for _, mName in ipairs(selectedList) do
                local mClean = CleanName(mName)
                if mClean == "allmutation" then
                    mutations["all"] = true
                else
                    mutations[mClean] = true
                end
            end
        end

        Config.Method2_Units[unitClean].Mutations = mutations
        SaveAutoState()
    end
})

local TabInv = Window:MakeTab({ Title = "Inventory & Units", Icon = 115960025411300 })

TabInv:Label({ Title = "<font color=\"#FF4500\">=== AUTO SELL SYSTEM ===</font>" })

UIElements.Toggles["AutoSell"] = TabInv:Toggle({ 
    Title = "Master Auto Sell", 
    Desc = "Automatically sells backpack items matching parameters", 
    Value = Config.AutoSell,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AutoSell = v 
        SaveAutoState()
    end 
})

TabInv:Label({ Title = "<font color=\"#FFD700\">1. SELL BY RARITY (Multi Dropdown)</font>" })

local SellRarityList = { "Common", "Rare", "Epic", "Legendary", "Mythic", "Secret", "God", "Limited" }
local initialSellRarities = {}
for rName, active in pairs(Config.SellRarities) do
    if active then table.insert(initialSellRarities, rName) end
end

UIElements.Dropdowns["SellRarities"] = TabInv:Dropdown({
    Title = "Select Rarities to Sell",
    List = SellRarityList,
    Multi = true,
    Value = initialSellRarities,
    Callback = function(selectedList)
        if isLoadingConfig then return end
        
        local selectedSet = {}
        if type(selectedList) == "table" then
            for _, rName in ipairs(selectedList) do
                selectedSet[rName] = true
            end
        end

        for _, rName in ipairs(SellRarityList) do
            Config.SellRarities[rName] = selectedSet[rName] == true
        end

        SaveAutoState()
    end
})

TabInv:Label({ Title = "<font color=\"#00FFFF\">2. SELL BY MUTATION</font>" })
for _, mutName in ipairs(AllMutations) do
    local mutClean = CleanName(mutName)
    UIElements.Toggles["SellMut_" .. mutClean] = TabInv:Toggle({ 
        Title = "Sell Mutation: " .. mutName, 
        Value = Config.SellMutations[mutClean] == true,
        Callback = function(v) 
            if isLoadingConfig then return end
            Config.SellMutations[mutClean] = v 
            SaveAutoState()
        end 
    })
end

TabInv:Label({ Title = "<font color=\"#FF69B4\">3. SELL SPECIFIC UNITS</font>" })
for _, rarityName in ipairs({ "Common", "Rare", "Epic", "Legendary", "Mythic" }) do
    local list = CharacterRarityMap[rarityName]
    if list then
        for _, charName in ipairs(list) do
            local charClean = CleanName(charName)
            UIElements.Toggles["SellChar_" .. charClean] = TabInv:Toggle({ 
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

TabInv:Label({ Title = "<font color=\"#FFD700\">=== AUTO EVO SYSTEM ===</font>" })

UIElements.Toggles["AutoEvo"] = TabInv:Toggle({ 
    Title = "Enable Auto Evolution", 
    Desc = "Evolves selected units in backpack automatically",
    Value = Config.AutoEvo,
    Callback = function(v) 
        if isLoadingConfig then return end
        Config.AutoEvo = v 
        SaveAutoState()
    end 
})

UIElements.Dropdowns["SelectedEvoUnits"] = TabInv:Dropdown({
    Title = "Select Specific Units to Evolve",
    List = EvolutionList,
    Multi = true,
    Value = {},
    Callback = function(selectedList)
        if isLoadingConfig then return end
        Config.SelectedEvoUnits = {}
        if type(selectedList) == "table" then
            for _, evoName in ipairs(selectedList) do
                Config.SelectedEvoUnits[evoName] = true
            end
        end
        SaveAutoState()
    end
})

TabInv:Label({ Title = "<font color=\"#00FFFF\">=== AUTO CLONE SYSTEM ===</font>" })

UIElements.Toggles["AutoClone"] = TabInv:Toggle({
    Title = "Enable Auto Clone",
    Desc = "Clones eligible units in backpack automatically",
    Value = Config.AutoClone,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.AutoClone = v
        SaveAutoState()
    end
})

UIElements.Dropdowns["SelectedCloneUnits"] = TabInv:Dropdown({
    Title = "Select Specific Units to Clone (Multi Dropdown)",
    List = AllUnitsList,
    Multi = true,
    Value = {},
    Callback = function(selectedList)
        if isLoadingConfig then return end
        Config.SelectedCloneUnits = {}
        if type(selectedList) == "table" then
            for _, unitName in ipairs(selectedList) do
                Config.SelectedCloneUnits[CleanName(unitName)] = true
            end
        end
        SaveAutoState()
    end
})

TabInv:Button({
    Title = "🔍 Print Inventory Units",
    Desc = "Reads and logs all units from inventory/backpack",
    Callback = function()
        GetInventoryUnits()
    end
})

local TabPerf = Window:MakeTab({ Title = "Performance & Visuals", Icon = 115960025411300 })

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

TabPerf:Label({ Title = "<font color=\"#00FFFF\">DISPLAY TAGS</font>" })

UIElements.Toggles["DisplayTag"] = TabPerf:Toggle({
    Title = "Enable Custom Name Tag",
    Value = Config.DisplayTag,
    Callback = function(v)
        if isLoadingConfig then return end
        Config.DisplayTag = v
        if LocalPlayer.Character then UpdateOverheadDisplay(LocalPlayer.Character) end
        SaveAutoState()
    end
})

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

SyncUIFromConfig()

isLoadingConfig = false

task.defer(function()
    ApplyLoadedConfig()
end)

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
        if Config.AutoEvo then
            pcall(ExecuteAutoEvo)
        end
        task.wait(Config.EvoDelay)
    end
end)

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

-- Background loop for Battlepass Quests & Rewards
task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        pcall(function()
            if QuestClaimRemote and BPQuestModule then
                if Config.AutoClaimQuests and BPQuestModule.Daily then
                    for _, quest in ipairs(BPQuestModule.Daily) do
                        QuestClaimRemote:FireServer("Daily", quest.ID)
                        task.wait(0.1)
                    end
                end

                if Config.AutoClaimWeeklyQuests and BPQuestModule.Weekly then
                    for _, quest in ipairs(BPQuestModule.Weekly) do
                        QuestClaimRemote:FireServer("Weekly", quest.ID)
                        task.wait(0.1)
                    end
                end
            end

            if Config.AutoClaimBP and BpClaimRemote then
                for tier = 1, 30 do
                    BpClaimRemote:FireServer(tier, "Free")
                    task.wait(0.05)
                end
            end
        end)
        task.wait(15)
    end
end)

-- Background loop for Faction Quests
task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        pcall(function()
            if Config.AutoClaimFactionQuests and FactionQuestRemote and FactionQuestModule then
                if FactionQuestModule.Daily then
                    for _, quest in ipairs(FactionQuestModule.Daily) do
                        FactionQuestRemote:FireServer("Daily", quest.ID)
                        task.wait(0.1)
                    end
                end
            end
        end)
        task.wait(15)
    end
end)

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoJoinTower then
            pcall(function()
                local joinTowerRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("JoinTower")
                if joinTowerRemote then
                    if Config.AutoExecute then
                        SetupAutoExecute()
                    end
                    getgenv().SenzyIntentionalTeleport = true
                    joinTowerRemote:FireServer()
                end
            end)
        end
        task.wait(5)
    end
end)

local autoStopTriggered = false

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoStopWave then
            pcall(function()
                local waveNum = nil
                for _, descendant in ipairs(LocalPlayer.PlayerGui:GetDescendants()) do
                    if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
                        local text = descendant.Text or ""
                        local foundWave = text:match("Wave:%s*(%d+)") or text:match("Wave%s*(%d+)")
                        if foundWave then
                            waveNum = tonumber(foundWave)
                            break
                        end
                    end
                end

                if waveNum and waveNum >= Config.TargetWave then
                    if not autoStopTriggered then
                        autoStopTriggered = true
                        pcall(function()
                            local stopRemote = ReplicatedStorage.Remotes.Fight.Start
                            if stopRemote then
                                stopRemote:FireServer("Stop")
                            end
                        end)
                    end
                else
                    if waveNum and waveNum < Config.TargetWave then
                        autoStopTriggered = false
                    end
                end
            end)
        else
            autoStopTriggered = false
        end
        task.wait(1)
    end
end)

local UseItem = nil
pcall(function()
    UseItem = ReplicatedStorage:WaitForChild("Remotes", 5):WaitForChild("Items", 5):WaitForChild("Use", 5)
end)

local PotionName = "Luck Potion"

local EventMutations = {
    Demon = true,
    Destroyer = true,
    Hollow = true,
    Slayer = true,
    Cursed = true,
    Astronaut = true,
}

local lastEvent = nil

local function UseLuckPotion()
    if UseItem and Config.AutoLuckPotion then
        pcall(function()
            UseItem:FireServer(PotionName)
        end)
    end
end

local function CheckAndUsePotion(newEvent)
    if newEvent and newEvent ~= "" and newEvent ~= lastEvent and EventMutations[newEvent] then
        if Config.AutoLuckPotion then
            UseLuckPotion()
        end
    end
    lastEvent = newEvent
end

pcall(value or function()
    local initialEvent = workspace:GetAttribute("MutationEvent")
    if initialEvent and EventMutations[initialEvent] then
        lastEvent = initialEvent
        if Config.AutoLuckPotion then
            UseLuckPotion()
        end
    else
        lastEvent = initialEvent
    end
end)

local mutConn = workspace:GetAttributeChangedSignal("MutationEvent"):Connect(function()
    CheckAndUsePotion(workspace:GetAttribute("MutationEvent"))
end)
table.insert(getgenv().AutoRollSystem.Connections, mutConn)

task.spawn(function()
    while getgenv().AutoRollSystem and getgenv().AutoRollSystem.Running do
        if Config.AutoLuckPotion then
            pcall(function()
                local currentEvent = workspace:GetAttribute("MonthEvent") or workspace:GetAttribute("MutationEvent")
                if currentEvent and EventMutations[currentEvent] and currentEvent ~= lastEvent then
                    CheckAndUsePotion(currentEvent)
                elseif not currentEvent or currentEvent == "" then
                    lastEvent = nil
                end
            end)
        end
        task.wait(1.0)
    end
end)

task.spawn(function()
    pcall(function()
        local spinWheelClientGui = LocalPlayer.PlayerGui:WaitForChild("MainUI", 5)
            and LocalPlayer.PlayerGui.MainUI:WaitForChild("Frames", 5)
            and LocalPlayer.PlayerGui.MainUI.Frames:WaitForChild("SpinWheel", 5)
            and LocalPlayer.PlayerGui.MainUI.Frames.SpinWheel:WaitForChild("SpinWheelClient", 5)
        
        if spinWheelClientGui and spinWheelClientGui:IsA("LocalScript") then
            spinWheelClientGui.Disabled = true
        end
    end)
end)

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
