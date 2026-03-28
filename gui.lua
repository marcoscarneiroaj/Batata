local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ROOT = getgenv and getgenv() or _G

local function loadShared()
    if type(ROOT.Batata) == "table" and type(ROOT.Batata.Util) == "table" then
        _G.Batata = ROOT.Batata
        return ROOT.Batata
    end

    local candidates = {
        "shared.lua",
        "batata\\shared.lua",
        "Batata\\shared.lua",
        "C:\\Users\\User\\AppData\\Local\\Wave\\Workspace\\Batata\\shared.lua",
    }

    for _, path in ipairs(candidates) do
        local ok, source = pcall(readfile, path)
        if ok and type(source) == "string" and source ~= "" then
            local batata = loadstring(source, "@" .. path)()
            ROOT.Batata = batata
            _G.Batata = batata
            return batata
        end
    end

    error("shared.lua nao encontrado")
end

local Batata = loadShared()

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")

local SCREEN_GUI_NAME = "BatataMainGui"
local SCRIPT_PATHS = Batata.Paths

local existingGui = playerGui:FindFirstChild(SCREEN_GUI_NAME)
if existingGui then
    existingGui:Destroy()
end

local running = true
local guiVisible = true
local scriptPaused = false
local pausedSnapshot = nil
local connections = {}
local pages = {}
local tabs = {}
local moduleRows = {}
local moduleStatusLabels = {}
local statLabels = {}
local infoLabels = {}
local pickerButtons = {}
local profileButtons = {}

local function bind(signal, callback)
    table.insert(connections, signal:Connect(callback))
end

local function disconnectAll()
    for _, connection in ipairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end

    table.clear(connections)
end

local function corner(instance, radius)
    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, radius)
    uiCorner.Parent = instance
    return uiCorner
end

local function stroke(instance, color, transparency, thickness)
    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = color
    uiStroke.Transparency = transparency or 0
    uiStroke.Thickness = thickness or 1
    uiStroke.Parent = instance
    return uiStroke
end

local function runFile(path)
    local ok, result = pcall(function()
        return Batata.Util.LoadFile(path)
    end)

    return ok, result
end

local function isConnectionActive(connection)
    if not connection then
        return false
    end

    local connected = true
    pcall(function()
        connected = connection.Connected
    end)

    return connected ~= false
end

local function isDataConnected()
    return Batata.DataLoaded == true or isConnectionActive(Batata.DataConnection)
end

local function ensureData()
    local ok, result = pcall(Batata.Util.EnsureData)
    if ok then
        Batata.LastEnsureDataError = nil
        if result ~= nil then
            Batata.DataLoaded = true
        end
    else
        Batata.LastEnsureDataError = tostring(result)
    end
    return ok, result
end

local function ensureRemotes()
    local ok, result = pcall(Batata.Util.EnsureRemotes)
    return ok, result
end

local function ensureModule(moduleKey, pathKey)
    local module = Batata.Modules[moduleKey]
    if module and module.Running == true then
        Batata.LastEnsureModuleError = nil
        Batata.Util.ApplyCurrentDelayProfileToModule(module)
        return true, module
    end

    local remotesOk, remotesResult = ensureRemotes()
    if not remotesOk then
        Batata.LastEnsureModuleError = "falha ao carregar remotes.lua: " .. tostring(remotesResult)
        return false, nil
    end

    local ok, result = runFile(SCRIPT_PATHS[pathKey])
    if ok and type(result) == "table" then
        Batata.LastEnsureModuleError = nil
        Batata.Util.ApplyCurrentDelayProfileToModule(result)
    elseif not ok then
        Batata.LastEnsureModuleError = string.format("%s falhou: %s", tostring(SCRIPT_PATHS[pathKey] or pathKey), tostring(result))
    end

    return ok, result
end

local function ensureClickController()
    return ensureModule("AutoClick", "Click")
end

local function ensureFarmController()
    return ensureModule("AutoFarm", "Farm")
end

local function ensurePotionController()
    return ensureModule("AutoPotion", "Potion")
end

local function ensureNotificationsController()
    return ensureModule("AutoNotifications", "Notifications")
end

local function ensureGeneticsController()
    return ensureModule("AutoGenetics", "Genetics")
end

local function ensureUpgradeController()
    return ensureModule("AutoUpgrade", "Upgrade")
end

local function ensureSellController()
    return ensureModule("AutoSell", "Sell")
end

local function ensureFusionController()
    return ensureModule("AutoFusion", "Fusion")
end

local function ensureShopController()
    return ensureModule("AutoShop", "Shop")
end

local function ensureDigController()
    return ensureModule("AutoDig", "Dig")
end

local function ensurePrestigeController()
    return ensureModule("AutoPrestige", "Prestige")
end

local function ensurePrestigeUpgradeController()
    return ensureModule("AutoPrestigeUpgrade", "PrestigeUpgrade")
end

local function ensureAscensionController()
    return ensureModule("AutoAscension", "Ascension")
end

local moduleDefinitions = {
    { Key = "Data", ModuleName = nil, Ensure = ensureData, Title = "Data", Description = "Mantem o DataUpdated conectado.", Page = "Automacao" },
    { Key = "Notifications", ModuleName = "AutoNotifications", Ensure = ensureNotificationsController, Title = "Auto Avisos", Description = "Fecha toasts de erro, venda e compra.", Page = "Automacao" },
    { Key = "Farm", ModuleName = "AutoFarm", Ensure = ensureFarmController, Title = "Auto Geradores", Description = "Compra e troca o melhor gerador.", Page = "Fazenda" },
    { Key = "Potion", ModuleName = "AutoPotion", Ensure = ensurePotionController, Title = "Auto Pocao", Description = "Mantem as pocoes ativas.", Page = "Pocoes" },
    { Key = "Genetics", ModuleName = "AutoGenetics", Ensure = ensureGeneticsController, Title = "Auto Genetics", Description = "Rola slot com filtro.", Page = "Genetics", TemporarilyDisabled = true },
    { Key = "Upgrade", ModuleName = "AutoUpgrade", Ensure = ensureUpgradeController, Title = "Auto Upgrade", Description = "Compra o melhor upgrade.", Page = "Upgrade" },
    { Key = "Click", ModuleName = "AutoClick", Ensure = ensureClickController, Title = "Auto Click", Description = "Executa clique continuo.", Page = "Automacao" },
    { Key = "Sell", ModuleName = "AutoSell", Ensure = ensureSellController, Title = "Auto Sell", Description = "Vende batatas automaticamente.", Page = "Sell" },
    { Key = "Fusion", ModuleName = "AutoFusion", Ensure = ensureFusionController, Title = "Auto Fusao", Description = "Funde deixando 1 de cada.", Page = "Fusao" },
    { Key = "Shop", ModuleName = "AutoShop", Ensure = ensureShopController, Title = "Auto Loja", Description = "Compra rotacao nova menos rock.", Page = "Loja" },
    { Key = "Dig", ModuleName = "AutoDig", Ensure = ensureDigController, Title = "Auto Dig", Description = "Escava com stamina.", Page = "Dig" },
    { Key = "Prestige", ModuleName = "AutoPrestige", Ensure = ensurePrestigeController, Title = "Auto Prestige", Description = "Prestigia com troca de batata.", Page = "Prestigio" },
    { Key = "PrestigeUpgrade", ModuleName = "AutoPrestigeUpgrade", Ensure = ensurePrestigeUpgradeController, Title = "Auto PP Upgrade", Description = "Compra upgrades de PP apos ascender.", Page = "Automacao" },
    { Key = "Ascension", ModuleName = "AutoAscension", Ensure = ensureAscensionController, Title = "Auto Ascension", Description = "Ascende quando o custo bate.", Page = "Ascensao" },
}

local moduleByKey = {}
for _, definition in ipairs(moduleDefinitions) do
    moduleByKey[definition.Key] = definition
end

local getCurrentProfile
local getModuleState
local safeEnsure
local setStartupModules

local function isTemporarilyDisabled(definition)
    return type(definition) == "table" and definition.TemporarilyDisabled == true
end

local function cloneBooleanMap(source)
    local copy = {}
    if type(source) ~= "table" then
        return copy
    end

    for key, value in pairs(source) do
        copy[key] = value == true
    end

    return copy
end

local function buildModuleConfigSnapshot()
    local snapshot = {
        Data = true,
    }

    for _, definition in ipairs(moduleDefinitions) do
        if definition.ModuleName and not isTemporarilyDisabled(definition) then
            local state = getModuleState(definition)
            snapshot[definition.Key] = state and state.Enabled == true or false
        end
    end

    snapshot.Genetics = false
    return snapshot
end

local function buildLocalConfig()
    local _, profileName = getCurrentProfile()
    local sellState = getModuleState(moduleByKey.Sell)
    local prestigeState = getModuleState(moduleByKey.Prestige)
    local potionState = getModuleState(moduleByKey.Potion)

    return {
        Version = 1,
        DelayProfile = profileName,
        Modules = buildModuleConfigSnapshot(),
        Sell = {
            CommonMinPrice = sellState and sellState.CommonMinPrice or 0,
            GoldenMinPrice = sellState and sellState.GoldenMinPrice or 2,
            Delay = sellState and sellState.Delay or 1,
        },
        Prestige = {
            TargetValue = prestigeState and prestigeState.TargetValue or 0,
        },
        Ascension = {
            Blessing = getModuleState(moduleByKey.Ascension) and getModuleState(moduleByKey.Ascension).Blessing or "abundance",
        },
        Potion = {
            SelectedPotions = cloneBooleanMap(potionState and potionState.SelectedPotions or nil),
        },
        SavedAt = os.time(),
    }
