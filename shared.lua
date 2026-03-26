local ROOT = getgenv and getgenv() or _G
ROOT.Batata = ROOT.Batata or {}
_G.Batata = ROOT.Batata

local Batata = ROOT.Batata

Batata.BasePathCandidates = Batata.BasePathCandidates or {
    "",
    "batata\\",
    "Batata\\",
    "C:\\Users\\User\\AppData\\Local\\Wave\\Workspace\\Batata\\",
}

Batata.Paths = Batata.Paths or {
    Shared = "shared.lua",
    Remotes = "remotes.lua",
    Data = "data.lua",
    InventoryDB = "inventorydb.lua",
    ItemDB = "itemdb.lua",
    GeneratorDB = "generatordb.lua",
    UpgradeDB = "upgradedb.lua",
    AutoController = "autoclick.lua",
    Notifications = "notifications.lua",
    Click = "click.lua",
    Potion = "potion.lua",
    Genetics = "genetics.lua",
    Upgrade = "upgrade.lua",
    Sell = "sell.lua",
    Fusion = "fusion.lua",
    Shop = "shop.lua",
    Farm = "farm.lua",
    Dig = "dig.lua",
    Prestige = "prestige.lua",
    PrestigeUpgrade = "prestigeupgrade.lua",
    Ascension = "ascension.lua",
}

Batata.Modules = Batata.Modules or {}
Batata.Util = Batata.Util or {}
Batata.DB = Batata.DB or {}
Batata.Settings = Batata.Settings or {
    DelayProfile = "medio",
}
Batata.SourceBaseUrl = Batata.SourceBaseUrl or nil

Batata.DelayProfiles = Batata.DelayProfiles or {
    economico = {
        Label = "Economico",
        GuiRefreshInterval = 1.0,
        ClickDelay = 0.22,
        FarmLoopDelay = 0.18,
        FarmBuyDelay = 0.06,
        FarmDeletePause = 0.16,
        UpgradeLoopDelay = 0.18,
        UpgradeBuyDelay = 0.04,
        SellDelay = 1.4,
        FusionDelay = 1.5,
        ShopBuyDelay = 0.35,
        DigDelay = 0.35,
        PotionDelay = 3.0,
        PotionUseDelay = 0.4,
        GeneticsDelay = 1.6,
        NotificationDelay = 1.2,
        PrestigeUpgradeDelay = 3.0,
        PrestigeDelay = 1.5,
        AscensionDelay = 1.5,
    },
    medio = {
        Label = "Medio",
        GuiRefreshInterval = 0.5,
        ClickDelay = 0.14,
        FarmLoopDelay = 0.12,
        FarmBuyDelay = 0.035,
        FarmDeletePause = 0.14,
        UpgradeLoopDelay = 0.08,
        UpgradeBuyDelay = 0.02,
        SellDelay = 1.0,
        FusionDelay = 1.0,
        ShopBuyDelay = 0.25,
        DigDelay = 0.25,
        PotionDelay = 2.2,
        PotionUseDelay = 0.3,
        GeneticsDelay = 1.0,
        NotificationDelay = 0.8,
        PrestigeUpgradeDelay = 2.0,
        PrestigeDelay = 1.0,
        AscensionDelay = 1.0,
    },
    maximo = {
        Label = "Maximo",
        GuiRefreshInterval = 0.25,
        ClickDelay = 0.1,
        FarmLoopDelay = 0.08,
        FarmBuyDelay = 0.02,
        FarmDeletePause = 0.12,
        UpgradeLoopDelay = 0.04,
        UpgradeBuyDelay = 0.01,
        SellDelay = 1.0,
        FusionDelay = 1.0,
        ShopBuyDelay = 0.2,
        DigDelay = 0.2,
        PotionDelay = 2.0,
        PotionUseDelay = 0.25,
        GeneticsDelay = 1.0,
        NotificationDelay = 0.5,
        PrestigeUpgradeDelay = 1.2,
        PrestigeDelay = 1.0,
        AscensionDelay = 1.0,
    },
}

local DEFAULT_DELAY_PROFILE = "medio"

