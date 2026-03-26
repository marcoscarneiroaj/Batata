local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoAscension then
    return Batata.Modules.AutoAscension
end

local ascensionRemote = Batata.Util.EnsureRemotes().PerformAscension

local CHECK_DELAY = 1
local MIN_INTERVAL = 30
local DEFAULT_BLESSING = "abundance"

local Module = {
    Running = true,
    Enabled = false,
    Delay = CHECK_DELAY,
    LastAscensionAt = 0,
    LastAscensionClock = "--:--:--",
    StartTimesAscended = nil,
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

local function getCurrentPrestigePoints()
    local stats = getStats()
    if type(stats) ~= "table" then
        return 0
    end

    return tonumber(stats.PrestigePoints) or 0
end

local function getRequiredPrestigePoints()
    local stats = getStats()
    if type(stats) ~= "table" then
        return math.huge
    end

    return tonumber(stats.AscensionCost) or math.huge
end

local function getSessionAscensions()
    local stats = getStats()
    if type(stats) ~= "table" then
        return 0
    end

    local timesAscended = tonumber(stats.TimesAscended) or 0
    if Module.StartTimesAscended == nil then
        Module.StartTimesAscended = timesAscended
    end

    return math.max(0, timesAscended - Module.StartTimesAscended)
end

local function canAscendNow()
    local currentPP = getCurrentPrestigePoints()
    local requiredPP = getRequiredPrestigePoints()

    if requiredPP == math.huge then
        return false
    end

    return currentPP >= requiredPP
end

local function isIntervalReady()
    return (getNow() - Module.LastAscensionAt) >= MIN_INTERVAL
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
    self:SetDelay(profile.AscensionDelay)
end

function Module:Toggle()
    self.Enabled = not self.Enabled
    return self.Enabled
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        CurrentPrestigePoints = getCurrentPrestigePoints(),
        RequiredPrestigePoints = getRequiredPrestigePoints(),
        CanAscendNow = canAscendNow(),
        Blessing = DEFAULT_BLESSING,
        LastAscensionAt = self.LastAscensionAt,
        LastAscensionClock = self.LastAscensionClock,
        SecondsUntilNextTry = math.max(0, MIN_INTERVAL - (getNow() - self.LastAscensionAt)),
        SessionAscensions = getSessionAscensions(),
        LastStatus = self.Enabled and "Rodando" or "Desligado",
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    if Batata.Modules.AutoAscension == self then
        Batata.Modules.AutoAscension = nil
    end
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled and isIntervalReady() and canAscendNow() then
            local ok = pcall(function()
                ascensionRemote:FireServer(DEFAULT_BLESSING)
            end)

            if ok then
                Module.LastAscensionAt = getNow()
                Module.LastAscensionClock = getClock()
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoAscension = Module

return Module