end

local function saveLocalConfig()
    if not Batata.Util or type(Batata.Util.SaveLocalConfig) ~= "function" then
        return false
    end

    local ok, saved, err = pcall(function()
        return Batata.Util.SaveLocalConfig(buildLocalConfig())
    end)

    if not ok then
        Batata.LastConfigError = tostring(saved)
        return false
    end

    if saved ~= true then
        Batata.LastConfigError = tostring(err or "falha ao salvar config")
        return false
    end

    Batata.LastConfigError = nil
    return true
end

local function applySavedRuntimeConfig(config)
    if type(config) ~= "table" then
        return
    end

    if type(config.DelayProfile) == "string" then
        Batata.Util.SetDelayProfile(config.DelayProfile)
    end

    if type(config.Sell) == "table" then
        local ok, controller = ensureSellController()
        if ok and type(controller) == "table" then
            if type(controller.SetCommonMinPrice) == "function" then
                controller:SetCommonMinPrice(config.Sell.CommonMinPrice)
            end
            if type(controller.SetGoldenMinPrice) == "function" then
                controller:SetGoldenMinPrice(config.Sell.GoldenMinPrice)
            end
            if type(controller.SetDelay) == "function" then
                controller:SetDelay(config.Sell.Delay)
            end
        end
    end

    if type(config.Prestige) == "table" then
        local ok, controller = ensurePrestigeController()
        if ok and type(controller) == "table" and type(controller.SetTargetValue) == "function" then
            controller:SetTargetValue(config.Prestige.TargetValue)
        end
    end

    if type(config.Ascension) == "table" then
        local ok, controller = ensureAscensionController()
        if ok and type(controller) == "table" and type(controller.SetBlessing) == "function" then
            controller:SetBlessing(config.Ascension.Blessing)
        end
    end

    if type(config.Potion) == "table" and type(config.Potion.SelectedPotions) == "table" then
        local ok, controller = ensurePotionController()
        if ok and type(controller) == "table" and type(controller.SetPotionEnabled) == "function" then
            for potionId, enabled in pairs(config.Potion.SelectedPotions) do
                controller:SetPotionEnabled(potionId, enabled == true)
            end
        end
    end
end

local function applySavedStartupConfig()
    if not Batata.Util or type(Batata.Util.LoadLocalConfig) ~= "function" then
        setStartupModules()
        return
    end

    local ok, config = pcall(Batata.Util.LoadLocalConfig)
    if not ok or type(config) ~= "table" or type(config.Modules) ~= "table" then
        setStartupModules()
        return
    end

    applySavedRuntimeConfig(config)

    local dataOk = ensureData()
    if not dataOk then
        infoLabels.SummaryStatus.Text = "falha ao carregar data.lua"
        return
    end

    local failedModules = {}
    for _, definition in ipairs(moduleDefinitions) do
        if definition.ModuleName then
            if isTemporarilyDisabled(definition) then
                local loadedModule = Batata.Modules[definition.ModuleName]
                if loadedModule and type(loadedModule.SetEnabled) == "function" then
                    loadedModule:SetEnabled(false)
                end
            else
                local okEnsure, controller = safeEnsure(definition)
                if okEnsure and type(controller.SetEnabled) == "function" then
                    controller:SetEnabled(config.Modules[definition.Key] == true)
                else
                    table.insert(failedModules, definition.Title)
                end
            end
        end
    end

    pausedSnapshot = nil
    scriptPaused = false

    if #failedModules > 0 then
        infoLabels.SummaryStatus.Text = "alguns modulos falharam"
        infoLabels.SummaryModules.Text = table.concat(failedModules, ", ")
    end
end

getCurrentProfile = function()
    local profile, profileName = Batata.Util.GetCurrentDelayProfile()
    return profile or {}, profileName or "medio"
end

local function getGuiRefreshInterval()
    local profile = getCurrentProfile()
    local interval = tonumber(profile.GuiRefreshInterval) or 0.5

    if guiVisible ~= true then
        interval = math.max(interval, 1.25)
    end

    return interval
end

local function formatNumber(value)
    local numberValue = tonumber(value) or 0

    if numberValue >= 1e63 then
        return string.format("%.2fVg", numberValue / 1e63)
    elseif numberValue >= 1e60 then
        return string.format("%.2fNd", numberValue / 1e60)
    elseif numberValue >= 1e57 then
        return string.format("%.2fOd", numberValue / 1e57)
    elseif numberValue >= 1e54 then
        return string.format("%.2fSd", numberValue / 1e54)
    elseif numberValue >= 1e51 then
        return string.format("%.2fQid", numberValue / 1e51)
    elseif numberValue >= 1e48 then
        return string.format("%.2fQad", numberValue / 1e48)
    elseif numberValue >= 1e45 then
        return string.format("%.2fDd", numberValue / 1e45)
    elseif numberValue >= 1e42 then
        return string.format("%.2fUd", numberValue / 1e42)
    elseif numberValue >= 1e39 then
        return string.format("%.2fDc", numberValue / 1e39)
    elseif numberValue >= 1e36 then
        return string.format("%.2fNo", numberValue / 1e36)
    elseif numberValue >= 1e33 then
        return string.format("%.2fOc", numberValue / 1e33)
    elseif numberValue >= 1e30 then
        return string.format("%.2fSp", numberValue / 1e30)
    elseif numberValue >= 1e27 then
        return string.format("%.2fSx", numberValue / 1e27)
    elseif numberValue >= 1e24 then
        return string.format("%.2fQi", numberValue / 1e24)
    elseif numberValue >= 1e21 then
        return string.format("%.2fQa", numberValue / 1e21)
    elseif numberValue >= 1e18 then
        return string.format("%.2fQt", numberValue / 1e18)
    elseif numberValue >= 1e15 then
        return string.format("%.2fQd", numberValue / 1e15)
    elseif numberValue >= 1e12 then
        return string.format("%.2fT", numberValue / 1e12)
    elseif numberValue >= 1e9 then
        return string.format("%.2fB", numberValue / 1e9)
    elseif numberValue >= 1e6 then
        return string.format("%.2fM", numberValue / 1e6)
    elseif numberValue >= 1e3 then
        return string.format("%.2fK", numberValue / 1e3)
    end

    return tostring(math.floor(numberValue))
end

local function getCurrencySnapshot()
    local data = Batata.Data
    local stats = data and data.Stats or nil
    local itemInventory = data and data.ItemInventory or nil

    return {
        Cash = stats and stats.Cash or 0,
        MagicPotatoes = stats and stats.MagicPotatoes or 0,
        PrestigePoints = stats and stats.PrestigePoints or 0,
        PotatoEyes = itemInventory and itemInventory.potato_eyes or 0,
        StarchDust = itemInventory and itemInventory.starch_dust or 0,
    }
end

getModuleState = function(definition)
    if definition.Key == "Data" then
        local connected = isDataConnected()
        return {
            Enabled = connected,
            LastStatus = connected and "Data conectado" or "Data desconectado",
        }
    end

    local module = definition.ModuleName and Batata.Modules[definition.ModuleName] or nil
    if module and type(module.GetState) == "function" then
        return module:GetState()
    end

    return module
end

safeEnsure = function(definition)
    local ok, result = definition.Ensure()
    if definition.Key == "Data" then
        return ok, result
    end

    if not ok or type(result) ~= "table" then
        return false, nil
    end

    return true, result
end

local function countEnabledModules()
    local enabled = 0
    local total = 0

    for _, definition in ipairs(moduleDefinitions) do
        if definition.Key ~= "Data" and not isTemporarilyDisabled(definition) then
            total = total + 1
            local state = getModuleState(definition)
            if state and state.Enabled == true then
                enabled = enabled + 1
            end
        end
    end

    return enabled, total
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = SCREEN_GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 760, 0, 500)
mainFrame.Position = UDim2.new(0.5, -380, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(13, 16, 24)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
corner(mainFrame, 18)
stroke(mainFrame, Color3.fromRGB(95, 110, 255), 0.45, 1.2)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
header.BorderSizePixel = 0
header.Parent = mainFrame
corner(header, 18)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 18)
headerFix.Position = UDim2.new(0, 0, 1, -18)
headerFix.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
headerFix.BorderSizePixel = 0
headerFix.Parent = header

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 12, 0, 12)
dot.Position = UDim2.new(0, 18, 0.5, -6)
dot.BackgroundColor3 = Color3.fromRGB(92, 234, 215)
dot.BorderSizePixel = 0
dot.Parent = header
corner(dot, 99)

