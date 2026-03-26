local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()
ROOT.Batata = Batata
_G.Batata = Batata

if Batata.Modules.AutoFusion then
    return Batata.Modules.AutoFusion
end

local remotes = Batata.Util.EnsureRemotes()
local itemDb = Batata.Util.EnsureItemDb()

local FUSION_DELAY = 1

local Module = {
    Running = true,
    Enabled = false,
    Delay = FUSION_DELAY,
    LastStatus = "Aguardando inventario",
    LastCandidate = nil,
    LastMessage = nil,
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

local function getPotatoInventory()
    local data = Batata.Data
    if type(data) ~= "table" then
        return nil
    end

    if type(data.PotatoInventory) == "table" then
        return data.PotatoInventory
    end

    if type(data.Inventory) == "table" and type(data.Inventory.Potatoes) == "table" then
        return data.Inventory.Potatoes
    end

    return nil
end

local function getLockedPotatoes()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    if type(data.LockedPotatoes) == "table" then
        return data.LockedPotatoes
    end

    if type(data.Inventory) == "table"
        and type(data.Inventory.Locked) == "table"
        and type(data.Inventory.Locked.Potatoes) == "table" then
        return data.Inventory.Locked.Potatoes
    end

    return {}
end

local function buildRarityBuckets()
    local inventory = getPotatoInventory()
    local locked = getLockedPotatoes()
    local buckets = {}

    if type(inventory) ~= "table" then
        return buckets
    end

    for potatoId, amount in pairs(inventory) do
        if locked[potatoId] ~= true then
            local info = itemDb.Get(potatoId)
            if info and info.Type == "Potato" then
                local rarity = info.Rarity or "unknown"
                local total = math.floor(math.max(0, tonumber(amount) or 0))
                local usable = math.max(0, total - 1)

                if usable > 0 then
                    buckets[rarity] = buckets[rarity] or {}
                    table.insert(buckets[rarity], {
                        Id = potatoId,
                        Count = total,
                        Usable = usable,
                    })
                end
            end
        end
    end

    for _, entries in pairs(buckets) do
        table.sort(entries, function(a, b)
            if a.Usable == b.Usable then
                return a.Id < b.Id
            end

            return a.Usable > b.Usable
        end)
    end

    return buckets
end

local function buildIdenticalTriplet(entries)
    if type(entries) ~= "table" or #entries == 0 then
        return nil
    end

    for _, entry in ipairs(entries) do
        if (entry.Usable or 0) >= 3 then
            return {
                entry.Id,
                entry.Id,
                entry.Id,
            }
        end
    end

    return nil
end

local function arrayContains(list, value)
    if type(list) ~= "table" then
        return false
    end

    for _, entry in ipairs(list) do
        if entry == value then
            return true
        end
    end

    return false
end

local function findFusionCandidate()
    local buckets = buildRarityBuckets()
    local rarityOrder = {
        "common",
        "uncommon",
        "rare",
        "epic",
        "legendary",
        "secret",
    }

    for _, rarity in ipairs(rarityOrder) do
        local entries = buckets[rarity]
        local triplet = buildIdenticalTriplet(entries)
        if triplet then
            return triplet, rarity
        end
    end

    for rarity, entries in pairs(buckets) do
        if not arrayContains(rarityOrder, rarity) then
            local triplet = buildIdenticalTriplet(entries)
            if triplet then
                return triplet, rarity
            end
        end
    end

    return nil, nil
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
end

function Module:SetDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.1 then
        self.Delay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.FusionDelay)
end

function Module:Toggle()
    self.Enabled = not self.Enabled
    return self.Enabled
end

function Module:GetState()
    local candidate, rarity = findFusionCandidate()

    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        HasCandidate = candidate ~= nil,
        Candidate = candidate,
        CandidateRarity = rarity,
        LastStatus = self.LastStatus,
        LastMessage = self.LastMessage,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    disconnectAll()
    if Batata.Modules.AutoFusion == self then
        Batata.Modules.AutoFusion = nil
    end
end

local fusionResultRemote = remotes:Get("FusionResult")
if fusionResultRemote and fusionResultRemote.OnClientEvent then
    table.insert(connections, fusionResultRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end

        Module.LastMessage = tostring(payload.Message or "")
        if payload.Success == true then
            Module.LastStatus = "Fusao concluida"
        else
            Module.LastStatus = tostring(payload.Message or "Falha na fusao")
        end
    end))
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            local remote = remotes:Get("FusePotatoes")
            local candidate = findFusionCandidate()

            if not remote then
                Module.LastStatus = "Remote ausente"
            elseif not candidate then
                Module.LastStatus = "Sem candidatos"
            else
                Module.LastCandidate = candidate
                Module.LastStatus = "Fazendo fusao"
                pcall(function()
                    remote:FireServer(candidate)
                end)
            end
        else
            Module.LastStatus = "Parado"
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoFusion = Module

return Module
