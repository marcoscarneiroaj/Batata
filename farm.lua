local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()
ROOT.Batata = Batata
_G.Batata = Batata

if Batata.Modules.AutoFarm then
    return Batata.Modules.AutoFarm
end

local remotes = Batata.Util.EnsureRemotes()
local generatorDb = Batata.Util.EnsureGeneratorDb()

local CHECK_DELAY = 0.2
local BUY_DELAY = 0.03
local DELETE_PAUSE = 0.12
local ACTION_INTERVAL = 5

local Module = {
    Running = true,
    Enabled = false,
    Delay = CHECK_DELAY,
    BuyDelay = BUY_DELAY,
    DeletePause = DELETE_PAUSE,
    ActionInterval = ACTION_INTERVAL,
    CurrentTarget = nil,
    CurrentTargetIndex = nil,
    LastStatus = "Aguardando dados",
    SlotFull = false,
    ObservedPrestiges = nil,
    NextActionAt = 0,
    InitialBuyDone = false,
    CycleCount = 0,
}

local connections = {}

local function disconnectAll()
    for _, connection in ipairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end

    table.clear(connections)
end

local function getStats()
    local data = Batata.Data
    if type(data) ~= "table" then
        return nil
    end

    return data.Stats
end

local function getCash()
    local stats = getStats()
    if type(stats) == "table" and tonumber(stats.Cash) then
        return tonumber(stats.Cash) or 0
    end

    local data = Batata.Data
    return tonumber(data and data.Cash) or 0
end

local function getTimesPrestiged()
    local stats = getStats()
    if type(stats) ~= "table" then
        return nil
    end

    return tonumber(stats.TimesPrestiged)
end

local function getOwnedGenerators()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    if type(data.Generators) == "table" then
        return data.Generators
    end

    return {}
end

local function scheduleNextCycle(reason)
    Module.SlotFull = false
    Module.CurrentTarget = nil
    Module.CurrentTargetIndex = nil
    Module.InitialBuyDone = false
    Module.NextActionAt = os.clock() + Module.ActionInterval
    Module.LastStatus = reason or "Aguardando ciclo"
end

local function initializePrestigeBaseline()
    local timesPrestiged = getTimesPrestiged()
    if timesPrestiged == nil then
        return false
    end

    if Module.ObservedPrestiges == nil then
        Module.ObservedPrestiges = timesPrestiged
        if Module.NextActionAt <= 0 then
            scheduleNextCycle("Aguardando 5s apos iniciar")
        end
    end

    return true
end

local function detectPrestigeReset()
    local timesPrestiged = getTimesPrestiged()
    if timesPrestiged == nil then
        return
    end

    if Module.ObservedPrestiges == nil then
        Module.ObservedPrestiges = timesPrestiged
        return
    end

    if timesPrestiged > Module.ObservedPrestiges then
        Module.ObservedPrestiges = timesPrestiged
        scheduleNextCycle("Prestigio detectado, aguardando 5s")
    end
end

local function deleteAllGenerators()
    local deleteRemote = remotes:Get("DeleteGenerator")
    if not deleteRemote then
        Module.LastStatus = "Delete remote ausente"
        return false
    end

    local owned = getOwnedGenerators()

    for index = #generatorDb.List, 1, -1 do
        local generator = generatorDb.List[index]
        local amount = math.max(0, math.floor(tonumber(owned[generator.Id]) or 0))

        if amount > 0 then
            Module.CurrentTarget = generator.Id
            Module.CurrentTargetIndex = generator.Index

            for _ = 1, amount do
                pcall(function()
                    deleteRemote:FireServer(generator.Id)
                end)
                task.wait(Module.DeletePause)
            end
        end
    end

    Module.SlotFull = false
    Module.CurrentTarget = nil
    Module.CurrentTargetIndex = nil
    return true
end

local function buyMaximumDescending()
    local purchaseRemote = remotes:Get("PurchaseGenerator")
    if not purchaseRemote then
        Module.LastStatus = "Purchase remote ausente"
        return 0
    end

    local owned = getOwnedGenerators()
    local cash = getCash()
    local boughtCount = 0

    for index = #generatorDb.List, 1, -1 do
        local generator = generatorDb.List[index]
        local ownedCount = math.max(0, math.floor(tonumber(owned[generator.Id]) or 0))

        while cash > 0 and not Module.SlotFull do
            local cost = generatorDb:GetCurrentCost(generator.Id, ownedCount)
            if cash < cost then
                break
            end

            Module.CurrentTarget = generator.Id
            Module.CurrentTargetIndex = generator.Index
            Module.LastStatus = "Comprando " .. tostring(generator.Id)

            pcall(function()
                purchaseRemote:FireServer(generator.Id)
            end)

            cash = cash - cost
            ownedCount = ownedCount + 1
            boughtCount = boughtCount + 1

            task.wait(Module.BuyDelay)
        end

        if Module.SlotFull then
            break
        end
    end

    if boughtCount <= 0 then
        Module.LastStatus = Module.SlotFull and "Slots cheios" or "Sem gerador compravel"
    else
        Module.CycleCount = Module.CycleCount + 1
        Module.LastStatus = string.format("Ciclo %d comprou %d", Module.CycleCount, boughtCount)
    end

    return boughtCount
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    if self.Enabled then
        if self.NextActionAt <= 0 then
            scheduleNextCycle("Aguardando 5s para comprar")
        end
    else
        self.LastStatus = "Desligado"
    end
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.05 then
        self.Delay = numberValue
    end
end

function Module:SetBuyDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.01 then
        self.BuyDelay = numberValue
    end
end

function Module:SetDeletePause(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.03 then
        self.DeletePause = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.FarmLoopDelay)
    self:SetBuyDelay(profile.FarmBuyDelay)
    self:SetDeletePause(profile.FarmDeletePause)
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        BuyDelay = self.BuyDelay,
        DeletePause = self.DeletePause,
        ActionInterval = self.ActionInterval,
        CurrentTarget = self.CurrentTarget,
        CurrentTargetIndex = self.CurrentTargetIndex,
        LastStatus = self.LastStatus,
        Cash = getCash(),
        SlotFull = self.SlotFull == true,
        InitialBuyDone = self.InitialBuyDone == true,
        SecondsUntilNextAction = math.max(0, (self.NextActionAt or 0) - os.clock()),
        CycleCount = self.CycleCount or 0,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    disconnectAll()

    if Batata.Modules.AutoFarm == self then
        Batata.Modules.AutoFarm = nil
    end
end

local errorRemote = remotes:Get("Error")
if errorRemote and errorRemote.OnClientEvent then
    table.insert(connections, errorRemote.OnClientEvent:Connect(function(message)
        local text = tostring(message or "")
        if text == "No generator slots available" then
            Module.SlotFull = true
            Module.LastStatus = "Slots cheios"
        end
    end))
end

task.spawn(function()
    while Module.Running do
        initializePrestigeBaseline()
        detectPrestigeReset()

        if Module.Enabled then
            if Module.NextActionAt <= 0 then
                scheduleNextCycle("Aguardando 5s para comprar")
            end

            if os.clock() >= Module.NextActionAt then
                if not Module.InitialBuyDone then
                    Module.LastStatus = "Compra inicial apos prestige"
                    buyMaximumDescending()
                    Module.InitialBuyDone = true
                    Module.NextActionAt = os.clock() + Module.ActionInterval
                else
                    Module.LastStatus = "Resetando geradores"
                    deleteAllGenerators()
                    buyMaximumDescending()
                    Module.NextActionAt = os.clock() + Module.ActionInterval
                end
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoFarm = Module

return Module
