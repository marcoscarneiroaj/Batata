local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()
ROOT.Batata = Batata
_G.Batata = Batata

if Batata.Modules.AutoDig then
    return Batata.Modules.AutoDig
end

local remotes = Batata.Util.EnsureRemotes()

local DIG_DELAY = 0.2
local DIG_MIN_COST = 5
local DIG_MAX_TILE = 18
local RARITY_PRIORITY = {
    secret = 7,
    mythic = 6,
    legendary = 5,
    epic = 4,
    rare = 3,
    uncommon = 2,
    common = 1,
}

local Module = {
    Running = true,
    Enabled = false,
    Delay = DIG_DELAY,
    StaminaCurrent = 0,
    StaminaMax = 0,
    PrizeTiles = {},
    LastTileTried = nil,
    LastResult = nil,
    LastStatus = "Aguardando dados",
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

local function normalizeRarity(value)
    local text = string.lower(tostring(value or "unknown"))
    if text == "mítico" or text == "mitico" then
        return "mythic"
    end
    if text == "lendário" or text == "lendario" then
        return "legendary"
    end
    if text == "épico" or text == "epico" then
        return "epic"
    end
    if text == "raro" then
        return "rare"
    end
    if text == "comum" then
        return "common"
    end
    return text
end

local function getRarityPriority(value)
    return RARITY_PRIORITY[normalizeRarity(value)] or 0
end

local function setPrizeTiles(prizeTiles)
    Module.PrizeTiles = {}

    if type(prizeTiles) ~= "table" then
        return
    end

    for _, info in ipairs(prizeTiles) do
        if type(info) == "table" and type(info.Tile) == "number" then
            table.insert(Module.PrizeTiles, {
                Tile = info.Tile,
                Rarity = normalizeRarity(info.Rarity),
            })
        end
    end

    table.sort(Module.PrizeTiles, function(left, right)
        local leftPriority = getRarityPriority(left and left.Rarity)
        local rightPriority = getRarityPriority(right and right.Rarity)

        if leftPriority ~= rightPriority then
            return leftPriority > rightPriority
        end

        return tonumber(left and left.Tile) < tonumber(right and right.Tile)
    end)
end

local function chooseRandomTile()
    return math.random(1, DIG_MAX_TILE)
end

local function chooseTargetTile()
    if #Module.PrizeTiles > 0 then
        return Module.PrizeTiles[1].Tile
    end

    return chooseRandomTile()
end

local function canDigNow()
    return (tonumber(Module.StaminaCurrent) or 0) >= DIG_MIN_COST
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    if self.Enabled then
        self.LastStatus = "Rodando"
    else
        self.LastStatus = "Desligado"
    end
end

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.05 then
        self.Delay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.DigDelay)
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        StaminaCurrent = self.StaminaCurrent,
        StaminaMax = self.StaminaMax,
        PrizeTiles = self.PrizeTiles,
        LastTileTried = self.LastTileTried,
        LastResult = self.LastResult,
        LastStatus = self.LastStatus,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    disconnectAll()

    if Batata.Modules.AutoDig == self then
        Batata.Modules.AutoDig = nil
    end
end

local staminaRemote = remotes:Get("DigStaminaUpdate")
if staminaRemote and staminaRemote.OnClientEvent then
    table.insert(connections, staminaRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end

        Module.StaminaCurrent = tonumber(payload.Current) or Module.StaminaCurrent or 0
        Module.StaminaMax = tonumber(payload.Max) or Module.StaminaMax or 0

        if Module.Enabled ~= true then
            Module.LastStatus = "Stamina atualizada"
        end
    end))
end

local roundInfoRemote = remotes:Get("DigRoundInfo")
if roundInfoRemote and roundInfoRemote.OnClientEvent then
    table.insert(connections, roundInfoRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end

        if payload.HasPrize == true and type(payload.PrizeTiles) == "table" then
            setPrizeTiles(payload.PrizeTiles)
            Module.LastStatus = "Premio encontrado"
        else
            setPrizeTiles(nil)
            Module.LastStatus = "Sem premio revelado"
        end
    end))
end

local resultRemote = remotes:Get("DigResult")
if resultRemote and resultRemote.OnClientEvent then
    table.insert(connections, resultRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end

        Module.LastResult = payload

        if payload.RoundOver == true then
            setPrizeTiles(nil)
        end

        if payload.Success == true then
            Module.LastStatus = "Escavacao concluida"
        else
            Module.LastStatus = "Tentativa concluida"
        end
    end))
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            local digRemote = remotes:Get("DigSquare")

            if not digRemote then
                Module.LastStatus = "Remote ausente"
            elseif not canDigNow() then
                Module.LastStatus = "Sem stamina"
            else
                local tile = chooseTargetTile()
                Module.LastTileTried = tile
                Module.LastStatus = #Module.PrizeTiles > 0 and "Escavando premio" or "Escavando aleatorio"

                pcall(function()
                    digRemote:FireServer(tile)
                end)
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoDig = Module

return Module
