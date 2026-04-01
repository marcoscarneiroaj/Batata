local Players = game:GetService("Players")

local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoTrade then
    return Batata.Modules.AutoTrade
end

local remotes = Batata.Util.EnsureRemotes()

local CHECK_DELAY = 0.25
local DEFAULT_WHITELIST_TEXT =
    "GalaxiaViajante,miguelcarneiroAC01,miguelcarneiroAC02,miguelcarneiroAC03"

local Module = {
    Running = true,
    Enabled = false,
    Delay = CHECK_DELAY,
    AllowedPlayers = {},
    AllowedList = {},
    WhitelistText = DEFAULT_WHITELIST_TEXT,
    LastStatus = "Desligado",
    LastRequester = "-",
    LastDecision = "-",
    LastResult = "-",
    LastRequestClock = "--:--:--",
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

local function normalizeToken(value)
    local text = tostring(value or "")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    text = string.lower(text)
    return text
end

local function getClock()
    return os.date("%H:%M:%S")
end

local function addAllowedToken(targetMap, targetList, token)
    local normalized = normalizeToken(token)
    if normalized == "" or targetMap[normalized] == true then
        return
    end

    targetMap[normalized] = true
    table.insert(targetList, tostring(token))
end

local function parseWhitelist(text)
    local targetMap = {}
    local targetList = {}
    local rawText = tostring(text or "")
    local separatorsNormalized = string.gsub(rawText, ";", "\n")
    separatorsNormalized = string.gsub(separatorsNormalized, ",", "\n")

    for token in string.gmatch(separatorsNormalized, "[^\r\n]+") do
        addAllowedToken(targetMap, targetList, token)
    end

    return targetMap, targetList
end

local function getPlayerSummary(player)
    if typeof(player) == "Instance" and player:IsA("Player") then
        return {
            Player = player,
            Name = player.Name,
            DisplayName = player.DisplayName,
            UserId = player.UserId,
        }
    end

    return nil
end

local function fillInfoFromValue(info, value)
    if value == nil then
        return
    end

    local playerSummary = getPlayerSummary(value)
    if playerSummary then
        info.Player = info.Player or playerSummary.Player
        info.Name = info.Name or playerSummary.Name
        info.DisplayName = info.DisplayName or playerSummary.DisplayName
        info.UserId = info.UserId or playerSummary.UserId
        return
    end

    if type(value) == "string" then
        if info.Name == nil or info.Name == "" then
            info.Name = value
        end
        return
    end

    if type(value) == "number" then
        if info.UserId == nil then
            info.UserId = value
        end
        return
    end

    if type(value) ~= "table" then
        return
    end

    local directPlayerKeys = {
        "FromPlayer",
        "Player",
        "From",
        "Sender",
        "Requester",
        "Initiator",
        "User",
        "Owner",
        "TargetPlayer",
    }

    for _, key in ipairs(directPlayerKeys) do
        local nested = value[key]
        local nestedPlayer = getPlayerSummary(nested)
        if nestedPlayer then
            info.Player = info.Player or nestedPlayer.Player
            info.Name = info.Name or nestedPlayer.Name
            info.DisplayName = info.DisplayName or nestedPlayer.DisplayName
            info.UserId = info.UserId or nestedPlayer.UserId
        end
    end

    local directStringKeys = {
        "Name",
        "Username",
        "FromName",
        "SenderName",
        "RequesterName",
        "PlayerName",
    }

    for _, key in ipairs(directStringKeys) do
        if type(value[key]) == "string" and value[key] ~= "" then
            info.Name = info.Name or value[key]
        end
    end

    local displayKeys = {
        "DisplayName",
        "FromDisplayName",
        "SenderDisplayName",
        "RequesterDisplayName",
    }

    for _, key in ipairs(displayKeys) do
        if type(value[key]) == "string" and value[key] ~= "" then
            info.DisplayName = info.DisplayName or value[key]
        end
    end

    local userIdKeys = {
        "UserId",
        "FromUserId",
        "SenderUserId",
        "RequesterUserId",
        "PlayerUserId",
    }

    for _, key in ipairs(userIdKeys) do
        if tonumber(value[key]) ~= nil then
            info.UserId = info.UserId or tonumber(value[key])
        end
    end

    if info.Name == nil and type(value[1]) == "string" then
        info.Name = value[1]
    end

    if info.UserId == nil and tonumber(value[1]) ~= nil then
        info.UserId = tonumber(value[1])
    end
end

local function extractRequestInfo(payload)
    local info = {
        Raw = payload,
        RequestKey = nil,
        Player = nil,
        Name = nil,
        DisplayName = nil,
        UserId = nil,
    }

    if payload == nil then
        return info
    end

    if typeof(payload) == "Instance" and payload:IsA("Player") then
        local summary = getPlayerSummary(payload)
        info.Player = summary.Player
        info.Name = summary.Name
        info.DisplayName = summary.DisplayName
        info.UserId = summary.UserId
        info.RequestKey = payload
        return info
    end

    if type(payload) == "string" then
        info.Name = payload
        info.RequestKey = payload
        return info
    end

    if type(payload) == "number" then
        info.UserId = payload
        info.RequestKey = payload
        return info
    end

    if type(payload) == "table" then
        local requestKeys = {
            "RequestId",
            "TradeId",
            "TradeRequestId",
            "Id",
        }

        for _, key in ipairs(requestKeys) do
            if payload[key] ~= nil then
                info.RequestKey = payload[key]
                break
            end
        end

        fillInfoFromValue(info, payload)
    end

    if info.RequestKey == nil then
        info.RequestKey = info.Player or info.UserId or info.Name or payload
    end

    return info
end

local function buildRequesterLabel(info)
    if type(info) ~= "table" then
        return "desconhecido"
    end

    if type(info.Name) == "string" and info.Name ~= "" then
        if type(info.DisplayName) == "string" and info.DisplayName ~= "" and info.DisplayName ~= info.Name then
            return string.format("%s (%s)", tostring(info.Name), tostring(info.DisplayName))
        end

        return info.Name
    end

    if tonumber(info.UserId) ~= nil then
        return "UserId " .. tostring(math.floor(tonumber(info.UserId)))
    end

    return "desconhecido"
end

local function isWhitelisted(info)
    if next(Module.AllowedPlayers) == nil then
        return false
    end

    local candidates = {
        info and info.Name,
        info and info.DisplayName,
        info and info.UserId and tostring(info.UserId) or nil,
    }

    for _, candidate in ipairs(candidates) do
        local normalized = normalizeToken(candidate)
        if normalized ~= "" and Module.AllowedPlayers[normalized] == true then
            return true
        end
    end

    if info and info.Player then
        local normalizedName = normalizeToken(info.Player.Name)
        local normalizedDisplay = normalizeToken(info.Player.DisplayName)
        if normalizedName ~= "" and Module.AllowedPlayers[normalizedName] == true then
            return true
        end
        if normalizedDisplay ~= "" and Module.AllowedPlayers[normalizedDisplay] == true then
            return true
        end
        if tostring(info.Player.UserId or "") ~= "" and Module.AllowedPlayers[tostring(info.Player.UserId)] == true then
            return true
        end
    end

    return false
end

local function sendTradeResponse(info, accepted)
    local respondRemote = remotes:Get("RespondToTrade")
    if not respondRemote then
        return false, "RespondToTrade ausente"
    end

    local requestKey = info and info.RequestKey or nil
    if requestKey == nil then
        requestKey = info and (info.Player or info.UserId or info.Name) or nil
    end

    if requestKey == nil then
        return false, "request_key ausente"
    end

    local ok, err = pcall(function()
        respondRemote:FireServer(requestKey, accepted == true)
    end)

    if not ok then
        return false, tostring(err)
    end

    return true
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    if self.Enabled then
        if next(self.AllowedPlayers) == nil then
            self.LastStatus = "Lista vazia: recusando tudo"
        else
            self.LastStatus = "Aceitando lista confiavel"
        end
    else
        self.LastStatus = "Desligado"
    end
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
end

function Module:SetWhitelistText(text)
    local whitelistText = tostring(text or "")
    local allowedMap, allowedList = parseWhitelist(whitelistText)
    self.WhitelistText = whitelistText
    self.AllowedPlayers = allowedMap
    self.AllowedList = allowedList

    if self.Enabled then
        if next(self.AllowedPlayers) == nil then
            self.LastStatus = "Lista vazia: recusando tudo"
        else
            self.LastStatus = "Whitelist atualizada"
        end
    end
end

function Module:SetWhitelistFromString(text)
    self:SetWhitelistText(text)
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        LastStatus = self.LastStatus,
        LastRequester = self.LastRequester,
        LastDecision = self.LastDecision,
        LastResult = self.LastResult,
        LastRequestClock = self.LastRequestClock,
        WhitelistText = self.WhitelistText,
        AllowedList = self.AllowedList,
        AllowedCount = #self.AllowedList,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    disconnectAll()

    if Batata.Modules.AutoTrade == self then
        Batata.Modules.AutoTrade = nil
    end
end

local requestRemote = remotes:Get("TradeRequestReceived")
if requestRemote and requestRemote.OnClientEvent then
    table.insert(connections, requestRemote.OnClientEvent:Connect(function(payload)
        local info = extractRequestInfo(payload)
        local requesterLabel = buildRequesterLabel(info)
        Module.LastRequester = requesterLabel
        Module.LastRequestClock = getClock()

        if Module.Enabled ~= true then
            Module.LastDecision = "Ignorado"
            Module.LastStatus = "Trade recebido com modulo desligado"
            return
        end

        local allowed = isWhitelisted(info)
        local accepted = allowed == true
        local ok, err = sendTradeResponse(info, accepted)

        if not ok then
            Module.LastDecision = accepted and "Falhou ao aceitar" or "Falhou ao recusar"
            Module.LastStatus = "Erro ao responder trade"
            Module.LastResult = tostring(err or "-")
            return
        end

        Module.LastDecision = accepted and "Aceito" or "Recusado"
        Module.LastStatus = accepted and "Trade confiavel aceito" or "Trade fora da lista recusado"
        Module.LastResult = accepted and "aceite enviado" or "recusa enviada"
    end))
end

local resultRemote = remotes:Get("TradeResult")
if resultRemote and resultRemote.OnClientEvent then
    table.insert(connections, resultRemote.OnClientEvent:Connect(function(payload)
        local message = nil

        if type(payload) == "table" then
            message = payload.Message or payload.Result or payload.Status
            if message == nil and payload.Success ~= nil then
                message = payload.Success == true and "trade concluido" or "trade falhou"
            end
        elseif type(payload) == "string" then
            message = payload
        else
            message = tostring(payload)
        end

        Module.LastResult = tostring(message or "-")
    end))
end

Module:SetWhitelistText(DEFAULT_WHITELIST_TEXT)

Batata.Modules.AutoTrade = Module

return Module
