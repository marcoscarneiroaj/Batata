local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoPrestige then
    return Batata.Modules.AutoPrestige
end

local prestigeRemote = Batata.Util.EnsureRemotes().PerformPrestige
local equipPotatoRemote = Batata.Util.EnsureRemotes():Get("EquipPotato")

local CHECK_DELAY = 1
local MIN_INTERVAL = 30
local DEFAULT_TARGET = 0
local PRESTIGE_POTATO = "solar_flare_potato"
local DEFAULT_POTATO = "the_first_potato"
local EQUIP_DELAY = 0.2

local Module = {
    Running = true,
    Enabled = false,
    Delay = CHECK_DELAY,
    LastPrestigeAt = 0,
    LastPrestigeClock = "--:--:--",
    TargetValue = DEFAULT_TARGET,
    SessionPrestiges = 0,
    SessionPrestigePoints = 0,
    StartTimesPrestiged = nil,
    StartTotalPrestigePointsEarned = nil,
}

local function getNow()
    return os.clock()
end

local function getClock()
    return os.date("%H:%M:%S")
end

local function getStats()
    local data = Batata.Data
    if type(data) ~= "table" then
        return nil
    end

    return data.Stats
end

local function getTargetValue()
    local target = tonumber(Module.TargetValue)
    if not target or target < 0 then
        return DEFAULT_TARGET
    end

    return target
end

local function getPotentialPrestigePoints()
    local stats = getStats()
    if type(stats) ~= "table" then
        return 0
    end

    return tonumber(stats.PotentialPrestigePoints) or 0
end

local function getSessionTotals()
    local stats = getStats()
    if type(stats) ~= "table" then
        return 0, 0
    end

    local timesPrestiged = tonumber(stats.TimesPrestiged) or 0
    local totalPPEarned = tonumber(stats.TotalPrestigePointsEarned) or 0

    if Module.StartTimesPrestiged == nil then
        Module.StartTimesPrestiged = timesPrestiged
    end

    if Module.StartTotalPrestigePointsEarned == nil then
        Module.StartTotalPrestigePointsEarned = totalPPEarned
    end

    local prestigeCount = math.max(0, timesPrestiged - Module.StartTimesPrestiged)
    local ppTotal = math.max(0, totalPPEarned - Module.StartTotalPrestigePointsEarned)

    return prestigeCount, ppTotal
end

local function canPrestigeNow()
    local targetValue = getTargetValue()
    if targetValue <= 0 then
        return true
    end

    return getPotentialPrestigePoints() >= targetValue
end

local function isIntervalReady()
    return (getNow() - Module.LastPrestigeAt) >= MIN_INTERVAL
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
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
    self:SetDelay(profile.PrestigeDelay)
end

function Module:Toggle()
    self.Enabled = not self.Enabled
    return self.Enabled
end

function Module:SetTargetValue(value)
    local numberValue = tonumber(value)
    if not numberValue or numberValue < 0 then
        self.TargetValue = DEFAULT_TARGET
    else
        self.TargetValue = numberValue
    end
end

function Module:GetState()
    local sessionPrestiges, sessionPrestigePoints = getSessionTotals()

    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        TargetValue = getTargetValue(),
        LastPrestigeAt = self.LastPrestigeAt,
        LastPrestigeClock = self.LastPrestigeClock,
        PotentialPrestigePoints = getPotentialPrestigePoints(),
        SecondsUntilNextTry = math.max(0, MIN_INTERVAL - (getNow() - self.LastPrestigeAt)),
        SessionPrestiges = sessionPrestiges,
        SessionPrestigePoints = sessionPrestigePoints,
        LastStatus = self.Enabled and "Rodando" or "Desligado",
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    if Batata.Modules.AutoPrestige == self then
        Batata.Modules.AutoPrestige = nil
    end
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled and isIntervalReady() and canPrestigeNow() then
            local ok = pcall(function()
                if equipPotatoRemote then
                    equipPotatoRemote:FireServer(PRESTIGE_POTATO)
                    task.wait(EQUIP_DELAY)
                end

                prestigeRemote:FireServer()

                if equipPotatoRemote then
                    task.wait(EQUIP_DELAY)
                    equipPotatoRemote:FireServer(DEFAULT_POTATO)
                end
            end)

            if ok then
                Module.LastPrestigeAt = getNow()
                Module.LastPrestigeClock = getClock()
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoPrestige = Module

return Module