local headerTitle = Instance.new("TextLabel")
headerTitle.BackgroundTransparency = 1
headerTitle.Position = UDim2.new(0, 36, 0, 0)
headerTitle.Size = UDim2.new(0, 320, 1, 0)
headerTitle.Text = "Batata Automation Panel"
headerTitle.Font = Enum.Font.GothamBold
headerTitle.TextSize = 16
headerTitle.TextColor3 = Color3.fromRGB(245, 247, 255)
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Parent = header

local headerSubtitle = Instance.new("TextLabel")
headerSubtitle.BackgroundTransparency = 1
headerSubtitle.Position = UDim2.new(0, 250, 0, 0)
headerSubtitle.Size = UDim2.new(0, 240, 1, 0)
headerSubtitle.Text = ""
headerSubtitle.Font = Enum.Font.Gotham
headerSubtitle.TextSize = 11
headerSubtitle.TextColor3 = Color3.fromRGB(134, 145, 173)
headerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
headerSubtitle.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 34, 0, 34)
closeButton.Position = UDim2.new(1, -48, 0.5, -17)
closeButton.BackgroundColor3 = Color3.fromRGB(201, 74, 74)
closeButton.BorderSizePixel = 0
closeButton.Text = "x"
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 14
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.Parent = header
corner(closeButton, 10)

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 34, 0, 34)
minimizeButton.Position = UDim2.new(1, -92, 0.5, -17)
minimizeButton.BackgroundColor3 = Color3.fromRGB(62, 72, 105)
minimizeButton.BorderSizePixel = 0
minimizeButton.Text = "-"
minimizeButton.Font = Enum.Font.GothamBold
minimizeButton.TextSize = 18
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Parent = header
corner(minimizeButton, 10)

local left = Instance.new("Frame")
left.Size = UDim2.new(0, 150, 1, -66)
left.Position = UDim2.new(0, 12, 0, 56)
left.BackgroundColor3 = Color3.fromRGB(9, 13, 24)
left.BorderSizePixel = 0
left.Parent = mainFrame
corner(left, 16)
stroke(left, Color3.fromRGB(71, 82, 116), 0.55, 1)

local right = Instance.new("Frame")
right.Size = UDim2.new(1, -174, 1, -66)
right.Position = UDim2.new(0, 168, 0, 56)
right.BackgroundColor3 = Color3.fromRGB(8, 12, 22)
right.BorderSizePixel = 0
right.Parent = mainFrame
corner(right, 16)
stroke(right, Color3.fromRGB(71, 82, 116), 0.55, 1)

local navTitle = Instance.new("TextLabel")
navTitle.BackgroundTransparency = 1
navTitle.Position = UDim2.new(0, 14, 0, 12)
navTitle.Size = UDim2.new(1, -20, 0, 20)
navTitle.Text = "ABAS"
navTitle.Font = Enum.Font.GothamBold
navTitle.TextSize = 12
navTitle.TextColor3 = Color3.fromRGB(125, 137, 170)
navTitle.TextXAlignment = Enum.TextXAlignment.Left
navTitle.Parent = left

local navHolder = Instance.new("ScrollingFrame")
navHolder.BackgroundTransparency = 1
navHolder.Position = UDim2.new(0, 10, 0, 38)
navHolder.Size = UDim2.new(1, -20, 1, -48)
navHolder.CanvasSize = UDim2.new(0, 0, 0, 560)
navHolder.ScrollBarThickness = 3
navHolder.BorderSizePixel = 0
navHolder.Parent = left

local navLayout = Instance.new("UIListLayout")
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = navHolder

local function createTab(name, active)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0, 38)
    button.BackgroundColor3 = active and Color3.fromRGB(76, 95, 228) or Color3.fromRGB(22, 28, 44)
    button.BorderSizePixel = 0
    button.Text = name
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 13
    button.TextColor3 = Color3.fromRGB(242, 245, 255)
    button.Parent = navHolder
    corner(button, 12)
    stroke(button, active and Color3.fromRGB(137, 148, 255) or Color3.fromRGB(76, 86, 116), active and 0.2 or 0.55, 1)
    return button
end

local function createPage(name)
    local page = Instance.new("Frame")
    page.Name = name
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = right
    return page
end

local function createPageHeader(parent, titleText, subtitleText)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 12, 0, 10)
    title.Size = UDim2.new(1, -24, 0, 22)
    title.Text = titleText
    title.Font = Enum.Font.GothamBold
    title.TextSize = 17
    title.TextColor3 = Color3.fromRGB(245, 247, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = parent

    local subtitle = Instance.new("TextLabel")
    subtitle.BackgroundTransparency = 1
    subtitle.Position = UDim2.new(0, 12, 0, 32)
    subtitle.Size = UDim2.new(1, -24, 0, 18)
    subtitle.Text = subtitleText
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 11
    subtitle.TextColor3 = Color3.fromRGB(135, 147, 176)
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = parent
end

local function createPanel(parent, x, y, w, h, titleText)
    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, w, 0, h)
    panel.Position = UDim2.new(0, x, 0, y)
    panel.BackgroundColor3 = Color3.fromRGB(18, 24, 39)
    panel.BorderSizePixel = 0
    panel.Parent = parent
    corner(panel, 14)
    stroke(panel, Color3.fromRGB(72, 84, 115), 0.55, 1)

    if titleText and titleText ~= "" then
        local title = Instance.new("TextLabel")
        title.BackgroundTransparency = 1
        title.Position = UDim2.new(0, 14, 0, 12)
        title.Size = UDim2.new(1, -28, 0, 20)
        title.Text = titleText
        title.Font = Enum.Font.GothamBold
        title.TextSize = 14
        title.TextColor3 = Color3.fromRGB(245, 247, 255)
        title.TextXAlignment = Enum.TextXAlignment.Left
        title.Parent = panel
    end

    return panel
end

local function createMiniCard(parent, x, y, w, titleText, valueKey, accentColor)
    local card = createPanel(parent, x, y, w, 58, nil)

    local line = Instance.new("Frame")
    line.Size = UDim2.new(0, 3, 1, -16)
    line.Position = UDim2.new(0, 8, 0, 8)
    line.BackgroundColor3 = accentColor
    line.BorderSizePixel = 0
    line.Parent = card
    corner(line, 9)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 18, 0, 9)
    title.Size = UDim2.new(1, -24, 0, 15)
    title.Text = titleText
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 10
    title.TextColor3 = Color3.fromRGB(146, 157, 184)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = card

    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.Position = UDim2.new(0, 18, 0, 24)
    value.Size = UDim2.new(1, -24, 0, 20)
    value.Text = "-"
    value.Font = Enum.Font.GothamBold
    value.TextSize = 13
    value.TextColor3 = Color3.fromRGB(245, 247, 255)
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.Parent = card

    statLabels[valueKey] = value
end

local function createInfoLabel(parent, x, y, w, h, key, titleText)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, x, 0, y)
    title.Size = UDim2.new(0, w, 0, 16)
    title.Text = titleText
    title.Font = Enum.Font.GothamMedium
    title.TextSize = 10
    title.TextColor3 = Color3.fromRGB(146, 157, 184)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = parent

    local value = Instance.new("TextLabel")
    value.BackgroundTransparency = 1
    value.Position = UDim2.new(0, x, 0, y + 16)
    value.Size = UDim2.new(0, w, 0, h)
    value.Text = "-"
    value.TextWrapped = true
    value.TextYAlignment = Enum.TextYAlignment.Top
    value.Font = Enum.Font.GothamBold
    value.TextSize = 13
    value.TextColor3 = Color3.fromRGB(245, 247, 255)
    value.TextXAlignment = Enum.TextXAlignment.Left
    value.Parent = parent

    infoLabels[key] = value
    return value
end

local function createSwitch(parent, x, y, initialState)
    local bg = Instance.new("TextButton")
    bg.Size = UDim2.new(0, 48, 0, 24)
    bg.Position = UDim2.new(0, x, 0, y)
    bg.BackgroundColor3 = initialState and Color3.fromRGB(57, 186, 119) or Color3.fromRGB(73, 82, 109)
    bg.BorderSizePixel = 0
    bg.Text = ""
    bg.AutoButtonColor = false
    bg.Parent = parent
    corner(bg, 999)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 20, 0, 20)
    knob.Position = initialState and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.Parent = bg
    corner(knob, 999)

    local function setState(state)
        bg.BackgroundColor3 = state and Color3.fromRGB(57, 186, 119) or Color3.fromRGB(73, 82, 109)
        knob.Position = state and UDim2.new(1, -22, 0.5, -10) or UDim2.new(0, 2, 0.5, -10)
    end

    return bg, setState
end

local function createInput(parent, x, y, w, text)
    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0, w, 0, 34)
    box.Position = UDim2.new(0, x, 0, y)
    box.BackgroundColor3 = Color3.fromRGB(27, 34, 50)
    box.BorderSizePixel = 0
    box.Text = text
    box.ClearTextOnFocus = false
    box.Font = Enum.Font.Gotham
    box.TextSize = 13
    box.TextColor3 = Color3.fromRGB(245, 247, 255)
    box.Parent = parent
    corner(box, 10)
    stroke(box, Color3.fromRGB(82, 93, 125), 0.45, 1)
    return box
end

