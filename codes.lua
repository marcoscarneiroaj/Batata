local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata
if type(Batata) ~= "table" then
    error("Batata shared nao carregado")
end

if Batata.Modules.AutoCodes then
    return Batata.Modules.AutoCodes
end

local remotes = Batata.Util.EnsureRemotes()
local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

local STORE_PATH = "batata/codes.json"
local CODE_LIST = {
    "HAPPYEASTER",
    "KEEWEE",
    "FARMERTIMMY",
    "WELCOME",
    "GOLDENSTART",
    "BLUEPOTATO",
    "CODEPOTATO",
}

local Module = {
    Running = true,
    InProgress = false,
    Codes = CODE_LIST,
    ResultsByCode = {},
    LastStatus = "Pronto",
    LastMessage = "-",
    LastCode = "-",
    CompletedCount = 0,
    PendingCode = nil,
    PendingChangedAt = 0,
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

local function getUserKey()
    return tostring(localPlayer and localPlayer.UserId or "0")
end

local function ensureStoreFolder()
    if type(makefolder) == "function" then
        pcall(makefolder, "batata")
    end
end

local function loadStore()
    if type(readfile) ~= "function" then
        return {}
    end

    local ok, content = pcall(readfile, STORE_PATH)
    if not ok or type(content) ~= "string" or content == "" then
        return {}
    end

    local decodeOk, decoded = pcall(function()
        return HttpService:JSONDecode(content)
    end)

    if not decodeOk or type(decoded) ~= "table" then
        return {}
    end

    return decoded
end

local function saveStore(store)
    if type(writefile) ~= "function" then
        return false, "writefile indisponivel"
    end

    ensureStoreFolder()

    local okEncode, encoded = pcall(function()
        return HttpService:JSONEncode(store)
    end)
    if not okEncode or type(encoded) ~= "string" then
        return false, "falha ao serializar"
    end

    local okWrite, err = pcall(writefile, STORE_PATH, encoded)
    if not okWrite then
        return false, tostring(err)
    end

    return true
end

local function loadUserResults()
    local store = loadStore()
    local userData = store[getUserKey()]
    if type(userData) ~= "table" or type(userData.Codes) ~= "table" then
        Module.ResultsByCode = {}
        return
    end

    Module.ResultsByCode = userData.Codes
end

local function persistUserResults()
    local store = loadStore()
    store[getUserKey()] = store[getUserKey()] or {}
    store[getUserKey()].Username = localPlayer and localPlayer.Name or ""
    store[getUserKey()].UpdatedAtLocal = Batata.Util.GetLocalDateTime()
    store[getUserKey()].Codes = Module.ResultsByCode
    return saveStore(store)
end

local function updateCompletedCount()
    local total = 0
    for _, code in ipairs(Module.Codes) do
        local entry = Module.ResultsByCode[code]
        if type(entry) == "table" and entry.Done == true then
            total = total + 1
        end
    end
    Module.CompletedCount = total
end

local function normalizeMessage(payload)
    if type(payload) == "string" then
        return payload
    end

    if type(payload) == "table" then
        return payload.Message or payload.Result or payload.Status or payload.Description or payload.Code or "-"
    end

    return tostring(payload)
end

local function extractCode(payload)
    if type(payload) ~= "table" then
        return nil
    end

    local candidateKeys = {
        "Code",
        "CodeId",
        "CodeName",
    }

    for _, key in ipairs(candidateKeys) do
        if type(payload[key]) == "string" and payload[key] ~= "" then
            return payload[key]
        end
    end

    return nil
end

local function isSuccessMessage(message)
    local text = string.lower(tostring(message or ""))
    if text == "" then
        return false
    end

    if string.find(text, "already") or string.find(text, "ja") or string.find(text, "used") then
        return true
    end

    if string.find(text, "redeemed")
        or string.find(text, "success")
        or string.find(text, "claimed")
        or string.find(text, "resgat")
        or string.find(text, "claim") then
        return true
    end

    return false
end

local function setResult(code, payload)
    local message = normalizeMessage(payload)
    local done = isSuccessMessage(message)
    Module.ResultsByCode[code] = {
        Message = message,
        Done = done,
        UpdatedAtLocal = Batata.Util.GetLocalDateTime(),
    }
    Module.LastCode = code
    Module.LastMessage = message
    Module.LastStatus = done and "Codigo processado" or "Retorno recebido"
    persistUserResults()
    updateCompletedCount()
end

function Module:GetState()
    return {
        Running = self.Running == true,
        InProgress = self.InProgress == true,
        Codes = self.Codes,
        ResultsByCode = self.ResultsByCode,
        LastStatus = self.LastStatus,
        LastMessage = self.LastMessage,
        LastCode = self.LastCode,
        CompletedCount = self.CompletedCount,
    }
end

function Module:RedeemAll()
    if self.InProgress then
        self.LastStatus = "Ja resgatando"
        return false
    end

    local redeemRemote = remotes:Get("RedeemCode")
    if not redeemRemote then
        self.LastStatus = "RedeemCode ausente"
        return false
    end

    self.InProgress = true
    self.LastStatus = "Resgatando codigos"

    task.spawn(function()
        for _, code in ipairs(self.Codes) do
            local entry = self.ResultsByCode[code]
            if type(entry) == "table" and entry.Done == true then
                self.LastCode = code
                self.LastMessage = tostring(entry.Message or "ja concluido")
                self.LastStatus = "Pulando codigo concluido"
            else
                self.PendingCode = code
                self.PendingChangedAt = os.clock()
                self.LastCode = code
                self.LastMessage = "enviado"
                self.LastStatus = "Enviando " .. code

                pcall(function()
                    redeemRemote:FireServer(code)
                end)

                local deadline = os.clock() + 1.8
                while self.PendingCode == code and os.clock() < deadline do
                    task.wait(0.05)
                end

                if self.PendingCode == code then
                    setResult(code, "sem resposta")
                    self.PendingCode = nil
                end
            end

            task.wait(0.15)
        end

        self.InProgress = false
        self.LastStatus = "Resgate finalizado"
        updateCompletedCount()
    end)

    return true
end

function Module:Stop()
    self.Running = false
    self.InProgress = false
    disconnectAll()
    if Batata.Modules.AutoCodes == self then
        Batata.Modules.AutoCodes = nil
    end
end

local resultRemote = remotes:Get("CodeRedeemed")
if resultRemote and resultRemote.OnClientEvent then
    table.insert(connections, resultRemote.OnClientEvent:Connect(function(payload)
        local code = extractCode(payload) or Module.PendingCode or Module.LastCode
        if type(code) ~= "string" or code == "" or code == "-" then
            Module.LastMessage = normalizeMessage(payload)
            Module.LastStatus = "Retorno sem codigo"
            return
        end

        setResult(code, payload)
        if Module.PendingCode == code then
            Module.PendingCode = nil
        end
    end))
end

loadUserResults()
updateCompletedCount()

Batata.Modules.AutoCodes = Module

return Module
