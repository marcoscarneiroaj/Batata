local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoUpgrade then
    return Batata.Modules.AutoUpgrade
end

local remotes = Batata.Util.EnsureRemotes()
local upgradeDb = Batata.Util.EnsureUpgradeDb()

local BUY_DELAY = 0
local LOOP_DELAY = 0
local MAX_PURCHASES_PER_PASS = 1
local PURCHASES_BEFORE_YIELD = 1
local RETRY_BLOCK_SECONDS = 0.2

local Module = {
    Running = true,
    Enabled = false,
    Delay = LOOP_DELAY,
    BuyDelay = BUY_DELAY,
    CurrentTarget = nil,
    LastAttemptedTarget = nil,
    LastStatus = "Aguardando dados",
    CycleCursor = 1,
    LastCostSource = "local",
    IgnoredUpgrades = {},
    IgnoredReasons = {},
    LastPrestigeCount = nil,
    RetryBlockedUntil = {},
    LastSeenLevels = {},
}

local purchasesSinceYield = 0
local errorConnection

local function waitIfNeeded(seconds)
    local delaySeconds = tonumber(seconds) or 0
    if delaySeconds > 0 then
        purchasesSinceYield = 0
        task.wait(delaySeconds)
        return
    end

    purchasesSinceYield = purchasesSinceYield + 1
    if purchasesSinceYield >= PURCHASES_BEFORE_YIELD then
        purchasesSinceYield = 0
        task.wait()
    end
end

local function getNow()
    if Batata.Util and type(Batata.Util.GetRuntimeSeconds) == "function" then
        return tonumber(Batata.Util.GetRuntimeSeconds()) or os.clock()
    end

    return os.clock()
end

local function getCash()
    local data = Batata.Data
    local stats = data and data.Stats or nil

    if stats and tonumber(stats.Cash) then
        return tonumber(stats.Cash) or 0
    end

    return tonumber(data and data.Cash) or 0
end

local function getPrestigeCount()
    local data = Batata.Data
    local stats = data and data.Stats or nil

    if stats and tonumber(stats.TimesPrestiged) then
        return tonumber(stats.TimesPrestiged) or 0
    end

    return tonumber(data and data.TimesPrestiged) or 0
end

local function clearIgnoredUpgrades(reason)
    if next(Module.IgnoredUpgrades) == nil and next(Module.IgnoredReasons) == nil then
        Module.RetryBlockedUntil = {}
        Module.LastSeenLevels = {}
        if type(reason) == "string" and reason ~= "" then
            Module.LastStatus = reason
        end
        return
    end

    Module.IgnoredUpgrades = {}
    Module.IgnoredReasons = {}
    Module.RetryBlockedUntil = {}
    Module.LastSeenLevels = {}

    if type(reason) == "string" and reason ~= "" then
        Module.LastStatus = reason
    end
end

local function syncPrestigeReset()
    local prestigeCount = getPrestigeCount()

    if Module.LastPrestigeCount == nil then
        Module.LastPrestigeCount = prestigeCount
        return
    end

    if prestigeCount ~= Module.LastPrestigeCount then
        Module.LastPrestigeCount = prestigeCount
        clearIgnoredUpgrades("Prestigio detectado, ciclo de upgrades reiniciado")
    end
end

local function getLevels()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    if type(data.ClickUpgrades) == "table" then
        return data.ClickUpgrades
    end

    return {}
end

local function getUpgradeCost(upgradeId, level)
    local localCost = upgradeDb:GetCurrentCost(upgradeId, level)
    if tonumber(localCost) ~= nil and localCost < math.huge then
        Module.LastCostSource = "local"
        return tonumber(localCost)
    end

    local remoteCost = nil
    if type(upgradeDb.GetRemoteCost) == "function" then
        remoteCost = upgradeDb:GetRemoteCost(upgradeId, level)
    end

    if tonumber(remoteCost) ~= nil then
        Module.LastCostSource = "server"
        return tonumber(remoteCost)
    end

    Module.LastCostSource = "unknown"
    return math.huge
end

local function getNextUpgradeTarget()
    local now = getNow()
    local cash = getCash()
    local levels = getLevels()
    local allUpgrades = upgradeDb.KnownList or upgradeDb.List or {}
    local bestTarget = nil

    if #allUpgrades == 0 then
        return nil
    end

    for _, upgrade in ipairs(allUpgrades) do
        if Module.IgnoredUpgrades[upgrade.Id] ~= true then
            local level = tonumber(levels[upgrade.Id]) or 0
            local previousLevel = Module.LastSeenLevels[upgrade.Id]
            if previousLevel == nil or previousLevel ~= level then
                Module.LastSeenLevels[upgrade.Id] = level
                Module.RetryBlockedUntil[upgrade.Id] = nil
            end

            if level < upgrade.Max and (tonumber(Module.RetryBlockedUntil[upgrade.Id]) or 0) <= now then
                local cost = getUpgradeCost(upgrade.Id, level)

                if tonumber(cost) ~= nil and cost <= cash then
                    local candidate = {
                        Id = upgrade.Id,
                        Level = level,
                        Max = upgrade.Max,
                        Cost = tonumber(cost),
                        Gain = tonumber(upgrade.Gain) or 0,
                        ListIndex = tonumber(upgrade.Index) or 0,
                    }

                    if not bestTarget
                        or candidate.Cost > bestTarget.Cost
                        or (candidate.Cost == bestTarget.Cost and candidate.Gain > bestTarget.Gain)
                    then
                        bestTarget = candidate
                    end
                end
            end
        end
    end

    return bestTarget
