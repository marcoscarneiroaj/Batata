local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ROOT = getgenv and getgenv() or _G
local GUI_NAME = "FormigaAutomationGui"
local STATE_KEY = "__FormigaAutomationState"
local RUN_KEY = "__FormigaAutomationRunId"

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")

if type(ROOT[STATE_KEY]) == "table" and type(ROOT[STATE_KEY].Stop) == "function" then
    pcall(function()
        ROOT[STATE_KEY]:Stop()
    end)
end

ROOT[RUN_KEY] = (tonumber(ROOT[RUN_KEY]) or 0) + 1
local currentRunId = ROOT[RUN_KEY]

local ASCENSION_RESERVE_TEXT = "143Qn"
local ASCENSION_RESERVE_START_RATIO = 0.85
local DEFAULT_ENABLED_EVENTS = {
    auto_click = true,
    auto_ascension = true,
    auto_upgrade_all = true,
    auto_generators = true,
    auto_pack_shop = true,
    auto_rune_upgrade = true,
    auto_runes = true,
    auto_reincarnation = true,
    auto_reincarnation_upgrade = true,
}

local UPGRADE_ALL_BATCH = {
    { Id = "AngelicClick", Amount = 100 },
    { Id = "DemonicClick", Amount = 100 },
    { Id = "RichUncle", Amount = 100 },
    { Id = "GigaClick", Amount = 100 },
    { Id = "UltraClick", Amount = 100 },
    { Id = "MegaClick", Amount = 100 },
    { Id = "BasicClick", Amount = 100 },
}

local GENERATOR_BATCH = {
    { Id = "FireAnt", Amount = 100 },
    { Id = "AntQueen", Amount = 100 },
    { Id = "ColonyMind", Amount = 100 },
    { Id = "HarvesterAnt", Amount = 100 },
    { Id = "SoldierAnt", Amount = 100 },
    { Id = "DoubleAnt", Amount = 100 },
    { Id = "CarrierAnt", Amount = 100 },
    { Id = "CommanderAnt", Amount = 100 },
    { Id = "QueenGuard", Amount = 100 },
}

local RUNE_UPGRADE_BATCH = {
    { Id = "RuneBulk", Amount = 6 },
    { Id = "RuneSpeed", Amount = 8 },
}

local RUNE_SET_OPTIONS = {
    { Id = "CityRunes", Label = "City" },
    { Id = "CaveRunes", Label = "Cave" },
    { Id = "SwampRunes", Label = "Swamp" },
    { Id = "DesertRunes", Label = "Desert" },
    { Id = "ForestRunes", Label = "Forest" },
    { Id = "OceanRunes", Label = "Ocean" },
}

local RUNE_SET_PROGRESS_RULES = {
    CityRunes = {
        { Id = "ConcreteRune", Patterns = { "concrete rune" } },
        { Id = "RebarRune", Patterns = { "rebar rune" } },
        { Id = "NeonRune", Patterns = { "neon rune" } },
        { Id = "CircuitRune", Patterns = { "circuit rune" } },
        { Id = "SkyscraperCore", Patterns = { "skyscraper core", "skyscraper rune" } },
        { Id = "GridHeart", Patterns = { "grid heart", "gridheart rune" } },
    },
    CaveRunes = {
        { Id = "PebbleRune", Patterns = { "pebble rune" } },
        { Id = "ShaleRune", Patterns = { "shale rune", "runa de xistos", "xistos" } },
        { Id = "QuartzRune", Patterns = { "quartz rune" } },
        { Id = "GeodeRune", Patterns = { "geode rune" } },
        { Id = "ObsidianCore", Patterns = { "obsidian core", "obsidianrune2", "obsidian rune" } },
        { Id = "CrystalHeart", Patterns = { "crystal heart", "crystalheart rune" } },
    },
    SwampRunes = {
        { Id = "BogRune", Patterns = { "bog rune", "runa de brejo" } },
        { Id = "MireRune", Patterns = { "mire rune", "runa de mira" } },
        { Id = "SporeRune", Patterns = { "spore rune", "runa de esporos" } },
        { Id = "MossheartRune", Patterns = { "mossheart rune", "runa de coracao de musgo" } },
        { Id = "BogfatherRune", Patterns = { "bogfather rune", "runa do pai do brejo" } },
        { Id = "SwampSpiritRune", Patterns = { "swamp spirit", "swamp spirit rune" } },
    },
    DesertRunes = {
        { Id = "SandRune", Patterns = { "sand rune", "runa de areia" } },
        { Id = "DuneRune", Patterns = { "dune rune", "runa de duna" } },
        { Id = "MirageRune", Patterns = { "mirage rune", "runa de miragem" } },
        { Id = "ScarabRune", Patterns = { "scarab rune", "runa de escaravelho" } },
        { Id = "ObeliskRune", Patterns = { "obelisk rune", "runa de obelisco" } },
        { Id = "DesertWraith", Patterns = { "desert wraith", "espectro do deserto", "desertwraith rune" } },
    },
    ForestRunes = {
        { Id = "LeafRune", Patterns = { "leaf rune", "runa de folha" } },
        { Id = "BarkRune", Patterns = { "bark rune", "runa de casco" } },
        { Id = "MossRune", Patterns = { "moss rune", "runa de musgo" } },
        { Id = "AmberRune", Patterns = { "amber rune", "runa de ambar" } },
        { Id = "AncientRoot", Patterns = { "ancient root", "raiz antiga", "ancientroot rune" } },
        { Id = "ForestSpirit", Patterns = { "forest spirit", "espirito da floresta" } },
    },
    OceanRunes = {
        { Id = "ShellRune", Patterns = { "shell rune" } },
        { Id = "KelpRune", Patterns = { "kelp rune" } },
        { Id = "CoralRune", Patterns = { "coral rune" } },
        { Id = "PearlRune", Patterns = { "pearl rune" } },
        { Id = "TridentRune", Patterns = { "trident rune" } },
        { Id = "LeviathanHeart", Patterns = { "leviathan heart", "leviathan rune" } },
    },
}

local RUNE_CYCLE_SECONDS = 3
local PURCHASE_BURST_SECONDS = 10
local PURCHASE_PAUSE_SECONDS = 20
local PURCHASE_SPAM_DELAY = 0.05
local COMBAT_LOOP_SECONDS = 3
local COMBAT_WORLD_MIN = 1
local COMBAT_WORLD_MAX = 20
local COMBAT_FOREST_MIN = 1
local COMBAT_FOREST_MAX = 3
local COMBAT_DIFFICULTIES = { "Easy", "Hard", "Demonic", "Impossible" }
local COMBAT_SKIP_TOKEN = "BattleSkip5"
local REINCARNATION_SKILL_PRIORITY = {
    "PerClick",
    "PerClick",
    "PerClick",
    "PerClick",
    "PerClick",
    "PerClick",
    "GemsMulti",
    "WorldRoll",
    "RuneCap",
}
local EXCLUSIVE_FIGHT_EVENT_IDS = {
    auto_fight_progress = true,
    auto_fight_single = true,
    auto_fight_skip5 = true,
}

local MINE_ROUTES = {
    {
        Slot = "1",
        Area = "CrystalCavern",
        Duration = "1h",
    },
    {
        Slot = "2",
        Area = "CrystalCavern",
        Duration = "1h",
    },
    {
        Slot = "3",
        Area = "CrystalCavern",
        Duration = "1h",
    },
}

local UI_RESOURCE_PATHS = {
    Food = {
        {
            "MainUI", "MainHolder", "StatsSidebar", "StatsHolder",
            "Currencies", "CurrenciesHolder", "FoodFrame", "ValueLabel",
        },
        {
            "MainUI", "MainHolder", "HomeWindow", "HomeFrame",
            "BalanceFrame", "BalanceHolder", "FoodFrame", "ValueLabel",
        },
    },
    Coins = {
        {
            "MainUI", "MainHolder", "StatsSidebar", "StatsHolder",
            "Currencies", "CurrenciesHolder", "CoinsFrame", "ValueLabel",
        },
        {
            "MainUI", "MainHolder", "HomeWindow", "HomeFrame",
            "BalanceFrame", "BalanceHolder", "CoinsFrame", "ValueLabel",
        },
    },
}

local NUMBER_SUFFIX_POWERS = {
    qn = 15,
    vg = 63,
    nd = 60,
    od = 57,
    sd = 54,
    qid = 51,
    qad = 48,
    dd = 45,
    ud = 42,
    dc = 39,
    no = 36,
    oc = 33,
    sp = 30,
    sx = 27,
    qi = 24,
    qa = 21,
    qt = 18,
    qd = 15,
    t = 12,
    b = 9,
    m = 6,
    k = 3,
}

local function cloneBatch(batch)
    local payload = {}
    for index, entry in ipairs(batch) do
        payload[index] = {
            Id = entry.Id,
            Amount = entry.Amount,
        }
    end
    return payload
end

local findRemote
local hasRemote
local safeFire
local safeInvoke
local connectRaidListener
local connectShopRestockListener
local state
local refreshRuneButtons
local refreshCombatConfigUi
local setActiveTab
local cachedEventsFolder
local remoteCache = {}

local function clonePath(pathParts)
    local copy = {}
    for index, value in ipairs(pathParts) do
        copy[index] = value
    end
    return copy
end

local function appendPath(pathParts, ...)
    local newPath = clonePath(pathParts)
    local offset = #newPath
    local extra = table.pack(...)
    for index = 1, extra.n do
        newPath[offset + index] = extra[index]
    end
    return newPath
end

local function getUiByPath(root, pathParts)
    local current = root
    for _, part in ipairs(pathParts) do
        if not current then
            return nil
        end
        current = current:FindFirstChild(part)
    end
    return current
end

local function stripRichText(text)
    text = tostring(text or "")
    text = text:gsub("<.->", "")
    text = text:gsub("&nbsp;", " ")
    return text
end

local function normalizeSearchText(text)
    text = stripRichText(text)
    text = string.lower(text)
    text = text
        :gsub("á", "a")
        :gsub("à", "a")
        :gsub("â", "a")
        :gsub("ã", "a")
        :gsub("ä", "a")
        :gsub("é", "e")
        :gsub("è", "e")
        :gsub("ê", "e")
        :gsub("ë", "e")
        :gsub("í", "i")
        :gsub("ì", "i")
        :gsub("î", "i")
        :gsub("ï", "i")
        :gsub("ó", "o")
        :gsub("ò", "o")
        :gsub("ô", "o")
        :gsub("õ", "o")
        :gsub("ö", "o")
        :gsub("ú", "u")
        :gsub("ù", "u")
        :gsub("û", "u")
        :gsub("ü", "u")
        :gsub("ç", "c")
    text = text:gsub("%s+", " ")
    return text
