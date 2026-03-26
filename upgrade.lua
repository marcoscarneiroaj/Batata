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
local MAX_PURCHASES_PER_PASS = 120

local Module = {
    Running = true,
    Enabled = false,
    Delay = LOOP_DELAY,
    BuyDelay = BUY_DELAY,
    CurrentTarget = nil,
    LastStatus = "Aguardando dados",
    CycleCursor = 1,
    LastCostSource = "local",
}

local function waitIfNeeded(seconds)
    local delaySeconds = tonumber(seconds) or 0
    if delaySeconds > 0 then
        task.wait(delaySeconds)
    end
end

local function getCash()
    local data = Batata.Data
    local stats = data and data.Stats or nil

    if stats and tonumber(stats.Cash) then
        return tonumber(stats.Cash) or 0
    end

    return tonumber(data and data.Cash) or 0
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

local function getNextUpgradeTarget()
    local levels = getLevels()
    local allUpgrades = upgradeDb.List or {}
    local total = #allUpgrades

    if total == 0 then
        return nil
    end

    local startIndex = math.max(1, math.min(total, tonumber(Module.CycleCursor) or 1))

    for offset = 0, total - 1 do
        local listIndex = ((startIndex + offset - 1) % total) + 1
        local upgrade = allUpgrades[listIndex]
        local level = tonumber(levels[upgrade.Id]) or 0

        if level < upgrade.Max then
            return {
                Id = upgrade.Id,
                Level = level,
                Max = upgrade.Max,
                Cost = getUpgradeCost(upgrade.Id, level),
                RetryOnly = upgradeDb:IsRetryOnly(upgrade.Id, level),
                ListIndex = listIndex,
            }
        end
    end

    return nil
end

local function advanceCycleCursor(target)
    local total = #(upgradeDb.List or {})
    if total <= 0 then
        return
    end

    local currentIndex = tonumber(target and target.ListIndex) or tonumber(Module.CycleCursor) or 1
    Module.CycleCursor = (currentIndex % total) + 1
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
        CycleCursor = self.CycleCursor,
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
                    local target = getNextUpgradeTarget()
                    if not target then
                        if not boughtAny then
                            Module.LastStatus = "Sem upgrade disponivel"
                        else
                            Module.LastStatus = "Comprando em lote"
                        end
                        break
                    end

                    Module.CurrentTarget = target.Id
                    advanceCycleCursor(target)

                    if target.RetryOnly == true then
                        Module.LastStatus = string.format(
                            "Tentando %s %d/%d",
                            tostring(target.Id),
                            math.min(target.Max or 0, (tonumber(target.Level) or 0) + 1),
                            tonumber(target.Max) or 0
                        )
                    else
                        Module.LastStatus = "Comprando " .. tostring(target.Id)
                    end

                    pcall(function()
                        purchaseRemote:FireServer(target.Id)
                    end)

                    boughtAny = true
                    waitIfNeeded(Module.BuyDelay)
                end

                if boughtAny then
                    Module.LastStatus = "Comprando em lote"
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
