local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROOT = getgenv and getgenv() or _G
ROOT.Batata = ROOT.Batata or {}
_G.Batata = ROOT.Batata

local Batata = ROOT.Batata
Batata.Data = Batata.Data or {}
Batata.DB = Batata.DB or {}
Batata.BootLog = Batata.BootLog or {}
Batata.BootErrors = Batata.BootErrors or {}

local Data = Batata.Data
local inventoryDb = Batata.DB.Inventory

local function recordBoot(stage, message)
    local entry = {
        Stage = stage,
        Message = tostring(message or ""),
        Timestamp = os.clock(),
    }

    table.insert(Batata.BootLog, entry)
    Batata.BootErrors[stage] = entry.Message
end

local function ensureRemoteTable()
    if type(Batata.Remotes) == "table" and Batata.Remotes.DataUpdated then
        return Batata.Remotes
    end

    if Batata.Util and type(Batata.Util.LoadFile) == "function" then
        local ok, loadedRemotes = pcall(Batata.Util.LoadFile, "remotes.lua")
        if ok and type(loadedRemotes) == "table" then
            Batata.Remotes = loadedRemotes
            return loadedRemotes
        end
    end

    Batata.Remotes = Batata.Remotes or {}
    return Batata.Remotes
end

local function ensureInventoryDb()
    if type(Batata.DB.Inventory) == "table" then
        return Batata.DB.Inventory
    end

    if Batata.Util and type(Batata.Util.LoadFile) == "function" then
        local ok, loadedInventoryDb = pcall(Batata.Util.LoadFile, "inventorydb.lua")
        if ok and type(loadedInventoryDb) == "table" then
            Batata.DB.Inventory = loadedInventoryDb
            return loadedInventoryDb
        end
    end

    return nil
end

local function ensureDataUpdatedRemote()
    local remotes = ensureRemoteTable()
    local remote = remotes and remotes.DataUpdated

    if remote and remote.OnClientEvent then
        return remote
    end

    local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes") or ReplicatedStorage:WaitForChild("Remotes")
    remote = remotesFolder and (remotesFolder:FindFirstChild("DataUpdated") or remotesFolder:WaitForChild("DataUpdated"))

    if remote then
        Batata.Remotes = Batata.Remotes or {}
        Batata.Remotes.DataUpdated = remote
    end

    return remote
end

inventoryDb = ensureInventoryDb()
local dataUpdatedRemote = ensureDataUpdatedRemote()

local DEBUG_ENABLED = false

local function debugPrint(...)
    if not DEBUG_ENABLED then
        return
    end

    print("[BatataData]", ...)
end

local function cloneTable(source)
    if type(source) ~= "table" then
        return source
    end

    local copy = {}
    for key, value in pairs(source) do
        copy[key] = cloneTable(value)
    end
    return copy
end

local function getSortedKeys(tbl)
    local keys = {}
    if type(tbl) ~= "table" then
        return keys
    end

    for key in pairs(tbl) do
        table.insert(keys, tostring(key))
    end

    table.sort(keys)
    return keys
end

local function shouldMergeTables(oldValue, newValue)
    if type(oldValue) ~= "table" or type(newValue) ~= "table" then
        return false
    end

    return true
end

local function mergeTables(target, incoming)
    if type(incoming) ~= "table" then
        return incoming
    end

    if type(target) ~= "table" then
        return cloneTable(incoming)
    end

    local merged = cloneTable(target)

    for key, value in pairs(incoming) do
        if shouldMergeTables(merged[key], value) then
            merged[key] = mergeTables(merged[key], value)
        else
            merged[key] = cloneTable(value)
        end
    end

    return merged
end

local function normalizeAmount(value)
    return tonumber(value) or 0
end

local function buildCategorizedInventory()
    local categorized = {
        Potatoes = cloneTable(Data.PotatoInventory or {}),
        Items = cloneTable(Data.ItemInventory or {}),
        Backgrounds = cloneTable(Data.BackgroundInventory or {}),
        Relics = cloneTable(Data.RelicInventory or {}),
        Unknown = {},
        Locked = {
            Potatoes = cloneTable(Data.LockedPotatoes or {}),
            Backgrounds = cloneTable(Data.LockedBackgrounds or {}),
            Relics = cloneTable(Data.LockedRelics or {}),
        },
    }

    if type(inventoryDb) ~= "table" or type(inventoryDb.GetCategory) ~= "function" then
        return categorized
    end

    local sources = {
        Data.PotatoInventory,
        Data.ItemInventory,
        Data.BackgroundInventory,
        Data.RelicInventory,
    }

    for _, source in ipairs(sources) do
        if type(source) == "table" then
            for itemId, amount in pairs(source) do
                local category = inventoryDb:GetCategory(itemId)
                if category == nil then
                    categorized.Unknown[itemId] = normalizeAmount(amount)
                end
            end
        end
    end

    return categorized
end

local function rebuildDerivedData()
    Data.Inventory = buildCategorizedInventory()
end

local function updateData(payload)
    if type(payload) ~= "table" then
        return
    end

    local updatedInventory = false

    for key, value in pairs(payload) do
        local previousValue = Data[key]

        if type(value) == "table" then
            Data[key] = mergeTables(previousValue, value)
        else
            Data[key] = value
        end

        if key == "PotatoInventory"
            or key == "ItemInventory"
            or key == "BackgroundInventory"
            or key == "RelicInventory"
            or key == "LockedPotatoes"
            or key == "LockedBackgrounds"
            or key == "LockedRelics" then
            updatedInventory = true
        end
    end

    Data.LastUpdatedAt = os.clock()
    rebuildDerivedData()

    debugPrint("DataUpdated recebido")
    debugPrint("Chaves:", table.concat(getSortedKeys(payload), ", "))

    if updatedInventory then
        debugPrint("Inventario/tabelas de inventario atualizados")
    end
end

if Batata.DataConnection and Batata.DataConnection.Disconnect then
    pcall(function()
        Batata.DataConnection:Disconnect()
    end)
end

if not dataUpdatedRemote or not dataUpdatedRemote.OnClientEvent then
    recordBoot("data.lua", "DataUpdated remoto ausente")
    error("DataUpdated remoto ausente")
end

Batata.DataConnection = dataUpdatedRemote.OnClientEvent:Connect(function(payload)
    local ok, err = pcall(updateData, payload)
    if not ok then
        warn("[BatataData] erro ao processar DataUpdated: " .. tostring(err))
    end
end)
Batata.DataLoaded = true
Batata.LastEnsureDataError = nil
recordBoot("data.lua", "conectado")

return Data