end

local function parseCompactNumber(text)
    text = stripRichText(text)
    text = text:gsub("%s+", "")
    text = text:gsub(",", "")
    text = text:gsub("^%+", "")
    text = text:gsub("^x", "")

    if text == "" then
        return nil
    end

    local lowered = string.lower(text)
    if lowered == "max" or lowered == "maximo" then
        return nil
    end

    local numericOnly = tonumber(text)
    if numericOnly then
        return numericOnly
    end

    local numberPart, suffix = text:match("^([%d%.]+)([%a]+)$")
    if not numberPart or not suffix then
        return nil
    end

    local baseValue = tonumber(numberPart)
    local power = NUMBER_SUFFIX_POWERS[string.lower(suffix)]
    if not baseValue or not power then
        return nil
    end

    return baseValue * (10 ^ power)
end

local function readUiText(pathParts)
    local instance = getUiByPath(playerGui, pathParts)
    if not instance then
        return nil
    end

    if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
        return instance.Text
    end

    return nil
end

local function readResourceValue(resourceName)
    local pathOptions = UI_RESOURCE_PATHS[resourceName]
    if type(pathOptions) ~= "table" then
        return nil
    end

    local firstValue = pathOptions[1]
    if type(firstValue) == "string" then
        return parseCompactNumber(readUiText(pathOptions))
    end

    for _, pathParts in ipairs(pathOptions) do
        local parsed = parseCompactNumber(readUiText(pathParts))
        if parsed then
            return parsed
        end
    end

    return nil
end

local function getAscensionReserveValue()
    return parseCompactNumber(ASCENSION_RESERVE_TEXT)
end

local function shouldHoldFoodForAscension()
    local currentFood = readResourceValue("Food")
    local reserveValue = getAscensionReserveValue()

    if not currentFood or not reserveValue or reserveValue <= 0 then
        return false, currentFood, reserveValue
    end

    local holdThreshold = reserveValue * ASCENSION_RESERVE_START_RATIO
    if currentFood >= holdThreshold then
        return true, currentFood, reserveValue
    end

    return false, currentFood, reserveValue
end

local function isAutomationEnabled(eventId)
    if type(state) ~= "table" or state.Running ~= true or state.RunId ~= ROOT[RUN_KEY] then
        return false
    end

    local eventState = state.EventStates and state.EventStates[eventId]
    return eventState and eventState.Enabled == true
end

local function waitWhileAutomationEnabled(eventId, seconds)
    local deadline = tick() + (tonumber(seconds) or 0)

    while tick() < deadline do
        if not isAutomationEnabled(eventId) then
            return false
        end

        task.wait(math.min(0.25, math.max(0, deadline - tick())))
    end

    return true
end

local function resetPurchaseCycle()
    if type(state) == "table" then
        state.PurchaseCycleStartedAt = tick()
    end
end

local function getSortedKeys(sourceTable)
    local keys = {}
    if type(sourceTable) ~= "table" then
        return keys
    end

    for key in pairs(sourceTable) do
        table.insert(keys, key)
    end

    table.sort(keys, function(left, right)
        return tostring(left) < tostring(right)
    end)

    return keys
end

local function buildShopPurchaseQueue(stockData)
    local queue = {}
    if type(stockData) ~= "table" then
        return queue
    end

    for _, groupName in ipairs(getSortedKeys(stockData)) do
        local groupStock = stockData[groupName]
        if type(groupStock) == "table" then
            for _, packName in ipairs(getSortedKeys(groupStock)) do
                local amount = math.max(0, math.floor(tonumber(groupStock[packName]) or 0))
                if amount > 0 then
                    table.insert(queue, {
                        Group = tostring(groupName),
                        Pack = tostring(packName),
                        Amount = amount,
                    })
                end
            end
        end
    end

    return queue
end

local function getShopRestockSignature(stockData, restockAt, refreshSeconds)
    local signatureParts = {
        tostring(math.floor(tonumber(restockAt) or 0)),
        tostring(math.floor(tonumber(refreshSeconds) or 0)),
    }

    for _, groupName in ipairs(getSortedKeys(stockData)) do
        local groupStock = stockData[groupName]
        if type(groupStock) == "table" then
            for _, packName in ipairs(getSortedKeys(groupStock)) do
                local amount = math.max(0, math.floor(tonumber(groupStock[packName]) or 0))
                table.insert(signatureParts, string.format("%s/%s=%d", tostring(groupName), tostring(packName), amount))
            end
        end
    end

    return table.concat(signatureParts, "|")
end

local function countEnabledRuneSets()
    if type(state) ~= "table" then
        return #RUNE_SET_OPTIONS
    end

    local total = 0
    local enabledMap = state.RuneSetEnabled or {}
    for _, option in ipairs(RUNE_SET_OPTIONS) do
        if enabledMap[option.Id] ~= false then
            total += 1
        end
    end

    return total
end

local function getEnabledRuneSets()
    local enabledSets = {}
    local enabledMap = type(state) == "table" and (state.RuneSetEnabled or {}) or {}

    for _, option in ipairs(RUNE_SET_OPTIONS) do
        if enabledMap[option.Id] ~= false then
            table.insert(enabledSets, option.Id)
        end
    end

    return enabledSets
end

local function toggleRuneSetEnabled(runeSetId)
    if type(state) ~= "table" then
        return
    end

    state.RuneSetEnabled = state.RuneSetEnabled or {}

    local currentlyEnabled = state.RuneSetEnabled[runeSetId] ~= false
    if currentlyEnabled and countEnabledRuneSets() <= 1 then
        return
    end

    state.RuneSetEnabled[runeSetId] = not currentlyEnabled
end

local function getCombatMaxForest(worldIndex)
    worldIndex = tonumber(worldIndex) or COMBAT_WORLD_MIN
    if worldIndex == 3 then
        return 2
    end
    return 3
end

local function getCombatMaxMob(worldIndex, forestIndex)
    worldIndex = tonumber(worldIndex) or COMBAT_WORLD_MIN
    forestIndex = tonumber(forestIndex) or COMBAT_FOREST_MIN

    if worldIndex == 3 then
        return 4
    end

    if worldIndex >= 4 then
        if forestIndex <= 2 then
            return 4
        end
        return 5
    end

    if forestIndex <= 1 then
        return 4
    end
    return 5
end

