local Players = game:GetService("Players")

local ROOT = getgenv and getgenv() or _G
local Batata = ROOT.Batata or loadstring(readfile("batata\\shared.lua"), "@batata\\shared.lua")()
ROOT.Batata = Batata
_G.Batata = Batata

if Batata.Modules.AutoNotifications then
    return Batata.Modules.AutoNotifications
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")

local DEFAULT_DELAY = 0.8
local CLOSE_TEXTS = {
    ["x"] = true,
}

local TOAST_PATTERNS = {
    "erro",
    "vendido",
    "comprado",
    "ganhou",
    "melhoria adquirida",
    "gerador adquirido",
    "nenhum slot de gerador disponivel",
    "no generator slots available",
    "you don't own this generator",
    "not enough cash",
}

local Module = {
    Running = true,
    Enabled = false,
    Delay = DEFAULT_DELAY,
    LastStatus = "Aguardando avisos",
    ClosedCount = 0,
}

local connections = {}
local closedRoots = setmetatable({}, { __mode = "k" })

local function disconnectAll()
    for _, connection in ipairs(connections) do
        if connection and connection.Disconnect then
            connection:Disconnect()
        end
    end

    table.clear(connections)
end

local function normalizeText(value)
    local text = string.lower(tostring(value or ""))
    text = string.gsub(text, "%s+", " ")
    text = string.gsub(text, "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

local function isTextGui(instance)
    return instance and (instance:IsA("TextLabel") or instance:IsA("TextButton"))
end

local function matchesToastText(text)
    local normalized = normalizeText(text)
    if normalized == "" then
        return false
    end

    for _, pattern in ipairs(TOAST_PATTERNS) do
        if string.find(normalized, pattern, 1, true) then
            return true
        end
    end

    return false
end

local function isCloseButton(instance)
    if not instance or not instance:IsA("TextButton") then
        return false
    end

    return CLOSE_TEXTS[normalizeText(instance.Text)] == true
end

local function looksLikeToastRoot(instance)
    if not instance or not instance:IsA("GuiObject") then
        return false
    end

    if instance.Visible == false then
        return false
    end

    local size = instance.AbsoluteSize
    if size.X <= 0 or size.Y <= 0 then
        return false
    end

    if size.X > 460 or size.Y > 160 then
        return false
    end

    local hasMatchingText = false
    local hasClose = false

    for _, descendant in ipairs(instance:GetDescendants()) do
        if isCloseButton(descendant) then
            hasClose = true
        elseif isTextGui(descendant) and matchesToastText(descendant.Text) then
            hasMatchingText = true
        end

        if hasMatchingText and hasClose then
            return true
        end
    end

    return false
end

local function findToastRoot(instance)
    local current = instance

    while current and current ~= playerGui do
        if current:IsA("GuiObject") and looksLikeToastRoot(current) then
            return current
        end

        current = current.Parent
    end

    return nil
end

local function suppressToast(root)
    if not root or closedRoots[root] == true then
        return false
    end

    closedRoots[root] = true
    Module.ClosedCount = Module.ClosedCount + 1
    Module.LastStatus = "Fechando aviso"

    pcall(function()
        root.Visible = false
    end)

    task.defer(function()
        if root and root.Parent then
            pcall(function()
                root:Destroy()
            end)
        end
    end)

    return true
end

local function processInstance(instance)
    if Module.Enabled ~= true or Module.Running ~= true then
        return false
    end

    if not isTextGui(instance) or not matchesToastText(instance.Text) then
        return false
    end

    local root = findToastRoot(instance)
    if root then
        return suppressToast(root)
    end

    return false
end

local function scanExistingToasts()
    if Module.Enabled ~= true or Module.Running ~= true then
        return
    end

    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if processInstance(descendant) then
            return
        end
    end

    Module.LastStatus = "Sem avisos"
end

function Module:SetEnabled(enabled)
    self.Enabled = enabled == true
    self.LastStatus = self.Enabled and "Escutando avisos" or "Desligado"

    if self.Enabled then
        scanExistingToasts()
    end
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
    self:SetDelay(profile.NotificationDelay)
end

function Module:GetState()
    return {
        Enabled = self.Enabled == true,
        Running = self.Running == true,
        Delay = self.Delay,
        ClosedCount = self.ClosedCount,
        LastStatus = self.LastStatus,
    }
end

function Module:Stop()
    self.Running = false
    self.Enabled = false
    self.LastStatus = "Desligado"
    disconnectAll()

    if Batata.Modules.AutoNotifications == self then
        Batata.Modules.AutoNotifications = nil
    end
end

table.insert(connections, playerGui.DescendantAdded:Connect(function(instance)
    task.defer(function()
        processInstance(instance)
    end)
end))

Batata.Util.ApplyCurrentDelayProfileToModule(Module)

task.spawn(function()
    while Module.Running do
        scanExistingToasts()
        task.wait(Module.Delay)
    end
end)

Batata.Modules.AutoNotifications = Module

return Module