function Batata.Util.LoadFile(path)
    local candidates = {}
    local rawPath = tostring(path or "")

    if rawPath ~= "" then
        table.insert(candidates, rawPath)

        for _, basePath in ipairs(Batata.BasePathCandidates or {}) do
            if basePath ~= "" then
                table.insert(candidates, basePath .. rawPath)
            end
        end
    end

    local tried = {}

    for _, candidate in ipairs(candidates) do
        if tried[candidate] ~= true then
            tried[candidate] = true

            local ok, source = pcall(readfile, candidate)
            if ok and type(source) == "string" and source ~= "" then
                return loadstring(source, "@" .. candidate)()
            end
        end
    end

    local baseUrl = tostring(Batata.SourceBaseUrl or "")
    if baseUrl ~= "" then
        local normalizedBaseUrl = string.gsub(baseUrl, "\\", "/")
        if string.sub(normalizedBaseUrl, -1) ~= "/" then
            normalizedBaseUrl = normalizedBaseUrl .. "/"
        end

        local normalizedPath = string.gsub(rawPath, "\\", "/")
        local httpPath = normalizedBaseUrl .. normalizedPath
        local ok, source = pcall(function()
            return game:HttpGet(httpPath, true)
        end)

        if ok and type(source) == "string" and source ~= "" then
            return loadstring(source, "@" .. httpPath)()
        end
    end

    error("nao foi possivel carregar arquivo: " .. rawPath)
end

function Batata.Util.EnsureShared()
    return Batata
end

function Batata.Util.GetDelayProfile(profileName)
    local key = string.lower(tostring(profileName or Batata.Settings.DelayProfile or DEFAULT_DELAY_PROFILE))
    local profile = Batata.DelayProfiles[key]

    if profile == nil then
        key = DEFAULT_DELAY_PROFILE
        profile = Batata.DelayProfiles[key]
    end

    return profile, key
end

function Batata.Util.GetCurrentDelayProfile()
    return Batata.Util.GetDelayProfile(Batata.Settings.DelayProfile)
end

function Batata.Util.ApplyDelayProfileToModule(module, profile, profileName)
    if type(module) ~= "table" then
        return
    end

    local resolvedProfile, resolvedName = Batata.Util.GetDelayProfile(profileName)
    local finalProfile = type(profile) == "table" and profile or resolvedProfile
    local finalName = resolvedName

    module.DelayProfile = finalName

    if type(module.ApplyDelayProfile) == "function" then
        module:ApplyDelayProfile(finalProfile, finalName)
    end
end

function Batata.Util.ApplyCurrentDelayProfileToModule(module)
    local profile, profileName = Batata.Util.GetCurrentDelayProfile()
    Batata.Util.ApplyDelayProfileToModule(module, profile, profileName)
    return module
end

function Batata.Util.SetDelayProfile(profileName)
    local profile, resolvedName = Batata.Util.GetDelayProfile(profileName)
    Batata.Settings.DelayProfile = resolvedName

    for _, module in pairs(Batata.Modules) do
        Batata.Util.ApplyDelayProfileToModule(module, profile, resolvedName)
    end

    return profile, resolvedName
end

function Batata.Util.EnsureRemotes()
    if Batata.Remotes and Batata.Remotes._initialized == true then
        return Batata.Remotes
    end

    return Batata.Util.LoadFile(Batata.Paths.Remotes)
end

function Batata.Util.EnsureInventoryDb()
    if Batata.DB.Inventory then
        return Batata.DB.Inventory
    end

    return Batata.Util.LoadFile(Batata.Paths.InventoryDB)
end

function Batata.Util.EnsureItemDb()
    if Batata.DB.ItemDB then
        return Batata.DB.ItemDB
    end

    return Batata.Util.LoadFile(Batata.Paths.ItemDB)
end

function Batata.Util.EnsureGeneratorDb()
    if Batata.DB.GeneratorDB then
        return Batata.DB.GeneratorDB
    end

    return Batata.Util.LoadFile(Batata.Paths.GeneratorDB)
end

function Batata.Util.EnsureUpgradeDb()
    if Batata.DB.UpgradeDB then
        return Batata.DB.UpgradeDB
    end

    return Batata.Util.LoadFile(Batata.Paths.UpgradeDB)
end

function Batata.Util.EnsureData()
    if Batata.DataConnection and Batata.DataConnection.Connected then
        return Batata.Data
    end

    return Batata.Util.LoadFile(Batata.Paths.Data)
end

function Batata.Util.PauseAutomationModules(excludedKeys)
    local snapshot = {}
    local excluded = excludedKeys or {}

    for moduleName, module in pairs(Batata.Modules) do
        if excluded[moduleName] ~= true and type(module) == "table" then
            local enabled = module.Enabled

            if enabled == true and type(module.SetEnabled) == "function" then
                snapshot[moduleName] = true
                module:SetEnabled(false)
            end
        end
    end

    return snapshot
end

function Batata.Util.ResumeAutomationModules(snapshot)
    if type(snapshot) ~= "table" then
        return
    end

    for moduleName, wasEnabled in pairs(snapshot) do
        local module = Batata.Modules[moduleName]
        if wasEnabled == true and type(module) == "table" and type(module.SetEnabled) == "function" then
            module:SetEnabled(true)
        end
    end
end

return Batata
