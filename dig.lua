local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoDig then
    return Batata.Modules.AutoDig
end

local remotes = Batata.Util.EnsureRemotes()

local DIG_DELAY = 1
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
    LastRoundSignature = nil,
    PendingResult = false,
    PendingChoiceTile = nil,
    PendingChoiceRarity = nil,
    PendingRoundSummary = nil,
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

local function getRarityLabel(value)
    local rarity = normalizeRarity(value)
    local labels = {
        common = "comum",
        uncommon = "incomum",
        rare = "rare",
        epic = "epic",
        legendary = "lendario",
        mythic = "mythic",
        secret = "secret",
    }

    return labels[rarity] or rarity
end

local function formatPrizeTiles()
    if type(Module.PrizeTiles) ~= "table" or #Module.PrizeTiles == 0 then
        return "nenhum"
    end

    local parts = {}
    local items = {}

    for _, info in ipairs(Module.PrizeTiles) do
        table.insert(items, {
            Tile = tonumber(info.Tile) or 0,
            Rarity = getRarityLabel(info.Rarity),
        })
    end

    table.sort(items, function(left, right)
        return left.Tile < right.Tile
    end)

    for _, info in ipairs(items) do
        table.insert(parts, string.format("%s=%s", tostring(info.Tile), tostring(info.Rarity)))
    end

    return table.concat(parts, " | ")
end

local function getRoundSignature()
    return formatPrizeTiles()
end

local function appendDigLog(message)
    if not (Batata.Util and type(Batata.Util.AppendLogLine) == "function") then
        return
    end

    local line = string.format("[%s] %s", Batata.Util.GetLocalDateTime(), tostring(message or ""))
    local ok, err = Batata.Util.AppendLogLine(Batata.LogPaths.Dig, line)
    if ok ~= true then
        warn("[BatataDig] falha ao salvar log: " .. tostring(err))
    end
end

local function clearPendingChoice()
    Module.PendingResult = false
    Module.PendingChoiceTile = nil
    Module.PendingChoiceRarity = nil
    Module.PendingRoundSummary = nil
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
        return Module.PrizeTiles[1].Tile, Module.PrizeTiles[1]
    end

    return chooseRandomTile(), nil
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
    if numberValue and numberValue >= 1 then
        self.Delay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    self.DelayProfile = profileName
    if type(profile) == "table" and tonumber(profile.DigDelay) then
        self.Delay = math.max(1, tonumber(profile.DigDelay))
    else
        self.Delay = DIG_DELAY
    end
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
            clearPendingChoice()
        end

        local signature = getRoundSignature()
        if payload.HasPrize == true and signature ~= Module.LastRoundSignature then
            Module.LastRoundSignature = signature
            appendDigLog(
                string.format(
                    "rodada revelada | stamina=%s/%s | premios=%s",
                    tostring(math.floor(tonumber(Module.StaminaCurrent or 0))),
                    tostring(math.floor(tonumber(Module.StaminaMax or 0))),
                    signature
                )
            )
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
        Module.PendingResult = false

        local itemData = type(payload.Item) == "table" and payload.Item or nil
        if Module.PendingRoundSummary then
            appendDigLog(
                string.format(
                    "%s | escolhido=%s | %s | item=%s | raridade_item=%s | sucesso=%s",
                    tostring(Module.PendingRoundSummary),
                    tostring(Module.PendingChoiceTile or payload.SquareIndex or "-"),
                    tostring(Module.PendingChoiceRarity or "-"),
                    tostring(itemData and (itemData.Id or itemData.Name) or "nenhum"),
                    tostring(itemData and getRarityLabel(itemData.Rarity) or "-"),
                    tostring(payload.Success == true)
                )
            )
        end

        if payload.RoundOver == true then
            setPrizeTiles(nil)
            Module.LastRoundSignature = nil
            clearPendingChoice()
        end

        if payload.Success == true then
            Module.LastStatus = "Escavacao concluida"
        else
            Module.LastStatus = "Tentativa concluida"
            if payload.RoundOver ~= true then
                clearPendingChoice()
            end
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
            elseif Module.PendingResult == true then
                Module.LastStatus = "Aguardando resultado"
            else
                local tile, selectedPrize = chooseTargetTile()
                Module.LastTileTried = tile
                Module.LastStatus = #Module.PrizeTiles > 0 and "Escavando premio" or "Escavando aleatorio"
                Module.PendingResult = true
                Module.PendingChoiceTile = tile
                Module.PendingChoiceRarity = selectedPrize and getRarityLabel(selectedPrize.Rarity) or "aleatorio"
                Module.PendingRoundSummary = selectedPrize and formatPrizeTiles() or nil

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
