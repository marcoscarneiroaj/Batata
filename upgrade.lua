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

local BUY_DELAY = 0.01
local LOOP_DELAY = 0.01
local RETRY_ONLY_PROBE_DELAY = 0.05
local MAX_PURCHASES_PER_PASS = 60
local OPTIMISTIC_LEVEL_TIMEOUT = 1.25

local Module = {
    Running = true,
    Enabled = false,
    Delay = LOOP_DELAY,
    BuyDelay = BUY_DELAY,
    CurrentTarget = nil,
    LastStatus = "Aguardando dados",
    PriorityProbeCursor = 1,
    LastPriorityProbeAt = 0,
    RetryCursor = 1,
    LastRetryProbeAt = 0,
    OptimisticLevels = {},
    OptimisticTouchedAt = {},
}

local function getCash()
    local data = Batata.Data
    local stats = data and data.Stats or nil

    if stats and tonumber(stats.Cash) then
        return tonumber(stats.Cash) or 0
    end

    return tonumber(data and data.Cash) or 0
end

local function waitIfNeeded(seconds)
    local delaySeconds = tonumber(seconds) or 0
    if delaySeconds > 0 then
        task.wait(delaySeconds)
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

local function getEffectiveLevel(levels, upgradeId)
    local serverLevel = tonumber(levels[upgradeId]) or 0
    local predictedLevel = tonumber(Module.OptimisticLevels[upgradeId]) or nil
    local touchedAt = tonumber(Module.OptimisticTouchedAt[upgradeId]) or 0

    if predictedLevel ~= nil then
        if predictedLevel <= serverLevel or (os.clock() - touchedAt) >= OPTIMISTIC_LEVEL_TIMEOUT then
            Module.OptimisticLevels[upgradeId] = nil
            Module.OptimisticTouchedAt[upgradeId] = nil
            predictedLevel = nil
        end
    end

    if predictedLevel ~= nil and predictedLevel > serverLevel then
        return predictedLevel
    end

    return serverLevel
end

local function markOptimisticPurchase(upgradeId, currentLevel, maxLevel)
    local nextLevel = math.max(0, math.floor(tonumber(currentLevel) or 0)) + 1
    local maxAllowed = tonumber(maxLevel)

    if maxAllowed ~= nil then
        nextLevel = math.min(nextLevel, maxAllowed)
    end

    Module.OptimisticLevels[upgradeId] = nextLevel
    Module.OptimisticTouchedAt[upgradeId] = os.clock()
end

local function getUpgradeCost(upgradeId, level)
    local remoteCost = nil
    if type(upgradeDb.GetRemoteCost) == "function" then
        remoteCost = upgradeDb:GetRemoteCost(upgradeId, level)
    end

    if tonumber(remoteCost) ~= nil then
        Module.LastCostSource = "server"
        return tonumber(remoteCost)
    end

    Module.LastCostSource = "local"
    return upgradeDb:GetCurrentCost(upgradeId, level)
end

local function getBestAvailableUpgrade(cash)
    local levels = getLevels()

    for _, upgrade in ipairs(upgradeDb.KnownList or upgradeDb.List) do
        local level = getEffectiveLevel(levels, upgrade.Id)
        if level < upgrade.Max and upgradeDb:IsRetryOnly(upgrade.Id, level) ~= true then
            local cost = getUpgradeCost(upgrade.Id, level)
            if cash >= cost then
                return {
                    Id = upgrade.Id,
                    Cost = cost,
                    Level = level,
                    Max = upgrade.Max,
                    Index = upgrade.Index,
                }
            end
        end
    end

    return nil
end

local function getPriorityProbeTarget(cash)
    local levels = getLevels()
    local allUpgrades = upgradeDb.List or {}
    local total = #allUpgrades

    if total == 0 then
        return nil
    end

    local startIndex = math.max(1, math.min(total, tonumber(Module.PriorityProbeCursor) or 1))

    for offset = 0, total - 1 do
        local listIndex = ((startIndex + offset - 1) % total) + 1
        local upgrade = allUpgrades[listIndex]
        local level = getEffectiveLevel(levels, upgrade.Id)
        if upgrade.PriorityProbe == true and level < upgrade.Max and upgradeDb:IsRetryOnly(upgrade.Id, level) == true then
            local cost = getUpgradeCost(upgrade.Id, level)
            if tonumber(cost) == nil or cash >= tonumber(cost) then
                return {
                    Id = upgrade.Id,
                    Level = level,
                    Max = upgrade.Max,
                    Cost = cost,
                    PriorityProbe = true,
                    PriorityListIndex = listIndex,
                    Index = upgrade.Index,
                }
            end
        end
    end

    return nil
end

local function getRetryOnlyTarget(cash)
    local levels = getLevels()
    local allUpgrades = upgradeDb.List or {}
    local total = #allUpgrades

    if total == 0 then
        return nil
    end

    local startIndex = math.max(1, math.min(total, tonumber(Module.RetryCursor) or 1))

    for offset = 0, total - 1 do
        local listIndex = ((startIndex + offset - 1) % total) + 1
        local upgrade = allUpgrades[listIndex]
        local level = getEffectiveLevel(levels, upgrade.Id)
        if level < upgrade.Max and upgrade.PriorityProbe ~= true and upgradeDb:IsRetryOnly(upgrade.Id, level) then
            local cost = getUpgradeCost(upgrade.Id, level)
            if tonumber(cost) == nil or cash >= tonumber(cost) then
                return {
                    Id = upgrade.Id,
                    Level = level,
                    Max = upgrade.Max,
                    Cost = cost,
                    RetryOnly = true,
                    RetryListIndex = listIndex,
                    Index = upgrade.Index,
                }
            end
        end
    end

    return nil
