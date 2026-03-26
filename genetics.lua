local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()
ROOT.Batata = Batata
_G.Batata = Batata

if Batata.Modules.AutoGenetics then
    return Batata.Modules.AutoGenetics
end

local remotes = Batata.Util.EnsureRemotes()

local LOOP_DELAY = 1
local DEFAULT_ITEM = "potato_eyes"
local DEFAULT_SLOTS = { 3 }
local DEFAULT_RARITIES = { epic = true }
local DEFAULT_EFFECTS = { PrestigePointBonus = true }

local RARITY_ORDER = {
    common = 1,
    uncommon = 2,
    rare = 3,
    epic = 4,
    legendary = 5,
    mythic = 6,
    secret = 7,
}

local Module = {
    Running = true,
    Enabled = false,
    Delay = LOOP_DELAY,
    CurrencyItem = DEFAULT_ITEM,
    SelectedSlots = DEFAULT_SLOTS,
    SelectedRarities = DEFAULT_RARITIES,
    SelectedEffects = DEFAULT_EFFECTS,
    LastResult = nil,
    LastStatus = "Aguardando dados",
    LastSlotIndex = nil,
    LastEffectType = nil,
    LastRarity = nil,
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

local function splitCsv(value)
    local results = {}
    for part in string.gmatch(tostring(value or ""), "[^,%s]+") do
        table.insert(results, part)
    end
    return results
end

local function getItemInventory()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    if type(data.ItemInventory) == "table" then
        return data.ItemInventory
    end

    if type(data.Inventory) == "table" and type(data.Inventory.Items) == "table" then
        return data.Inventory.Items
    end

    return {}
end

local function hasCurrencyItem()
    local inventory = getItemInventory()
    return (tonumber(inventory[Module.CurrencyItem]) or 0) > 0
end

local function getCurrentSlots()
    local data = Batata.Data
    if type(data) ~= "table" then
        return {}
    end

    if type(data.GeneticsSlots) == "table" then
        return data.GeneticsSlots
    end

    local stats = data.Stats
    if type(stats) == "table" and type(stats.GeneticsSlots) == "table" then
        return stats.GeneticsSlots
    end

    return {}
end

local function getCurrentSlotData(slotIndex)
    local slots = getCurrentSlots()
    return slots[tostring(slotIndex)] or slots[slotIndex]
end

local function hasAnySelectedValues(tbl)
    if type(tbl) ~= "table" then
        return false
    end

    for _, enabled in pairs(tbl) do
        if enabled == true then
            return true
        end
    end

    return false
end

local function meetsTarget(result)
    if type(result) ~= "table" then
        return false
    end

    if hasAnySelectedValues(Module.SelectedEffects) then
        if Module.SelectedEffects[tostring(result.EffectType)] ~= true then
            return false
        end
    end

    if hasAnySelectedValues(Module.SelectedRarities) then
        if Module.SelectedRarities[string.lower(tostring(result.Rarity or ""))] ~= true then
            return false
        end
    end

    return true
end

local function sanitizeSlots(slots)
    local output = {}
    local seen = {}

    for _, slotValue in ipairs(slots) do
        local numberValue = math.max(1, math.min(8, math.floor(tonumber(slotValue) or 0)))
        if numberValue > 0 and not seen[numberValue] then
            seen[numberValue] = true
            table.insert(output, numberValue)
        end
    end

    if #output == 0 then
        for _, defaultSlot in ipairs(DEFAULT_SLOTS) do
            table.insert(output, defaultSlot)
        end
    end

    table.sort(output)
    return output
end

local function findSlotToRoll()
    for _, slotIndex in ipairs(Module.SelectedSlots) do
        local slotData = getCurrentSlotData(slotIndex)
        if not meetsTarget(slotData) then
            return slotIndex, slotData
        end
    end

    return Module.SelectedSlots[1], getCurrentSlotData(Module.SelectedSlots[1])
end

local function allSelectedSlotsMeetTarget()
    for _, slotIndex in ipairs(Module.SelectedSlots) do
        if not meetsTarget(getCurrentSlotData(slotIndex)) then
            return false
        end
    end

    return true
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    self.LastStatus = self.Enabled and "Rodando" or "Desligado"
end

function Module:Toggle()
    self:SetEnabled(not self.Enabled)
    return self.Enabled
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
    self:SetDelay(profile.GeneticsDelay)
end

function Module:SetSlot(index)
    self.SelectedSlots = sanitizeSlots({ index })
end

function Module:SetSelectedSlotsFromString(value)
    self.SelectedSlots = sanitizeSlots(splitCsv(value))
end

function Module:SetSlotEnabled(slotIndex, enabled)
    local selected = {}
    for _, value in ipairs(self.SelectedSlots) do
        selected[value] = true
    end

    local numberValue = math.max(1, math.min(8, math.floor(tonumber(slotIndex) or 0)))
    if numberValue <= 0 then
        return
    end

    selected[numberValue] = enabled == true

    local list = {}
    for value, isEnabled in pairs(selected) do
        if isEnabled then
            table.insert(list, value)
        end
    end

    self.SelectedSlots = sanitizeSlots(list)
end

function Module:SetTargetEffect(effectType)
    self.SelectedEffects = {}
    local clean = tostring(effectType or "")
    if clean ~= "" then
        self.SelectedEffects[clean] = true
    end
end

function Module:SetSelectedEffectsFromString(value)
    local selected = {}
    for _, token in ipairs(splitCsv(value)) do
        selected[tostring(token)] = true
    end
    self.SelectedEffects = selected
end

function Module:SetEffectEnabled(effectType, enabled)
    if type(effectType) ~= "string" or effectType == "" then
        return
    end

    self.SelectedEffects[effectType] = enabled == true
end

function Module:SetTargetRarity(rarity)
    self.SelectedRarities = {}
    local clean = string.lower(tostring(rarity or ""))
    if clean ~= "" then
        self.SelectedRarities[clean] = true
    end
end

function Module:SetSelectedRaritiesFromString(value)
    local selected = {}
    for _, token in ipairs(splitCsv(string.lower(tostring(value or "")))) do
        if RARITY_ORDER[token] then
            selected[token] = true
        end
    end
    self.SelectedRarities = selected
end

function Module:SetRarityEnabled(rarity, enabled)
    local key = string.lower(tostring(rarity or ""))
    if RARITY_ORDER[key] == nil then
        return
    end

    self.SelectedRarities[key] = enabled == true
end

function Module:GetState()
    local slotIndex, currentSlot = findSlotToRoll()

    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        CurrencyItem = self.CurrencyItem,
        SlotIndex = slotIndex,
        SelectedSlots = self.SelectedSlots,
        SelectedEffects = self.SelectedEffects,
        SelectedRarities = self.SelectedRarities,
        LastResult = self.LastResult,
        LastStatus = self.LastStatus,
        CurrentSlot = currentSlot,
        LastSlotIndex = self.LastSlotIndex,
        LastEffectType = self.LastEffectType,
        LastRarity = self.LastRarity,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    disconnectAll()

    if Batata.Modules.AutoGenetics == self then
        Batata.Modules.AutoGenetics = nil
    end
end

local geneticsResultRemote = remotes:Get("GeneticsResult")
if geneticsResultRemote and geneticsResultRemote.OnClientEvent then
    table.insert(connections, geneticsResultRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" or type(payload.Result) ~= "table" then
            return
        end

        Module.LastResult = payload.Result
        Module.LastSlotIndex = tonumber(payload.SlotIndex) or Module.LastSlotIndex
        Module.LastEffectType = payload.Result.EffectType
        Module.LastRarity = payload.Result.Rarity

        if meetsTarget(payload.Result) then
            Module.LastStatus = "Alvo encontrado"
        else
            Module.LastStatus = "Rolando"
        end
    end))
end

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            local rollRemote = remotes:Get("GeneticsRollSlot")
            local slotIndex, currentSlot = findSlotToRoll()

            if not rollRemote then
                Module.LastStatus = "Remote ausente"
            elseif not hasCurrencyItem() then
                Module.LastStatus = "Sem potato_eyes"
            elseif allSelectedSlotsMeetTarget() then
                Module.LastStatus = "Alvos encontrados"
            else
                Module.LastStatus = "Rolando slot " .. tostring(slotIndex)
                pcall(function()
                    rollRemote:FireServer(slotIndex, Module.CurrencyItem)
                end)
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoGenetics = Module

return Module