local function getCombatDifficulty()
    local config = type(state) == "table" and state.CombatConfig or nil
    local difficultyIndex = config and tonumber(config.DifficultyIndex) or 1
    difficultyIndex = math.clamp(difficultyIndex, 1, #COMBAT_DIFFICULTIES)
    return COMBAT_DIFFICULTIES[difficultyIndex], difficultyIndex
end

local function normalizeCombatConfig()
    if type(state) ~= "table" then
        return nil
    end

    state.CombatConfig = state.CombatConfig or {}
    local config = state.CombatConfig
    config.World = math.clamp(tonumber(config.World) or COMBAT_WORLD_MIN, COMBAT_WORLD_MIN, COMBAT_WORLD_MAX)
    local maxForest = getCombatMaxForest(config.World)
    config.Forest = math.clamp(tonumber(config.Forest) or COMBAT_FOREST_MIN, COMBAT_FOREST_MIN, maxForest)

    local maxMob = getCombatMaxMob(config.World, config.Forest)
    config.Mob = math.clamp(tonumber(config.Mob) or 1, 1, maxMob)
    config.DifficultyIndex = math.clamp(tonumber(config.DifficultyIndex) or 1, 1, #COMBAT_DIFFICULTIES)

    if config.SequenceNextMob == nil then
        config.SequenceNextMob = config.Mob
    end
    config.SequenceNextMob = math.clamp(tonumber(config.SequenceNextMob) or config.Mob, 1, maxMob)
    return config
end

local function changeCombatNumber(fieldName, delta, minValue, maxValue)
    local config = normalizeCombatConfig()
    if not config then
        return
    end

    config[fieldName] = (tonumber(config[fieldName]) or minValue) + delta
    if config[fieldName] > maxValue then
        config[fieldName] = minValue
    elseif config[fieldName] < minValue then
        config[fieldName] = maxValue
    end

    if fieldName == "World" then
        local maxForest = getCombatMaxForest(config.World)
        config.Forest = math.clamp(config.Forest, COMBAT_FOREST_MIN, maxForest)
    end

    if fieldName == "Forest" or fieldName == "World" then
        local maxMob = getCombatMaxMob(config.World, config.Forest)
        config.Mob = math.clamp(config.Mob, 1, maxMob)
    end

    config.SequenceNextMob = config.Mob
    if refreshCombatConfigUi then
        refreshCombatConfigUi()
    end
end

local function changeCombatDifficulty(delta)
    local config = normalizeCombatConfig()
    if not config then
        return
    end

    config.DifficultyIndex = config.DifficultyIndex + delta
    if config.DifficultyIndex > #COMBAT_DIFFICULTIES then
        config.DifficultyIndex = 1
    elseif config.DifficultyIndex < 1 then
        config.DifficultyIndex = #COMBAT_DIFFICULTIES
    end

    if refreshCombatConfigUi then
        refreshCombatConfigUi()
    end
end

local function resetFightProgression()
    if type(state) ~= "table" then
        return
    end

    local config = normalizeCombatConfig()
    local startWorld = config and math.clamp(tonumber(config.World) or 1, COMBAT_WORLD_MIN, COMBAT_WORLD_MAX) or 1
    local startForest = config and math.clamp(tonumber(config.Forest) or 1, COMBAT_FOREST_MIN, getCombatMaxForest(tonumber(config.World) or 1)) or 1

    state.FightProgress = {
        World = startWorld,
        Forest = startForest,
        Mob = 1,
        DifficultyIndex = 1,
    }
end

local function normalizeFightProgression()
    if type(state) ~= "table" then
        return nil
    end

    state.FightProgress = state.FightProgress or {}
    local progress = state.FightProgress
    progress.World = math.clamp(tonumber(progress.World) or 1, COMBAT_WORLD_MIN, COMBAT_WORLD_MAX)
    progress.Forest = math.clamp(tonumber(progress.Forest) or 1, COMBAT_FOREST_MIN, getCombatMaxForest(progress.World))

    local maxMob = getCombatMaxMob(progress.World, progress.Forest)
    progress.Mob = math.clamp(tonumber(progress.Mob) or 1, 1, maxMob)
    progress.DifficultyIndex = math.clamp(tonumber(progress.DifficultyIndex) or 1, 1, #COMBAT_DIFFICULTIES)
    return progress
end

local function getFightProgressDifficulty(progress)
    local difficultyIndex = math.clamp(tonumber(progress and progress.DifficultyIndex) or 1, 1, #COMBAT_DIFFICULTIES)
    return COMBAT_DIFFICULTIES[difficultyIndex], difficultyIndex
end

local function advanceFightProgression(progress)
    if type(progress) ~= "table" then
        return
    end

    progress.DifficultyIndex = (tonumber(progress.DifficultyIndex) or 1) + 1
    if progress.DifficultyIndex <= #COMBAT_DIFFICULTIES then
        return
    end

    progress.DifficultyIndex = 1
    progress.Mob = (tonumber(progress.Mob) or 1) + 1

    local maxMob = getCombatMaxMob(progress.World, progress.Forest)
    if progress.Mob <= maxMob then
        return
    end

    progress.Mob = 1
    progress.Forest = (tonumber(progress.Forest) or 1) + 1
    if progress.Forest <= getCombatMaxForest(progress.World) then
        return
    end

    progress.Forest = COMBAT_FOREST_MIN
    progress.World = (tonumber(progress.World) or 1) + 1
    if progress.World > COMBAT_WORLD_MAX then
        progress.World = COMBAT_WORLD_MIN
    end
end

local function performCombatStart(worldIndex, forestIndex, mobIndex, difficultyName)
    safeFire("CombatEvent", "Ready")
    task.wait(0.15)
    return safeFire("CombatEvent", "Start", worldIndex, forestIndex, mobIndex, difficultyName)
end

local function performCombatSkip(worldIndex, forestIndex, mobIndex, difficultyName, skipToken)
    safeFire("CombatEvent", "Stop", 0)
    task.wait(0.15)
    return safeFire("CombatEvent", "MultiSkip", worldIndex, forestIndex, mobIndex, difficultyName, skipToken)
end

local function bothPurchaseModulesEnabled()
    local generatorsOn = isAutomationEnabled("auto_generators")
    local upgradesOn = isAutomationEnabled("auto_upgrade_all")

    return generatorsOn and upgradesOn
end

local function getPurchaseCyclePhase()
    if type(state) ~= "table" then
        return "solo", 0
    end

    state.PurchaseCycleStartedAt = tonumber(state.PurchaseCycleStartedAt) or tick()

    local burstSeconds = PURCHASE_BURST_SECONDS
    local cycleSeconds = (PURCHASE_BURST_SECONDS * 2) + PURCHASE_PAUSE_SECONDS
    local elapsed = (tick() - state.PurchaseCycleStartedAt) % cycleSeconds

    if elapsed < burstSeconds then
        return "generators", burstSeconds - elapsed
    end

    if elapsed < burstSeconds * 2 then
        return "upgrades", (burstSeconds * 2) - elapsed
    end

    return "pause", cycleSeconds - elapsed
end

local function runPurchaseBurst(kind, batch, eventId)
    if not bothPurchaseModulesEnabled() then
        local holdSpending = shouldHoldFoodForAscension()
        if holdSpending then
            return true, "reservando comida para ascensao"
        end

        return safeFire("UpgradeEvent", cloneBatch(batch))
    end

    local phase = getPurchaseCyclePhase()
    if phase ~= kind then
        if phase == "pause" then
            return true, "pausa do ciclo"
        end

        return true, "fase " .. tostring(phase)
    end

    local attempts = 0

    while isAutomationEnabled(eventId) and bothPurchaseModulesEnabled() do
        local currentPhase = getPurchaseCyclePhase()
        if currentPhase ~= kind then
            break
        end

        local holdSpending = shouldHoldFoodForAscension()
        if holdSpending then
            return true, "reservando comida para ascensao"
        end

        local ok, err = safeFire("UpgradeEvent", cloneBatch(batch))
        if not ok then
            return false, err
        end

        attempts += 1
        task.wait(PURCHASE_SPAM_DELAY)
    end

    return true, string.format("%s tentativas=%d", kind, attempts)
end

local function getUpgradeBasePath(groupId, upgradeId)
    local groupConfig = UPGRADE_GROUP_CONFIG[groupId]
    if not groupConfig then
        return nil
    end

    return {
        "MainUI", "MainHolder", "HomeWindow", "UpgradesFrame",
        "MainHolder", "UpgradesHolder", groupConfig.Folder, "Holder", upgradeId,
    }
end

local function readUpgradeDescription(groupId, upgradeId)
    local basePath = getUpgradeBasePath(groupId, upgradeId)
    if not basePath then
        return nil
    end

    return stripRichText(readUiText(appendPath(basePath, "DescriptionLabel")))
end

local function readUpgradeCost(groupId, upgradeId)
    local basePath = getUpgradeBasePath(groupId, upgradeId)
    if not basePath then
        return nil
    end

    return parseCompactNumber(readUiText(appendPath(basePath, "BuyButtonHolder", "BuySingular")))
end

local function parseUpgradeGain(descriptionText)
    local description = string.lower(stripRichText(descriptionText))
    if description == "" then
        return nil
    end

    local perClickAmount = description:match("%+%s*([%d%.]+%s*[%a]*)%s+food%s+per%s+click")
    if not perClickAmount then
        perClickAmount = description:match("%+%s*([%d%.]+%s*[%a]*)%s+more%s+food%s+per%s+click")
    end
    if perClickAmount then
        return parseCompactNumber(perClickAmount), "per_click"
    end

    local perSecondAmount = description:match("%+%s*([%d%.]+%s*[%a]*)%s+food%s+per%s+second")
    if not perSecondAmount then
        perSecondAmount = description:match("%+%s*([%d%.]+%s*[%a]*)%s+more%s+food%s+per%s+second")
    end
    if perSecondAmount then
        return parseCompactNumber(perSecondAmount), "per_second"
    end

    return nil
end

local function chooseBestUpgrade(groupId, availableFood)
    local groupConfig = UPGRADE_GROUP_CONFIG[groupId]
    if not groupConfig then
        return nil
    end

    local bestUpgrade
    for _, upgradeId in ipairs(groupConfig.Upgrades) do
        local cost = readUpgradeCost(groupId, upgradeId)
        local description = readUpgradeDescription(groupId, upgradeId)
        local gain, gainType = parseUpgradeGain(description)

        if cost and gain and cost > 0 and availableFood >= cost then
            local score = gain / cost
            if (not bestUpgrade) or score > bestUpgrade.Score then
                bestUpgrade = {
                    Id = upgradeId,
                    Cost = cost,
                    Gain = gain,
                    GainType = gainType,
                    Score = score,
                    Description = description,
                }
            end
        end
    end

    return bestUpgrade
end

local function buyBestUpgradeByGroup(groupId, maxPurchases)
    local remote = findRemote("UpgradeEvent")
    if not remote then
        return false, "remote ausente"
    end

    local purchases = 0
    local lastUpgrade

    for _ = 1, maxPurchases do
        local availableFood = readResourceValue("Food")
        if not availableFood then
            break
        end

        local bestUpgrade = chooseBestUpgrade(groupId, availableFood)
        if not bestUpgrade then
            break
        end

        local ok, err = pcall(function()
            remote:FireServer(bestUpgrade.Id, 1)
        end)

        if not ok then
            return purchases > 0, tostring(err)
        end

        purchases += 1
        lastUpgrade = bestUpgrade
        task.wait(0.03)
    end

    if purchases == 0 then
        return true, "sem compra"
    end

    if lastUpgrade then
        return true, string.format("comprou %d | ultimo=%s", purchases, lastUpgrade.Id)
    end

    return true, string.format("comprou %d", purchases)
end

findRemote = function(name)
    local eventsFolder = cachedEventsFolder
    if not eventsFolder or eventsFolder.Parent ~= ReplicatedStorage then
        eventsFolder = ReplicatedStorage:FindFirstChild("Events")
        cachedEventsFolder = eventsFolder
        remoteCache = {}
    end

    if not eventsFolder then
        return nil
    end

    local cached = remoteCache[name]
    if cached ~= nil then
        if cached == false then
            return nil
        end

        if cached.Parent == eventsFolder then
            return cached
        end
    end

    local remote = eventsFolder:FindFirstChild(name)
    remoteCache[name] = remote or false
    return remote
end

hasRemote = function(name)
    return findRemote(name) ~= nil
end

safeFire = function(remoteName, ...)
    local remote = findRemote(remoteName)
    if not remote then
        return false, "remote ausente"
    end

    local argCount = select("#", ...)
    local args = argCount > 0 and table.pack(...) or nil

    local ok, err = pcall(function()
        if argCount == 0 then
            remote:FireServer()
            return
        end

        remote:FireServer(table.unpack(args, 1, args.n))
    end)

    if not ok then
        return false, tostring(err)
    end

    return true
end

safeInvoke = function(remoteName, ...)
    local remote = findRemote(remoteName)
    if not remote then
        return false, "remote ausente"
    end

    local argCount = select("#", ...)
    local args = argCount > 0 and table.pack(...) or nil

    local ok, result = pcall(function()
        if argCount == 0 then
            return remote:InvokeServer()
        end

        return remote:InvokeServer(table.unpack(args, 1, args.n))
    end)

    if not ok then
        return false, tostring(result)
    end

    return true, result
end

local popGoldenAnt
local trySendGoldenAnt

local EVENTS = {
    {
        Id = "auto_click",
        Category = "automation",
        Title = "Auto Click",
        Description = 'Executa Events.ClickEvent:FireServer() em loop.',
        ToggleKey = Enum.KeyCode.C,
        Delay = 0.01,
        RemoteNames = { "ClickEvent" },
        Run = function()
            return safeFire("ClickEvent")
        end,
    },
    {
        Id = "auto_combat_click",
        Category = "fight",
        Title = "Auto Click Combate",
        Description = 'Executa Events.CombatClick:FireServer() em loop.',
        ToggleKey = Enum.KeyCode.B,
        Delay = 0.01,
        RemoteNames = { "CombatClick" },
        Run = function()
            return safeFire("CombatClick")
        end,
    },
    {
        Id = "auto_fight_progress",
        Category = "fight",
        ManualOnly = true,
        Title = "Auto Luta 1x1",
        Description = "Comeca no mundo/floresta escolhidos, no Mob1 Easy, e fecha todas as dificuldades antes de avancar.",
        ToggleKey = Enum.KeyCode.F,
        Delay = COMBAT_LOOP_SECONDS,
        RemoteNames = { "CombatEvent" },
        Run = function()
            local progress = normalizeFightProgression()
            if not progress then
                return false, "progresso luta ausente"
            end

            local difficultyName = getFightProgressDifficulty(progress)
            local ok, err = performCombatStart(progress.World, progress.Forest, progress.Mob, difficultyName)
            if not ok then
                return false, err
            end

            local worldIndex = progress.World
            local forestIndex = progress.Forest
            local mobIndex = progress.Mob
            advanceFightProgression(progress)

            if refreshCombatConfigUi then
                refreshCombatConfigUi()
            end

            return true, string.format("W%d F%d Mob%d %s", worldIndex, forestIndex, mobIndex, difficultyName)
        end,
    },
    {
        Id = "auto_fight_single",
        Category = "fight",
        ManualOnly = true,
        Title = "Mob em Loop",
        Description = "Repete sempre o mesmo mob da configuracao de luta.",
        ToggleKey = Enum.KeyCode.G,
        Delay = COMBAT_LOOP_SECONDS,
        RemoteNames = { "CombatEvent" },
        Run = function()
            local config = normalizeCombatConfig()
            if not config then
                return false, "config luta ausente"
            end

            local difficultyName = getCombatDifficulty()
            config.SequenceNextMob = config.Mob
            local ok, err = performCombatStart(config.World, config.Forest, config.Mob, difficultyName)
            if not ok then
                return false, err
            end

            if refreshCombatConfigUi then
                refreshCombatConfigUi()
            end

            return true, string.format("loop W%d F%d Mob%d %s", config.World, config.Forest, config.Mob, difficultyName)
        end,
    },
    {
        Id = "auto_fight_skip5",
        Category = "fight",
        ManualOnly = true,
        Title = "BattleSkip5",
        Description = "Usa BattleSkip5 no mob configurado.",
        ToggleKey = Enum.KeyCode.H,
        Delay = COMBAT_LOOP_SECONDS,
        RemoteNames = { "CombatEvent" },
        Run = function()
            local config = normalizeCombatConfig()
            if not config then
                return false, "config luta ausente"
            end

            local difficultyName = getCombatDifficulty()
            config.SequenceNextMob = config.Mob
            local ok, err = performCombatSkip(config.World, config.Forest, config.Mob, difficultyName, COMBAT_SKIP_TOKEN)
            if not ok then
                return false, err
            end

            if refreshCombatConfigUi then
                refreshCombatConfigUi()
            end

            return true, string.format("skip5 W%d F%d Mob%d %s", config.World, config.Forest, config.Mob, difficultyName)
        end,
    },
    {
        Id = "auto_upgrade_all",
        Category = "automation",
        Title = "Upgrade All",
        Description = "Compra em rajada por 10s apos os geradores.",
        ToggleKey = Enum.KeyCode.U,
        Delay = 0.1,
        RemoteNames = { "UpgradeEvent" },
        Run = function()
            return runPurchaseBurst("upgrades", UPGRADE_ALL_BATCH, "auto_upgrade_all")
        end,
    },
    {
        Id = "auto_generators",
        Category = "automation",
        Title = "Auto Geradores",
        Description = "Prioridade: compra em rajada por 10s.",
        ToggleKey = Enum.KeyCode.I,
        Delay = 0.1,
        RemoteNames = { "UpgradeEvent" },
        Run = function()
            return runPurchaseBurst("generators", GENERATOR_BATCH, "auto_generators")
        end,
    },
    {
        Id = "auto_pack_shop",
        Category = "automation",
        Title = "Auto Cartas",
        Description = "Compra packs assim que ShopRestock atualizar a loja.",
        ToggleKey = Enum.KeyCode.P,
        Delay = 1,
        RemoteNames = { "ShopRestock", "BuyPack" },
        Run = function()
            connectShopRestockListener()

            local shopState = state.Shop
            if type(shopState) ~= "table" then
                return false, "estado da loja ausente"
            end

            if not shopState.PendingSignature then
                return true, "aguardando restock"
            end

            if type(shopState.PendingQueue) ~= "table" or #shopState.PendingQueue == 0 then
                shopState.ProcessedSignature = shopState.PendingSignature
                shopState.PendingSignature = nil
                return true, "restock vazio"
            end

            local purchasedCount = 0

            while isAutomationEnabled("auto_pack_shop") and type(shopState.PendingQueue) == "table" and #shopState.PendingQueue > 0 do
                local nextPurchase = table.remove(shopState.PendingQueue, 1)
                if not nextPurchase then
                    break
                end

                local ok, err = safeFire("BuyPack", nextPurchase.Group, nextPurchase.Pack, nextPurchase.Amount)
                if not ok then
                    table.insert(shopState.PendingQueue, 1, nextPurchase)
                    return false, err
                end

                purchasedCount += 1
                task.wait(0.2)
            end

            if type(shopState.PendingQueue) ~= "table" or #shopState.PendingQueue == 0 then
                shopState.ProcessedSignature = shopState.PendingSignature
                shopState.PendingSignature = nil
            end

            return true, string.format("packs comprados=%d", purchasedCount)
        end,
    },
    {
        Id = "auto_rune_upgrade",
        Category = "automation",
        Title = "Upgrade Runas",
        Description = "Compra RuneBulk e RuneSpeed.",
        ToggleKey = Enum.KeyCode.O,
        Delay = 3,
        RemoteNames = { "UpgradeEvent" },
        Run = function()
            return safeFire("UpgradeEvent", cloneBatch(RUNE_UPGRADE_BATCH))
        end,
    },
    {
        Id = "auto_runes",
        Category = "automation",
        Title = "Auto Runas",
        Description = "Reativa as runas marcadas a cada 3s.",
        ToggleKey = Enum.KeyCode.N,
        Delay = 0.1,
        RemoteNames = { "RuneEvent", "AutoStateEvent" },
        Run = function()
            local enabledRuneSets = getEnabledRuneSets()
            if #enabledRuneSets == 0 then
                return true, "nenhuma runa marcada"
            end

            local nextIndex = (tonumber(state.RuneCycleIndex) or 0) + 1
            if nextIndex > #enabledRuneSets then
                nextIndex = 1
            end

            state.RuneCycleIndex = nextIndex
            local runeSet = enabledRuneSets[nextIndex]

            safeFire("RuneEvent", "Stop")
            task.wait(0.2)
            safeFire("AutoStateEvent", "StartRune", {
                Set = runeSet,
            })
            task.wait(0.2)

            local ok, err = safeFire("RuneEvent", "Start", runeSet)
            if not ok then
                return false, err
            end

            waitWhileAutomationEnabled("auto_runes", RUNE_CYCLE_SECONDS)

            return true, "set=" .. tostring(runeSet)
        end,
    },
    {
        Id = "auto_ascension",
        Category = "automation",
        Title = "Auto Ascensao",
        Description = 'Executa Events.AscensionEvent:FireServer("Ascend").',
        ToggleKey = Enum.KeyCode.J,
        Delay = 1.5,
        RemoteNames = { "AscensionEvent" },
        Run = function()
            return safeFire("AscensionEvent", "Ascend")
        end,
    },
    {
        Id = "auto_reincarnation",
        Category = "automation",
        Title = "Auto Reencarnacao",
        Description = 'Executa Events.ReincarnationEvent:FireServer("Reincarnate").',
        ToggleKey = Enum.KeyCode.K,
        Delay = 2,
        RemoteNames = { "ReincarnationEvent" },
        Run = function()
            return safeFire("ReincarnationEvent", "Reincarnate")
        end,
    },
    {
        Id = "auto_reincarnation_upgrade",
        Category = "automation",
        Title = "Upgrade Reencarnacao",
        Description = "Gasta os pontos de reencarnacao na ordem PerClick, GemsMulti, WorldRoll e RuneCap.",
        ToggleKey = Enum.KeyCode.L,
        Delay = 1.5,
        RemoteNames = { "ReincarnationEvent" },
        Run = function()
            local spentCount = 0

            for _, skillName in ipairs(REINCARNATION_SKILL_PRIORITY) do
                local ok, err = safeFire("ReincarnationEvent", "SpendSkillPoint", skillName)
                if not ok then
                    return false, err
                end

                spentCount += 1
                task.wait(0.05)
            end

            return true, string.format("skills=%d", spentCount)
        end,
    },
    {
        Id = "auto_boss",
        Category = "fight",
        Title = "Auto Boss",
        Description = 'Cria/entra no boss Impossible e tenta iniciar automaticamente.',
        ToggleKey = Enum.KeyCode.R,
        Delay = 5,
        RemoteNames = { "RaidEvent" },
        Run = function()
            connectRaidListener()

            local raidState = state.Raid or {}
            local now = tick()

            if (tonumber(raidState.LastBossDiedAt) or 0) > 0 then
                local elapsedAfterDeath = now - (tonumber(raidState.LastBossDiedAt) or 0)

                if elapsedAfterDeath <= 20 then
                    if (now - (tonumber(raidState.LastFightAgainAttemptAt) or 0)) >= 2 then
                        raidState.LastFightAgainAttemptAt = now
                        safeFire("RaidEvent", "FightAgain")
                        task.wait(0.35)
                        safeFire("RaidEvent", "Ready")
                        task.wait(0.35)
                        safeFire("RaidEvent", "ForceStart")
                        return true, "pos-boss fight again"
                    end

                    return true, "aguardando fight again"
                end

                if elapsedAfterDeath > 20 and (now - (tonumber(raidState.LastLeaveAttemptAt) or 0)) >= 8 then
                    raidState.LastLeaveAttemptAt = now
                    safeFire("RaidEvent", "Leave")
                    return true, "leave recompensa"
                end
            end

            if raidState.FightAgainStarted == true then
                local currentCount = tonumber(raidState.FightAgain.Count) or 0
                local totalCount = tonumber(raidState.FightAgain.Total) or 1

                if currentCount < totalCount then
                    raidState.LastFightAgainAttemptAt = now
                    safeFire("RaidEvent", "FightAgain")
                    return true, "fight again vote"
                end

                safeFire("RaidEvent", "Ready")
                task.wait(0.25)
                safeFire("RaidEvent", "ForceStart")
                return true, "fight again start"
            end

            if raidState.Active == true then
                return true, "boss ativo"
            end

            safeFire("RaidEvent", "RequestList")
            task.wait(0.25)

            if raidState.InLobby == true or (tonumber(raidState.LastListCount) or 0) > 0 then
                safeFire("RaidEvent", "Ready")
                task.wait(0.25)
                safeFire("RaidEvent", "ForceStart")
                return true, "ready/start"
            end

            safeFire("RaidEvent", "Create", 1, 4, 1, "Impossible")
            task.wait(0.35)
            safeFire("RaidEvent", "Ready")
            task.wait(0.25)
            safeFire("RaidEvent", "ForceStart")
            return true, "create"
        end,
    },
    {
        Id = "auto_boss_click",
        Category = "fight",
        Title = "Auto Click Boss",
        Description = "Clica automaticamente durante a luta do boss.",
        ToggleKey = Enum.KeyCode.T,
        Delay = 0.01,
        RemoteNames = { "RaidClick" },
        Run = function()
            local raidState = state.Raid or {}
            if raidState.Active ~= true then
                return true, "fora do boss"
            end

            return safeFire("RaidClick")
        end,
    },
    {
        Id = "auto_mine",
        Category = "automation",
        Title = "Auto Mina",
        Description = "Coleta e reinicia TicketBurrow nos slots 1, 2 e 3.",
        ToggleKey = Enum.KeyCode.M,
        Delay = 900,
        RemoteNames = { "MineEvent" },
        Run = function()
            local remote = findRemote("MineEvent")
            if not remote then
                return false, "remote ausente"
            end

            local claimedCount = 0
            local startedCount = 0
            local lastStartError

            for _, mineInfo in ipairs(MINE_ROUTES) do
                local claimOk = pcall(function()
                    remote:FireServer("Claim", mineInfo.Slot)
                end)

                if claimOk then
                    claimedCount += 1
                end

                task.wait(1)

                local startOk, startErr = pcall(function()
                    remote:FireServer("Start", mineInfo.Slot, mineInfo.Area, mineInfo.Duration)
                end)
                if startOk then
                    startedCount += 1
                else
                    lastStartError = tostring(startErr)
                end

                task.wait(1)
            end

            if startedCount > 0 then
                return true, string.format("claim=%d | start=%d", claimedCount, startedCount)
            end

            if lastStartError then
                return false, lastStartError
            end

            return true, string.format("claim=%d | start=0", claimedCount)
        end,
    },
}

state = {
    Running = true,
    Visible = true,
    Connections = {},
    EventStates = {},
    Rows = {},
    Pages = {},
    TabButtons = {},
    RuneButtons = {},
    RuneSetEnabled = {},
    CombatLabels = {},
    ActiveTab = "automation",
    CombatConfig = {
        World = 1,
        Forest = 1,
        Mob = 1,
        DifficultyIndex = 1,
        SequenceNextMob = 1,
    },
    FightProgress = {
        World = 1,
        Forest = 1,
        Mob = 1,
        DifficultyIndex = 1,
    },
    RunId = currentRunId,
    PurchaseCycleStartedAt = tick(),
    OpenButton = nil,
    SummaryLabel = nil,
    DetailsLabel = nil,
    GoldenAntRemote = nil,
    GoldenAntConnection = nil,
    PendingGoldenAnts = {},
    PendingGoldenAntLookup = {},
    ShopRestockRemote = nil,
    ShopRestockConnection = nil,
    Shop = {
        LastRestockAt = 0,
        RefreshSeconds = 0,
        LastStock = {},
        PendingQueue = {},
        PendingSignature = nil,
        ProcessedSignature = nil,
    },
    RaidEventRemote = nil,
    RaidEventConnection = nil,
    Raid = {
        Active = false,
        InLobby = false,
        LastList = {},
        LastListCount = 0,
        FightAgain = {},
        FightAgainStarted = false,
        LastRaidId = nil,
        LastBossDiedAt = 0,
        LastFightAgainAttemptAt = 0,
        LastLeaveAttemptAt = 0,
    },
}

for _, option in ipairs(RUNE_SET_OPTIONS) do
    state.RuneSetEnabled[option.Id] = true
end

for _, child in ipairs(playerGui:GetChildren()) do
    if child.Name == GUI_NAME then
        child:Destroy()
    end
end

local function bind(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(state.Connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(state.Connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end

    table.clear(state.Connections)

    if state.GoldenAntConnection and state.GoldenAntConnection.Disconnect then
        state.GoldenAntConnection:Disconnect()
    end

    state.GoldenAntConnection = nil
    state.GoldenAntRemote = nil

    if state.ShopRestockConnection and state.ShopRestockConnection.Disconnect then
        state.ShopRestockConnection:Disconnect()
    end

    state.ShopRestockConnection = nil
    state.ShopRestockRemote = nil

    if state.RaidEventConnection and state.RaidEventConnection.Disconnect then
        state.RaidEventConnection:Disconnect()
    end

    state.RaidEventConnection = nil
    state.RaidEventRemote = nil
end

local function queueGoldenAnt(antId, antCount)
    if type(antId) ~= "string" or antId == "" then
        return
    end

    if state.PendingGoldenAntLookup[antId] then
        return
    end

    state.PendingGoldenAntLookup[antId] = true
    table.insert(state.PendingGoldenAnts, {
        Id = antId,
        Count = tonumber(antCount) or 0,
    })
end

popGoldenAnt = function()
    while #state.PendingGoldenAnts > 0 do
        local entry = table.remove(state.PendingGoldenAnts, 1)
        if entry and type(entry.Id) == "string" and entry.Id ~= "" then
            state.PendingGoldenAntLookup[entry.Id] = nil
            return entry
        end
    end

    return nil
end

trySendGoldenAnt = function(antId)
    if type(antId) ~= "string" or antId == "" then
        return false, "uuid invalido"
    end

    return safeFire("GoldenAnt", antId)
end

local function connectGoldenAntListener()
    if state.GoldenAntConnection and state.GoldenAntConnection.Disconnect then
        state.GoldenAntConnection:Disconnect()
    end

    state.GoldenAntRemote = nil
    state.GoldenAntConnection = nil
    table.clear(state.PendingGoldenAnts)
    table.clear(state.PendingGoldenAntLookup)
end

connectRaidListener = function()
    local remote = findRemote("RaidEvent")
    if state.RaidEventRemote == remote and state.RaidEventConnection then
        return
    end

    if state.RaidEventConnection and state.RaidEventConnection.Disconnect then
        state.RaidEventConnection:Disconnect()
    end

    state.RaidEventRemote = remote
    state.RaidEventConnection = nil

    if not remote or not remote.OnClientEvent then
        return
    end

    state.RaidEventConnection = remote.OnClientEvent:Connect(function(eventName, arg2, arg3)
        local raidState = state.Raid
        if type(eventName) ~= "string" or type(raidState) ~= "table" then
            return
        end

        if eventName == "RaidStarted" then
            raidState.Active = true
            raidState.InLobby = false
            raidState.FightAgainStarted = false
            raidState.LastBossDiedAt = 0
            raidState.LastFightAgainAttemptAt = 0
            raidState.LastLeaveAttemptAt = 0
            if type(arg2) == "table" and arg2.RaidId then
                raidState.LastRaidId = tostring(arg2.RaidId)
            end
            return
        end

        if eventName == "RaidCreated" then
            raidState.Active = false
            raidState.InLobby = true
            if arg2 ~= nil then
                raidState.LastRaidId = tostring(arg2)
            elseif type(arg3) == "table" and arg3.RaidId then
                raidState.LastRaidId = tostring(arg3.RaidId)
            end
            return
        end

        if eventName == "RaidListUpdate" then
            if type(arg2) == "table" then
                raidState.LastList = arg2
                raidState.LastListCount = #arg2
            else
                raidState.LastList = {}
                raidState.LastListCount = 0
            end

            if raidState.Active ~= true then
                raidState.InLobby = raidState.LastListCount > 0
            end
            return
        end

        if eventName == "BossDied" then
            raidState.Active = false
            raidState.InLobby = false
            raidState.LastBossDiedAt = tick()
            raidState.LastFightAgainAttemptAt = 0
            raidState.LastLeaveAttemptAt = 0
            return
        end

        if eventName == "FightAgainUpdate" then
            raidState.FightAgain = type(arg2) == "table" and arg2 or {}
            raidState.FightAgainStarted = raidState.FightAgain.Started == true
            if raidState.FightAgainStarted == true then
                raidState.Active = false
                raidState.InLobby = false
                raidState.LastFightAgainAttemptAt = 0
            end
            return
        end
    end)
end

connectShopRestockListener = function()
    local remote = findRemote("ShopRestock")
    if state.ShopRestockRemote == remote and state.ShopRestockConnection then
        return
    end

    if state.ShopRestockConnection and state.ShopRestockConnection.Disconnect then
        state.ShopRestockConnection:Disconnect()
    end

    state.ShopRestockRemote = remote
    state.ShopRestockConnection = nil

    if not remote or not remote.OnClientEvent then
        return
    end

    state.ShopRestockConnection = remote.OnClientEvent:Connect(function(stockData, restockAt, refreshSeconds)
        local shopState = state.Shop
        if type(shopState) ~= "table" or type(stockData) ~= "table" then
            return
        end

        local signature = getShopRestockSignature(stockData, restockAt, refreshSeconds)
        if signature == shopState.PendingSignature or signature == shopState.ProcessedSignature then
            return
        end

        shopState.LastRestockAt = math.floor(tonumber(restockAt) or 0)
        shopState.RefreshSeconds = math.floor(tonumber(refreshSeconds) or 0)
        shopState.LastStock = stockData
        shopState.PendingQueue = buildShopPurchaseQueue(stockData)
        shopState.PendingSignature = signature
    end)
end

local function makeCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function makeStroke(instance, color, transparency, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color
    stroke.Transparency = transparency or 0
    stroke.Thickness = thickness or 1
    stroke.Parent = instance
    return stroke
end

local function createText(parent, props)
    local isButton = props.Button == true
    local element = Instance.new(isButton and "TextButton" or "TextLabel")
    element.BackgroundTransparency = props.BackgroundTransparency ~= nil and props.BackgroundTransparency or (isButton and 0 or 1)
    if props.BackgroundColor3 then
        element.BackgroundColor3 = props.BackgroundColor3
    end
    element.BorderSizePixel = 0
    element.Position = props.Position or UDim2.new()
    element.Size = props.Size or UDim2.new()
    element.Text = props.Text or ""
    element.TextColor3 = props.TextColor3 or Color3.fromRGB(255, 255, 255)
    element.Font = props.Font or Enum.Font.Gotham
    element.TextSize = props.TextSize or 14
    element.TextWrapped = props.TextWrapped == true
    element.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    element.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    if isButton then
        element.AutoButtonColor = true
    end
    element.Parent = parent
    return element
end

local function formatKey(keyCode)
    if typeof(keyCode) ~= "EnumItem" then
        return "-"
    end

    return string.upper(tostring(keyCode.Name or "-"))
end

local function formatRemoteNames(remoteNames)
    if type(remoteNames) ~= "table" or #remoteNames == 0 then
        return "sem remote definido"
    end

    return table.concat(remoteNames, ", ")
end

local function describeRemoteState(eventConfig)
    local available = {}
    local missing = {}

    for _, remoteName in ipairs(eventConfig.RemoteNames or {}) do
        if hasRemote(remoteName) then
            table.insert(available, remoteName)
        else
            table.insert(missing, remoteName)
        end
    end

    if #missing == 0 then
        return "Remotes: ok"
    end

    return "Faltando: " .. table.concat(missing, ", ")
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local isTouchDevice = UserInputService.TouchEnabled == true

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = isTouchDevice and UDim2.new(0, 340, 0, 360) or UDim2.new(0, 410, 0, 390)
mainFrame.Position = UDim2.new(0.5, -(mainFrame.Size.X.Offset / 2), 0.5, -(mainFrame.Size.Y.Offset / 2))
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 16, 13)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
makeCorner(mainFrame, 16)
makeStroke(mainFrame, Color3.fromRGB(230, 164, 79), 0.35, 1)

local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 37, 22)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(28, 22, 17)),
})
mainGradient.Rotation = 90
mainGradient.Parent = mainFrame

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(86, 50, 24)
header.BorderSizePixel = 0
header.Parent = mainFrame
makeCorner(header, 18)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 18)
headerFix.Position = UDim2.new(0, 0, 1, -18)
headerFix.BackgroundColor3 = header.BackgroundColor3
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local titleLabel = createText(header, {
    Position = UDim2.new(0, 14, 0, 0),
    Size = UDim2.new(1, -120, 1, 0),
    Text = "Formiga Auto",
    Font = Enum.Font.GothamBold,
    TextSize = 15,
})

local subtitleLabel = createText(header, {
    Position = UDim2.new(0, 118, 0, 0),
    Size = UDim2.new(1, -130, 0, 14),
    Text = "modulos compactos",
    TextColor3 = Color3.fromRGB(249, 218, 176),
    TextSize = 9,
})

local closeButton = createText(header, {
    Button = true,
    Position = UDim2.new(1, -42, 0.5, -14),
    Size = UDim2.new(0, 28, 0, 28),
    Text = "X",
    Font = Enum.Font.GothamBold,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(190, 75, 61),
})
makeCorner(closeButton, 9)

local minimizeButton = createText(header, {
    Button = true,
    Position = UDim2.new(1, -76, 0.5, -14),
    Size = UDim2.new(0, 28, 0, 28),
    Text = "-",
    Font = Enum.Font.GothamBold,
    TextSize = 16,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(119, 96, 64),
})
makeCorner(minimizeButton, 9)

local body = Instance.new("Frame")
body.BackgroundColor3 = Color3.fromRGB(20, 17, 13)
body.Position = UDim2.new(0, 8, 0, 58)
body.Size = UDim2.new(1, -16, 1, -66)
body.BorderSizePixel = 0
body.Parent = mainFrame
makeCorner(body, 16)
makeStroke(body, Color3.fromRGB(134, 97, 53), 0.4, 1)

state.SummaryLabel = createText(body, {
    Position = UDim2.new(0, 8, 0, 6),
    Size = UDim2.new(1, -16, 0, 16),
    Text = "0 de 4 automacoes ligadas",
    TextColor3 = Color3.fromRGB(215, 194, 160),
    TextSize = 10,
})

state.DetailsLabel = createText(body, {
    Position = UDim2.new(0, 8, 0, 22),
    Size = UDim2.new(1, -16, 0, 10),
    Text = "Delete minimiza. Use os botoes para alternar.",
    TextColor3 = Color3.fromRGB(180, 158, 129),
    TextSize = 9,
    TextWrapped = true,
    TextYAlignment = Enum.TextYAlignment.Top,
})

local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Position = UDim2.new(0, 8, 0, 38)
tabRow.Size = UDim2.new(1, -16, 0, 24)
tabRow.Parent = body

local automationTabButton = createText(tabRow, {
    Button = true,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.49, -3, 1, 0),
    Text = "Automacao",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(74, 129, 78),
})
makeCorner(automationTabButton, 8)
state.TabButtons.automation = automationTabButton

local fightTabButton = createText(tabRow, {
    Button = true,
    Position = UDim2.new(0.51, 3, 0, 0),
    Size = UDim2.new(0.49, -3, 1, 0),
    Text = "Lutas",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(77, 70, 61),
})
makeCorner(fightTabButton, 8)
state.TabButtons.fight = fightTabButton

local automationPage = Instance.new("Frame")
automationPage.BackgroundTransparency = 1
automationPage.Position = UDim2.new(0, 8, 0, 70)
automationPage.Size = UDim2.new(1, -16, 1, -78)
automationPage.Parent = body
state.Pages.automation = automationPage

local fightPage = Instance.new("Frame")
fightPage.BackgroundTransparency = 1
fightPage.Position = UDim2.new(0, 8, 0, 70)
fightPage.Size = UDim2.new(1, -16, 1, -78)
fightPage.Visible = false
fightPage.Parent = body
state.Pages.fight = fightPage

local buttonRow = Instance.new("Frame")
buttonRow.BackgroundTransparency = 1
buttonRow.Position = UDim2.new(0, 0, 0, 0)
buttonRow.Size = UDim2.new(1, 0, 0, 28)
buttonRow.Parent = automationPage

local enableAllButton = createText(buttonRow, {
    Button = true,
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.31, -4, 1, 0),
    Text = "Ligar Tudo",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(74, 129, 78),
})
makeCorner(enableAllButton, 9)