local function createChoiceButton(parent, x, y, w, h, text)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, w, 0, h)
    button.Position = UDim2.new(0, x, 0, y)
    button.BackgroundColor3 = Color3.fromRGB(27, 34, 50)
    button.BorderSizePixel = 0
    button.Text = text
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 11
    button.TextWrapped = true
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.TextColor3 = Color3.fromRGB(238, 242, 255)
    button.ClipsDescendants = true
    button.Parent = parent
    corner(button, 10)
    stroke(button, Color3.fromRGB(82, 93, 125), 0.45, 1)
    return button
end

local function setChoiceButtonState(button, enabled)
    button.BackgroundColor3 = enabled and Color3.fromRGB(76, 95, 228) or Color3.fromRGB(27, 34, 50)
    local uiStroke = button:FindFirstChildOfClass("UIStroke")
    if uiStroke then
        uiStroke.Color = enabled and Color3.fromRGB(137, 148, 255) or Color3.fromRGB(82, 93, 125)
        uiStroke.Transparency = enabled and 0.15 or 0.45
    end
end

local principalPage = createPage("Principal")
local automationPage = createPage("Automacao")
local clickPage = createPage("Click")
local geneticsPage = createPage("Genetics")
local farmPage = createPage("Fazenda")
local upgradePage = createPage("Upgrade")
local sellPage = createPage("Sell")
local fusionPage = createPage("Fusao")
local shopPage = createPage("Loja")
local digPage = createPage("Dig")
local prestigePage = createPage("Prestigio")
local ascensionPage = createPage("Ascensao")
local potionPage = createPage("Pocoes")

pages.Principal = principalPage
pages.Automacao = automationPage
pages.Click = clickPage
pages.Genetics = geneticsPage
pages.Fazenda = farmPage
pages.Geradores = farmPage
pages.Upgrade = upgradePage
pages.Sell = sellPage
pages.Fusao = fusionPage
pages.Loja = shopPage
pages.Dig = digPage
pages.Prestigio = prestigePage
pages.Ascensao = ascensionPage
pages.Pocoes = potionPage

createPageHeader(principalPage, "Painel Principal", "Visao geral do script e estatisticas principais")
createPageHeader(automationPage, "Automacao", "Ative ou desative cada modulo individualmente")
createPageHeader(clickPage, "Auto Click", "Controle do clique continuo")
createPageHeader(geneticsPage, "Genetics", "Slot, bonus alvo e raridade minima")
createPageHeader(farmPage, "Geradores", "Controle da compra e troca de geradores")
createPageHeader(upgradePage, "Upgrade", "Controle de upgrades automaticos")
createPageHeader(sellPage, "Auto Sell", "Venda automatica de batatas")
createPageHeader(fusionPage, "Fusao", "Fusao automatica com seguranca")
createPageHeader(shopPage, "Loja", "Compra da rotacao da loja")
createPageHeader(digPage, "Dig", "Escavacao por stamina e tiles")
createPageHeader(prestigePage, "Prestigio", "Prestigio com glitter_potato")
createPageHeader(ascensionPage, "Ascensao", "Ascensao automatica")
createPageHeader(potionPage, "Pocoes", "Renovacao automatica de buffs")

local masterPanel = createPanel(principalPage, 12, 62, 562, 62, "Script geral")

local masterDesc = Instance.new("TextLabel")
masterDesc.BackgroundTransparency = 1
masterDesc.Position = UDim2.new(0, 14, 0, 34)
masterDesc.Size = UDim2.new(1, -120, 0, 16)
masterDesc.Text = "Pause ou retome todas as rotinas do script"
masterDesc.Font = Enum.Font.Gotham
masterDesc.TextSize = 11
masterDesc.TextColor3 = Color3.fromRGB(145, 155, 182)
masterDesc.TextXAlignment = Enum.TextXAlignment.Left
masterDesc.Parent = masterPanel

local masterSwitch, setMasterSwitch = createSwitch(masterPanel, 500, 19, true)

createMiniCard(principalPage, 12, 136, 112, "Cash", "Cash", Color3.fromRGB(92, 234, 215))
createMiniCard(principalPage, 132, 136, 112, "Batata magica", "MagicPotatoes", Color3.fromRGB(129, 140, 248))
createMiniCard(principalPage, 252, 136, 112, "PP", "PrestigePoints", Color3.fromRGB(250, 204, 21))
createMiniCard(principalPage, 372, 136, 112, "Olho", "PotatoEyes", Color3.fromRGB(251, 146, 60))
createMiniCard(principalPage, 12, 202, 152, "Po estela", "StarchDust", Color3.fromRGB(96, 165, 250))
createMiniCard(principalPage, 172, 202, 152, "Modulos ON", "EnabledCount", Color3.fromRGB(192, 132, 252))
createMiniCard(principalPage, 332, 202, 152, "Estado", "PauseState", Color3.fromRGB(74, 222, 128))

local summaryPanel = createPanel(principalPage, 12, 268, 562, 118, "Resumo atual")
createInfoLabel(summaryPanel, 14, 38, 260, 24, "SummaryStatus", "Status geral")
createInfoLabel(summaryPanel, 290, 38, 250, 24, "SummaryModules", "Detalhes")

local profileTitle = Instance.new("TextLabel")
profileTitle.BackgroundTransparency = 1
profileTitle.Position = UDim2.new(0, 14, 0, 72)
profileTitle.Size = UDim2.new(0, 220, 0, 14)
profileTitle.Text = "Perfil de delay"
profileTitle.Font = Enum.Font.GothamMedium
profileTitle.TextSize = 10
profileTitle.TextColor3 = Color3.fromRGB(146, 157, 184)
profileTitle.TextXAlignment = Enum.TextXAlignment.Left
profileTitle.Parent = summaryPanel

profileButtons.economico = createChoiceButton(summaryPanel, 14, 86, 112, 20, "Economico")
profileButtons.medio = createChoiceButton(summaryPanel, 134, 86, 100, 20, "Medio")
profileButtons.maximo = createChoiceButton(summaryPanel, 242, 86, 100, 20, "Maximo")

local allOnButton = Instance.new("TextButton")
allOnButton.Size = UDim2.new(0, 132, 0, 40)
allOnButton.Position = UDim2.new(0, 12, 0, 398)
allOnButton.BackgroundColor3 = Color3.fromRGB(58, 160, 103)
allOnButton.BorderSizePixel = 0
allOnButton.Text = "Ligar All"
allOnButton.Font = Enum.Font.GothamBold
allOnButton.TextSize = 13
allOnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
allOnButton.Parent = principalPage
corner(allOnButton, 12)

local allOffButton = Instance.new("TextButton")
allOffButton.Size = UDim2.new(0, 132, 0, 40)
allOffButton.Position = UDim2.new(0, 152, 0, 398)
allOffButton.BackgroundColor3 = Color3.fromRGB(184, 82, 82)
allOffButton.BorderSizePixel = 0
allOffButton.Text = "Desligar All"
allOffButton.Font = Enum.Font.GothamBold
allOffButton.TextSize = 13
allOffButton.TextColor3 = Color3.fromRGB(255, 255, 255)
allOffButton.Parent = principalPage
corner(allOffButton, 12)

local saveConfigButton = Instance.new("TextButton")
saveConfigButton.Size = UDim2.new(0, 132, 0, 40)
saveConfigButton.Position = UDim2.new(0, 292, 0, 398)
saveConfigButton.BackgroundColor3 = Color3.fromRGB(67, 109, 196)
saveConfigButton.BorderSizePixel = 0
saveConfigButton.Text = "Salvar Config"
saveConfigButton.Font = Enum.Font.GothamBold
saveConfigButton.TextSize = 13
saveConfigButton.TextColor3 = Color3.fromRGB(255, 255, 255)
saveConfigButton.Parent = principalPage
corner(saveConfigButton, 12)

local reconnectDataButton = Instance.new("TextButton")
reconnectDataButton.Size = UDim2.new(0, 132, 0, 40)
reconnectDataButton.Position = UDim2.new(0, 432, 0, 398)
reconnectDataButton.BackgroundColor3 = Color3.fromRGB(69, 79, 119)
reconnectDataButton.BorderSizePixel = 0
reconnectDataButton.Text = "Reconectar Data"
reconnectDataButton.Font = Enum.Font.GothamBold
reconnectDataButton.TextSize = 13
reconnectDataButton.TextColor3 = Color3.fromRGB(255, 255, 255)
reconnectDataButton.Parent = principalPage
corner(reconnectDataButton, 12)

local automationScroll = Instance.new("ScrollingFrame")
automationScroll.BackgroundTransparency = 1
automationScroll.Position = UDim2.new(0, 0, 0, 58)
automationScroll.Size = UDim2.new(1, 0, 1, -58)
automationScroll.CanvasSize = UDim2.new(0, 0, 0, 760)
automationScroll.ScrollBarThickness = 4
automationScroll.BorderSizePixel = 0
automationScroll.Parent = automationPage

local automationLayout = Instance.new("UIListLayout")
automationLayout.Padding = UDim.new(0, 10)
automationLayout.Parent = automationScroll

automationLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    automationScroll.CanvasSize = UDim2.new(0, 0, 0, automationLayout.AbsoluteContentSize.Y + 12)
end)

