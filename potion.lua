local Batata = _G.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()

if Batata.Modules.AutoPotion then
    return Batata.Modules.AutoPotion
end

local remotes = Batata.Util.EnsureRemotes()

local LOOP_DELAY = 2
local REFRESH_WINDOW = 30
local POTION_ORDER = {
    { ItemId = "potion_click", BuffKey = "click", Label = "Click" },
    { ItemId = "potion_golden", BuffKey = "golden", Label = "Golden" },
    { ItemId = "potion_luck", BuffKey = "luck", Label = "Luck" },
    { ItemId = "potion_drop_chance", BuffKey = "drop_chance", Label = "Drop Chance" },
    { ItemId = "potion_production", BuffKey = "production", Label = "Production" },
}

local Module = {
    Running = true,
    Enabled = false,
    Delay = LOOP_DELAY,
    UseDelay = 0.25,
    Buffs = {},
    LastStatus = "Aguardando buffs",
    SelectedPotions = {},
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
    return os.time()
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

local function hasPotion(itemId)
    local inventory = getItemInventory()
    return (tonumber(inventory[itemId]) or 0) > 0
end

local function getBuff(buffKey)
    local buff = Module.Buffs[buffKey]
    if type(buff) ~= "table" then
        return nil
    end

    return buff
end

local function isPotionSelected(itemId)
    if next(Module.SelectedPotions) == nil then
        return true
    end

    return Module.SelectedPotions[itemId] == true
end

local function shouldUsePotion(entry)
    if type(entry) ~= "table" or not isPotionSelected(entry.ItemId) then
        return false
    end

    if not hasPotion(entry.ItemId) then
        return false
    end

    local buff = getBuff(entry.BuffKey)
    if not buff then
        return true
    end

    local expiresAt = tonumber(buff.ExpiresAt) or 0
    return expiresAt <= (getNow() + REFRESH_WINDOW)
end

local function setDefaultSelections()
    for _, entry in ipairs(POTION_ORDER) do
        Module.SelectedPotions[entry.ItemId] = true
    end
end

local function splitCsv(value)
    local results = {}
    for part in string.gmatch(string.lower(tostring(value or "")), "[^,%s]+") do
        table.insert(results, part)
    end
    return results
end

setDefaultSelections()

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
    if numberValue and numberValue >= 0.5 then
        self.Delay = numberValue
    end
end

function Module:SetUseDelay(value)
    local numberValue = tonumber(value)
    if numberValue and numberValue >= 0.1 then
        self.UseDelay = numberValue
    end
end

function Module:ApplyDelayProfile(profile, profileName)
    if type(profile) ~= "table" then
        return
    end

    self.DelayProfile = profileName
    self:SetDelay(profile.PotionDelay)
    self:SetUseDelay(profile.PotionUseDelay)
end

function Module:SetPotionEnabled(itemId, enabled)
    if type(itemId) ~= "string" or itemId == "" then
        return
    end

    self.SelectedPotions[itemId] = enabled == true
end

function Module:SetSelectedPotionsFromString(value)
    local tokens = splitCsv(value)
    local selected = {}

    for _, entry in ipairs(POTION_ORDER) do
        selected[entry.ItemId] = false
    end

    for _, token in ipairs(tokens) do
        if token == "click" or token == "potion_click" then
            selected.potion_click = true
        elseif token == "golden" or token == "potion_golden" then
            selected.potion_golden = true
        elseif token == "luck" or token == "potion_luck" then
            selected.potion_luck = true
        elseif token == "drop" or token == "drop_chance" or token == "potion_drop_chance" then
            selected.potion_drop_chance = true
        elseif token == "production" or token == "potion_production" then
            selected.potion_production = true
        end
    end

    self.SelectedPotions = selected
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        UseDelay = self.UseDelay,
        LastStatus = self.LastStatus,
        Buffs = self.Buffs,
        SelectedPotions = self.SelectedPotions,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    disconnectAll()

    if Batata.Modules.AutoPotion == self then
        Batata.Modules.AutoPotion = nil
    end
end

local potionBuffRemote = remotes:Get("PotionBuffUpdated")
if potionBuffRemote and potionBuffRemote.OnClientEvent then
    table.insert(connections, potionBuffRemote.OnClientEvent:Connect(function(payload)
        if type(payload) ~= "table" then
            return
        end

        if type(payload.ActivePotionBuffs) == "table" then
            Module.Buffs = payload.ActivePotionBuffs
            Module.LastStatus = tostring(payload.Message or "Buff atualizado")
        end
    end))
end

task.spawn(function()
    while Module.Running do
        if Module.Enabled then
            local usePotionRemote = remotes:Get("UsePotion")

            if not usePotionRemote then
                Module.LastStatus = "Remote ausente"
            else
                local usedAny = false

                for _, entry in ipairs(POTION_ORDER) do
                    if shouldUsePotion(entry) then
                        Module.LastStatus = "Usando " .. entry.ItemId
                        pcall(function()
                            usePotionRemote:FireServer(entry.ItemId)
                        end)
                        usedAny = true
                        task.wait(Module.UseDelay)
                    end
                end

                if not usedAny then
                    Module.LastStatus = "Buffs ativos"
                end
            end
        end

        task.wait(Module.Delay)
    end
end)

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

Batata.Modules.AutoPotion = Module

return Module