local clickAscensionOnlyButton = createText(buttonRow, {
    Button = true,
    Position = UDim2.new(0.345, 0, 0, 0),
    Size = UDim2.new(0.31, -4, 1, 0),
    Text = "So Click+Asc",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(91, 112, 190),
})
makeCorner(clickAscensionOnlyButton, 9)

local disableAllButton = createText(buttonRow, {
    Button = true,
    Position = UDim2.new(0.69, 0, 0, 0),
    Size = UDim2.new(0.31, 0, 1, 0),
    Text = "Desligar Tudo",
    Font = Enum.Font.GothamBold,
    TextSize = 10,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(154, 76, 65),
})
makeCorner(disableAllButton, 9)

local runeSelectorFrame = Instance.new("Frame")
runeSelectorFrame.BackgroundColor3 = Color3.fromRGB(27, 23, 18)
runeSelectorFrame.Position = UDim2.new(0, 0, 0, 32)
runeSelectorFrame.Size = UDim2.new(1, 0, 0, 46)
runeSelectorFrame.BorderSizePixel = 0
runeSelectorFrame.Parent = automationPage
makeCorner(runeSelectorFrame, 11)
makeStroke(runeSelectorFrame, Color3.fromRGB(116, 82, 45), 0.48, 1)

local runeSelectorTitle = createText(runeSelectorFrame, {
    Position = UDim2.new(0, 8, 0, 4),
    Size = UDim2.new(1, -16, 0, 12),
    Text = "Runas no ciclo",
    TextColor3 = Color3.fromRGB(215, 194, 160),
    Font = Enum.Font.GothamBold,
    TextSize = 9,
})