end

local function canProbePriority()
    return (os.clock() - Module.LastPriorityProbeAt) >= RETRY_ONLY_PROBE_DELAY
end

local function canProbeRetryOnly()
    return (os.clock() - Module.LastRetryProbeAt) >= RETRY_ONLY_PROBE_DELAY
end

local function markPriorityProbe(target)
    local allUpgrades = upgradeDb.List or {}
    local total = #allUpgrades

    Module.LastPriorityProbeAt = os.clock()

    if total > 0 then
        local currentIndex = tonumber(target and target.PriorityListIndex) or tonumber(Module.PriorityProbeCursor) or 1
        Module.PriorityProbeCursor = (currentIndex % total) + 1
    end
end

local function markRetryOnlyProbe(target)
    local allUpgrades = upgradeDb.List or {}
    local total = #allUpgrades

    Module.LastRetryProbeAt = os.clock()

    if total > 0 then
        local currentIndex = tonumber(target and target.RetryListIndex) or tonumber(Module.RetryCursor) or 1
        Module.RetryCursor = (currentIndex % total) + 1
    end
end

local function getFallbackTarget()
    if not Module.CurrentTarget then
        return nil
    end

    local levels = getLevels()
    local info = upgradeDb:Get(Module.CurrentTarget)
    local level = getEffectiveLevel(levels, Module.CurrentTarget)

    if not info or upgradeDb:IsRetryOnly(Module.CurrentTarget, level) then
        return nil
    end

    if level >= info.Max then
        return nil
    end

    return {
        Id = Module.CurrentTarget,
        Cost = getUpgradeCost(Module.CurrentTarget, level),
        Level = level,
        Max = info.Max,
        Index = info.Index,
    }
end

local function getCurrentTarget(cashBudget)
    local cash = tonumber(cashBudget)
    if cash == nil then
        cash = getCash()
    end

    local best = getBestAvailableUpgrade(cash)

    if best then
        Module.CurrentTarget = best.Id
        return best
    end

    local priorityProbe = getPriorityProbeTarget(cash)
    local retryOnly = getRetryOnlyTarget(cash)

    if priorityProbe and canProbePriority() then
        Module.CurrentTarget = priorityProbe.Id
        return priorityProbe
    end

    if retryOnly and canProbeRetryOnly() then
        Module.CurrentTarget = retryOnly.Id
        return retryOnly
    end

    return getFallbackTarget()
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
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
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        BuyDelay = self.BuyDelay,
        CurrentTarget = self.CurrentTarget,
        LastStatus = self.LastStatus,
        Cash = getCash(),
        OptimisticLevels = self.OptimisticLevels,
        PriorityProbeTarget = getPriorityProbeTarget(getCash()),
        RetryOnlyTarget = getRetryOnlyTarget(getCash()),
        CostSource = self.LastCostSource,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"

    if Batata.Modules.AutoUpgrade == self then
        Batata.Modules.AutoUpgrade = nil
    end
end

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            local purchaseRemote = remotes:Get("PurchaseClickUpgrade")
            if not purchaseRemote then
                Module.LastStatus = "Remote ausente"
            else
                local boughtAny = false

                for _ = 1, MAX_PURCHASES_PER_PASS do
                    local target = getCurrentTarget(getCash())
                    if not target then
                        if not boughtAny then
                            if getRetryOnlyTarget(getCash()) then
                                Module.LastStatus = "Aguardando probe"
                            else
                                Module.LastStatus = "Sem upgrade disponivel"
                            end
                        end
                        break
                    end

                    if target.PriorityProbe == true or target.RetryOnly == true then
                        local cash = getCash()
                        if tonumber(target.Cost) ~= nil and cash < tonumber(target.Cost) then
                            if not boughtAny then
                                Module.LastStatus = "Aguardando cash"
                            end
                            break
                        end

                        Module.CurrentTarget = target.Id
                        if target.PriorityProbe == true then
                            markPriorityProbe(target)
                        else
                            markRetryOnlyProbe(target)
                        end
                        Module.LastStatus = string.format(
                            "Tentando %s %d/%d",
                            tostring(target.Id),
                            math.min(target.Max or 0, (tonumber(target.Level) or 0) + 1),
                            tonumber(target.Max) or 0
                        )
                        pcall(function()
                            purchaseRemote:FireServer(target.Id)
                        end)
                        boughtAny = true
                        markOptimisticPurchase(target.Id, target.Level, target.Max)
                        waitIfNeeded(Module.BuyDelay)
                        break
                    end

                    local cash = getCash()
                    if cash < target.Cost then
                        if not boughtAny then
                            Module.LastStatus = "Aguardando cash"
                        end
                        break
                    end

                    Module.CurrentTarget = target.Id
                    Module.LastStatus = "Comprando " .. tostring(target.Id)
                    pcall(function()
                        purchaseRemote:FireServer(target.Id)
                    end)
                    boughtAny = true
                    markOptimisticPurchase(target.Id, target.Level, target.Max)
                    waitIfNeeded(Module.BuyDelay)
                end
            end
        end

        if Module.Delay > 0 then
            task.wait(Module.Delay)
        else
            task.wait()
        end
    end
end)

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoUpgrade = Module

return Module