local automationPadding = Instance.new("UIPadding")
automationPadding.PaddingLeft = UDim.new(0, 12)
automationPadding.PaddingRight = UDim.new(0, 12)
automationPadding.PaddingTop = UDim.new(0, 4)
automationPadding.PaddingBottom = UDim.new(0, 8)
automationPadding.Parent = automationScroll

navLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    navHolder.CanvasSize = UDim2.new(0, 0, 0, navLayout.AbsoluteContentSize.Y + 12)
end)

local function createAutomationRow(definition)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, 0, 0, 64)
    row.BackgroundColor3 = Color3.fromRGB(18, 24, 39)
    row.BorderSizePixel = 0
    row.AutoButtonColor = false
    row.Text = ""
    row.Parent = automationScroll
    corner(row, 14)
    stroke(row, Color3.fromRGB(72, 84, 115), 0.55, 1)

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, 16, 0, 10)
    title.Size = UDim2.new(1, -100, 0, 18)
    title.Text = definition.Title
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(239, 243, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = row

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.new(0, 16, 0, 30)
    desc.Size = UDim2.new(1, -120, 0, 16)
    desc.Text = definition.Description
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 10
    desc.TextColor3 = Color3.fromRGB(138, 149, 177)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = row

    local switchButton, setSwitch = createSwitch(row, 486, 20, false)
    moduleRows[definition.Key] = {
        Row = row,
        SwitchButton = switchButton,
        SetSwitch = setSwitch,
    }
end

for _, definition in ipairs(moduleDefinitions) do
    createAutomationRow(definition)
end

local function createModulePage(page, definition, subtitleText)
    local controlPanel = createPanel(page, 12, 62, 562, 78, definition.Title)

    local description = Instance.new("TextLabel")
    description.BackgroundTransparency = 1
    description.Position = UDim2.new(0, 14, 0, 34)
    description.Size = UDim2.new(1, -90, 0, 16)
    description.Text = subtitleText
    description.Font = Enum.Font.Gotham
    description.TextSize = 11
    description.TextColor3 = Color3.fromRGB(145, 155, 182)
    description.TextXAlignment = Enum.TextXAlignment.Left
    description.Parent = controlPanel

    moduleStatusLabels[definition.Key] = createInfoLabel(page, 26, 170, 530, 52, definition.Key .. "Status", "Status atual")
end

createModulePage(farmPage, moduleByKey.Farm, "Compra o melhor gerador disponivel e troca quando um melhor libera.")
createModulePage(clickPage, moduleByKey.Click, "Executa o remote principal de clique continuamente.")
createModulePage(upgradePage, moduleByKey.Upgrade, "Compra sempre o melhor upgrade compravel no momento.")
createModulePage(sellPage, moduleByKey.Sell, "Vende comum e dourada de forma independente.")
createModulePage(fusionPage, moduleByKey.Fusion, "Funde com foco em seguranca e mantendo 1 no inventario.")
createModulePage(shopPage, moduleByKey.Shop, "Compra itens de cada rotacao, menos rock.")
createModulePage(digPage, moduleByKey.Dig, "Escava quando a stamina atual estiver em 5 ou mais.")
createModulePage(prestigePage, moduleByKey.Prestige, "Equipa solar_flare_potato, prestigia e volta para the_first_potato.")
createModulePage(ascensionPage, moduleByKey.Ascension, "Usa a blessing escolhida quando os PP atuais batem o custo.")
createModulePage(potionPage, moduleByKey.Potion, "Renova click, golden, luck, drop chance e production.")
createModulePage(geneticsPage, moduleByKey.Genetics, "Rola o slot escolhido com filtros configurados.")

createInfoLabel(farmPage, 26, 256, 530, 52, "FarmExtra", "Alvo atual")
createInfoLabel(clickPage, 26, 256, 530, 52, "ClickExtra", "Detalhes")
createInfoLabel(upgradePage, 26, 256, 530, 52, "UpgradeExtra", "Alvo atual")
createInfoLabel(sellPage, 26, 256, 530, 52, "SellExtra", "Detalhes")
createInfoLabel(fusionPage, 26, 256, 530, 52, "FusionExtra", "Detalhes")
createInfoLabel(shopPage, 26, 256, 530, 52, "ShopExtra", "Detalhes")
createInfoLabel(digPage, 26, 256, 530, 52, "DigExtra", "Detalhes")
createInfoLabel(prestigePage, 26, 256, 530, 52, "PrestigeExtra", "Detalhes")
createInfoLabel(ascensionPage, 26, 256, 530, 52, "AscensionExtra", "Detalhes")
createInfoLabel(potionPage, 26, 256, 530, 52, "PotionExtra", "Detalhes")

local sellConfigPanel = createPanel(sellPage, 12, 256, 562, 170, "Configuracao dos valores de venda")
local function createSimpleRowTitle(parent, x, y, titleText, descText)
    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Position = UDim2.new(0, x, 0, y)
    title.Size = UDim2.new(0, 280, 0, 18)
    title.Text = titleText
    title.Font = Enum.Font.GothamSemibold
    title.TextSize = 13
    title.TextColor3 = Color3.fromRGB(239, 243, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = parent

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Position = UDim2.new(0, x, 0, y + 18)
    desc.Size = UDim2.new(0, 320, 0, 16)
    desc.Text = descText
    desc.Font = Enum.Font.Gotham
    desc.TextSize = 10
    desc.TextColor3 = Color3.fromRGB(138, 149, 177)
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Parent = parent
end

createSimpleRowTitle(sellConfigPanel, 14, 38, "Batata dourada", "Vende quando o preco atual estiver acima desse valor.")
createSimpleRowTitle(sellConfigPanel, 14, 84, "Batata comum", "Vende quando o preco atual estiver acima desse valor.")
createSimpleRowTitle(sellConfigPanel, 14, 130, "Espere entre venda segundos", "Tempo entre cada tentativa de venda.")
local sellGoldenBox = createInput(sellConfigPanel, 430, 34, 110, "2")
local sellCommonBox = createInput(sellConfigPanel, 430, 80, 110, "0")
local sellDelayBox = createInput(sellConfigPanel, 430, 126, 110, "1")

local prestigeStatsPanel = createPanel(prestigePage, 12, 256, 562, 168, "Sessao")
createInfoLabel(prestigeStatsPanel, 14, 38, 250, 20, "PrestigeCount", "Prestigios desde o inicio")
createInfoLabel(prestigeStatsPanel, 290, 38, 250, 20, "PrestigePointsSession", "PP total desde o inicio")
createInfoLabel(prestigeStatsPanel, 14, 92, 250, 20, "PrestigeLastClock", "Horario do ultimo prestigio")
createInfoLabel(prestigeStatsPanel, 290, 92, 250, 20, "PrestigeWait", "Tempo para nova tentativa")

local ascensionBlessingPanel = createPanel(ascensionPage, 12, 256, 562, 76, "Blessing")
local ascensionBlessingHint = Instance.new("TextLabel")
ascensionBlessingHint.BackgroundTransparency = 1
ascensionBlessingHint.Position = UDim2.new(0, 14, 0, 36)
ascensionBlessingHint.Size = UDim2.new(0, 220, 0, 14)
ascensionBlessingHint.Text = "Cada PC pode usar uma blessing diferente."
ascensionBlessingHint.Font = Enum.Font.Gotham
ascensionBlessingHint.TextSize = 10
ascensionBlessingHint.TextColor3 = Color3.fromRGB(138, 149, 177)
ascensionBlessingHint.TextXAlignment = Enum.TextXAlignment.Left
ascensionBlessingHint.Parent = ascensionBlessingPanel

local ascensionBlessingOptions = {
    { Id = "golden", Label = "Golden" },
    { Id = "prestige", Label = "Prestige" },
    { Id = "thrifty", Label = "Thrifty" },
    { Id = "collector", Label = "Collector" },
    { Id = "abundance", Label = "Abundance" },
}

for index, blessingInfo in ipairs(ascensionBlessingOptions) do
    local button = createChoiceButton(ascensionBlessingPanel, 14 + ((index - 1) * 108), 50, 98, 18, blessingInfo.Label)
    button.TextSize = 10
    pickerButtons["ascension_" .. blessingInfo.Id] = button
end

local ascensionStatsPanel = createPanel(ascensionPage, 12, 344, 562, 80, "Sessao")
createInfoLabel(ascensionStatsPanel, 14, 34, 250, 16, "AscensionCount", "Ascensoes desde o inicio")
createInfoLabel(ascensionStatsPanel, 290, 34, 250, 16, "AscensionLastClock", "Horario da ultima ascensao")
createInfoLabel(ascensionStatsPanel, 14, 56, 250, 16, "AscensionPP", "PP atual")
createInfoLabel(ascensionStatsPanel, 290, 56, 250, 16, "AscensionWait", "Tempo para nova tentativa")

local geneticsScroll = Instance.new("ScrollingFrame")
geneticsScroll.BackgroundTransparency = 1
geneticsScroll.Position = UDim2.new(0, 0, 0, 240)
geneticsScroll.Size = UDim2.new(1, 0, 1, -240)
geneticsScroll.CanvasSize = UDim2.new(0, 0, 0, 360)
geneticsScroll.ScrollBarThickness = 4
geneticsScroll.BorderSizePixel = 0
geneticsScroll.Parent = geneticsPage

local geneticsConfig = createPanel(geneticsScroll, 12, 0, 562, 224, "Configuracao")

local slotTitle = Instance.new("TextLabel")
slotTitle.BackgroundTransparency = 1
slotTitle.Position = UDim2.new(0, 14, 0, 38)
slotTitle.Size = UDim2.new(0, 80, 0, 14)
slotTitle.Text = "Slot"
slotTitle.Font = Enum.Font.Gotham
slotTitle.TextSize = 10
slotTitle.TextColor3 = Color3.fromRGB(138, 151, 179)
slotTitle.TextXAlignment = Enum.TextXAlignment.Left
slotTitle.Parent = geneticsConfig
slotTitle.Visible = false

local effectTitle = slotTitle:Clone()
effectTitle.Position = UDim2.new(0, 110, 0, 38)
effectTitle.Size = UDim2.new(0, 160, 0, 14)
effectTitle.Text = "Bonus alvo"
effectTitle.Parent = geneticsConfig
effectTitle.Visible = false

local rarityTitle = slotTitle:Clone()
rarityTitle.Position = UDim2.new(0, 392, 0, 38)
rarityTitle.Size = UDim2.new(0, 140, 0, 14)
rarityTitle.Text = "Raridade min."
rarityTitle.Parent = geneticsConfig
rarityTitle.Visible = false

local geneticsSlotBox = createInput(geneticsConfig, 14, 56, 72, "3")
local geneticsEffectBox = createInput(geneticsConfig, 110, 56, 252, "PrestigePointBonus")
local geneticsRarityBox = createInput(geneticsConfig, 392, 56, 156, "epic")
geneticsSlotBox.Visible = false
geneticsEffectBox.Visible = false
geneticsRarityBox.Visible = false

local geneticsHint = Instance.new("TextLabel")
geneticsHint.BackgroundTransparency = 1
geneticsHint.Position = UDim2.new(0, 14, 0, 196)
geneticsHint.Size = UDim2.new(1, -28, 0, 14)
geneticsHint.Text = "Bonus vazio = focar apenas na raridade."
geneticsHint.Font = Enum.Font.Gotham
geneticsHint.TextSize = 10
geneticsHint.TextColor3 = Color3.fromRGB(138, 149, 177)
geneticsHint.TextXAlignment = Enum.TextXAlignment.Left
geneticsHint.Parent = geneticsConfig

createInfoLabel(geneticsScroll, 26, 234, 530, 40, "GeneticsExtra", "Ultimo resultado")

local geneticsRarityPanel = createPanel(geneticsConfig, 14, 56, 270, 54, "Raridades")
local geneticsSlotPanel = createPanel(geneticsConfig, 292, 56, 256, 54, "Slots")

local rarityOptions = { "common", "uncommon", "rare", "epic", "legendary", "mythic", "secret" }
for index, rarity in ipairs(rarityOptions) do
    local button = createChoiceButton(geneticsRarityPanel, 14 + ((index - 1) * 36), 26, 32, 22, string.sub(rarity, 1, 1):upper())
    pickerButtons["rarity_" .. rarity] = button
end

for slotIndex = 1, 8 do
    local button = createChoiceButton(geneticsSlotPanel, 14 + ((slotIndex - 1) * 32), 26, 28, 22, tostring(slotIndex))
    pickerButtons["slot_" .. tostring(slotIndex)] = button
end

local geneticsEffectsPanel = createPanel(geneticsConfig, 14, 112, 534, 78, "Bonus")
local effectOptions = {
    { Id = "PrestigePointBonus", Label = "Prestige PP" },
    { Id = "GeneratorMultiplier", Label = "Generator Mult" },
    { Id = "CollectableDropChance", Label = "Collect Drop" },
    { Id = "GoldenGenBonus", Label = "Golden Gen" },
    { Id = "DoubleClickChance", Label = "Double Click" },
    { Id = "CriticalClickChance", Label = "Critical Click" },
    { Id = "OfflineBonus", Label = "Offline Bonus" },
    { Id = "AutoClickerSpeedBonus", Label = "AutoClick Speed" },
    { Id = "PotatoMultiplier", Label = "Potato Mult" },
    { Id = "ClickMultiplier", Label = "Click Mult" },
    { Id = "CostReduction", Label = "Cost Reduction" },
    { Id = "GoldenConversionBonus", Label = "Golden Conv" },
}

for index, effectInfo in ipairs(effectOptions) do
    local column = (index - 1) % 3
    local row = math.floor((index - 1) / 3)
    local button = createChoiceButton(geneticsEffectsPanel, 14 + (column * 170), 28 + (row * 24), 160, 20, effectInfo.Label)
    button.TextSize = 10
    pickerButtons["effect_" .. effectInfo.Id] = button
end

local potionSelectPanel = createPanel(potionPage, 12, 330, 562, 94, "Pocoes selecionadas")
local potionOptions = {
    { ItemId = "potion_click", Label = "Click" },
    { ItemId = "potion_golden", Label = "Golden" },
    { ItemId = "potion_luck", Label = "Luck" },
    { ItemId = "potion_drop_chance", Label = "Drop" },
    { ItemId = "potion_production", Label = "Production" },
}

for index, potionInfo in ipairs(potionOptions) do
    local button = createChoiceButton(potionSelectPanel, 14 + ((index - 1) * 108), 40, 98, 28, potionInfo.Label)
    pickerButtons["potion_" .. potionInfo.ItemId] = button
end

local tabNames = {
    "Principal",
    "Automacao",
    "Genetics",
    "Geradores",
    "Upgrade",
    "Sell",
    "Fusao",
    "Loja",
    "Dig",
    "Prestigio",
    "Ascensao",
    "Pocoes",
}

local function showTab(name)
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end

    for tabName, button in pairs(tabs) do
        local active = tabName == name
        button.BackgroundColor3 = active and Color3.fromRGB(76, 95, 228) or Color3.fromRGB(22, 28, 44)
        local uiStroke = button:FindFirstChildOfClass("UIStroke")
        if uiStroke then
            uiStroke.Color = active and Color3.fromRGB(137, 148, 255) or Color3.fromRGB(76, 86, 116)
            uiStroke.Transparency = active and 0.2 or 0.55
        end
    end
end

for index, name in ipairs(tabNames) do
    local button = createTab(name, index == 1)
    tabs[name] = button
    bind(button.MouseButton1Click, function()
        showTab(name)
    end)
end

local function setAllModules(enabled)
    local dataOk = ensureData()
    if not dataOk then
        infoLabels.SummaryStatus.Text = "falha ao carregar data.lua"
        return
    end

    local failedModules = {}

    for _, definition in ipairs(moduleDefinitions) do
        if definition.ModuleName then
            if isTemporarilyDisabled(definition) then
                local loadedModule = Batata.Modules[definition.ModuleName]
                if loadedModule and type(loadedModule.SetEnabled) == "function" then
                    loadedModule:SetEnabled(false)
                end
            else
                local ok, controller = safeEnsure(definition)
                if ok and type(controller.SetEnabled) == "function" then
                    controller:SetEnabled(enabled)
                else
                    table.insert(failedModules, definition.Title)
                end
            end
        end
    end

    if #failedModules > 0 then
        infoLabels.SummaryStatus.Text = "alguns modulos falharam"
        infoLabels.SummaryModules.Text = table.concat(failedModules, ", ")
    end

    pausedSnapshot = nil
    scriptPaused = not enabled
end

setStartupModules = function()
    setAllModules(true)

    local geneticsDefinition = moduleByKey.Genetics
    if geneticsDefinition and geneticsDefinition.ModuleName then
        local geneticsModule = Batata.Modules[geneticsDefinition.ModuleName]
        if geneticsModule and type(geneticsModule.SetEnabled) == "function" then
            geneticsModule:SetEnabled(false)
        end
    end

    pausedSnapshot = nil
    scriptPaused = false
end

local function pauseModules()
    pausedSnapshot = {}

    for _, definition in ipairs(moduleDefinitions) do
        if definition.ModuleName then
            local state = getModuleState(definition)
            pausedSnapshot[definition.ModuleName] = state and state.Enabled == true or false
            local module = Batata.Modules[definition.ModuleName]
            if module and type(module.SetEnabled) == "function" and not isTemporarilyDisabled(definition) then
                module:SetEnabled(false)
            end
        end
    end

    scriptPaused = true
end

local function resumeModules()
    local snapshot = pausedSnapshot
    pausedSnapshot = nil

    if type(snapshot) == "table" then
        for _, definition in ipairs(moduleDefinitions) do
            if definition.ModuleName then
                if isTemporarilyDisabled(definition) then
                    local loadedModule = Batata.Modules[definition.ModuleName]
                    if loadedModule and type(loadedModule.SetEnabled) == "function" then
                        loadedModule:SetEnabled(false)
                    end
                else
                    local ok, controller = safeEnsure(definition)
                    if ok and type(controller.SetEnabled) == "function" then
                        controller:SetEnabled(snapshot[definition.ModuleName] == true)
                    end
                end
            end
        end
    else
        setAllModules(true)
    end

    scriptPaused = false
end

local function stopEverything()
    running = false

    for _, definition in ipairs(moduleDefinitions) do
        if definition.ModuleName then
            local module = Batata.Modules[definition.ModuleName]
            if module and type(module.Stop) == "function" then
                module:Stop()
            end
        end
    end

    disconnectAll()

    if screenGui then
        screenGui:Destroy()
    end

    if Batata.ActiveGui and Batata.ActiveGui.Stop == stopEverything then
        Batata.ActiveGui = nil
    end
end

local function refreshGui()
    mainFrame.Visible = guiVisible

    local currencies = getCurrencySnapshot()
    local profile, profileName = getCurrentProfile()
    statLabels.Cash.Text = formatNumber(currencies.Cash)
    statLabels.MagicPotatoes.Text = formatNumber(currencies.MagicPotatoes)
    statLabels.PrestigePoints.Text = formatNumber(currencies.PrestigePoints)
    statLabels.PotatoEyes.Text = formatNumber(currencies.PotatoEyes)
    statLabels.StarchDust.Text = formatNumber(currencies.StarchDust)

    local enabledCount, total = countEnabledModules()
    statLabels.EnabledCount.Text = tostring(enabledCount) .. "/" .. tostring(total)
    statLabels.PauseState.Text = scriptPaused and "Pausado" or "Rodando"
    infoLabels.SummaryModules.Text = string.format(
        "Perfil %s | GUI %.2fs",
        tostring(profile.Label or profileName),
        tonumber(profile.GuiRefreshInterval) or 0.5
    )

    for buttonProfileName, button in pairs(profileButtons) do
        setChoiceButtonState(button, buttonProfileName == profileName)
    end

    local dataConnected = isDataConnected()
    if not dataConnected then
        if Batata.LastEnsureDataError then
            infoLabels.SummaryStatus.Text = "falha ao carregar data.lua"
            infoLabels.SummaryModules.Text = tostring(Batata.LastEnsureDataError)
        elseif type(Batata.BootErrors) == "table" and Batata.BootErrors["data.lua"] then
            infoLabels.SummaryStatus.Text = "falha no boot web"
            infoLabels.SummaryModules.Text = tostring(Batata.BootErrors["data.lua"])
        else
            infoLabels.SummaryStatus.Text = "data desconectado"
        end
    elseif scriptPaused then
        infoLabels.SummaryStatus.Text = "script pausado"
    elseif enabledCount == total then
        infoLabels.SummaryStatus.Text = "todas automacoes ligadas"
    elseif enabledCount == 0 then
        infoLabels.SummaryStatus.Text = "todas automacoes desligadas"
    else
        infoLabels.SummaryStatus.Text = tostring(enabledCount) .. " modulos ligados"
        if Batata.LastEnsureModuleError then
            infoLabels.SummaryModules.Text = tostring(Batata.LastEnsureModuleError)
        end
    end

    setMasterSwitch(not scriptPaused)

    for _, definition in ipairs(moduleDefinitions) do
        local state = getModuleState(definition)
        local enabled = state and state.Enabled == true or false
        local statusText = isTemporarilyDisabled(definition) and "Temporariamente desativado"
            or state and state.LastStatus
            or (enabled and "Ligado" or "Desligado")

        if moduleRows[definition.Key] and moduleRows[definition.Key].SetSwitch then
            moduleRows[definition.Key].SetSwitch(enabled and not isTemporarilyDisabled(definition))
        end

        if moduleStatusLabels[definition.Key] then
            moduleStatusLabels[definition.Key].Text = tostring(statusText or "-")
        end
    end

    local geneticsState = getModuleState(moduleByKey.Genetics)
    if geneticsState then
        infoLabels.GeneticsExtra.Text = string.format(
            "Slot %s | Bonus %s | Raridade %s",
            tostring(geneticsState.LastSlotIndex or geneticsState.SlotIndex or "-"),
            tostring(geneticsState.LastEffectType or "-"),
            tostring(geneticsState.LastRarity or "-")
        )

        for _, rarity in ipairs(rarityOptions) do
            local button = pickerButtons["rarity_" .. rarity]
            if button then
                setChoiceButtonState(button, geneticsState.SelectedRarities and geneticsState.SelectedRarities[rarity] == true)
            end
        end

        for slotIndex = 1, 8 do
            local button = pickerButtons["slot_" .. tostring(slotIndex)]
            local enabled = false
            if type(geneticsState.SelectedSlots) == "table" then
                for _, value in ipairs(geneticsState.SelectedSlots) do
                    if tonumber(value) == slotIndex then
                        enabled = true
                        break
                    end
                end
            end
            if button then
                setChoiceButtonState(button, enabled)
            end
        end

        for _, effectInfo in ipairs(effectOptions) do
            local button = pickerButtons["effect_" .. effectInfo.Id]
            if button then
                setChoiceButtonState(button, geneticsState.SelectedEffects and geneticsState.SelectedEffects[effectInfo.Id] == true)
            end
        end
    elseif isTemporarilyDisabled(moduleByKey.Genetics) then
        infoLabels.GeneticsExtra.Text = "Modulo pausado para reformulacao"
    else
        infoLabels.GeneticsExtra.Text = "-"
    end

    local farmState = getModuleState(moduleByKey.Farm)
    infoLabels.FarmExtra.Text = farmState and tostring(farmState.CurrentTarget or farmState.LastStatus or "-") or "-"

    local clickState = getModuleState(moduleByKey.Click)
    infoLabels.ClickExtra.Text = clickState and tostring(clickState.LastStatus or "-") or "-"

    local upgradeState = getModuleState(moduleByKey.Upgrade)
    infoLabels.UpgradeExtra.Text = upgradeState and tostring(upgradeState.CurrentTarget or upgradeState.LastStatus or "-") or "-"

    local sellState = getModuleState(moduleByKey.Sell)
    if sellState then
        infoLabels.SellExtra.Text = string.format(
            "Comum %.2f/%.2f | Dourada %.2f/%.2f",
            tonumber(sellState.CommonPrice or 0),
            tonumber(sellState.CommonMinPrice or 0),
            tonumber(sellState.GoldenPrice or 0),
            tonumber(sellState.GoldenMinPrice or 0)
        )
        if not sellGoldenBox:IsFocused() then
            sellGoldenBox.Text = tostring(sellState.GoldenMinPrice or 2)
        end
        if not sellCommonBox:IsFocused() then
            sellCommonBox.Text = tostring(sellState.CommonMinPrice or 0)
        end
        if not sellDelayBox:IsFocused() then
            sellDelayBox.Text = tostring(sellState.Delay or 1)
        end
    else
        infoLabels.SellExtra.Text = "-"
    end

    local fusionState = getModuleState(moduleByKey.Fusion)
    infoLabels.FusionExtra.Text = fusionState and tostring(fusionState.LastMessage or fusionState.LastStatus or "-") or "-"

    local shopState = getModuleState(moduleByKey.Shop)
    infoLabels.ShopExtra.Text = shopState and tostring(shopState.LastStatus or "-") or "-"

    local digState = getModuleState(moduleByKey.Dig)
    if digState then
        infoLabels.DigExtra.Text = string.format(
            "Stamina %s/%s | Ultimo tile %s",
            tostring(math.floor(tonumber(digState.StaminaCurrent or 0))),
            tostring(math.floor(tonumber(digState.StaminaMax or 0))),
            tostring(digState.LastTileTried or "-")
        )
    else
        infoLabels.DigExtra.Text = "-"
    end

    local prestigeState = getModuleState(moduleByKey.Prestige)
    local stats = Batata.Data and Batata.Data.Stats or nil
    infoLabels.PrestigeExtra.Text = string.format(
        "Potential PP %s | Alvo %s",
        formatNumber(stats and stats.PotentialPrestigePoints or 0),
        tostring(prestigeState and prestigeState.TargetValue or 0)
    )
    infoLabels.PrestigeCount.Text = tostring(prestigeState and prestigeState.SessionPrestiges or 0)
    infoLabels.PrestigePointsSession.Text = formatNumber(prestigeState and prestigeState.SessionPrestigePoints or 0)
    infoLabels.PrestigeLastClock.Text = tostring(prestigeState and prestigeState.LastPrestigeClock or "--:--:--")
    infoLabels.PrestigeWait.Text = tostring(math.floor(tonumber(prestigeState and prestigeState.SecondsUntilNextTry or 0))) .. "s"

    local ascensionState = getModuleState(moduleByKey.Ascension)
    infoLabels.AscensionExtra.Text = string.format(
        "PP %s | Custo %s | Blessing %s",
        formatNumber(stats and stats.PrestigePoints or 0),
        formatNumber(stats and stats.AscensionCost or 0),
        tostring(ascensionState and ascensionState.Blessing or "abundance")
    )
    infoLabels.AscensionCount.Text = tostring(ascensionState and ascensionState.SessionAscensions or 0)
    infoLabels.AscensionLastClock.Text = tostring(ascensionState and ascensionState.LastAscensionClock or "--:--:--")
    infoLabels.AscensionPP.Text = formatNumber(stats and stats.PrestigePoints or 0)
    infoLabels.AscensionWait.Text = tostring(math.floor(tonumber(ascensionState and ascensionState.SecondsUntilNextTry or 0))) .. "s"

    for _, blessingInfo in ipairs(ascensionBlessingOptions) do
        local button = pickerButtons["ascension_" .. blessingInfo.Id]
        if button then
            setChoiceButtonState(button, ascensionState and ascensionState.Blessing == blessingInfo.Id)
        end
    end

    local potionState = getModuleState(moduleByKey.Potion)
    if potionState and type(potionState.Buffs) == "table" then
        local count = 0
        for _ in pairs(potionState.Buffs) do
            count = count + 1
        end
        infoLabels.PotionExtra.Text = string.format("Buffs ativos %s | %s", tostring(count), tostring(potionState.LastStatus or "-"))
        for _, potionInfo in ipairs(potionOptions) do
            local button = pickerButtons["potion_" .. potionInfo.ItemId]
            if button then
                setChoiceButtonState(button, potionState.SelectedPotions and potionState.SelectedPotions[potionInfo.ItemId] == true)
            end
        end
    else
        infoLabels.PotionExtra.Text = "-"
    end
end

for _, definition in ipairs(moduleDefinitions) do
    if moduleRows[definition.Key] and moduleRows[definition.Key].Row then
        local function toggleModule()
            if isTemporarilyDisabled(definition) then
                infoLabels.SummaryStatus.Text = "genetics desativada temporariamente"
                return
            end

            if definition.Key == "Data" then
                ensureData()
                return
            end

            local dataOk = ensureData()
            if not dataOk then
                infoLabels.SummaryStatus.Text = "falha ao carregar data.lua"
                return
            end

            local ok, controller = safeEnsure(definition)
            if not ok then
                infoLabels.SummaryStatus.Text = "falha ao carregar " .. string.lower(definition.Key) .. ".lua"
                if Batata.LastEnsureModuleError then
                    infoLabels.SummaryModules.Text = tostring(Batata.LastEnsureModuleError)
                end
                return
            end

            controller:Toggle()
        end

        bind(moduleRows[definition.Key].Row.MouseButton1Click, toggleModule)

        if moduleRows[definition.Key].SwitchButton then
            bind(moduleRows[definition.Key].SwitchButton.MouseButton1Click, toggleModule)
        end
    end
end

bind(masterSwitch.MouseButton1Click, function()
    if scriptPaused then
        resumeModules()
    else
        pauseModules()
    end
end)

bind(allOnButton.MouseButton1Click, function()
    setAllModules(true)
end)

bind(allOffButton.MouseButton1Click, function()
    setAllModules(false)
end)

bind(saveConfigButton.MouseButton1Click, function()
    local saved = saveLocalConfig()
    if saved then
        infoLabels.SummaryStatus.Text = "config salva neste pc"
        infoLabels.SummaryModules.Text = tostring(Batata.LocalConfigPath or "batata/profile.json")
    else
        infoLabels.SummaryStatus.Text = "falha ao salvar config"
        infoLabels.SummaryModules.Text = tostring(Batata.LastConfigError or "erro desconhecido")
    end
end)

bind(reconnectDataButton.MouseButton1Click, function()
    ensureData()
end)

for profileName, button in pairs(profileButtons) do
    bind(button.MouseButton1Click, function()
        Batata.Util.SetDelayProfile(profileName)
        refreshGui()
    end)
end

bind(geneticsSlotBox.FocusLost, function()
    local controller = Batata.Modules.AutoGenetics
    if controller and type(controller.SetSelectedSlotsFromString) == "function" then
        controller:SetSelectedSlotsFromString(geneticsSlotBox.Text)
    end
end)

bind(geneticsEffectBox.FocusLost, function()
    local controller = Batata.Modules.AutoGenetics
    if controller and type(controller.SetSelectedEffectsFromString) == "function" then
        controller:SetSelectedEffectsFromString(geneticsEffectBox.Text)
    end
end)

bind(geneticsRarityBox.FocusLost, function()
    local controller = Batata.Modules.AutoGenetics
    if controller and type(controller.SetSelectedRaritiesFromString) == "function" then
        controller:SetSelectedRaritiesFromString(geneticsRarityBox.Text)
    end
end)

bind(sellGoldenBox.FocusLost, function()
    local controller = Batata.Modules.AutoSell
    if controller and type(controller.SetGoldenMinPrice) == "function" then
        controller:SetGoldenMinPrice(sellGoldenBox.Text)
    end
end)

bind(sellCommonBox.FocusLost, function()
    local controller = Batata.Modules.AutoSell
    if controller and type(controller.SetCommonMinPrice) == "function" then
        controller:SetCommonMinPrice(sellCommonBox.Text)
    end
end)

bind(sellDelayBox.FocusLost, function()
    local controller = Batata.Modules.AutoSell
    if controller and type(controller.SetDelay) == "function" then
        controller:SetDelay(sellDelayBox.Text)
    end
end)

for _, rarity in ipairs(rarityOptions) do
    local button = pickerButtons["rarity_" .. rarity]
    if button then
        bind(button.MouseButton1Click, function()
            local controller = Batata.Modules.AutoGenetics
            if controller and type(controller.SetRarityEnabled) == "function" then
                local state = controller:GetState()
                local enabled = state.SelectedRarities and state.SelectedRarities[rarity] == true
                controller:SetRarityEnabled(rarity, not enabled)
            end
        end)
    end
end

for slotIndex = 1, 8 do
    local button = pickerButtons["slot_" .. tostring(slotIndex)]
    if button then
        bind(button.MouseButton1Click, function()
            local controller = Batata.Modules.AutoGenetics
            if controller and type(controller.SetSlotEnabled) == "function" then
                local state = controller:GetState()
                local enabled = false
                if type(state.SelectedSlots) == "table" then
                    for _, value in ipairs(state.SelectedSlots) do
                        if tonumber(value) == slotIndex then
                            enabled = true
                            break
                        end
                    end
                end
                controller:SetSlotEnabled(slotIndex, not enabled)
            end
        end)
    end
end

for _, effectInfo in ipairs(effectOptions) do
    local button = pickerButtons["effect_" .. effectInfo.Id]
    if button then
        bind(button.MouseButton1Click, function()
            local controller = Batata.Modules.AutoGenetics
            if controller and type(controller.SetEffectEnabled) == "function" then
                local state = controller:GetState()
                local enabled = state.SelectedEffects and state.SelectedEffects[effectInfo.Id] == true
                controller:SetEffectEnabled(effectInfo.Id, not enabled)
            end
        end)
    end
end

for _, blessingInfo in ipairs(ascensionBlessingOptions) do
    local button = pickerButtons["ascension_" .. blessingInfo.Id]
    if button then
        bind(button.MouseButton1Click, function()
            local ok, controller = ensureAscensionController()
            if ok and type(controller.SetBlessing) == "function" then
                controller:SetBlessing(blessingInfo.Id)
                refreshGui()
            end
        end)
    end
end

for _, potionInfo in ipairs(potionOptions) do
    local button = pickerButtons["potion_" .. potionInfo.ItemId]
    if button then
        bind(button.MouseButton1Click, function()
            local controller = Batata.Modules.AutoPotion
            if controller and type(controller.SetPotionEnabled) == "function" then
                local state = controller:GetState()
                local enabled = state.SelectedPotions and state.SelectedPotions[potionInfo.ItemId] == true
                controller:SetPotionEnabled(potionInfo.ItemId, not enabled)
            end
        end)
    end
end

local function setGuiVisible(state)
    guiVisible = state == true
    mainFrame.Visible = guiVisible
end

bind(closeButton.MouseButton1Click, function()
    stopEverything()
end)

bind(minimizeButton.MouseButton1Click, function()
    setGuiVisible(false)
end)

bind(UserInputService.InputBegan, function(input, gameProcessed)
    if not running then
        return
    end

    if input.KeyCode == Enum.KeyCode.Delete then
        setGuiVisible(not guiVisible)
        refreshGui()
        return
    end

    if input.KeyCode == Enum.KeyCode.End then
        if scriptPaused then
            applySavedStartupConfig()
        else
            setAllModules(false)
        end
        refreshGui()
        return
    end

    if gameProcessed then
        return
    end
end)

do
    local dragging = false
    local dragStart
    local startPos

    bind(header.InputBegan, function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position

            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    bind(UserInputService.InputChanged, function(input)
        if not dragging then
            return
        end

        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

showTab("Principal")
refreshGui()

task.spawn(function()
    local ok = false
    for _ = 1, 3 do
        ok = ensureData()
        if ok then
            break
        end
        task.wait(1)
    end

    if ok then
        applySavedStartupConfig()
    end
    refreshGui()
end)

task.spawn(function()
    while running and screenGui.Parent do
        task.wait(getGuiRefreshInterval())
        if guiVisible then
            refreshGui()
        else
            mainFrame.Visible = false
        end
    end
end)

local guiController = {
    Stop = stopEverything,
    Refresh = refreshGui,
}

Batata.ActiveGui = guiController

return guiController