for index, option in ipairs(RUNE_SET_OPTIONS) do
    local widthScale = 1 / #RUNE_SET_OPTIONS
    local runeButton = createText(runeSelectorFrame, {
        Button = true,
        Position = UDim2.new((index - 1) * widthScale, 2, 0, 20),
        Size = UDim2.new(widthScale, -4, 0, 18),
        Text = option.Label,
        Font = Enum.Font.GothamBold,
        TextSize = 8,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(77, 70, 61),
    })
    makeCorner(runeButton, 7)
    state.RuneButtons[option.Id] = runeButton

    bind(runeButton.MouseButton1Click, function()
        toggleRuneSetEnabled(option.Id)
        refreshRuneButtons()
    end)
end

local automationRowHolder = Instance.new("ScrollingFrame")
automationRowHolder.BackgroundTransparency = 1
automationRowHolder.Position = UDim2.new(0, 0, 0, 86)
automationRowHolder.Size = UDim2.new(1, 0, 1, -86)
automationRowHolder.BorderSizePixel = 0
automationRowHolder.ScrollBarThickness = 3
automationRowHolder.Parent = automationPage

local fightConfigFrame = Instance.new("Frame")
fightConfigFrame.BackgroundColor3 = Color3.fromRGB(27, 23, 18)
fightConfigFrame.Position = UDim2.new(0, 0, 0, 0)
fightConfigFrame.Size = UDim2.new(1, 0, 0, 114)
fightConfigFrame.BorderSizePixel = 0
fightConfigFrame.Parent = fightPage
makeCorner(fightConfigFrame, 11)
makeStroke(fightConfigFrame, Color3.fromRGB(116, 82, 45), 0.48, 1)