end

local function onUpgradeError(message)
    local errorText = tostring(message or "")
    local attemptedId = Module.LastAttemptedTarget

    if attemptedId == nil or attemptedId == "" then
        Module.LastStatus = errorText ~= "" and errorText or "Erro de upgrade"
        return
    end

    if errorText == "Max level reached" then
        Module.IgnoredUpgrades[attemptedId] = true
        Module.IgnoredReasons[attemptedId] = errorText
        if Module.CurrentTarget == attemptedId then
            Module.CurrentTarget = nil
        end
        Module.LastStatus = "Ignorando maximo: " .. tostring(attemptedId)
        return
    end

    if errorText == "Invalid upgrade" then
        Module.IgnoredUpgrades[attemptedId] = true
        Module.IgnoredReasons[attemptedId] = errorText
        if Module.CurrentTarget == attemptedId then
            Module.CurrentTarget = nil
        end
        Module.LastStatus = "Ignorando invalido: " .. tostring(attemptedId)
        return
    end

    if errorText == "Not enough cash" then
        Module.RetryBlockedUntil[attemptedId] = getNow() + RETRY_BLOCK_SECONDS
        Module.LastStatus = "Sem cash para " .. tostring(attemptedId)
        return
    end

    Module.LastStatus = errorText ~= "" and errorText or "Erro de upgrade"
end

local errorRemote = remotes:Get("Error")
if errorRemote and errorRemote.OnClientEvent then
    errorConnection = errorRemote.OnClientEvent:Connect(onUpgradeError)
end

local function advanceCycleCursor(target)
    local total = #(upgradeDb.KnownList or upgradeDb.List or {})
    if total <= 0 then
        return
    end

    local currentIndex = tonumber(target and target.ListIndex) or tonumber(Module.CycleCursor) or 1
    Module.CycleCursor = (currentIndex % total) + 1
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    syncPrestigeReset()
    self.LastStatus = self.Enabled and "Rodando" or "Desligado"
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0 then
        self.Delay = numberValue
    end
end

function Module:SetBuyDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0 then
        self.BuyDelay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.UpgradeLoopDelay)
    self:SetBuyDelay(profile.UpgradeBuyDelay)
end

function Module:GetState()
    local ignoredCount = 0
    for _ in pairs(self.IgnoredUpgrades or {}) do
        ignoredCount = ignoredCount + 1
    end

    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        BuyDelay = self.BuyDelay,
        CurrentTarget = self.CurrentTarget,
        LastAttemptedTarget = self.LastAttemptedTarget,
        LastStatus = self.LastStatus,
        Cash = getCash(),
        CycleCursor = self.CycleCursor,
        CostSource = self.LastCostSource,
        IgnoredCount = ignoredCount,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.CurrentTarget = nil
    self.LastAttemptedTarget = nil
    self.LastStatus = "Desligado"

    if errorConnection and errorConnection.Disconnect then
        errorConnection:Disconnect()
        errorConnection = nil
    end

    if Batata.Modules.AutoUpgrade == self then
        Batata.Modules.AutoUpgrade = nil
    end
end

task.spawn(function()
    while Module.Running do
        local boughtAnyThisPass = false
        syncPrestigeReset()

        if Module.Enabled then
            local purchaseRemote = remotes:Get("PurchaseClickUpgrade")
            if not purchaseRemote then
                Module.LastStatus = "Remote ausente"
            else
                local boughtAny = false

                for _ = 1, MAX_PURCHASES_PER_PASS do
                    local target = getNextUpgradeTarget()
                    if not target then
                        Module.CurrentTarget = nil
                        Module.LastAttemptedTarget = nil
                        if not boughtAny then
                            Module.LastStatus = "Sem upgrade compravel"
                        else
                            Module.LastStatus = "Comprando em lote"
                        end
                        break
                    end

                    Module.CurrentTarget = target.Id
                    Module.LastAttemptedTarget = target.Id
                    advanceCycleCursor(target)
                    Module.LastStatus = string.format(
                        "Comprando melhor %s %d/%d",
                        tostring(target.Id),
                        math.min(target.Max or 0, (tonumber(target.Level) or 0) + 1),
                        tonumber(target.Max) or 0
                    )
                    Module.RetryBlockedUntil[target.Id] = getNow() + RETRY_BLOCK_SECONDS

                    pcall(function()
                        purchaseRemote:FireServer(target.Id)
                    end)

                    boughtAny = true
                    boughtAnyThisPass = true
                    waitIfNeeded(Module.BuyDelay)
                end

                if boughtAny then
                    Module.LastStatus = "Comprando em lote"
                end
            end
        end

        if Module.Delay > 0 then
            task.wait(Module.Delay)
        elseif boughtAnyThisPass then
            purchasesSinceYield = 0
            task.wait()
        else
            task.wait()
        end
    end
end)

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoUpgrade = Module

return Module
