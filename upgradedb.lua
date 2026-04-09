local ROOT = getgenv and getgenv() or _G
ROOT.Batata = ROOT.Batata or {}
_G.Batata = ROOT.Batata

local Batata = ROOT.Batata
Batata.DB = Batata.DB or {}

if Batata.DB.UpgradeDB then
    return Batata.DB.UpgradeDB
end

local KnownUpgrades = {
    -- Custos observados na UI atual do jogo com o desconto atual ja aplicado.
    { Id = "the_final_click", Cost = 209000000000000000000, Max = 2, Gain = 15000000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "infinity_finger_poke", Cost = 41800000000000000000, Max = 2, Gain = 5000000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "big_bang_click", Cost = 8360000000000000000, Max = 2, Gain = 1600000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "galaxy_tap", Cost = 1672000000000000000, Max = 2, Gain = 500000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "omnifinger", Cost = 418000000000000000, Max = 2, Gain = 170000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "mind_click", Cost = 83600000000000000, Max = 2, Gain = 55000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "magical_foam_finger", Cost = 16720000000000000, Max = 2, Gain = 20000000, CostKnownLevels = 1, PriorityProbe = true },
    { Id = "finger_of_god", Cost = 3344000000000000, Growth = 2.50, Max = 2, Gain = 10000000 },
    { Id = "singularity_tap", Cost = 836000000000000, Growth = 2.40, Max = 3, Gain = 3000000 },
    { Id = "omniversal_click", Cost = 167200000000000, Growth = 2.30, Max = 4, Gain = 1000000 },
    { Id = "infinite_potato_mastery", Cost = 41800000000000, Growth = 2.20, Max = 5, Gain = 350000 },
    { Id = "universal_potato_power", Cost = 4180000000000, Growth = 2.10, Max = 6, Gain = 120000 },
    { Id = "galactic_harvest", Cost = 836000000000, Growth = 2.00, Max = 8, Gain = 40000 },
    { Id = "transcendent_harvest", Cost = 125400000000, Growth = 2.00, Max = 8, Gain = 15000 },
    { Id = "omnipotato_blessing", Cost = 12540000000, Growth = 1.95, Max = 10, Gain = 5000 },
    { Id = "infinite_energy", Cost = 1254000000, Growth = 1.90, Max = 12, Gain = 2000 },
    { Id = "dimensional_reach", Cost = 225720000, Growth = 1.85, Max = 15, Gain = 800 },
    { Id = "lunar_planting", Cost = 25080000, Growth = 1.80, Max = 18, Gain = 300 },
    { Id = "grandfathers_wisdom", Cost = 2090000, Growth = 1.75, Max = 22, Gain = 120 },
    { Id = "advanced_techniques", Cost = 710600, Growth = 1.70, Max = 25, Gain = 50 },
    { Id = "farmers_instinct", Cost = 125400, Growth = 1.65, Max = 30, Gain = 25 },
    { Id = "golden_trowel", Cost = 45980, Growth = 1.62, Max = 32, Gain = 15 },
    { Id = "steel_trowel", Cost = 10032, Growth = 1.60, Max = 35, Gain = 8 },
    { Id = "padded_gloves", Cost = 3344, Growth = 1.55, Max = 40, Gain = 3 },
    { Id = "stronger_hands", Cost = 836, Growth = 1.50, Max = 50, Gain = 1 },
    { Id = "golden_enlightenment", Cost = 418000000, Growth = 5.00, Max = 5, Gain = 0.60 },
    { Id = "gilded_instinct", Cost = 4180000, Growth = 4.50, Max = 8, Gain = 0.40 },
    { Id = "midas_touch", Cost = 83600, Growth = 4.00, Max = 10, Gain = 0.25 },
    { Id = "lucky_fertilizer", Cost = 4180, Growth = 3.50, Max = 15, Gain = 0.15 },
    { Id = "golden_touch", Cost = 167, Growth = 3.00, Max = 20, Gain = 0.10 },
    { Id = "prize_winning_seeds", Cost = 62700, Growth = 4.50, Max = 12, Gain = 20 },
    { Id = "premium_fertilizer", Cost = 8360, Growth = 4.00, Max = 15, Gain = 10 },
    { Id = "collectors_guidebook", Cost = 1254, Growth = 3.50, Max = 20, Gain = 5 },
}

local RetryOnlyUpgrades = {
    { Id = "runic_soil", Max = 10, RetryOnly = true, PriorityProbe = true },
    { Id = "enchanted_peeler", Max = 10, RetryOnly = true, PriorityProbe = true },
    { Id = "archmages_blessing", Max = 10, RetryOnly = true, PriorityProbe = true },
    { Id = "arcane_awakening", Max = 10, RetryOnly = true, PriorityProbe = true },
}

local ById = {}
local AllUpgrades = {}

for index, upgrade in ipairs(KnownUpgrades) do
    upgrade.Index = index
    ById[upgrade.Id] = upgrade
    table.insert(AllUpgrades, upgrade)
end

for index, upgrade in ipairs(RetryOnlyUpgrades) do
    upgrade.Index = #KnownUpgrades + index
    ById[upgrade.Id] = upgrade
    table.insert(AllUpgrades, upgrade)
end

local DB = {
    List = AllUpgrades,
    KnownList = KnownUpgrades,
    RetryList = RetryOnlyUpgrades,
    ById = ById,
}

function DB:Get(id)
    return self.ById[id]
end

function DB:IsRetryOnly(id, level)
    local upgrade = self:Get(id)
    if not upgrade then
        return true
    end

    if upgrade.RetryOnly == true then
        return true
    end

    local knownLevels = tonumber(upgrade.CostKnownLevels)
    if knownLevels then
        local currentLevel = math.max(0, math.floor(tonumber(level) or 0))
        return currentLevel >= knownLevels
    end

    return false
end

function DB:GetCurrentCost(id, level)
    local upgrade = self:Get(id)
    if not upgrade or self:IsRetryOnly(id, level) then
        return math.huge
    end

    local currentLevel = math.max(0, math.floor(tonumber(level) or 0))

    if upgrade.Growth == nil then
        return upgrade.Cost
    end

    return upgrade.Cost * (upgrade.Growth ^ currentLevel)
end

function DB:GetRemoteCost(id, level)
    if not Batata.Util or type(Batata.Util.TryGetRemoteNumber) ~= "function" then
        return nil
    end

    local keys = { "Cost", "CurrentCost", "Price", "Value" }
    local currentLevel = math.max(0, math.floor(tonumber(level) or 0))

    local response = Batata.Util.TryGetRemoteNumber("GetUpgradeCost", keys, id)
    if response ~= nil then
        return response
    end

    response = Batata.Util.TryGetRemoteNumber("GetUpgradeCost", keys, id, currentLevel)
    if response ~= nil then
        return response
    end

    return nil
end

Batata.DB.UpgradeDB = DB

return DB