createText(fightConfigFrame, {
    Position = UDim2.new(0, 8, 0, 4),
    Size = UDim2.new(1, -16, 0, 14),
    Text = "Config Luta",
    TextColor3 = Color3.fromRGB(215, 194, 160),
    Font = Enum.Font.GothamBold,
    TextSize = 10,
})

local function createConfigControl(parent, yOffset, keyName, labelText)
    createText(parent, {
        Position = UDim2.new(0, 8, 0, yOffset + 3),
        Size = UDim2.new(0, 82, 0, 16),
        Text = labelText,
        TextColor3 = Color3.fromRGB(215, 194, 160),
        Font = Enum.Font.GothamBold,
        TextSize = 9,
    })

    local minusButton = createText(parent, {
        Button = true,
        Position = UDim2.new(0, 94, 0, yOffset),
        Size = UDim2.new(0, 24, 0, 22),
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(99, 74, 54),
    })
    makeCorner(minusButton, 7)

    local valueButton = createText(parent, {
        Button = true,
        Position = UDim2.new(0, 122, 0, yOffset),
        Size = UDim2.new(1, -180, 0, 22),
        Text = "-",
        Font = Enum.Font.GothamBold,
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(63, 58, 49),
    })
    makeCorner(valueButton, 7)

    local plusButton = createText(parent, {
        Button = true,
        Position = UDim2.new(1, -50, 0, yOffset),
        Size = UDim2.new(0, 24, 0, 22),
        Text = "+",
        Font = Enum.Font.GothamBold,
        TextSize = 11,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(74, 129, 78),
    })
    makeCorner(plusButton, 7)

    state.CombatLabels[keyName] = valueButton
    return minusButton, valueButton, plusButton
