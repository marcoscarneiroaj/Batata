local ReplicatedStorage = game:GetService("ReplicatedStorage")

_G.Batata = _G.Batata or {}

local Batata = _G.Batata
Batata.Data = Batata.Data or {}
Batata.Remotes = Batata.Remotes or (Batata.Util and Batata.Util.LoadFile and Batata.Util.LoadFile("remotes.lua"))
Batata.DB = Batata.DB or {}
Batata.DB.Inventory = Batata.DB.Inventory or (Batata.Util and Batata.Util.LoadFile and Batata.Util.LoadFile("inventorydb.lua"))

local Data = Batata.Data
local dataUpdatedRemote = Batata.Remotes.DataUpdated
local inventoryDb = Batata.DB.Inventory

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

if Batata.DataConnection and Batata.DataConnection.Connected then
    Batata.DataConnection:Disconnect()
end

Batata.DataConnection = dataUpdatedRemote.OnClientEvent:Connect(function(payload)
    local ok, err = pcall(updateData, payload)
    if not ok then
        warn("[BatataData] erro ao processar DataUpdated: " .. tostring(err))
    end
end)

return Data
