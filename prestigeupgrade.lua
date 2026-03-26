local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoPrestigeUpgrade then
    return Batata.Modules.AutoPrestigeUpgrade
end

local remotes = Batata.Util.EnsureRemotes()

local DEFAULT_DELAY = 2
local TARGET_LEVEL = 10
local RETRY_DELAY = 4
local TARGET_UPGRADES = {
    "critical_harvest",
    "golden_generators",
    "collectors_luck",
    "bulk_discounts",
    "double_harvest",
    "prestige_mastery",
    "generator_percent_bonus",
    "click_percent_bonus",
}

local Module = {
    Running = true,
    Enabled = false,
    Delay = DEFAULT_DELAY,
    CycleActive = false,
    ObservedTimesAscended = nil,
    LastStatus = "Aguardando dados",
    LastUpgradeId = nil,
    LastUpgradeLevel = nil,
    LastAttemptAt = 0,
}

local function getNow()
    return os.clock()
end

local function getStats()
    local data = Batata.Data
    if type(data) ~= "table" then
        return nil
    end

    return data.Stats
end

local function getCurrentPrestigePoints()
    local stats = getStats()
    if type(stats) ~= "table" then
        return 0
    end

    return tonumber(stats.PrestigePoints) or 0
end

local function getTimesAscended()
    local stats = getStats()
    if type(stats) ~= "table" then
        return nil
    end

    return tonumber(stats.TimesAscended)
end

local function getPrestigeUpgrades()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    if type(data.PrestigeUpgrades) == "table" then
        return data.PrestigeUpgrades
    end

    local stats = data.Stats
    if type(stats) == "table" and type(stats.PrestigeUpgrades) == "table" then
        return stats.PrestigeUpgrades
    end

    return {}
end

local function getUpgradeLevel(upgradeId)
    local upgrades = getPrestigeUpgrades()
    return tonumber(upgrades[upgradeId]) or 0
end

local function getPrestigeUpgradeCost(upgradeId)
    if not Batata.Util or type(Batata.Util.TryGetRemoteNumber) ~= "function" then
        return nil
    end

    local keys = { "Cost", "CurrentCost", "Price", "Value" }
    local response = Batata.Util.TryGetRemoteNumber("GetPrestigeUpgradeCost", keys, upgradeId)
    if response ~= nil then
        Module.LastCostSource = "server"
        return response
    end

    Module.LastCostSource = "unknown"
    return nil
end

local function countCompletedTargets()
    local completed = 0

    for _, upgradeId in ipairs(TARGET_UPGRADES) do
        if getUpgradeLevel(upgradeId) >= TARGET_LEVEL then
            completed = completed + 1
        end
    end

    return completed
end

local function findNextTarget()
    for _, upgradeId in ipairs(TARGET_UPGRADES) do
        local level = getUpgradeLevel(upgradeId)
        if level < TARGET_LEVEL then
            return upgradeId, level
        end
    end

    return nil, nil
end

local function refreshAscensionWatch()
    local currentTimesAscended = getTimesAscended()
    if currentTimesAscended == nil then
        Module.LastStatus = "Aguardando dados"
        return
    end

    if Module.ObservedTimesAscended == nil then
        Module.ObservedTimesAscended = currentTimesAscended
        if Module.CycleActive ~= true then
            Module.LastStatus = "Aguardando ascensao"
        end
        return
    end

    if currentTimesAscended > Module.ObservedTimesAscended then
        Module.ObservedTimesAscended = currentTimesAscended
        Module.CycleActive = true
        Module.LastUpgradeId = nil
        Module.LastUpgradeLevel = nil
        Module.LastAttemptAt = 0
        Module.LastStatus = "Ascensao detectada"
    elseif currentTimesAscended < Module.ObservedTimesAscended then
        Module.ObservedTimesAscended = currentTimesAscended
    end
end

local function canRetryTarget(upgradeId, currentLevel)
    if Module.LastUpgradeId ~= upgradeId then
        return true
    end

    if tonumber(currentLevel) > tonumber(Module.LastUpgradeLevel) then
        return true
    end

    return (getNow() - Module.LastAttemptAt) >= RETRY_DELAY
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true

    if self.Enabled then
        self.ObservedTimesAscended = nil
        self.CycleActive = false
        self.LastUpgradeId = nil
        self.LastUpgradeLevel = nil
        self.LastAttemptAt = 0
        self.LastStatus = "Aguardando dados"
    else
        self.CycleActive = false
        self.LastStatus = "Desligado"
    end
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.2 then
        self.Delay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.PrestigeUpgradeDelay)
end

function Module:GetState()
    local nextUpgradeId, nextUpgradeLevel = findNextTarget()
    local nextUpgradeCost = nextUpgradeId and getPrestigeUpgradeCost(nextUpgradeId) or nil

    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        CycleActive = self.CycleActive == true,
        CurrentPrestigePoints = getCurrentPrestigePoints(),
        ObservedTimesAscended = self.ObservedTimesAscended,
        CompletedTargets = countCompletedTargets(),
        TotalTargets = #TARGET_UPGRADES,
        NextUpgradeId = nextUpgradeId,
        NextUpgradeLevel = nextUpgradeLevel,
        NextUpgradeCost = nextUpgradeCost,
        LastUpgradeId = self.LastUpgradeId,
        LastStatus = self.LastStatus,
        CostSource = self.LastCostSource,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.CycleActive = false
    self.LastStatus = "Desligado"

    if Batata.Modules.AutoPrestigeUpgrade == self then
        Batata.Modules.AutoPrestigeUpgrade = nil
    end
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            refreshAscensionWatch()

            if Module.CycleActive then
                local purchaseRemote = remotes:Get("PurchasePrestigeUpgrade")
                local nextUpgradeId, currentLevel = findNextTarget()

                if not purchaseRemote then
                    Module.LastStatus = "Remote ausente"
                elseif not nextUpgradeId then
                    Module.CycleActive = false
                    Module.LastStatus = "Alvos concluidos"
                elseif getCurrentPrestigePoints() <= 0 then
                    Module.LastStatus = "Aguardando PP"
                elseif not canRetryTarget(nextUpgradeId, currentLevel) then
                    Module.LastStatus = "Esperando liberar " .. tostring(nextUpgradeId)
                else
                    local currentPP = getCurrentPrestigePoints()
                    local nextUpgradeCost = getPrestigeUpgradeCost(nextUpgradeId)

                    if tonumber(nextUpgradeCost) ~= nil and currentPP < tonumber(nextUpgradeCost) then
                        Module.LastStatus = "Aguardando PP"
                    else
                        Module.LastUpgradeId = nextUpgradeId
                        Module.LastUpgradeLevel = currentLevel
                        Module.LastAttemptAt = getNow()
                        Module.LastStatus = string.format(
                            "Tentando %s %d/%d",
                            tostring(nextUpgradeId),
                            math.min(TARGET_LEVEL, (tonumber(currentLevel) or 0) + 1),
                            TARGET_LEVEL
                        )

                        pcall(function()
                            purchaseRemote:FireServer(nextUpgradeId)
                        end)
                    end
                end
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoPrestigeUpgrade = Module

return Module