end

local worldMinus, worldValue, worldPlus = createConfigControl(fightConfigFrame, 22, "World", "Mundo")
local forestMinus, forestValue, forestPlus = createConfigControl(fightConfigFrame, 46, "Forest", "Floresta")
local mobMinus, mobValue, mobPlus = createConfigControl(fightConfigFrame, 70, "Mob", "Mob")
local diffMinus, diffValue, diffPlus = createConfigControl(fightConfigFrame, 94, "Difficulty", "Dificuldade")

state.CombatLabels.Info = createText(fightPage, {
    Position = UDim2.new(0, 0, 0, 118),
    Size = UDim2.new(1, 0, 0, 14),
    Text = "1x1 usa mobs em sequencia | Loop e Skip5 usam o mob escolhido.",
    TextColor3 = Color3.fromRGB(201, 180, 148),
    TextSize = 9,
})

local fightRowHolder = Instance.new("ScrollingFrame")
fightRowHolder.BackgroundTransparency = 1
fightRowHolder.Position = UDim2.new(0, 0, 0, 136)
fightRowHolder.Size = UDim2.new(1, 0, 1, -136)
fightRowHolder.BorderSizePixel = 0
fightRowHolder.ScrollBarThickness = 3
fightRowHolder.Parent = fightPage

bind(automationTabButton.MouseButton1Click, function()
    setActiveTab("automation")
end)

bind(fightTabButton.MouseButton1Click, function()
    setActiveTab("fight")
end)

bind(worldMinus.MouseButton1Click, function()
    changeCombatNumber("World", -1, COMBAT_WORLD_MIN, COMBAT_WORLD_MAX)
end)
bind(worldValue.MouseButton1Click, function()
    changeCombatNumber("World", 1, COMBAT_WORLD_MIN, COMBAT_WORLD_MAX)
end)
bind(worldPlus.MouseButton1Click, function()
    changeCombatNumber("World", 1, COMBAT_WORLD_MIN, COMBAT_WORLD_MAX)
end)

bind(forestMinus.MouseButton1Click, function()
    local currentConfig = normalizeCombatConfig() or {}
    local maxForest = getCombatMaxForest(currentConfig.World)
    changeCombatNumber("Forest", -1, COMBAT_FOREST_MIN, maxForest)
end)
bind(forestValue.MouseButton1Click, function()
    local currentConfig = normalizeCombatConfig() or {}
    local maxForest = getCombatMaxForest(currentConfig.World)
    changeCombatNumber("Forest", 1, COMBAT_FOREST_MIN, maxForest)
end)
bind(forestPlus.MouseButton1Click, function()
    local currentConfig = normalizeCombatConfig() or {}
    local maxForest = getCombatMaxForest(currentConfig.World)
    changeCombatNumber("Forest", 1, COMBAT_FOREST_MIN, maxForest)
end)

bind(mobMinus.MouseButton1Click, function()
    local currentConfig = normalizeCombatConfig() or {}
    local maxMob = getCombatMaxMob(currentConfig.World, currentConfig.Forest)
    changeCombatNumber("Mob", -1, 1, maxMob)
end)
bind(mobValue.MouseButton1Click, function()
    local currentConfig = normalizeCombatConfig() or {}
    local maxMob = getCombatMaxMob(currentConfig.World, currentConfig.Forest)
    changeCombatNumber("Mob", 1, 1, maxMob)
end)
bind(mobPlus.MouseButton1Click, function()
    local currentConfig = normalizeCombatConfig() or {}
    local maxMob = getCombatMaxMob(currentConfig.World, currentConfig.Forest)
    changeCombatNumber("Mob", 1, 1, maxMob)
end)

bind(diffMinus.MouseButton1Click, function()
    changeCombatDifficulty(-1)
end)
bind(diffValue.MouseButton1Click, function()
    changeCombatDifficulty(1)
end)
bind(diffPlus.MouseButton1Click, function()
    changeCombatDifficulty(1)
end)

local openButton = createText(screenGui, {
    Button = true,
    Position = UDim2.new(0, 18, 0.5, -22),
    Size = UDim2.new(0, 110, 0, 44),
    Text = "Formiga",
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Center,
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(70, 50, 33),
})
openButton.Visible = false
makeCorner(openButton, 14)
makeStroke(openButton, Color3.fromRGB(223, 162, 82), 0.2, 1.1)
state.OpenButton = openButton

