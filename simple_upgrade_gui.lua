local UPGRADE_DELAY = 0.05

local UPGRADE_IDS = {
    "stronger_hands",
    "padded_gloves",
    "steel_trowel",
    "golden_touch",
    "collectors_guidebook",
    "lucky_fertilizer",
    "premium_fertilizer",
    "prize_winning_seeds",
    "midas_touch",
    "gilded_instinct",
    "golden_enlightenment",
    "farmers_instinct",
    "golden_trowel",
    "advanced_techniques",
    "grandfathers_wisdom",
    "lunar_planting",
    "dimensional_reach",
    "infinite_energy",
    "omnipotato_blessing",
}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local ROOT = getgenv and getgenv() or _G
local STATE_KEY = "BatataSimpleUpgradeGui"
local GUI_NAME = "BatataSimpleUpgradeGui"

if type(ROOT[STATE_KEY]) == "table" and type(ROOT[STATE_KEY].Stop) == "function" then
    pcall(function()
        ROOT[STATE_KEY]:Stop()
    end)
end

local localPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()
local playerGui = localPlayer:WaitForChild("PlayerGui")
local purchaseRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PurchaseClickUpgrade")

local existingGui = playerGui:FindFirstChild(GUI_NAME)
if existingGui then
    existingGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = GUI_NAME
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 300, 0, 170)
mainFrame.Position = UDim2.new(0, 30, 0, 180)
mainFrame.BackgroundColor3 = Color3.fromRGB(18, 24, 39)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 14)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new("UIStroke")
mainStroke.Color = Color3.fromRGB(78, 92, 130)
mainStroke.Transparency = 0.2
mainStroke.Parent = mainFrame

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 38)
titleBar.BackgroundColor3 = Color3.fromRGB(34, 45, 74)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 14)
titleCorner.Parent = titleBar

local titleFill = Instance.new("Frame")
titleFill.Size = UDim2.new(1, 0, 1, -14)
titleFill.Position = UDim2.new(0, 0, 0, 14)
titleFill.BackgroundColor3 = Color3.fromRGB(34, 45, 74)
titleFill.BorderSizePixel = 0
titleFill.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.new(0, 14, 0, 0)
titleLabel.Size = UDim2.new(1, -28, 1, 0)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Upgrade Simples"
titleLabel.Parent = titleBar

local infoLabel = Instance.new("TextLabel")
infoLabel.BackgroundTransparency = 1
infoLabel.Position = UDim2.new(0, 16, 0, 52)
infoLabel.Size = UDim2.new(1, -32, 0, 20)
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextColor3 = Color3.fromRGB(196, 204, 229)
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.Text = "Delay local: " .. tostring(UPGRADE_DELAY)
infoLabel.Parent = mainFrame

local listLabel = Instance.new("TextLabel")
listLabel.BackgroundTransparency = 1
listLabel.Position = UDim2.new(0, 16, 0, 76)
listLabel.Size = UDim2.new(1, -32, 0, 18)
listLabel.Font = Enum.Font.Gotham
listLabel.TextSize = 11
listLabel.TextColor3 = Color3.fromRGB(138, 149, 177)
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.Text = "IDs na lista: " .. tostring(#UPGRADE_IDS)
listLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.BackgroundTransparency = 1
statusLabel.Position = UDim2.new(0, 16, 0, 100)
statusLabel.Size = UDim2.new(1, -32, 0, 18)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(138, 149, 177)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = "Status: desligado"
statusLabel.Parent = mainFrame

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0, 268, 0, 36)
toggleButton.Position = UDim2.new(0, 16, 0, 126)
toggleButton.BackgroundColor3 = Color3.fromRGB(76, 95, 228)
toggleButton.BorderSizePixel = 0
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 13
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Text = "Ligar Upgrades"
toggleButton.Parent = mainFrame

local buttonCorner = Instance.new("UICorner")
buttonCorner.CornerRadius = UDim.new(0, 10)
buttonCorner.Parent = toggleButton

local buttonStroke = Instance.new("UIStroke")
buttonStroke.Color = Color3.fromRGB(137, 148, 255)
buttonStroke.Transparency = 0.15
buttonStroke.Parent = toggleButton

local Controller = {
    Running = true,
    Enabled = false,
    CurrentTarget = nil,
}

local function refreshButton()
    toggleButton.Text = Controller.Enabled and "Desligar Upgrades" or "Ligar Upgrades"
    toggleButton.BackgroundColor3 = Controller.Enabled and Color3.fromRGB(184, 82, 82) or Color3.fromRGB(76, 95, 228)
    buttonStroke.Color = Controller.Enabled and Color3.fromRGB(219, 121, 121) or Color3.fromRGB(137, 148, 255)
    local current = Controller.CurrentTarget and (" | " .. tostring(Controller.CurrentTarget)) or ""
    statusLabel.Text = "Status: " .. (Controller.Enabled and "rodando" or "desligado") .. current
end

function Controller:SetEnabled(enabled)
    self.Enabled = enabled == true
    if self.Enabled ~= true then
        self.CurrentTarget = nil
    end
    refreshButton()
end

function Controller:Toggle()
    self:SetEnabled(not self.Enabled)
end

function Controller:Stop()
    self.Running = false
    self.Enabled = false
    self.CurrentTarget = nil
    pcall(function()
        screenGui:Destroy()
    end)
    if ROOT[STATE_KEY] == self then
        ROOT[STATE_KEY] = nil
    end
end

ROOT[STATE_KEY] = Controller
refreshButton()

toggleButton.MouseButton1Click:Connect(function()
    Controller:Toggle()
end)

local dragging = false
local dragStart
local startPosition

titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = mainFrame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging ~= true then
        return
    end

    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

task.spawn(function()
    while Controller.Running do
        if Controller.Enabled then
            for _, upgradeId in ipairs(UPGRADE_IDS) do
                if Controller.Running ~= true or Controller.Enabled ~= true then
                    break
                end

                Controller.CurrentTarget = upgradeId
                refreshButton()

                pcall(function()
                    purchaseRemote:FireServer(upgradeId)
                end)

                if tonumber(UPGRADE_DELAY) and tonumber(UPGRADE_DELAY) > 0 then
                    task.wait(tonumber(UPGRADE_DELAY))
                else
                    task.wait()
                end
            end
        else
            task.wait(0.2)
        end
    end
end)

return Controller
