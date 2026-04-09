local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoFarm then
    return Batata.Modules.AutoFarm
end

local remotes = Batata.Util.EnsureRemotes()
local generatorDb = Batata.Util.EnsureGeneratorDb()

local CHECK_DELAY = 0.12
local BUY_DELAY = 0.03
local DELETE_PAUSE = 0.12
local ACTION_INTERVAL = 0.2
local PRESTIGE_GRACE = 1.5

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
    LastCostSource = "local",
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

local function getNow()
    if Batata.Util and type(Batata.Util.GetRuntimeSeconds) == "function" then
        return tonumber(Batata.Util.GetRuntimeSeconds()) or os.clock()
    end

    return os.clock()
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
    if type(stats) == "table" and tonumber(stats.TimesPrestiged) then
        return tonumber(stats.TimesPrestiged) or 0
    end

    local data = Batata.Data
    return tonumber(data and data.TimesPrestiged)
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

local function getGeneratorCost(generatorId, ownedCount)
    local remoteCost = nil
    if type(generatorDb.GetRemoteCost) == "function" then
        remoteCost = generatorDb:GetRemoteCost(generatorId, ownedCount)
    end

    if tonumber(remoteCost) ~= nil then
        Module.LastCostSource = "server"
        return tonumber(remoteCost)
    end

    Module.LastCostSource = "local"
    return generatorDb:GetCurrentCost(generatorId, ownedCount)
end

local function scheduleNextAction(reason, interval)
    Module.NextActionAt = getNow() + math.max(0, tonumber(interval) or Module.ActionInterval or ACTION_INTERVAL)
    if type(reason) == "string" and reason ~= "" then
        Module.LastStatus = reason
    end
end

local function initializePrestigeBaseline()
    local timesPrestiged = getTimesPrestiged()
    if timesPrestiged == nil then
        return false
    end

    if Module.ObservedPrestiges == nil then
        Module.ObservedPrestiges = timesPrestiged
        if Module.NextActionAt <= 0 then
            scheduleNextAction("Preparando geradores", PRESTIGE_GRACE)
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
        Module.SlotFull = false
        Module.CurrentTarget = nil
        Module.CurrentTargetIndex = nil
        Module.InitialBuyDone = false
        scheduleNextAction("Prestigio detectado, aguardando geradores", PRESTIGE_GRACE)
    end
end

local function getBestAffordableGenerator()
    local cash = getCash()
    local owned = getOwnedGenerators()

    for index = #generatorDb.List, 1, -1 do
        local generator = generatorDb.List[index]
        local ownedCount = math.max(0, math.floor(tonumber(owned[generator.Id]) or 0))
        local cost = getGeneratorCost(generator.Id, ownedCount)

        if tonumber(cost) ~= nil and cost <= cash then
            return {
                Id = generator.Id,
                Index = generator.Index or index,
                Cost = tonumber(cost),
                OwnedCount = ownedCount,
            }
        end
    end

    return nil
end

local function getWorstOwnedGenerator()
    local owned = getOwnedGenerators()

    for index = 1, #generatorDb.List do
        local generator = generatorDb.List[index]
        local amount = math.max(0, math.floor(tonumber(owned[generator.Id]) or 0))

        if amount > 0 then
            return {
                Id = generator.Id,
                Index = generator.Index or index,
                Amount = amount,
            }
        end
    end

    return nil
end

local function deleteOneWorstGenerator()
    local deleteRemote = remotes:Get("DeleteGenerator")
    if not deleteRemote then
        Module.LastStatus = "Delete remote ausente"
        return false
    end

    local worst = getWorstOwnedGenerator()
    if not worst then
        Module.LastStatus = "Sem gerador para deletar"
        return false
    end

    Module.CurrentTarget = worst.Id
    Module.CurrentTargetIndex = worst.Index
    Module.LastStatus = "Deletando pior " .. tostring(worst.Id)

    local ok = pcall(function()
        deleteRemote:FireServer(worst.Id)
    end)

    if ok then
        Module.SlotFull = false
    else
        Module.LastStatus = "Falha ao deletar " .. tostring(worst.Id)
    end

    task.wait(Module.DeletePause)
    return ok, worst
end

local function buyOneGenerator(target)
    local purchaseRemote = remotes:Get("PurchaseGenerator")
    if not purchaseRemote then
        Module.LastStatus = "Purchase remote ausente"
        return false
    end

    if not target then
        Module.LastStatus = "Sem gerador compravel"
        return false
    end

    Module.CurrentTarget = target.Id
    Module.CurrentTargetIndex = target.Index
    Module.LastStatus = "Comprando melhor " .. tostring(target.Id)

    local ok = pcall(function()
        purchaseRemote:FireServer(target.Id)
    end)

    if ok then
        Module.InitialBuyDone = true
        Module.CycleCount = (Module.CycleCount or 0) + 1
    else
        Module.LastStatus = "Falha ao comprar " .. tostring(target.Id)
    end

    task.wait(Module.BuyDelay)
    return ok
end

local function performFarmAction()
    local best = getBestAffordableGenerator()
    if not best then
        Module.CurrentTarget = nil
        Module.CurrentTargetIndex = nil
        Module.LastStatus = "Sem gerador compravel"
        return false
    end

    if Module.SlotFull then
        local worst = getWorstOwnedGenerator()
        if not worst then
            Module.LastStatus = "Slots cheios sem gerador para deletar"
            return false
        end

        if worst.Index >= best.Index then
            Module.CurrentTarget = best.Id
            Module.CurrentTargetIndex = best.Index
            Module.LastStatus = "Slots cheios aguardando gerador melhor"
            return false
        end

        local deleted = deleteOneWorstGenerator()
        if deleted ~= true then
            return false
        end

        best = getBestAffordableGenerator()
        if not best then
            Module.CurrentTarget = nil
            Module.CurrentTargetIndex = nil
            Module.LastStatus = "Sem gerador apos deletar"
            return false
        end
    end

    return buyOneGenerator(best)
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true

    if self.Enabled then
        if self.NextActionAt <= 0 then
            scheduleNextAction("Preparando geradores", PRESTIGE_GRACE)
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
    self.ActionInterval = math.max(0.15, (tonumber(profile.FarmLoopDelay) or self.Delay or 0.12) * 2)
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
        SecondsUntilNextAction = math.max(0, (self.NextActionAt or 0) - getNow()),
        CycleCount = self.CycleCount or 0,
        CostSource = self.LastCostSource,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.CurrentTarget = nil
    self.CurrentTargetIndex = nil
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
            Module.NextActionAt = getNow()
        elseif text == "Not enough cash" then
            Module.LastStatus = "Sem cash para gerador"
        elseif text == "You don't own this generator" then
            Module.LastStatus = "Delete recusado"
        end
    end))
end

task.spawn(function()
    while Module.Running do
        initializePrestigeBaseline()
        detectPrestigeReset()

        if Module.Enabled then
            if Module.NextActionAt <= 0 then
                scheduleNextAction("Preparando geradores", PRESTIGE_GRACE)
            end

            if getNow() >= Module.NextActionAt then
                performFarmAction()
                Module.NextActionAt = getNow() + Module.ActionInterval
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoFarm = Module

return Module