local function refreshSummary()
    local enabledCount = 0
    local availableCount = 0

    for _, eventConfig in ipairs(EVENTS) do
        local eventState = state.EventStates[eventConfig.Id]
        if eventState and eventState.Enabled == true then
            enabledCount = enabledCount + 1
        end

        local missingAny = false
        for _, remoteName in ipairs(eventConfig.RemoteNames or {}) do
            if not hasRemote(remoteName) then
                missingAny = true
                break
            end
        end

        if not missingAny then
            availableCount = availableCount + 1
        end
    end

    if state.SummaryLabel then
        state.SummaryLabel.Text = string.format("%d de %d automacoes ligadas | %d remotes prontos", enabledCount, #EVENTS, availableCount)
    end
end

refreshRuneButtons = function()
    for _, option in ipairs(RUNE_SET_OPTIONS) do
        local runeButton = state.RuneButtons[option.Id]
        if runeButton then
            local enabled = state.RuneSetEnabled[option.Id] ~= false
            runeButton.Text = option.Label
            runeButton.TextColor3 = enabled and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(210, 193, 171)
            runeButton.BackgroundColor3 = enabled and Color3.fromRGB(74, 129, 78) or Color3.fromRGB(77, 70, 61)
        end
    end
end

refreshCombatConfigUi = function()
    local config = normalizeCombatConfig()
    if not config then
        return
    end

    local difficultyName = getCombatDifficulty()
    local maxMob = getCombatMaxMob(config.World, config.Forest)

    if state.CombatLabels.World then
        state.CombatLabels.World.Text = tostring(config.World)
    end
    if state.CombatLabels.Forest then
        state.CombatLabels.Forest.Text = tostring(config.Forest)
    end
    if state.CombatLabels.Mob then
        state.CombatLabels.Mob.Text = string.format("%d / max %d", config.Mob, maxMob)
    end
    if state.CombatLabels.Difficulty then
        state.CombatLabels.Difficulty.Text = difficultyName
    end
    if state.CombatLabels.Info then
        local progress = normalizeFightProgression()
        local progressDifficulty = getFightProgressDifficulty(progress)
        local startConfig = normalizeCombatConfig()
        state.CombatLabels.Info.Text = string.format(
            "1x1 inicio W%d F%d | atual W%d F%d/%d Mob%d/%d %s | Skip: %s",
            tonumber(startConfig and startConfig.World) or 1,
            tonumber(startConfig and startConfig.Forest) or 1,
            tonumber(progress and progress.World) or 1,
            tonumber(progress and progress.Forest) or 1,
            getCombatMaxForest(tonumber(progress and progress.World) or 1),
            tonumber(progress and progress.Mob) or 1,
            getCombatMaxMob(tonumber(progress and progress.World) or 1, tonumber(progress and progress.Forest) or 1),
            progressDifficulty,
            COMBAT_SKIP_TOKEN
        )
    end
end

setActiveTab = function(tabId)
    state.ActiveTab = tabId == "fight" and "fight" or "automation"

    for pageId, page in pairs(state.Pages) do
        page.Visible = pageId == state.ActiveTab
    end

    for buttonId, button in pairs(state.TabButtons) do
        local active = buttonId == state.ActiveTab
        button.BackgroundColor3 = active and Color3.fromRGB(74, 129, 78) or Color3.fromRGB(77, 70, 61)
        button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(210, 193, 171)
    end
end

local function refreshRemoteVisuals()
    remoteCache = {}
    cachedEventsFolder = nil
    connectGoldenAntListener()
    connectRaidListener()
    connectShopRestockListener()

    for _, eventConfig in ipairs(EVENTS) do
        refreshRow(eventConfig)
    end
    refreshRuneButtons()
    refreshSummary()
end

local function refreshRow(eventConfig)
    local eventState = state.EventStates[eventConfig.Id]
    local row = state.Rows[eventConfig.Id]
    if not eventState or not row then
        return
    end

    local enabled = eventState.Enabled == true

    row.Title.Text = eventConfig.Title
    row.Description.Text = eventConfig.Description
    row.Key.Text = "Tecla: " .. formatKey(eventConfig.ToggleKey)
    row.Delay.Text = string.format("Delay: %.2fs", tonumber(eventConfig.Delay) or 0)
    row.Remote.Text = describeRemoteState(eventConfig)

    if enabled then
        row.Status.Text = "Status: ligado"
        row.Status.TextColor3 = Color3.fromRGB(119, 215, 141)
        row.Toggle.Text = "ON"
        row.Toggle.BackgroundColor3 = Color3.fromRGB(74, 129, 78)
        row.BackgroundColor3 = Color3.fromRGB(31, 39, 29)
    else
        row.Status.Text = "Status: off"
        row.Status.TextColor3 = Color3.fromRGB(221, 170, 162)
        row.Toggle.Text = "OFF"
        row.Toggle.BackgroundColor3 = Color3.fromRGB(110, 69, 61)
        row.BackgroundColor3 = Color3.fromRGB(33, 27, 22)
    end
end

local function setVisible(visible)
    state.Visible = visible == true
    mainFrame.Visible = state.Visible
    openButton.Visible = not state.Visible
end

local function setEventEnabled(eventId, enabled)
    local eventState = state.EventStates[eventId]
    if not eventState then
        return
    end

    if enabled == true and EXCLUSIVE_FIGHT_EVENT_IDS[eventId] == true then
        for otherEventId, _ in pairs(EXCLUSIVE_FIGHT_EVENT_IDS) do
            if otherEventId ~= eventId and state.EventStates[otherEventId] then
                state.EventStates[otherEventId].Enabled = false
                refreshRow(state.EventStates[otherEventId].Config)
            end
        end
    end

    eventState.Enabled = enabled == true
    if eventId == "auto_fight_progress" then
        if enabled == true then
            resetFightProgression()
        else
            local config = normalizeCombatConfig()
            if config then
                config.SequenceNextMob = config.Mob
            end
            resetFightProgression()
        end
    end
    refreshRow(eventState.Config)
    refreshSummary()
    if refreshCombatConfigUi then
        refreshCombatConfigUi()
    end
end

local function stopAllEvents()
    resetPurchaseCycle()
    for _, eventConfig in ipairs(EVENTS) do
        setEventEnabled(eventConfig.Id, false)
    end
end

local function startAllEvents()
    resetPurchaseCycle()
    for _, eventConfig in ipairs(EVENTS) do
        setEventEnabled(eventConfig.Id, eventConfig.ManualOnly ~= true)
    end
end

local function startDefaultEvents()
    resetPurchaseCycle()
    for _, eventConfig in ipairs(EVENTS) do
        setEventEnabled(eventConfig.Id, DEFAULT_ENABLED_EVENTS[eventConfig.Id] == true)
    end
end

local function startClickAscensionOnly()
    resetPurchaseCycle()
    for _, eventConfig in ipairs(EVENTS) do
        local keepEnabled = eventConfig.Id == "auto_click" or eventConfig.Id == "auto_ascension"
        setEventEnabled(eventConfig.Id, keepEnabled)
    end
end

local rowIndexByCategory = {
    automation = 0,
    fight = 0,
}

for _, eventConfig in ipairs(EVENTS) do
    local category = eventConfig.Category == "fight" and "fight" or "automation"
    rowIndexByCategory[category] = rowIndexByCategory[category] + 1
    local rowIndex = rowIndexByCategory[category]
    local parentHolder = category == "fight" and fightRowHolder or automationRowHolder

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 38)
    row.Position = UDim2.new(0, 0, 0, (rowIndex - 1) * 44)
    row.BackgroundColor3 = Color3.fromRGB(33, 27, 22)
    row.BorderSizePixel = 0
    row.Parent = parentHolder
    makeCorner(row, 11)
    makeStroke(row, Color3.fromRGB(116, 82, 45), 0.48, 1)

    local title = createText(row, {
        Position = UDim2.new(0, 10, 0, 4),
        Size = UDim2.new(1, -118, 0, 16),
        Text = eventConfig.Title,
        Font = Enum.Font.GothamBold,
        TextSize = 12,
    })

    local description = createText(row, {
        Position = UDim2.new(0, 10, 0, 20),
        Size = UDim2.new(1, -160, 0, 12),
        Text = eventConfig.Description,
        TextColor3 = Color3.fromRGB(201, 180, 148),
        TextSize = 9,
    })

    local status = createText(row, {
        Position = UDim2.new(1, -154, 0, 21),
        Size = UDim2.new(0, 56, 0, 12),
        Text = "Status: off",
        TextColor3 = Color3.fromRGB(221, 170, 162),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local remoteText = createText(row, {
        Position = UDim2.new(0, 10, 0, 31),
        Size = UDim2.new(0, 1, 0, 1),
        Text = describeRemoteState(eventConfig),
        TextColor3 = Color3.fromRGB(180, 158, 129),
        TextSize = 1,
    })
    remoteText.Visible = false

    local keyText = createText(row, {
        Position = UDim2.new(1, -154, 0, 5),
        Size = UDim2.new(0, 56, 0, 12),
        Text = "Tecla: " .. formatKey(eventConfig.ToggleKey),
        TextColor3 = Color3.fromRGB(232, 210, 180),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local delayText = createText(row, {
        Position = UDim2.new(1, -94, 0, 5),
        Size = UDim2.new(0, 38, 0, 12),
        Text = string.format("Delay: %.2fs", tonumber(eventConfig.Delay) or 0),
        TextColor3 = Color3.fromRGB(180, 158, 129),
        TextSize = 9,
        TextXAlignment = Enum.TextXAlignment.Right,
    })

    local toggleButton = createText(row, {
        Button = true,
        Position = UDim2.new(1, -50, 0.5, -13),
        Size = UDim2.new(0, 42, 0, 26),
        Text = "OFF",
        Font = Enum.Font.GothamBold,
        TextSize = 10,
        TextXAlignment = Enum.TextXAlignment.Center,
        BackgroundTransparency = 0,
        BackgroundColor3 = Color3.fromRGB(110, 69, 61),
    })
    makeCorner(toggleButton, 8)

    state.EventStates[eventConfig.Id] = {
        Config = eventConfig,
        Enabled = false,
        LastResult = "idle",
    }

    state.Rows[eventConfig.Id] = {
        Frame = row,
        Title = title,
        Description = description,
        Status = status,
        Remote = remoteText,
        Key = keyText,
        Delay = delayText,
        Toggle = toggleButton,
    }

    bind(toggleButton.MouseButton1Click, function()
        local eventState = state.EventStates[eventConfig.Id]
        setEventEnabled(eventConfig.Id, not (eventState and eventState.Enabled == true))
    end)

    refreshRow(eventConfig)
end

automationRowHolder.CanvasSize = UDim2.new(0, 0, 0, rowIndexByCategory.automation * 44)
fightRowHolder.CanvasSize = UDim2.new(0, 0, 0, rowIndexByCategory.fight * 44)

refreshRuneButtons()
refreshCombatConfigUi()
setActiveTab("automation")
refreshSummary()
connectGoldenAntListener()
connectRaidListener()
connectShopRestockListener()

local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if eventsFolder then
    bind(eventsFolder.ChildAdded, refreshRemoteVisuals)
    bind(eventsFolder.ChildRemoved, refreshRemoteVisuals)
else
    bind(ReplicatedStorage.ChildAdded, function(child)
        if child.Name == "Events" then
            bind(child.ChildAdded, refreshRemoteVisuals)
            bind(child.ChildRemoved, refreshRemoteVisuals)
            refreshRemoteVisuals()
        end
    end)
end

bind(enableAllButton.MouseButton1Click, startAllEvents)
bind(clickAscensionOnlyButton.MouseButton1Click, startClickAscensionOnly)
bind(disableAllButton.MouseButton1Click, stopAllEvents)
bind(openButton.MouseButton1Click, function()
    setVisible(true)
end)
bind(minimizeButton.MouseButton1Click, function()
    setVisible(false)
end)
bind(closeButton.MouseButton1Click, function()
    state.Running = false
    stopAllEvents()
    disconnectAll()
    screenGui:Destroy()
    if ROOT[STATE_KEY] == state then
        ROOT[STATE_KEY] = nil
    end
end)

local dragging = false
local dragStart
local startPosition

bind(header.InputBegan, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = mainFrame.Position
    end
end)

bind(header.InputEnded, function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

bind(UserInputService.InputChanged, function(input)
    if not dragging then
        return
    end

    if input.UserInputType ~= Enum.UserInputType.MouseMovement and input.UserInputType ~= Enum.UserInputType.Touch then
        return
    end

    local delta = input.Position - dragStart
    mainFrame.Position = UDim2.new(
        startPosition.X.Scale,
        startPosition.X.Offset + delta.X,
        startPosition.Y.Scale,
        startPosition.Y.Offset + delta.Y
    )
end)

bind(UserInputService.InputBegan, function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Enum.KeyCode.Delete then
        setVisible(not state.Visible)
        return
    end

    for _, eventConfig in ipairs(EVENTS) do
        if input.KeyCode == eventConfig.ToggleKey then
            local eventState = state.EventStates[eventConfig.Id]
            setEventEnabled(eventConfig.Id, not (eventState and eventState.Enabled == true))
            break
        end
    end
end)

startDefaultEvents()

for _, eventConfig in ipairs(EVENTS) do
    task.spawn(function()
        while state.Running and screenGui.Parent and state.RunId == ROOT[RUN_KEY] do
            local eventState = state.EventStates[eventConfig.Id]
            if not eventState or eventState.Enabled ~= true then
                task.wait(0.1)
            else
                local ok, result = pcall(eventConfig.Run)
                if ok then
                    eventState.LastResult = result == false and "falhou" or "ok"
                else
                    eventState.LastResult = tostring(result)
                    warn("[FormigaAutomation] erro em " .. eventConfig.Id .. ": " .. tostring(result))
                end

                task.wait(eventConfig.Delay)
            end
        end
    end)
end

ROOT[STATE_KEY] = state

function state:Stop()
    self.Running = false
    stopAllEvents()
    disconnectAll()
    if screenGui and screenGui.Parent then
        screenGui:Destroy()
    end
end

print("[FormigaAutomation] GUI carregada")
print("[FormigaAutomation] Delete minimiza/restaura")
print("[FormigaAutomation] Abas: Automacao e Lutas")
print("[FormigaAutomation] C = click | B = hit combate | F = luta 1x1 | G = mob loop | H = BattleSkip5 | U = upgrade all | I = geradores | P = cartas | O = up runas | N = auto runas | J = ascensao | K = reenc | L = up reenc | M = mina | R = boss | T = hit boss")
print("[FormigaAutomation] Remotes mapeados do log: AscensionEvent, ReincarnationEvent, MineEvent, RaidEvent, ShopRestock")
print("[FormigaAutomation] Remotes assumidos/passados: ClickEvent, CombatClick, CombatEvent, UpgradeEvent, BuyPack, AutoStateEvent, RuneEvent, RaidClick")
